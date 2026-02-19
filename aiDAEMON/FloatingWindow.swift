import Cocoa
import SwiftUI

final class FloatingWindow: NSWindow {
    /// Compact size: just the input bar (no messages).
    private static let compactSize = NSSize(width: 480, height: 56)
    /// Expanded size: chat area + input bar.
    private static let chatSize = NSSize(width: 480, height: 500)

    private let commandInputState = CommandInputState()
    private let confirmationState = ConfirmationState()
    private let conversationStore = ConversationStore.shared
    private let chatState = ChatWindowState()
    private let orchestrator = Orchestrator.shared

    private var orchestratorTask: Task<Void, Never>?
    private var confirmationContinuation: CheckedContinuation<Bool, Never>?

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
        conversationStore.save()
        orderOut(nil)
    }

    /// Emergency stop for orchestrator execution (triggered by Cmd+Shift+Escape or UI button).
    func emergencyStop() {
        emergencyStop(showMessage: true)
    }

    override func keyDown(with event: NSEvent) {
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
        commandInputState.clear()
        confirmationState.dismiss()
        chatState.isGenerating = false
        conversationStore.clearAll()
        resizeToCompact()
    }

    private func handleSubmit(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard !chatState.isGenerating else {
            conversationStore.conversation.addAssistantMessage(
                "Already working on a request. Use the stop button if you want to cancel it.",
                success: false
            )
            resizeToChat()
            return
        }

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

                if !(result.responseText == "Stopped." && self.lastAssistantMessageIsStopped()) {
                    self.conversationStore.conversation.addAssistantMessage(
                        result.responseText,
                        modelUsed: result.modelUsed,
                        wasCloud: result.wasCloud,
                        success: result.success
                    )
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

        if confirmationState.isPresented {
            confirmationState.dismiss()
        }
        resolvePendingConfirmation(approved: false)

        chatState.isGenerating = false
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
                onSubmit: { [weak self] command in
                    self?.handleSubmit(command)
                },
                onNewConversation: { [weak self] in
                    self?.startNewConversation()
                },
                onKillSwitch: { [weak self] in
                    self?.emergencyStop()
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
}

// MARK: - Chat Window State

/// Observable state shared between FloatingWindow (controller) and the SwiftUI shell view.
final class ChatWindowState: ObservableObject {
    @Published var isGenerating: Bool = false
}

// MARK: - Shell View

private struct FloatingWindowShellView: View {
    @ObservedObject var commandInputState: CommandInputState
    @ObservedObject var confirmationState: ConfirmationState
    @ObservedObject var conversation: Conversation
    @ObservedObject var chatState: ChatWindowState

    let onSubmit: (String) -> Void
    let onNewConversation: () -> Void
    let onKillSwitch: () -> Void

    private var hasMessages: Bool {
        !conversation.messages.isEmpty
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.94))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            VStack(spacing: 0) {
                if hasMessages || chatState.isGenerating {
                    HStack {
                        Text("aiDAEMON")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

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
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                }

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

                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.secondary)

                    CommandInputView(
                        state: commandInputState,
                        onSubmit: onSubmit
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, hasMessages ? 10 : 16)
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
