import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var floatingWindow = FloatingWindow()
    private var hotkeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Run debug test suites on launch
        CommandParser.runTests()
        CommandRegistry.runTests()
        FileSearcher.runTests()
        WindowManager.runTests()
        SystemInfo.runTests()
        CommandValidator.runTests()
        ConfirmationState.runTests()
        #endif

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

        // Register command executors
        CommandRegistry.shared.register(AppLauncher(), for: .APP_OPEN)
        CommandRegistry.shared.register(FileSearcher(), for: .FILE_SEARCH)
        CommandRegistry.shared.register(WindowManager(), for: .WINDOW_MANAGE)
        CommandRegistry.shared.register(SystemInfo(), for: .SYSTEM_INFO)

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
