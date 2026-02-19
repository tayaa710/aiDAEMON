import Foundation

// MARK: - MCP Transport Type

public enum MCPTransportType: String, Codable, CaseIterable {
    case stdio
    case http

    var displayName: String {
        switch self {
        case .stdio: return "stdio (local process)"
        case .http: return "HTTP+SSE (remote)"
        }
    }
}

// MARK: - MCP Server Configuration

/// Persistent configuration for a single MCP server.
public struct MCPServerConfig: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var transport: MCPTransportType
    public var command: String?          // stdio: executable (e.g. "npx")
    public var arguments: [String]?      // stdio: arguments (e.g. ["-y", "@modelcontextprotocol/server-filesystem", "/path"])
    public var url: String?              // http: server URL (must be HTTPS)
    public var environmentKeys: [String]? // Names of env vars to inject (values in Keychain)
    public var enabled: Bool

    public init(id: UUID = UUID(), name: String, transport: MCPTransportType,
                command: String? = nil, arguments: [String]? = nil,
                url: String? = nil, environmentKeys: [String]? = nil, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.transport = transport
        self.command = command
        self.arguments = arguments
        self.url = url
        self.environmentKeys = environmentKeys
        self.enabled = enabled
    }
}

// MARK: - MCP Server Status

public enum MCPServerStatus: Equatable {
    case disconnected
    case connecting
    case connected(toolCount: Int)
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected(let count): return "Connected (\(count) tools)"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - MCP Tool Executor

/// Bridges an MCP tool into the ToolRegistry execution interface.
/// Each instance wraps a specific server + tool name pair.
struct MCPToolExecutor: ToolExecutor {
    let serverId: UUID
    let mcpToolName: String

    func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        Task {
            do {
                let result = try await MCPServerManager.shared.callTool(
                    serverId: serverId,
                    toolName: mcpToolName,
                    arguments: arguments
                )
                let text = result.textContent
                completion(result.isError ? .error(text) : .ok(text))
            } catch {
                completion(.error("MCP tool error: \(error.localizedDescription)"))
            }
        }
    }
}

// MARK: - MCP Preset Configurations

public enum MCPPreset: String, CaseIterable, Identifiable {
    case filesystem
    case github
    case braveSearch

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .filesystem: return "Filesystem"
        case .github: return "GitHub"
        case .braveSearch: return "Brave Search"
        }
    }

    var icon: String {
        switch self {
        case .filesystem: return "folder"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .braveSearch: return "magnifyingglass"
        }
    }

    var description: String {
        switch self {
        case .filesystem: return "Read, write, and search files in allowed directories"
        case .github: return "Browse repos, issues, pull requests, and files on GitHub"
        case .braveSearch: return "Search the web using Brave Search API"
        }
    }

    func makeConfig() -> MCPServerConfig {
        switch self {
        case .filesystem:
            let home = NSHomeDirectory()
            return MCPServerConfig(
                name: "Filesystem",
                transport: .stdio,
                command: "npx",
                arguments: ["-y", "@modelcontextprotocol/server-filesystem",
                           home + "/Desktop",
                           home + "/Documents",
                           home + "/Downloads"],
                enabled: true
            )
        case .github:
            return MCPServerConfig(
                name: "GitHub",
                transport: .stdio,
                command: "npx",
                arguments: ["-y", "@modelcontextprotocol/server-github"],
                environmentKeys: ["GITHUB_PERSONAL_ACCESS_TOKEN"],
                enabled: true
            )
        case .braveSearch:
            return MCPServerConfig(
                name: "Brave Search",
                transport: .stdio,
                command: "npx",
                arguments: ["-y", "@modelcontextprotocol/server-brave-search"],
                environmentKeys: ["BRAVE_API_KEY"],
                enabled: true
            )
        }
    }
}

// MARK: - MCP Server Manager

/// Singleton that manages multiple MCP server connections and bridges their tools
/// into the ToolRegistry for seamless use in Claude's tool_use loop.
public final class MCPServerManager: ObservableObject {

    public static let shared = MCPServerManager()

    @Published public private(set) var servers: [MCPServerConfig] = []
    @Published public private(set) var statuses: [UUID: MCPServerStatus] = [:]

