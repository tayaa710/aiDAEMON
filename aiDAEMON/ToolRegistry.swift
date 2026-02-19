import Foundation

// MARK: - Tool Executor Protocol

/// Protocol that tool executors must conform to.
/// Bridges between the new ToolRegistry and existing CommandExecutor-based executors.
public protocol ToolExecutor {
    /// Execute the tool with the given arguments.
    func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void)
}

// MARK: - Command Executor Adapter

/// Adapts an existing CommandExecutor to the new ToolExecutor interface.
/// Translates tool arguments into a Command struct for backward-compatible execution.
struct CommandExecutorAdapter: ToolExecutor {
    let commandType: CommandType
    let executor: CommandExecutor

    func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        // Build a Command from the tool arguments
        let target = arguments["target"] as? String
        let query = arguments["query"] as? String

        // Convert remaining arguments to AnyCodable parameters
        var params: [String: AnyCodable]? = nil
        let reservedKeys: Set<String> = ["target", "query"]
        let extraArgs = arguments.filter { !reservedKeys.contains($0.key) }
        if !extraArgs.isEmpty {
            params = extraArgs.mapValues { AnyCodable($0) }
        }

        let command = Command(
            type: commandType,
            target: target,
            query: query,
            parameters: params,
            confidence: 1.0
        )

        executor.execute(command, completion: completion)
    }
}

// MARK: - Registered Tool

/// A tool definition paired with its executor.
struct RegisteredTool {
    let definition: ToolDefinition
    let executor: ToolExecutor
}

// MARK: - Tool Registry

/// Registry of all available tools. Replaces CommandRegistry for new code paths.
/// Provides tool definitions for the planner prompt and dispatches validated tool calls.
public final class ToolRegistry {

    public static let shared = ToolRegistry()

    private var tools: [String: RegisteredTool] = [:]

    /// Raw JSON Schema `input_schema` for MCP tools (bypasses ToolParameter conversion).
    private var rawSchemas: [String: [String: Any]] = [:]

    private init() {}

    // MARK: - Registration

    /// Register a tool with its definition and executor.
    public func register(tool: ToolDefinition, executor: ToolExecutor) {
        tools[tool.id] = RegisteredTool(definition: tool, executor: executor)
        NSLog("ToolRegistry: registered tool '%@' (%@)", tool.id, tool.name)
    }

    /// Convenience: register an existing CommandExecutor as a tool.
    public func register(tool: ToolDefinition, commandType: CommandType, commandExecutor: CommandExecutor) {
        let adapter = CommandExecutorAdapter(commandType: commandType, executor: commandExecutor)
        register(tool: tool, executor: adapter)
    }

    /// Register an MCP tool using its raw JSON Schema input_schema directly.
    /// MCP servers provide JSON Schema; converting to ToolParameter and back would be lossy.
    public func register(toolId: String, name: String, description: String,
                         inputSchema: [String: Any], riskLevel: RiskLevel,
                         executor: ToolExecutor) {
        let definition = ToolDefinition(
            id: toolId,
            name: name,
            description: description,
            parameters: [],        // Not used for MCP tools — raw schema is authoritative.
            riskLevel: riskLevel,
            requiredPermissions: []
        )
        tools[toolId] = RegisteredTool(definition: definition, executor: executor)
        rawSchemas[toolId] = inputSchema
        NSLog("ToolRegistry: registered MCP tool '%@' (%@)", toolId, name)
    }

    /// Unregister a tool by ID. Called when an MCP server disconnects.
    public func unregister(toolId: String) {
        if tools.removeValue(forKey: toolId) != nil {
            rawSchemas.removeValue(forKey: toolId)
            NSLog("ToolRegistry: unregistered tool '%@'", toolId)
        }
    }

    // MARK: - Queries

    /// Return definitions for all registered tools (used by planner prompts).
    public func allTools() -> [ToolDefinition] {
        tools.values.map { $0.definition }.sorted { $0.id < $1.id }
    }

    /// Get the executor for a tool ID, or nil if not registered.
    public func executor(for toolId: String) -> ToolExecutor? {
        tools[toolId]?.executor
    }

