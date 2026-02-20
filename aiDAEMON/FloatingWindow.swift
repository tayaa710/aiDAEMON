import Cocoa
import SwiftUI

final class FloatingWindow: NSWindow {
    /// Compact size: header + input bar (no messages yet).
    private static let compactSize = NSSize(width: 480, height: 90)
    /// Expanded size: chat area + input bar.
    private static let chatSize = NSSize(width: 480, height: 500)
    private static let hotkeyHoldThresholdNs: UInt64 = 250_000_000

    private let commandInputState = CommandInputState()
    private let confirmationState = ConfirmationState()
    private let conversationStore = ConversationStore.shared
    private let chatState = ChatWindowState()
    private let orchestrator = Orchestrator.shared
    private let speechInput = SpeechInput.shared
    private let speechOutput = SpeechOutput.shared

    private var orchestratorTask: Task<Void, Never>?
    private var confirmationContinuation: CheckedContinuation<Bool, Never>?
    private var activationHoldTask: Task<Void, Never>?
    private var voiceStartTask: Task<Void, Never>?
    private var screenCaptureObserver: NSObjectProtocol?
    private var activationKeyIsDown = false
    private var activationStartedVoice = false
    private var submitVoiceTranscriptOnStop = false

    /// The app that was frontmost before the user submitted a command.
    /// Used to re-activate it for computer-control tools (keyboard/mouse).
    private var targetApp: NSRunningApplication?
    /// Whether the window was hidden for a computer-control tool and needs restoring.
    private var windowHiddenForToolExecution = false

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.compactSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        configureContent()
        configureOrchestratorCallbacks()
        configureSpeechCallbacks()
        configureScreenCaptureCallbacks()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func showOnActiveScreen() {
        WindowManager.rememberLastExternalApplication(NSWorkspace.shared.frontmostApplication)
        conversationStore.load()

        let hasMessages = !conversationStore.conversation.messages.isEmpty
        let targetSize = hasMessages ? Self.chatSize : Self.compactSize
        setContentSize(targetSize)

        centerOnActiveScreen(size: targetSize)
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        commandInputState.requestFocus()
    }

    func hideWindow() {
        activationHoldTask?.cancel()
        activationHoldTask = nil
        voiceStartTask?.cancel()
        voiceStartTask = nil
        activationKeyIsDown = false
        activationStartedVoice = false
        stopVoiceInput(shouldSubmit: false)
        speechOutput.stop()
        chatState.isScreenCaptureActive = false
        conversationStore.save()
        orderOut(nil)
    }

    /// Emergency stop for orchestrator execution (triggered by Cmd+Shift+Escape or UI button).
    func emergencyStop() {
        emergencyStop(showMessage: true)
    }

