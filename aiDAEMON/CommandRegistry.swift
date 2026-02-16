import Foundation

// MARK: - Execution Result

/// Result of executing a command
public struct ExecutionResult {
    public let success: Bool
    public let message: String
    public let details: String?

    public init(success: Bool, message: String, details: String? = nil) {
        self.success = success
        self.message = message
        self.details = details
    }

    static func ok(_ message: String, details: String? = nil) -> ExecutionResult {
        ExecutionResult(success: true, message: message, details: details)
    }

    static func error(_ message: String, details: String? = nil) -> ExecutionResult {
        ExecutionResult(success: false, message: message, details: details)
    }
}

// MARK: - Command Executor Protocol

/// Protocol that all command executors must conform to
public protocol CommandExecutor {
    /// Execute the given command and call completion on the main queue
    func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void)

    /// Human-readable name for this executor
    var name: String { get }
}

// MARK: - Placeholder Executor

/// Stub executor used when the real executor hasn't been implemented yet
private struct PlaceholderExecutor: CommandExecutor {
    let commandType: CommandType

    var name: String {
        "Placeholder (\(commandType.rawValue))"
    }

    func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void) {
        let msg = "\(readableType) is not yet implemented."
        completion(.error(msg, details: "Target: \(command.target ?? "(none)")"))
    }

    private var readableType: String {
        switch commandType {
        case .APP_OPEN: return "App Launcher"
        case .FILE_SEARCH: return "File Search"
        case .WINDOW_MANAGE: return "Window Management"
        case .SYSTEM_INFO: return "System Info"
        case .FILE_OP: return "File Operations"
        case .PROCESS_MANAGE: return "Process Management"
        case .QUICK_ACTION: return "Quick Actions"
        }
    }
}

// MARK: - Command Registry

/// Maps CommandType values to their executor implementations.
/// Starts with placeholder executors; real executors are registered as they're built.
public final class CommandRegistry {

    public static let shared = CommandRegistry()

    private var executors: [CommandType: CommandExecutor] = [:]

    private init() {
        // Register placeholder executors for every command type
        for type in CommandType.allCases {
            executors[type] = PlaceholderExecutor(commandType: type)
        }
    }

    /// Register a real executor for a command type, replacing the placeholder
    public func register(_ executor: CommandExecutor, for type: CommandType) {
        executors[type] = executor
        NSLog("CommandRegistry: registered %@ for %@", executor.name, type.rawValue)
    }

    /// Get the executor for a command type
    public func executor(for type: CommandType) -> CommandExecutor {
        guard let executor = executors[type] else {
            // Should never happen since we pre-fill all types, but be safe
            return PlaceholderExecutor(commandType: type)
        }
        return executor
    }

    /// Execute a command by dispatching to the correct executor
    public func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void) {
        let exec = executor(for: command.type)
        NSLog("CommandRegistry: dispatching %@ to %@", command.type.rawValue, exec.name)
        exec.execute(command, completion: completion)
    }

    #if DEBUG
    /// Reset registry to initial state (placeholders only) - for testing
    func resetForTesting() {
        executors.removeAll()
        for type in CommandType.allCases {
            executors[type] = PlaceholderExecutor(commandType: type)
        }
    }
    #endif
}

// MARK: - Debug Tests