    /// Get the definition for a tool ID, or nil if not registered.
    public func definition(for toolId: String) -> ToolDefinition? {
        tools[toolId]?.definition
    }

    /// Check if a tool ID is registered.
    public func isRegistered(_ toolId: String) -> Bool {
        tools[toolId] != nil
    }

    // MARK: - Validation

    /// Validate a ToolCall against the tool's schema.
    public func validate(call: ToolCall) -> ToolValidationResult {
        // Check tool exists
        guard let registered = tools[call.toolId] else {
            return .invalid(reason: "Unknown tool: '\(call.toolId)'")
        }

        // MCP tools use raw JSON Schema — the server validates arguments itself.
        if rawSchemas[call.toolId] != nil {
            return .valid
        }

        let definition = registered.definition

        // Check required parameters are present
        for param in definition.parameters where param.required {
            guard let value = call.arguments[param.name] else {
                return .invalid(reason: "Missing required parameter '\(param.name)' for tool '\(definition.id)'")
            }

            // Check type
            if let typeError = validateType(value: value, expected: param.type, paramName: param.name) {
                return .invalid(reason: typeError)
            }
        }

        // Check provided arguments have correct types (even optional ones)
        for (key, value) in call.arguments {
            guard let param = definition.parameters.first(where: { $0.name == key }) else {
                // Extra arguments are silently ignored (flexible for model output)
                continue
            }
            if let typeError = validateType(value: value, expected: param.type, paramName: param.name) {
                return .invalid(reason: typeError)
            }
        }

        return .valid
    }

    /// Validate that a value matches the expected parameter type.
    private func validateType(value: Any, expected: ParameterType, paramName: String) -> String? {
        switch expected {
        case .string:
            if !(value is String) {
                return "Parameter '\(paramName)' must be a string, got \(type(of: value))"
            }
        case .int:
            if !(value is Int) {
                return "Parameter '\(paramName)' must be an integer, got \(type(of: value))"
            }
        case .bool:
            if !(value is Bool) {
                return "Parameter '\(paramName)' must be a boolean, got \(type(of: value))"
            }
        case .double:
            if !(value is Double) && !(value is Int) {
                return "Parameter '\(paramName)' must be a number, got \(type(of: value))"
            }
        case .enumeration(let allowed):
            guard let strValue = value as? String else {
                return "Parameter '\(paramName)' must be a string (one of: \(allowed.joined(separator: ", ")))"
            }
            if !allowed.contains(strValue) {
                return "Parameter '\(paramName)' value '\(strValue)' is not one of: \(allowed.joined(separator: ", "))"
            }
        }
        return nil
    }

    // MARK: - Execution

    /// Execute a validated tool call. Caller should validate first.
    public func execute(call: ToolCall, completion: @escaping (ExecutionResult) -> Void) {
        guard let registered = tools[call.toolId] else {
            completion(.error("Unknown tool: '\(call.toolId)'"))
            return
        }

        NSLog("ToolRegistry: executing tool '%@'", call.toolId)
        registered.executor.execute(arguments: call.arguments, completion: completion)
    }

    // MARK: - Prompt Generation

    /// Generate a text description of all tools for inclusion in planner prompts.
    public func toolDescriptionsForPrompt() -> String {
        let toolList = allTools()
        guard !toolList.isEmpty else { return "No tools available." }

        var lines: [String] = ["Available tools:"]
        for tool in toolList {
            lines.append("")
            lines.append("- \(tool.id): \(tool.description)")
            let paramDescs = tool.parameters.map { p in
                let req = p.required ? "required" : "optional"
                let typeStr: String
                switch p.type {
                case .string: typeStr = "string"
                case .int: typeStr = "integer"
                case .bool: typeStr = "boolean"
                case .double: typeStr = "number"
                case .enumeration(let vals): typeStr = "one of: \(vals.joined(separator: ", "))"
                }
                return "    \(p.name) (\(typeStr), \(req)): \(p.description)"
            }
            lines.append(contentsOf: paramDescs)
        }
        return lines.joined(separator: "\n")
    }