    /// Discovered tool names per server (for UI display).
    @Published public private(set) var serverToolNames: [UUID: [String]] = [:]

    private var clients: [UUID: MCPClient] = [:]
    private let configFileName = "mcp-servers.json"

    private init() {
        load()
    }

    // MARK: - Server Management

    /// Add a new server configuration, save, and optionally auto-connect.
    public func addServer(_ config: MCPServerConfig) {
        servers.append(config)
        statuses[config.id] = .disconnected
        save()
        NSLog("MCPServerManager: added server '%@'", config.name)

        if config.enabled {
            Task { await connect(serverId: config.id) }
        }
    }

    /// Remove a server: disconnect, unregister tools, delete config.
    public func removeServer(id: UUID) {
        disconnect(serverId: id)
        servers.removeAll { $0.id == id }
        statuses.removeValue(forKey: id)
        serverToolNames.removeValue(forKey: id)
        save()
        NSLog("MCPServerManager: removed server %@", id.uuidString)
    }

    /// Update an existing server's config. Reconnects if currently connected.
    public func updateServer(_ config: MCPServerConfig) {
        guard let index = servers.firstIndex(where: { $0.id == config.id }) else { return }
        let wasConnected = statuses[config.id]?.isConnected ?? false
        if wasConnected { disconnect(serverId: config.id) }
        servers[index] = config
        save()
        if config.enabled && wasConnected {
            Task { await connect(serverId: config.id) }
        }
    }

    // MARK: - Connection

    /// Connect to a server: create MCPClient, perform handshake, discover tools, register in ToolRegistry.
    public func connect(serverId: UUID) async {
        guard let config = servers.first(where: { $0.id == serverId }) else { return }

        await MainActor.run {
            statuses[serverId] = .connecting
        }

        let client = MCPClient(label: config.name)

        do {
            switch config.transport {
            case .stdio:
                guard let command = config.command, !command.isEmpty else {
                    throw MCPClientError.connectionFailed("No command specified for stdio server.")
                }
                let args = config.arguments ?? []
                let env = resolveEnvironment(config: config)
                try await client.connectStdio(command: command, arguments: args, environment: env)

            case .http:
                guard let urlString = config.url,
                      let url = URL(string: urlString),
                      url.scheme == "https" else {
                    throw MCPClientError.connectionFailed("Invalid or non-HTTPS URL.")
                }
                try await client.connectHTTP(url: url)
            }

            clients[serverId] = client

            // Register discovered tools in ToolRegistry.
            registerMCPTools(serverId: serverId, serverName: config.name, tools: client.discoveredTools)

            let toolNames = client.discoveredTools.map { $0.name }
            let toolCount = toolNames.count

            await MainActor.run {
                statuses[serverId] = .connected(toolCount: toolCount)
                serverToolNames[serverId] = toolNames
            }

            NSLog("MCPServerManager: connected '%@' — %d tools", config.name, toolCount)

        } catch {
            clients.removeValue(forKey: serverId)
            let errorMessage = error.localizedDescription
            await MainActor.run {
                statuses[serverId] = .error(errorMessage)
            }
            NSLog("MCPServerManager: failed to connect '%@': %@", config.name, errorMessage)
        }
    }

    /// Disconnect from a server: close client, unregister tools.
    public func disconnect(serverId: UUID) {
        clients[serverId]?.disconnect()
        clients.removeValue(forKey: serverId)
        unregisterMCPTools(serverId: serverId)

        DispatchQueue.main.async { [weak self] in
            self?.statuses[serverId] = .disconnected
            self?.serverToolNames.removeValue(forKey: serverId)
        }

        let name = servers.first(where: { $0.id == serverId })?.name ?? serverId.uuidString
        NSLog("MCPServerManager: disconnected '%@'", name)
    }

    /// Connect all enabled servers (called on app launch).
    public func connectAllEnabled() async {
        let enabledServers = servers.filter { $0.enabled }
        for server in enabledServers {
            await connect(serverId: server.id)
        }
    }

    /// Disconnect all servers (called on app termination).
    public func disconnectAll() {
        for serverId in clients.keys {
            disconnect(serverId: serverId)
        }
    }

    // MARK: - Tool Call Routing

