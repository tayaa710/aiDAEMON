import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var floatingWindow = FloatingWindow()
    private var hotkeyDownObserver: NSObjectProtocol?
    private var hotkeyUpObserver: NSObjectProtocol?
    private var killSwitchObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Run debug test suites on launch
        CommandParser.runTests()
        CommandRegistry.runTests()
        FileSearcher.runTests()
        WindowManager.runTests()
        SystemInfo.runTests()
        CommandValidator.runTests()
        ToolDefinition.runTests()
        ToolRegistry.runTests()
        ConfirmationState.runTests()
        ResultsView.runTests()
        MCPClient.runTests()
        MCPServerManager.runTests()
        #endif

        HotkeyManager.shared.startListening()

        hotkeyDownObserver = NotificationCenter.default.addObserver(
            forName: .hotkeyPressedDown,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.floatingWindow.handleActivationHotkeyDown()
        }

        hotkeyUpObserver = NotificationCenter.default.addObserver(
            forName: .hotkeyPressedUp,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.floatingWindow.handleActivationHotkeyUp()
        }

        killSwitchObserver = NotificationCenter.default.addObserver(
            forName: .killSwitchPressed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.floatingWindow.emergencyStop()
        }

        // Register command executors (legacy CommandRegistry — kept for backward compatibility)
        let appLauncher = AppLauncher()
        let fileSearcher = FileSearcher()
        let windowManager = WindowManager()
        let systemInfo = SystemInfo()
        let screenCapture = ScreenCapture()

        CommandRegistry.shared.register(appLauncher, for: .APP_OPEN)
        CommandRegistry.shared.register(fileSearcher, for: .FILE_SEARCH)
        CommandRegistry.shared.register(windowManager, for: .WINDOW_MANAGE)
        CommandRegistry.shared.register(systemInfo, for: .SYSTEM_INFO)

        // Register tools in new ToolRegistry (used by orchestrator / planner in M033+)
        ToolRegistry.shared.register(tool: .appOpen, commandType: .APP_OPEN, commandExecutor: appLauncher)
        ToolRegistry.shared.register(tool: .fileSearch, commandType: .FILE_SEARCH, commandExecutor: fileSearcher)
        ToolRegistry.shared.register(tool: .windowManage, commandType: .WINDOW_MANAGE, commandExecutor: windowManager)
        ToolRegistry.shared.register(tool: .systemInfo, commandType: .SYSTEM_INFO, commandExecutor: systemInfo)
        ToolRegistry.shared.register(tool: .screenCapture, executor: screenCapture)

        // Load LLM model in background
        LLMManager.shared.loadModelAsync()

        // Connect enabled MCP servers in background
        Task {
            await MCPServerManager.shared.connectAllEnabled()
        }

        NSLog("aiDAEMON launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up MCP server child processes before exit.
        MCPServerManager.shared.disconnectAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    deinit {
        if let hotkeyDownObserver {
            NotificationCenter.default.removeObserver(hotkeyDownObserver)
        }
        if let hotkeyUpObserver {
            NotificationCenter.default.removeObserver(hotkeyUpObserver)
        }
        if let killSwitchObserver {
            NotificationCenter.default.removeObserver(killSwitchObserver)
        }
    }
}
