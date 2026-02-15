import Cocoa
import SwiftUI

final class FloatingWindow: NSWindow {
    private static let defaultSize = NSSize(width: 400, height: 80)

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
    }

    func hideWindow() {
        orderOut(nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            hideWindow()
            return
        }

        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        hideWindow()
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
        let hostingView = NSHostingView(rootView: FloatingWindowShellView())
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
}

private struct FloatingWindowShellView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.94))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.secondary)
                Text("aiDAEMON")
                    .font(.headline)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 400, height: 80)
    }
}