    /// Route a tool call to the correct MCP server.
    public func callTool(serverId: UUID, toolName: String, arguments: [String: Any]) async throws -> MCPToolResult {
        guard let client = clients[serverId], client.isConnected else {
            throw MCPClientError.notConnected
        }
        return try await client.callTool(name: toolName, arguments: arguments)
    }

    // MARK: - ToolRegistry Integration

    /// Register all tools from an MCP server into ToolRegistry.
    private func registerMCPTools(serverId: UUID, serverName: String, tools: [MCPToolDefinition]) {
        for tool in tools {
            let toolId = MCPClient.toolRegistryId(serverName: serverName, toolName: tool.name)
            let executor = MCPToolExecutor(serverId: serverId, mcpToolName: tool.name)
            ToolRegistry.shared.register(
                toolId: toolId,
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema,
                riskLevel: .caution,
                executor: executor
            )
        }
    }

    /// Unregister all tools for a server from ToolRegistry.
    private func unregisterMCPTools(serverId: UUID) {
        guard let config = servers.first(where: { $0.id == serverId }) else { return }
        let toolNames = serverToolNames[serverId] ?? []
        for toolName in toolNames {
            let toolId = MCPClient.toolRegistryId(serverName: config.name, toolName: toolName)
            ToolRegistry.shared.unregister(toolId: toolId)
        }
    }

    // MARK: - Environment Variable Resolution

    /// Resolve environment variable values from Keychain for a server config.
    private func resolveEnvironment(config: MCPServerConfig) -> [String: String]? {
        guard let keys = config.environmentKeys, !keys.isEmpty else { return nil }
        var env: [String: String] = [:]
        for key in keys {
            let keychainKey = "mcp-env-\(config.id.uuidString)-\(key)"
            if let value = KeychainHelper.load(key: keychainKey) {
                env[key] = value
            }
        }
        return env.isEmpty ? nil : env
    }

    // MARK: - Keychain Helpers for MCP Environment Variables

    /// Save an environment variable value to Keychain for a server.
    public static func saveEnvironmentVariable(serverId: UUID, name: String, value: String) {
        let key = "mcp-env-\(serverId.uuidString)-\(name)"
        KeychainHelper.save(key: key, value: value)
    }

    /// Load an environment variable value from Keychain for a server.
    public static func loadEnvironmentVariable(serverId: UUID, name: String) -> String? {
        let key = "mcp-env-\(serverId.uuidString)-\(name)"
        return KeychainHelper.load(key: key)
    }

    /// Delete an environment variable from Keychain for a server.
    public static func deleteEnvironmentVariable(serverId: UUID, name: String) {
        let key = "mcp-env-\(serverId.uuidString)-\(name)"
        KeychainHelper.delete(key: key)
    }

    // MARK: - Persistence

    public func save() {
        guard let path = configFilePath else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(servers)
            try data.write(to: path, options: .atomic)
            NSLog("MCPServerManager: saved %d server configs", servers.count)
        } catch {
            NSLog("MCPServerManager: save failed — %@", error.localizedDescription)
        }
    }

    public func load() {
        guard let path = configFilePath else { return }
        guard FileManager.default.fileExists(atPath: path.path) else {
            NSLog("MCPServerManager: no config file found, starting fresh")
            return
        }
        do {
            let data = try Data(contentsOf: path)
            servers = try JSONDecoder().decode([MCPServerConfig].self, from: data)
            for server in servers {
                statuses[server.id] = .disconnected
            }
            NSLog("MCPServerManager: loaded %d server configs", servers.count)
        } catch {
            NSLog("MCPServerManager: load failed — %@", error.localizedDescription)
        }
    }

    private var configFilePath: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("com.aidaemon")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(configFileName)
    }
}

// MARK: - Debug Tests