    func handleActivationHotkeyDown() {
        activationHoldTask?.cancel()
        activationKeyIsDown = true
        activationStartedVoice = false

        guard SpeechInput.voiceInputEnabled,
              SpeechInput.pushToTalkStyle == .holdHotkey else {
            return
        }

        activationHoldTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: Self.hotkeyHoldThresholdNs)
            guard !Task.isCancelled else { return }
            guard self.activationKeyIsDown else { return }
            await MainActor.run {
                self.activationStartedVoice = true
                if !self.isVisible {
                    self.showOnActiveScreen()
                }
                self.startVoiceInput(submitOnStop: true)
            }
        }
    }

    func handleActivationHotkeyUp() {
        activationKeyIsDown = false
        activationHoldTask?.cancel()
        activationHoldTask = nil

        if activationStartedVoice {
            activationStartedVoice = false
            stopVoiceInput(shouldSubmit: submitVoiceTranscriptOnStop)
            return
        }

        toggleWindowVisibility()
    }

    override func keyDown(with event: NSEvent) {
        interruptSpeechOnUserInput()

        // Escape key
        if event.keyCode == 53 {
            hideAndPreserve()
            return
        }

        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd+N: new conversation
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "n" {
            startNewConversation()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        hideAndPreserve()
    }

    // MARK: - Conversation / Execution lifecycle

    func startNewConversation() {
        emergencyStop(showMessage: false)
        stopVoiceInput(shouldSubmit: false)
        commandInputState.clear()
        confirmationState.dismiss()
        chatState.isGenerating = false
        conversationStore.clearAll()
        resizeToCompact()
    }

    private func handleSubmit(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        interruptSpeechOnUserInput()
        stopVoiceInput(shouldSubmit: false)

        guard !chatState.isGenerating else {
            conversationStore.conversation.addAssistantMessage(
                "Already working on a request. Use the stop button if you want to cancel it.",
                success: false
            )
            resizeToChat()
            return
        }

        // Capture the most recent non-aiDAEMON app so computer-control tools
        // (keyboard, mouse) can re-activate it before sending events.
        targetApp = WindowManager.rememberedExternalApplication()

        conversationStore.conversation.addUserMessage(trimmed)
        commandInputState.clear()
        chatState.isGenerating = true
        resizeToChat()

        orchestratorTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.orchestrator.handleUserInput(
                text: trimmed,
                conversation: self.conversationStore.conversation
            )

            await MainActor.run {
                self.chatState.isGenerating = false
                self.orchestratorTask = nil

                let shouldAppendMessage = !(result.responseText == "Stopped." && self.lastAssistantMessageIsStopped())
                if shouldAppendMessage {
                    self.conversationStore.conversation.addAssistantMessage(
                        result.responseText,
                        modelUsed: result.modelUsed,
                        wasCloud: result.wasCloud,
                        success: result.success
                    )
                    self.speakAssistantResponseIfEnabled(result.responseText)
                }
                self.commandInputState.requestFocus()
            }
        }
    }

    private func emergencyStop(showMessage: Bool) {
        let wasBusy = chatState.isGenerating || confirmationState.isPresented
        orchestrator.abort()
        orchestratorTask?.cancel()
        orchestratorTask = nil
        stopVoiceInput(shouldSubmit: false)
        speechOutput.stop()

        if confirmationState.isPresented {
            confirmationState.dismiss()
        }
        resolvePendingConfirmation(approved: false)

        chatState.isGenerating = false
        chatState.isScreenCaptureActive = false
        if showMessage && wasBusy && !lastAssistantMessageIsStopped() {
            conversationStore.conversation.addAssistantMessage("Stopped.", success: false)
        }
        commandInputState.requestFocus()
    }

    private func lastAssistantMessageIsStopped() -> Bool {
        guard let last = conversationStore.conversation.messages.last else { return false }
        return last.role == .assistant && last.content == "Stopped."
    }

    // MARK: - Orchestrator callbacks

    private func configureOrchestratorCallbacks() {
        orchestrator.onStatusUpdate = { [weak self] status in
            guard let self else { return }
            self.conversationStore.conversation.addAssistantMessage(status, success: true)
            self.resizeToChat()
        }

        orchestrator.onConfirmationRequest = { [weak self] request in
            guard let self else { return false }
            return await self.awaitConfirmation(for: request)
        }

        orchestrator.onBeforeToolExecution = { [weak self] toolName in
            DispatchQueue.main.async {
                self?.hideForComputerControlTool()
            }
        }

        orchestrator.onAfterTurnComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.restoreAfterComputerControlTool()
            }
        }
    }

    /// Hide the floating window and activate the target app so keyboard/mouse
    /// events reach the correct window instead of aiDAEMON's text field.
    private func hideForComputerControlTool() {
        guard !windowHiddenForToolExecution else { return }
        windowHiddenForToolExecution = true
        orderOut(nil)

        if let app = targetApp, !app.isTerminated {
            app.activate()
        }
    }

    /// Re-show the floating window after computer-control tools are done.
    private func restoreAfterComputerControlTool() {
        guard windowHiddenForToolExecution else { return }
        windowHiddenForToolExecution = false
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        commandInputState.requestFocus()
    }

    private func awaitConfirmation(for request: ToolConfirmationRequest) async -> Bool {
        await MainActor.run {
            self.confirmationState.present(
                toolCall: request.toolCall,
                reason: request.reason,
                level: request.level
            )
            self.resizeToChat()
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.confirmationContinuation = continuation

                self.confirmationState.onApprove = { [weak self] in
                    guard let self else { return }
                    self.confirmationState.dismiss()
                    self.resolvePendingConfirmation(approved: true)
                }

                self.confirmationState.onCancel = { [weak self] in
                    guard let self else { return }
                    self.confirmationState.dismiss()
                    self.resolvePendingConfirmation(approved: false)
                }
            }
        }
    }

    private func resolvePendingConfirmation(approved: Bool) {
        guard let continuation = confirmationContinuation else { return }
        confirmationContinuation = nil
        continuation.resume(returning: approved)
    }

    // MARK: - Voice Input

    private func configureSpeechCallbacks() {
        speechInput.onTranscriptChanged = { [weak self] text in
            guard let self else { return }
            self.commandInputState.text = text
        }

        speechInput.onStopped = { [weak self] transcript, _ in
            guard let self else { return }
            let shouldSubmit = self.submitVoiceTranscriptOnStop
            self.submitVoiceTranscriptOnStop = false

            self.commandInputState.requestFocus()

            guard shouldSubmit else { return }
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            self.handleSubmit(trimmed)
        }

        speechInput.onError = { [weak self] message in
            guard let self else { return }
            self.conversationStore.conversation.addAssistantMessage(message, success: false)
            self.resizeToChat()
            self.commandInputState.requestFocus()
        }
    }

    private func configureScreenCaptureCallbacks() {
        screenCaptureObserver = NotificationCenter.default.addObserver(
            forName: ScreenCapture.activityDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let isActive = (notification.userInfo?[ScreenCapture.activityStateUserInfoKey] as? Bool) ?? false
            self.chatState.isScreenCaptureActive = isActive
        }
    }

    private func startVoiceInput(submitOnStop: Bool) {
        interruptSpeechOnUserInput()

        guard SpeechInput.voiceInputEnabled else {
            conversationStore.conversation.addAssistantMessage(
                "Voice input is disabled. Enable it in Settings → General → Voice Input.",
                success: false
            )
            resizeToChat()
            return
        }

        guard !chatState.isGenerating else {
            conversationStore.conversation.addAssistantMessage(
                "Voice input is unavailable while another request is running.",
                success: false
            )
            resizeToChat()
            return
        }

        submitVoiceTranscriptOnStop = submitOnStop
        commandInputState.text = ""
        commandInputState.requestFocus()

        voiceStartTask?.cancel()
        voiceStartTask = Task { [weak self] in
            guard let self else { return }
            let started = await self.speechInput.startListening()

            await MainActor.run {
                defer { self.voiceStartTask = nil }

                if Task.isCancelled {
                    if started, self.speechInput.isListening {
                        self.speechInput.stopListening(reason: .manual)
                    }
                    self.submitVoiceTranscriptOnStop = false
                    return
                }

                if !started {
                    self.submitVoiceTranscriptOnStop = false
                }
            }
        }
    }

    private func stopVoiceInput(shouldSubmit: Bool) {
        voiceStartTask?.cancel()
        voiceStartTask = nil
        submitVoiceTranscriptOnStop = shouldSubmit
        if speechInput.isListening {
            speechInput.stopListening()
        }
    }

    private func toggleVoiceInputFromButton() {
        if speechInput.isListening {
            stopVoiceInput(shouldSubmit: true)
        } else {
            startVoiceInput(submitOnStop: true)
        }
    }

    private func setVoiceModeEnabled(_ enabled: Bool) {
        SpeechOutput.setVoiceModeEnabled(enabled)
        if !enabled {
            stopVoiceInput(shouldSubmit: false)
            speechOutput.stop()
        }
    }

    private func interruptSpeechOnUserInput() {
        speechOutput.stop()
    }

    private func speakAssistantResponseIfEnabled(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        speechOutput.speak(text: cleaned)
    }

    private func toggleWindowVisibility() {
        if isVisible {
            hideWindow()
            NSLog("Floating window hidden")
        } else {
            showOnActiveScreen()
            NSLog("Floating window shown")
        }
    }

    // MARK: - Window Configuration

    private func configureWindow() {
        isReleasedWhenClosed = false
        level = .floating
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        animationBehavior = .utilityWindow
        collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
    }

    private func configureContent() {
        let hostingView = NSHostingView(
            rootView: FloatingWindowShellView(
                commandInputState: commandInputState,
                confirmationState: confirmationState,
                conversation: conversationStore.conversation,
                chatState: chatState,
                speechInput: speechInput,
                speechOutput: speechOutput,
                onSubmit: { [weak self] command in
                    self?.handleSubmit(command)
                },
                onNewConversation: { [weak self] in
                    self?.startNewConversation()
                },
                onKillSwitch: { [weak self] in
                    self?.emergencyStop()
                },
                onVoiceButtonTap: { [weak self] in
                    self?.toggleVoiceInputFromButton()
                },
                onVoiceModeToggle: { [weak self] enabled in
                    self?.setVoiceModeEnabled(enabled)
                },
                onStopSpeaking: { [weak self] in
                    self?.speechOutput.stop()
                },
                onUserInputDetected: { [weak self] in
                    self?.interruptSpeechOnUserInput()
                }
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: Self.compactSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 14
        hostingView.layer?.masksToBounds = true

        contentView = hostingView
        setContentSize(Self.compactSize)
    }

    private func centerOnActiveScreen(size: NSSize? = nil) {
        let targetSize = size ?? frame.size
        let pointerLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let activeScreen else {
            center()
            return
        }

        let visibleFrame = activeScreen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - (targetSize.width / 2),
            y: visibleFrame.midY - (targetSize.height / 2)
        )

        setFrameOrigin(origin)
    }

    /// Hide the window but preserve conversation — Escape key behavior.
    private func hideAndPreserve() {
        commandInputState.clear()
        confirmationState.dismiss()
        conversationStore.save()
        hideWindow()
    }

    // MARK: - Window Resizing

    private func resizeToChat(animated: Bool = true) {
        let targetFrame = frameCentered(at: frame.center, size: Self.chatSize)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(targetFrame, display: true)
            }
        } else {
            setFrame(targetFrame, display: true)
        }
    }

    private func resizeToCompact(animated: Bool = true) {
        let targetFrame = frameCentered(at: frame.center, size: Self.compactSize)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(targetFrame, display: true)
            }
        } else {
            setFrame(targetFrame, display: true)
        }
    }

    private func frameCentered(at center: NSPoint, size: NSSize) -> NSRect {
        NSRect(
            x: center.x - (size.width / 2),
            y: center.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    deinit {
        if let screenCaptureObserver {
            NotificationCenter.default.removeObserver(screenCaptureObserver)
        }
    }
}

// MARK: - Chat Window State

/// Observable state shared between FloatingWindow (controller) and the SwiftUI shell view.
final class ChatWindowState: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var isScreenCaptureActive: Bool = false
}

