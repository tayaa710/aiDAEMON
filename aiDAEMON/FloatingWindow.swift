import Cocoa
import SwiftUI

final class FloatingWindow: NSWindow {
    private static let defaultSize = NSSize(width: 400, height: 80)
    private static let expandedSize = NSSize(width: 400, height: 360)

    private let commandInputState = CommandInputState()
    private let resultsState = ResultsState()

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
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
        centerOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        commandInputState.requestFocus()
    }

    func hideWindow() {
        orderOut(nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            clearInputAndHide()
            return
        }

        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        clearInputAndHide()
    }

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
                resultsState: resultsState,
                onSubmit: { [weak self] command in
                    self?.handleSubmit(command)
                }
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: Self.defaultSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 14
        hostingView.layer?.masksToBounds = true

        contentView = hostingView
        setContentSize(Self.defaultSize)
    }

    private func centerOnActiveScreen() {
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
            x: visibleFrame.midX - (Self.defaultSize.width / 2),
            y: visibleFrame.midY - (Self.defaultSize.height / 2)
        )

        setFrameOrigin(origin)
    }

    private func clearInputAndHide() {
        commandInputState.clear()
        resultsState.clear()
        resizeForResultsVisibility(hasResults: false, animated: false)
        hideWindow()
    }

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
            resultsState.show(msg, style: .error)
            resizeForResultsVisibility(hasResults: true)
            return
        }

        resultsState.show("Thinking...", style: .loading)
        resizeForResultsVisibility(hasResults: true)

        let prompt = PromptBuilder.buildCommandPrompt(userInput: command)
        NSLog("Prompt built (%d chars) for input: %@", prompt.count, command)

        var streamedOutput = ""
        manager.generate(
            prompt: prompt,
            params: PromptBuilder.commandParams,
            onToken: { [weak self] token in
                DispatchQueue.main.async {
                    streamedOutput += token
                    self?.resultsState.show(streamedOutput, style: .loading)
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleGenerationResult(result, userInput: command)
                }
            }
        )
    }

    private func handleGenerationResult(_ result: Result<String, Error>, userInput: String) {
        switch result {
        case .success(let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                resultsState.show("No response from model. Try rephrasing your command.", style: .error)
                return
            }

            do {
                let command = try CommandParser.parse(trimmed)
                NSLog("Parsed command: %@ target=%@", command.type.rawValue, command.target ?? "(none)")

                let validation = CommandValidator.shared.validate(command)
                switch validation {
                case .rejected(let reason):
                    resultsState.show("Command blocked: \(reason)", style: .error)
                    resizeForResultsVisibility(hasResults: true)
                    return

                case .needsConfirmation(let validCmd, let reason, _):
                    // M023 will add a real confirmation dialog; for now, show reason and proceed
                    NSLog("CommandValidator: needsConfirmation — %@", reason)
                    executeValidatedCommand(validCmd, userInput: userInput)

                case .valid(let validCmd):
                    executeValidatedCommand(validCmd, userInput: userInput)
                }
            } catch {
                NSLog("Parse failed: %@\nRaw output: %@", error.localizedDescription, trimmed)
                resultsState.show(
                    friendlyParseError(error, rawOutput: trimmed),
                    style: .error
                )
            }

        case .failure(let error):
            resultsState.show(
                "Generation failed: \(error.localizedDescription)",
                style: .error
            )
        }
    }

    private func executeValidatedCommand(_ command: Command, userInput: String) {
        let display = formatCommand(command, userInput: userInput)
        resultsState.show(display, style: .loading)

        CommandRegistry.shared.execute(command) { [weak self] execResult in
            DispatchQueue.main.async {
                var msg = display + "\n\n" + execResult.message
                if let details = execResult.details {
                    msg += "\n" + details
                }
                self?.resultsState.show(msg, style: execResult.success ? .success : .error)
            }
        }
    }

    private func formatCommand(_ command: Command, userInput: String) -> String {
        var lines: [String] = []

        lines.append("Understood: \(userInput)")
        lines.append("")
        lines.append("Action: \(readableCommandType(command.type))")

        if let target = command.target {
            lines.append("Target: \(target)")
        }

        if let query = command.query {
            lines.append("Query: \(query)")
        }

        if let params = command.parameters, !params.isEmpty {
            for (key, value) in params {
                lines.append("\(key): \(value.value)")
            }
        }

        if let confidence = command.confidence {
            lines.append("Confidence: \(String(format: "%.0f%%", confidence * 100))")
        }

        return lines.joined(separator: "\n")
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

        return "\(explanation)\nTry rephrasing your command.\n\nRaw output:\n\(rawOutput)"
    }

    private func resizeForResultsVisibility(hasResults: Bool, animated: Bool = true) {
        let targetSize = hasResults ? Self.expandedSize : Self.defaultSize
        let targetFrame = frameCentered(at: frame.center, size: targetSize)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
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

private struct FloatingWindowShellView: View {
    @ObservedObject var commandInputState: CommandInputState
    @ObservedObject var resultsState: ResultsState

    let onSubmit: (String) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.94))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.secondary)

                    CommandInputView(
                        state: commandInputState,
                        onSubmit: onSubmit
                    )
                }

                if let output = resultsState.output {
                    ResultsView(output: output, style: resultsState.style)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: resultsState.hasResults)
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