#if DEBUG
extension MCPServerManager {
    public static func runTests() {
        print("\nRunning MCPServerManager tests...")
        var passed = 0
        var failed = 0

        // Test 1: MCPServerConfig encodes/decodes correctly
        do {
            let config = MCPServerConfig(
                name: "Test Server",
                transport: .stdio,
                command: "npx",
                arguments: ["-y", "@test/server"],
                enabled: true
            )
            let data = try JSONEncoder().encode([config])
            let decoded = try JSONDecoder().decode([MCPServerConfig].self, from: data)
            if decoded.count == 1 && decoded[0].name == "Test Server" && decoded[0].transport == .stdio
                && decoded[0].command == "npx" && decoded[0].arguments == ["-y", "@test/server"] {
                print("  ✅ Test 1: MCPServerConfig encode/decode round-trip")
                passed += 1
            } else {
                print("  ❌ Test 1: MCPServerConfig round-trip mismatch")
                failed += 1
            }
        } catch {
            print("  ❌ Test 1: MCPServerConfig codec error: \(error)")
            failed += 1
        }

        // Test 2: Tool registration and unregistration in ToolRegistry
        do {
            struct FakeExec: ToolExecutor {
                func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
                    completion(.ok("fake"))
                }
            }
            let toolId = "mcp__test__read_file"
            let schema: [String: Any] = ["type": "object", "properties": ["path": ["type": "string"]]]
            ToolRegistry.shared.register(
                toolId: toolId, name: "read_file", description: "Read a file",
                inputSchema: schema, riskLevel: .caution, executor: FakeExec()
            )
            let registered = ToolRegistry.shared.isRegistered(toolId)
            ToolRegistry.shared.unregister(toolId: toolId)
            let unregistered = !ToolRegistry.shared.isRegistered(toolId)
            if registered && unregistered {
                print("  ✅ Test 2: MCP tool register/unregister works")
                passed += 1
            } else {
                print("  ❌ Test 2: register=\(registered) unregister=\(unregistered)")
                failed += 1
            }
        }

        // Test 3: anthropicToolDefinitions includes MCP tools with raw schema
        do {
            struct FakeExec: ToolExecutor {
                func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
                    completion(.ok("fake"))
                }
            }
            let toolId = "mcp__test__get_info"
            let schema: [String: Any] = [
                "type": "object",
                "properties": ["query": ["type": "string", "description": "Search query"]],
                "required": ["query"]
            ]
            ToolRegistry.shared.register(
                toolId: toolId, name: "get_info", description: "Get information",
                inputSchema: schema, riskLevel: .caution, executor: FakeExec()
            )
            let defs = ToolRegistry.shared.anthropicToolDefinitions()
            let mcpDef = defs.first { ($0["name"] as? String) == toolId }
            ToolRegistry.shared.unregister(toolId: toolId)

            if let def = mcpDef,
               let inputSchema = def["input_schema"] as? [String: Any],
               inputSchema["type"] as? String == "object",
               let props = inputSchema["properties"] as? [String: Any],
               props["query"] != nil {
                print("  ✅ Test 3: anthropicToolDefinitions includes MCP tool with raw schema")
                passed += 1
            } else {
                print("  ❌ Test 3: MCP tool not found in anthropicToolDefinitions or schema wrong")
                failed += 1
            }
        }

        // Test 4: MCP tool validation skips ToolParameter checks
        do {
            struct FakeExec: ToolExecutor {
                func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
                    completion(.ok("fake"))
                }
            }
            let toolId = "mcp__test__do_thing"
            let schema: [String: Any] = ["type": "object"]
            ToolRegistry.shared.register(
                toolId: toolId, name: "do_thing", description: "Do something",
                inputSchema: schema, riskLevel: .caution, executor: FakeExec()
            )
            let call = ToolCall(toolId: toolId, arguments: ["anything": "works", "number": 42])
            let result = ToolRegistry.shared.validate(call: call)
            ToolRegistry.shared.unregister(toolId: toolId)

            if case .valid = result {
                print("  ✅ Test 4: MCP tool validation passes (skips ToolParameter checks)")
                passed += 1
            } else {
                print("  ❌ Test 4: MCP tool validation should pass for any arguments")
                failed += 1
            }
        }

        // Test 5: MCPPreset configurations are valid
        do {
            let allValid = MCPPreset.allCases.allSatisfy { preset in
                let config = preset.makeConfig()
                return !config.name.isEmpty && config.transport == .stdio && config.command != nil
            }
            if allValid {
                print("  ✅ Test 5: All MCPPreset configs are valid")
                passed += 1
            } else {
                print("  ❌ Test 5: Some MCPPreset configs are invalid")
                failed += 1
            }
        }

        print("\nMCPServerManager results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