#if DEBUG
extension CommandRegistry {
    public static func runTests() {
        print("\nRunning CommandRegistry tests...")
        var passed = 0
        var failed = 0
        let registry = CommandRegistry.shared
        registry.resetForTesting()

        // Test 1: All 7 types have executors
        do {
            let count = CommandType.allCases.count
            guard count == 7 else {
                print("  ❌ Test 1: Expected 7 command types, got \(count)")
                failed += 1
                return
            }
            for type in CommandType.allCases {
                let exec = registry.executor(for: type)
                guard exec.name.contains("Placeholder") else {
                    print("  ❌ Test 1: \(type.rawValue) executor is not placeholder: \(exec.name)")
                    failed += 1
                    return
                }
            }
            print("  ✅ Test 1: All 7 types have placeholder executors")
            passed += 1
        }

        // Test 2: Placeholder executors return error results
        do {
            let cmd = Command(type: .APP_OPEN, target: "Safari", confidence: 0.9)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            registry.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()

            if let r = testResult, !r.success, r.message.contains("not yet implemented") {
                print("  ✅ Test 2: Placeholder returns error with 'not yet implemented'")
                passed += 1
            } else {
                print("  ❌ Test 2: Placeholder did not return expected error")
                failed += 1
            }
        }

        // Test 3: Register custom executor replaces placeholder
        do {
            struct FakeLauncher: CommandExecutor {
                var name: String { "FakeLauncher" }
                func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void) {
                    completion(.ok("Opened \(command.target ?? "unknown")"))
                }
            }

            registry.register(FakeLauncher(), for: .APP_OPEN)
            let exec = registry.executor(for: .APP_OPEN)
            if exec.name == "FakeLauncher" {
                print("  ✅ Test 3: Custom executor replaced placeholder")
                passed += 1
            } else {
                print("  ❌ Test 3: Expected FakeLauncher, got \(exec.name)")
                failed += 1
            }
        }

        // Test 4: Custom executor actually runs and returns success
        do {
            let cmd = Command(type: .APP_OPEN, target: "Safari", confidence: 0.95)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            registry.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()

            if let r = testResult, r.success, r.message == "Opened Safari" {
                print("  ✅ Test 4: Custom executor runs and returns success")
                passed += 1
            } else {
                print("  ❌ Test 4: Custom executor did not return expected result")
                failed += 1
            }
        }

        // Test 5: Other types remain as placeholders after registering one
        do {
            let fileExec = registry.executor(for: .FILE_SEARCH)
            let windowExec = registry.executor(for: .WINDOW_MANAGE)
            if fileExec.name.contains("Placeholder") && windowExec.name.contains("Placeholder") {
                print("  ✅ Test 5: Other types still have placeholder executors")
                passed += 1
            } else {
                print("  ❌ Test 5: Other types were unexpectedly modified")
                failed += 1
            }
        }

        // Test 6: ExecutionResult convenience constructors
        do {
            let ok = ExecutionResult.ok("Done", details: "extra info")
            let err = ExecutionResult.error("Failed")
            if ok.success && ok.message == "Done" && ok.details == "extra info"
                && !err.success && err.message == "Failed" && err.details == nil {
                print("  ✅ Test 6: ExecutionResult .ok() and .error() work correctly")
                passed += 1
            } else {
                print("  ❌ Test 6: ExecutionResult constructors returned unexpected values")
                failed += 1
            }
        }

        // Test 7: Placeholder includes target in details
        do {
            registry.resetForTesting()
            let cmd = Command(type: .SYSTEM_INFO, target: "ip_address", confidence: 0.95)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            registry.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()

            if let r = testResult, let details = r.details, details.contains("ip_address") {
                print("  ✅ Test 7: Placeholder includes target in details")
                passed += 1
            } else {
                print("  ❌ Test 7: Placeholder details missing target")
                failed += 1
            }
        }

        // Test 8: End-to-end parse → dispatch
        do {
            registry.resetForTesting()
            let json = #"{"type": "QUICK_ACTION", "target": "screenshot", "confidence": 0.95}"#
            do {
                let cmd = try CommandParser.parse(json)
                let group = DispatchGroup()
                var testResult: ExecutionResult?
                group.enter()
                registry.execute(cmd) { result in
                    testResult = result
                    group.leave()
                }
                group.wait()

                if let r = testResult, !r.success, r.message.contains("Quick Actions") {
                    print("  ✅ Test 8: End-to-end parse → dispatch works")
                    passed += 1
                } else {
                    print("  ❌ Test 8: End-to-end dispatch returned unexpected result")
                    failed += 1
                }
            } catch {
                print("  ❌ Test 8: Parse failed: \(error)")
                failed += 1
            }
        }

        // Clean up - restore placeholders
        registry.resetForTesting()

        print("\nCommandRegistry results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
