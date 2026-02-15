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

        resultsState.show("Generating...", style: .success)
        resizeForResultsVisibility(hasResults: true)

        var streamedOutput = ""
        manager.generate(
            prompt: command,
            onToken: { [weak self] token in
                DispatchQueue.main.async {
                    streamedOutput += token
                    self?.resultsState.show(streamedOutput, style: .success)
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let output):
                        let finalOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        self?.resultsState.show(
                            finalOutput.isEmpty ? "(empty response)" : finalOutput,
                            style: .success
                        )
                    case .failure(let error):
                        self?.resultsState.show(
                            "Generation failed: \(error.localizedDescription)",
                            style: .error
                        )
                    }
                }
            }
        )
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
