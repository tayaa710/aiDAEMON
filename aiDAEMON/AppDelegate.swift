import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.startListening()

        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .hotkeyPressed,
            object: nil,
            queue: .main
        ) { _ in
            NSLog("Hotkey notification received")
        }

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
