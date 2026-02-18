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
    /// Tracks whether the model is currently generating (drives typing indicator).
    private let chatState = ChatWindowState()

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.compactSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        configureContent()
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    func showOnActiveScreen() {
        WindowManager.rememberLastExternalApplication(NSWorkspace.shared.frontmostApplication)
        conversationStore.load()

        // Size the window based on whether there are messages
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

    // MARK: - New Conversation

    func startNewConversation() {
        commandInputState.clear()
        confirmationState.dismiss()
        chatState.isGenerating = false
        conversationStore.clearAll()
        resizeToCompact()
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

    // MARK: - Confirmation Dialog

    private func presentConfirmation(command: Command, userInput: String, reason: String, level: SafetyLevel) {
        NSLog("CommandValidator: needsConfirmation (%@) — %@",
              level == .dangerous ? "dangerous" : "caution", reason)

        confirmationState.present(command: command, userInput: userInput, reason: reason, level: level)

        confirmationState.onApprove = { [weak self] in
            guard let self else { return }
            self.confirmationState.dismiss()
            self.executeValidatedCommand(command, userInput: userInput)
        }

        confirmationState.onCancel = { [weak self] in
            guard let self else { return }
            self.confirmationState.dismiss()
            self.conversationStore.conversation.addAssistantMessage(
                "Action cancelled.", success: false
            )
            self.chatState.isGenerating = false
        }
    }

    // MARK: - Command Submission

    private func handleSubmit(_ command: String) {
        NSLog("Command submitted: %@", command)

        let manager = LLMManager.shared

        guard manager.state == .ready else {
            let msg: String
            switch manager.state {
            case .idle:
                msg = "Model not loaded. Restart app to load model."
            case .loading:
                msg = "Model is still loading, please wait..."
            case .generating:
                msg = "Already generating, please wait..."
            case .error(let detail):
                msg = "Model error: \(detail)"
            case .ready:
                msg = "Ready" // unreachable
            }
            conversationStore.conversation.addUserMessage(command)
            conversationStore.conversation.addAssistantMessage(msg, success: false)
            resizeToChat()
            return
        }

        // Record user message and expand window
        conversationStore.conversation.addUserMessage(command)
        commandInputState.clear()
        chatState.isGenerating = true
        resizeToChat()

        // Build prompt — only include conversation context for the cloud model.
        let recentMessages = conversationStore.conversation.recentMessages()
        let routingDecision = manager.router?.route(input: command)
        let useConversationalPrompt = (routingDecision?.isCloud == true) && recentMessages.count > 1

        let prompt: String
        if useConversationalPrompt {
            let historyMessages = Array(recentMessages.dropLast())
            prompt = PromptBuilder.buildConversationalPrompt(messages: historyMessages, currentInput: command)
        } else {
            prompt = PromptBuilder.buildCommandPrompt(userInput: command)
        }
        NSLog("Prompt built (%d chars, %d history msgs, conversational=%@) for input: %@",
              prompt.count, recentMessages.count - 1, useConversationalPrompt ? "yes" : "no", command)

        let routedProviderName = routingDecision?.provider.providerName ?? "Local"
        let routedWasCloud = routingDecision?.isCloud ?? false

        var streamedOutput = ""
        var didAbortEarly = false
        manager.generate(
            prompt: prompt,
            userInput: command,
            params: PromptBuilder.commandParams,
            onToken: { token in
                DispatchQueue.main.async {
                    guard !didAbortEarly else { return }
                    streamedOutput += token

                    // Early termination: once we have a complete JSON object, stop generating.
                    let trimmed = streamedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
                        if let data = trimmed.data(using: .utf8),
                           (try? JSONSerialization.jsonObject(with: data)) != nil {
                            didAbortEarly = true
                            manager.abort()
                        }
                    }
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    if didAbortEarly {
                        let mgr = LLMManager.shared
                        mgr.setLastProvider(name: routedProviderName, wasCloud: routedWasCloud,
                                            reason: mgr.lastRoutingReason)
                        let captured = streamedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                        self?.handleGenerationResult(.success(captured), userInput: command)
                    } else {
                        self?.handleGenerationResult(result, userInput: command)
                    }
                }
            }
        )
    }

    private func handleGenerationResult(_ result: Result<String, Error>, userInput: String) {
        let manager = LLMManager.shared

        switch result {
        case .success(let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                let errMsg = "No response from model. Try rephrasing your command."
                conversationStore.conversation.addAssistantMessage(
                    errMsg, modelUsed: manager.lastProviderName, wasCloud: manager.lastWasCloud, success: false
                )
                chatState.isGenerating = false
                return
            }

            do {
                let command = try CommandParser.parse(trimmed)
                NSLog("Parsed command: %@ target=%@", command.type.rawValue, command.target ?? "(none)")

                let validation = CommandValidator.shared.validate(command)
                switch validation {
                case .rejected(let reason):
                    let errMsg = "Command blocked: \(reason)"
                    conversationStore.conversation.addAssistantMessage(
                        errMsg, modelUsed: manager.lastProviderName, wasCloud: manager.lastWasCloud, success: false
                    )
                    chatState.isGenerating = false

                case .needsConfirmation(let validCmd, let reason, let level):
                    chatState.isGenerating = false
                    presentConfirmation(command: validCmd, userInput: userInput, reason: reason, level: level)

                case .valid(let validCmd):
                    executeValidatedCommand(validCmd, userInput: userInput)
                }
            } catch {
                NSLog("Parse failed: %@\nRaw output: %@", error.localizedDescription, trimmed)
                let errMsg = friendlyParseError(error, rawOutput: trimmed)
                conversationStore.conversation.addAssistantMessage(
                    errMsg, modelUsed: manager.lastProviderName, wasCloud: manager.lastWasCloud, success: false
                )
                chatState.isGenerating = false
            }

        case .failure(let error):
            let errMsg = "Generation failed: \(error.localizedDescription)"
            conversationStore.conversation.addAssistantMessage(errMsg, success: false)
            chatState.isGenerating = false
        }
    }

    private func executeValidatedCommand(_ command: Command, userInput: String) {
        let action = readableCommandType(command.type)

        let manager = LLMManager.shared
        let providerName = manager.lastProviderName
        let isCloud = manager.lastWasCloud

        CommandRegistry.shared.execute(command) { [weak self] execResult in
            DispatchQueue.main.async {
                let context = "\(userInput) → \(action)"
                var msg = context + "\n\n" + execResult.message
                if let details = execResult.details {
                    msg += "\n" + details
                }

                self?.conversationStore.conversation.addAssistantMessage(
                    msg,
                    modelUsed: providerName,
                    wasCloud: isCloud,
                    toolCall: command.type.rawValue,
                    success: execResult.success
                )
                self?.chatState.isGenerating = false
            }
        }
    }

    private func readableCommandType(_ type: CommandType) -> String {
        switch type {
        case .APP_OPEN: return "Open Application"
        case .FILE_SEARCH: return "Search Files"
        case .WINDOW_MANAGE: return "Manage Window"
        case .SYSTEM_INFO: return "System Information"
        case .FILE_OP: return "File Operation"
        case .PROCESS_MANAGE: return "Manage Process"
        case .QUICK_ACTION: return "Quick Action"
        }
    }

    private func friendlyParseError(_ error: Error, rawOutput: String) -> String {
        let explanation: String
        if let parseError = error as? CommandParserError {
            switch parseError {
            case .invalidJSON:
                explanation = "The model returned an unexpected format."
            case .missingType:
                explanation = "The model response was missing a command type."
            case .unknownCommandType(let type):
                explanation = "Unknown command type: \(type)"
            case .missingRequiredField(let field):
                explanation = "Missing required field: \(field)"
            case .invalidFormat:
                explanation = "The model response had an invalid format."
            }
        } else {
            explanation = error.localizedDescription
        }

        return "\(explanation)\nTry rephrasing your command."
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

    private var hasMessages: Bool {
        !conversation.messages.isEmpty
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.94))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            VStack(spacing: 0) {
                // Header with "New Chat" button (visible when there are messages)
                if hasMessages || chatState.isGenerating {
                    HStack {
                        Text("aiDAEMON")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

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

                // Chat messages area
                if hasMessages || chatState.isGenerating {
                    ChatView(
                        conversation: conversation,
                        isGenerating: chatState.isGenerating
                    )
                    .frame(maxHeight: .infinity)

                    Divider()
                        .padding(.horizontal, 10)
                }

                // Confirmation dialog overlay
                if confirmationState.isPresented {
                    ConfirmationDialogView(state: confirmationState)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }

                // Input bar at the bottom
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