// MARK: - Shell View

private struct FloatingWindowShellView: View {
    @ObservedObject var commandInputState: CommandInputState
    @ObservedObject var confirmationState: ConfirmationState
    @ObservedObject var conversation: Conversation
    @ObservedObject var chatState: ChatWindowState
    @ObservedObject var speechInput: SpeechInput
    @ObservedObject var speechOutput: SpeechOutput

    let onSubmit: (String) -> Void
    let onNewConversation: () -> Void
    let onKillSwitch: () -> Void
    let onVoiceButtonTap: () -> Void
    let onVoiceModeToggle: (Bool) -> Void
    let onStopSpeaking: () -> Void
    let onUserInputDetected: () -> Void

    @AppStorage(SpeechInput.voiceEnabledDefaultsKey)
    private var voiceInputEnabled: Bool = true

    @AppStorage(SpeechOutput.voiceModeDefaultsKey)
    private var voiceModeEnabled: Bool = false

    @AppStorage(SpeechInput.pushToTalkStyleDefaultsKey)
    private var pushToTalkStyleRawValue: String = VoicePushToTalkStyle.holdHotkey.rawValue

    private var hasMessages: Bool {
        !conversation.messages.isEmpty
    }

    private var selectedPushToTalkStyle: VoicePushToTalkStyle {
        VoicePushToTalkStyle(rawValue: pushToTalkStyleRawValue) ?? .holdHotkey
    }