    /// Convert registered tools into Anthropic Messages API `tools` definitions.
    ///
    /// Output format:
    /// [
    ///   {
    ///     "name": "app_open",
    ///     "description": "...",
    ///     "input_schema": {
    ///       "type": "object",
    ///       "properties": { ... },
    ///       "required": [...]
    ///     }
    ///   }
    /// ]
    public func anthropicToolDefinitions() -> [[String: Any]] {
        allTools().map { tool in
            // MCP tools: use the raw JSON Schema directly (avoids lossy conversion).
            if let rawSchema = rawSchemas[tool.id] {
                return [
                    "name": tool.id,
                    "description": tool.description,
                    "input_schema": rawSchema
                ]
            }

            // Built-in tools: build input_schema from ToolParameter definitions.
            var properties: [String: Any] = [:]
            var required: [String] = []

            for parameter in tool.parameters {
                var schema: [String: Any] = [
                    "description": parameter.description
                ]

                switch parameter.type {
                case .string:
                    schema["type"] = "string"
                case .int:
                    schema["type"] = "integer"
                case .bool:
                    schema["type"] = "boolean"
                case .double:
                    schema["type"] = "number"
                case .enumeration(let values):
                    schema["type"] = "string"
                    schema["enum"] = values
                }

                properties[parameter.name] = schema
                if parameter.required {
                    required.append(parameter.name)
                }
            }

            var inputSchema: [String: Any] = [
                "type": "object",
                "properties": properties
            ]
            if !required.isEmpty {
                inputSchema["required"] = required.sorted()
            }

            return [
                "name": tool.id,
                "description": tool.description,
                "input_schema": inputSchema
            ]
        }
    }

    #if DEBUG
    /// Reset registry to empty state — for testing only.
    func resetForTesting() {
        tools.removeAll()
        rawSchemas.removeAll()
    }
    #endif
}

// MARK: - Debug Tests

#if DEBUG
extension ToolRegistry {
    public static func runTests() {
        print("\nRunning ToolRegistry tests...")
        var passed = 0
        var failed = 0
        let registry = ToolRegistry.shared
        registry.resetForTesting()

        // Helper: fake executor that always succeeds
        struct FakeExecutor: ToolExecutor {
            let result: String
            func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
                completion(.ok(result))
            }
        }

        // Test 1: Register a tool and retrieve it
        do {
            registry.register(tool: .appOpen, executor: FakeExecutor(result: "opened"))
            if registry.isRegistered("app_open") {
                print("  ✅ Test 1: Tool registered and found")
                passed += 1
            } else {
                print("  ❌ Test 1: Tool not found after registration")
                failed += 1
            }
        }

        // Test 2: allTools returns registered tools
        do {
            registry.register(tool: .systemInfo, executor: FakeExecutor(result: "info"))
            let all = registry.allTools()
            if all.count == 2 && all.contains(where: { $0.id == "app_open" })
                && all.contains(where: { $0.id == "system_info" }) {
                print("  ✅ Test 2: allTools returns 2 registered tools")
                passed += 1
            } else {
                print("  ❌ Test 2: allTools returned \(all.count) tools: \(all.map { $0.id })")
                failed += 1
            }
        }

        // Test 3: Validate valid tool call
        do {
            let call = ToolCall(toolId: "app_open", arguments: ["target": "Safari"])
            if case .valid = registry.validate(call: call) {
                print("  ✅ Test 3: Valid tool call passes validation")
                passed += 1
            } else {
                print("  ❌ Test 3: Valid tool call should pass")
                failed += 1
            }
        }

        // Test 4: Validate missing required parameter
        do {
            let call = ToolCall(toolId: "app_open", arguments: [:])
            if case .invalid(let reason) = registry.validate(call: call), reason.contains("target") {
                print("  ✅ Test 4: Missing required param detected")
                passed += 1
            } else {
                print("  ❌ Test 4: Should detect missing required param")
                failed += 1
            }
        }

