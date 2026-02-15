import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var floatingWindow = FloatingWindow()
    private var hotkeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.startListening()

        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .hotkeyPressed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            if self.floatingWindow.isVisible {
                self.floatingWindow.hideWindow()
                NSLog("Floating window hidden")
            } else {
                self.floatingWindow.showOnActiveScreen()
                NSLog("Floating window shown")
            }
        }

        // Load LLM model in background
        LLMManager.shared.loadModelAsync()

        NSLog("aiDAEMON launched successfully")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    deinit {
        if let hotkeyObserver {
            NotificationCenter.default.removeObserver(hotkeyObserver)
        }
    }
}