    private var showsMicrophoneButton: Bool {
        guard voiceInputEnabled else { return false }
        return selectedPushToTalkStyle == .clickButton || speechInput.isListening
    }

    private var voiceModeTitle: String {
        voiceModeEnabled ? "Voice On" : "Voice Off"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.94))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            VStack(spacing: 0) {
                HStack {
                    Text("aiDAEMON")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if chatState.isScreenCaptureActive {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9))
                            Text("Vision")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.16))
                        )
                        .help("Screen capture is active")
                    }

                    Spacer()

                    Button {
                        let enabled = !voiceModeEnabled
                        voiceModeEnabled = enabled
                        onVoiceModeToggle(enabled)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: voiceModeEnabled ? "waveform.and.mic" : "waveform.slash")
                                .font(.system(size: 10))
                            Text(voiceModeTitle)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(voiceModeEnabled ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((voiceModeEnabled ? Color.green : Color.secondary).opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle voice mode (voice input + voice output)")

                    if speechOutput.isSpeaking {
                        Button(action: onStopSpeaking) {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.slash.fill")
                                    .font(.system(size: 10))
                                Text("Mute")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Stop speech immediately")
                    }

                    if chatState.isGenerating {
                        Button(action: onKillSwitch) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 10))
                                Text("Stop")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.red)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Emergency stop (Cmd+Shift+Escape)")
                    }

                    if hasMessages || chatState.isGenerating {
                        Button(action: onNewConversation) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus.bubble")
                                    .font(.system(size: 10))
                                Text("New Chat")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                        .help("New conversation (Cmd+N)")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if hasMessages || chatState.isGenerating {
                    ChatView(
                        conversation: conversation,
                        isGenerating: chatState.isGenerating
                    )
                    .frame(maxHeight: .infinity)

                    Divider()
                        .padding(.horizontal, 10)
                }

                if confirmationState.isPresented {
                    ConfirmationDialogView(state: confirmationState)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }

                if let ttsError = speechOutput.lastErrorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text(ttsError)
                            .font(.system(size: 10))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            speechOutput.clearError()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }

                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.secondary)

                    CommandInputView(
                        state: commandInputState,
                        speechInput: speechInput,
                        showsMicrophoneButton: showsMicrophoneButton,
                        onVoiceButtonTap: onVoiceButtonTap,
                        onUserInputDetected: onUserInputDetected,
                        onSubmit: onSubmit
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, hasMessages ? 10 : 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