        // Test 5: Validate unknown tool
        do {
            let call = ToolCall(toolId: "nonexistent_tool", arguments: [:])
            if case .invalid(let reason) = registry.validate(call: call), reason.contains("Unknown") {
                print("  ✅ Test 5: Unknown tool ID detected")
                passed += 1
            } else {
                print("  ❌ Test 5: Should detect unknown tool")
                failed += 1
            }
        }

        // Test 6: Validate wrong type for parameter
        do {
            let call = ToolCall(toolId: "app_open", arguments: ["target": 42])
            if case .invalid(let reason) = registry.validate(call: call), reason.contains("string") {
                print("  ✅ Test 6: Wrong parameter type detected")
                passed += 1
            } else {
                print("  ❌ Test 6: Should detect wrong parameter type")
                failed += 1
            }
        }

        // Test 7: Validate enum parameter with invalid value
        do {
            registry.register(tool: .windowManage, executor: FakeExecutor(result: "moved"))
            let call = ToolCall(toolId: "window_manage", arguments: ["position": "upside_down"])
            if case .invalid(let reason) = registry.validate(call: call), reason.contains("not one of") {
                print("  ✅ Test 7: Invalid enum value detected")
                passed += 1
            } else {
                print("  ❌ Test 7: Should detect invalid enum value")
                failed += 1
            }
        }

        // Test 8: Validate enum parameter with valid value
        do {
            let call = ToolCall(toolId: "window_manage", arguments: ["position": "left_half"])
            if case .valid = registry.validate(call: call) {
                print("  ✅ Test 8: Valid enum value passes validation")
                passed += 1
            } else {
                print("  ❌ Test 8: Valid enum value should pass")
                failed += 1
            }
        }

        // Test 9: Execute dispatches to correct executor
        do {
            let call = ToolCall(toolId: "app_open", arguments: ["target": "Safari"])
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            registry.execute(call: call) { result in
                testResult = result
                group.leave()
            }
            group.wait()
            if let r = testResult, r.success, r.message == "opened" {
                print("  ✅ Test 9: Execute dispatches to correct executor")
                passed += 1
            } else {
                print("  ❌ Test 9: Execution result unexpected")
                failed += 1
            }
        }

        // Test 10: Execute unknown tool returns error
        do {
            let call = ToolCall(toolId: "does_not_exist", arguments: [:])
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            registry.execute(call: call) { result in
                testResult = result
                group.leave()
            }
            group.wait()
            if let r = testResult, !r.success, r.message.contains("Unknown") {
                print("  ✅ Test 10: Unknown tool execution returns error")
                passed += 1
            } else {
                print("  ❌ Test 10: Should return error for unknown tool")
                failed += 1
            }
        }

        // Test 11: toolDescriptionsForPrompt returns non-empty string
        do {
            let desc = registry.toolDescriptionsForPrompt()
            if desc.contains("app_open") && desc.contains("window_manage") && desc.contains("Available tools") {
                print("  ✅ Test 11: toolDescriptionsForPrompt includes registered tools")
                passed += 1
            } else {
                print("  ❌ Test 11: toolDescriptionsForPrompt output unexpected")
                failed += 1
            }
        }

        // Test 12: CommandExecutorAdapter bridges correctly
        do {
            registry.resetForTesting()
            struct FakeCommandExecutor: CommandExecutor {
                var name: String { "FakeCmdExec" }
                func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void) {
                    let t = command.target ?? "none"
                    completion(.ok("Executed \(command.type.rawValue) on \(t)"))
                }
            }
            registry.register(tool: .appOpen, commandType: .APP_OPEN, commandExecutor: FakeCommandExecutor())
            let call = ToolCall(toolId: "app_open", arguments: ["target": "Chrome"])
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            registry.execute(call: call) { result in
                testResult = result
                group.leave()
            }
            group.wait()
            if let r = testResult, r.success, r.message.contains("Chrome") && r.message.contains("APP_OPEN") {
                print("  ✅ Test 12: CommandExecutorAdapter bridges arguments correctly")
                passed += 1
            } else {
                print("  ❌ Test 12: Adapter result unexpected: \(testResult?.message ?? "nil")")
                failed += 1
            }
        }

        // Clean up
        registry.resetForTesting()

        print("\nToolRegistry results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
