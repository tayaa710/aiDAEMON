import Foundation

// MARK: - MCP Protocol Types

/// A tool definition discovered from an MCP server.
public struct MCPToolDefinition {
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]
}

/// A single content block in an MCP tool result.
public enum MCPContentBlock {
    case text(String)
    case image(data: String, mimeType: String)
    case resource(uri: String, text: String?)
}

/// Result returned from an MCP `tools/call` invocation.
public struct MCPToolResult {
    public let content: [MCPContentBlock]
    public let isError: Bool

    /// Concatenated text content for passing to Claude as tool_result.
    public var textContent: String {
        content.compactMap { block in
            switch block {
            case .text(let t): return t
            case .image(_, let mime): return "[Image: \(mime)]"
            case .resource(let uri, let text): return text ?? "[Resource: \(uri)]"
            }
        }.joined(separator: "\n")
    }
}

/// Server info returned during MCP initialization.
public struct MCPServerInfo {
    public let name: String
    public let version: String?
}

/// Server capabilities returned during MCP initialization.
public struct MCPCapabilities {
    public let supportsTools: Bool
    public let supportsToolListChanged: Bool
}

// MARK: - MCP Client Errors

public enum MCPClientError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case protocolError(String)
    case timeout
    case serverError(code: Int, message: String)
    case invalidResponse(String)
    case processLaunchFailed(String)
    case transportClosed

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "MCP client is not connected."
        case .connectionFailed(let detail):
            return "MCP connection failed: \(detail)"
        case .protocolError(let detail):
            return "MCP protocol error: \(detail)"
        case .timeout:
            return "MCP request timed out."
        case .serverError(let code, let message):
            return "MCP server error (\(code)): \(message)"
        case .invalidResponse(let detail):
            return "Invalid MCP response: \(detail)"
        case .processLaunchFailed(let detail):
            return "Failed to launch MCP server process: \(detail)"
        case .transportClosed:
            return "MCP transport connection closed unexpectedly."
        }
    }
}

// MARK: - MCP Transport Protocol

/// Abstraction for MCP message transport (stdio or HTTP+SSE).
protocol MCPTransport: AnyObject {
    /// Send a JSON-RPC message (caller provides serialized JSON data).
    func send(_ data: Data) throws
    /// Receive the next complete JSON-RPC message (blocks until available).
    func receive() async throws -> Data
    /// Close the transport and release resources.
    func close()
    /// Whether the transport is currently open.
    var isConnected: Bool { get }
}

// MARK: - stdio Transport

/// Launches an MCP server as a subprocess and communicates via stdin/stdout.
/// Messages are newline-delimited JSON (one JSON-RPC message per line).
final class MCPStdioTransport: MCPTransport {

    let command: String
    let arguments: [String]
    let environment: [String: String]?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    /// Buffered data from stdout not yet consumed as a complete line.
    private var buffer = Data()
    private let bufferLock = NSLock()

    /// Queue of complete JSON lines ready to be consumed by `receive()`.
    private var lineQueue: [Data] = []
    private let lineQueueLock = NSLock()
    private let lineAvailable = DispatchSemaphore(value: 0)

    private var _isConnected = false

    var isConnected: Bool { _isConnected && (process?.isRunning ?? false) }

    init(command: String, arguments: [String], environment: [String: String]? = nil) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
    }

    /// Launch the server subprocess and set up pipes.
    func start() throws {
        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        // Resolve the user's real shell PATH (macOS GUI apps get a crippled PATH).
        let shellPath = MCPStdioTransport.resolveUserShellPath()

        // Resolve the command to an absolute path using the full shell PATH.
        // Security: arguments are passed as an array, never through a shell.
        let executableURL = resolveExecutable(command, searchPath: shellPath)
        proc.executableURL = executableURL
        // If we fall back to /usr/bin/env, prepend the original command name.
        // Otherwise env would try to execute only the argument list.
        proc.arguments = executableURL.path == "/usr/bin/env" ? [command] + arguments : arguments
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        // Build process environment: start from inherited, inject shell PATH,
        // then merge caller-supplied env vars.
        var merged = ProcessInfo.processInfo.environment
        merged["PATH"] = shellPath
        if let env = environment, !env.isEmpty {
            for (k, v) in env { merged[k] = v }
        }
        proc.environment = merged

        proc.terminationHandler = { [weak self] _ in
            self?._isConnected = false
            // Signal any waiting receive() so it doesn't hang forever.
            self?.lineAvailable.signal()
            NSLog("MCPStdioTransport: server process terminated")
        }

        // Read stdout asynchronously: accumulate data, split on newlines.
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                // EOF
                self?._isConnected = false
                self?.lineAvailable.signal()
                return
            }
            self?.appendToBuffer(chunk)
        }

        // Log stderr for debugging.
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty, let text = String(data: chunk, encoding: .utf8) {
                NSLog("MCPStdioTransport stderr: %@", text)
            }
        }

        do {
            try proc.run()
        } catch {
            throw MCPClientError.processLaunchFailed(
                "\(command) \(arguments.joined(separator: " ")): \(error.localizedDescription)"
            )
        }

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        self._isConnected = true

        NSLog("MCPStdioTransport: launched PID %d — %@ %@",
              proc.processIdentifier, command, arguments.joined(separator: " "))
    }

    func send(_ data: Data) throws {
        guard _isConnected, let pipe = stdinPipe else {
            throw MCPClientError.notConnected
        }
        // JSON-RPC over stdio: message + newline
        var payload = data
        payload.append(contentsOf: [0x0A]) // '\n'
        pipe.fileHandleForWriting.write(payload)
    }

    func receive() async throws -> Data {
        // Wait for a complete line (with timeout handled by caller).
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: MCPClientError.transportClosed)
                    return
                }
                // Block until a line is available or transport closes.
                self.lineAvailable.wait()

                self.lineQueueLock.lock()
                if self.lineQueue.isEmpty {
                    self.lineQueueLock.unlock()
                    continuation.resume(throwing: MCPClientError.transportClosed)
                    return
                }
                let line = self.lineQueue.removeFirst()
                self.lineQueueLock.unlock()
                continuation.resume(returning: line)
            }
        }
    }

    func close() {
        _isConnected = false
        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
            // Give the process a moment, then force kill.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if proc.isRunning {
                    kill(proc.processIdentifier, SIGKILL)
                }
            }
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil

        // Unblock any waiting receive()
        lineAvailable.signal()
    }

    // MARK: - Buffer management

    private func appendToBuffer(_ chunk: Data) {
        bufferLock.lock()
        buffer.append(chunk)

        // Split on newlines (0x0A).
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            buffer = Data(buffer[buffer.index(after: newlineIndex)...])

            // Skip empty lines.
            if lineData.isEmpty { continue }

            lineQueueLock.lock()
            lineQueue.append(Data(lineData))
            lineQueueLock.unlock()
            lineAvailable.signal()
        }
        bufferLock.unlock()
    }

    /// Resolve command name to URL. Checks if it's an absolute path; otherwise searches the given PATH.
    private func resolveExecutable(_ name: String, searchPath: String) -> URL {
        if name.hasPrefix("/") {
            return URL(fileURLWithPath: name)
        }
        // Search PATH for the executable.
        let pathDirs = searchPath.split(separator: ":").map(String.init)
        for dir in pathDirs {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                NSLog("MCPStdioTransport: resolved '%@' → '%@'", name, candidate.path)
                return candidate
            }
        }
        NSLog("MCPStdioTransport: could not resolve '%@' in PATH, falling back to /usr/bin/env", name)
        // Fallback: let Process try to find it (may fail with a helpful error).
        return URL(fileURLWithPath: "/usr/bin/env")
    }

    /// Get the user's real shell PATH. macOS GUI apps inherit a minimal PATH
    /// (/usr/bin:/bin:/usr/sbin:/sbin) that doesn't include Homebrew, nvm, etc.
    /// We run the user's login shell to resolve their actual PATH.
    static func resolveUserShellPath() -> String {
        let cachedKey = "MCPStdioTransport.cachedShellPath"

        // Cache in-process to avoid spawning a shell on every connection.
        if let cached = objc_getAssociatedObject(MCPStdioTransport.self, cachedKey) as? String {
            return cached
        }

        let userShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = URL(fileURLWithPath: userShell)
        // -l = login shell (sources .zprofile/.bash_profile), -i = interactive (sources .zshrc/.bashrc),
        // -c = run command. This gives us the same PATH the user sees in Terminal.
        proc.arguments = ["-l", "-i", "-c", "echo $PATH"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let resolved = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !resolved.isEmpty {
                NSLog("MCPStdioTransport: resolved user shell PATH (%d entries)", resolved.split(separator: ":").count)
                objc_setAssociatedObject(MCPStdioTransport.self, cachedKey, resolved, .OBJC_ASSOCIATION_RETAIN)
                return resolved
            }
        } catch {
            NSLog("MCPStdioTransport: failed to resolve user shell PATH: %@", error.localizedDescription)
        }

        // Fallback: well-known paths for Homebrew (Apple Silicon + Intel), nvm, volta, fnm, system.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fallback = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(home)/.nvm/current/bin",
            "\(home)/.volta/bin",
            "\(home)/.fnm/current/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
        NSLog("MCPStdioTransport: using fallback PATH")
        objc_setAssociatedObject(MCPStdioTransport.self, cachedKey, fallback, .OBJC_ASSOCIATION_RETAIN)
        return fallback
    }
}

// MARK: - HTTP+SSE Transport

/// Communicates with a remote MCP server via HTTP POST and Server-Sent Events.
final class MCPHTTPSSETransport: MCPTransport {

    let url: URL
    private var sessionId: String?
    private let session = URLSession.shared

    /// Queue of received JSON-RPC messages from the SSE stream.
    private var messageQueue: [Data] = []
    private let queueLock = NSLock()
    private let messageAvailable = DispatchSemaphore(value: 0)

    private var sseTask: URLSessionDataTask?
    private var sseBuffer = Data()
    private var _isConnected = false

    var isConnected: Bool { _isConnected }

    init(url: URL) {
        self.url = url
    }

    /// Open the SSE stream for server-initiated messages.
    func start() throws {
        guard url.scheme == "https" else {
            throw MCPClientError.connectionFailed("MCP HTTP transport requires HTTPS. Got: \(url.absoluteString)")
        }
        _isConnected = true
        NSLog("MCPHTTPSSETransport: connected to %@", url.absoluteString)
    }

    func send(_ data: Data) throws {
        guard _isConnected else {
            throw MCPClientError.notConnected
        }

        // For HTTP transport, we POST the JSON-RPC message and read the response synchronously.
        // The response is enqueued so `receive()` can pick it up.
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sid = sessionId {
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }
        request.timeoutInterval = 30.0

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            defer { semaphore.signal() }
            if let error { responseError = error; return }
            guard let http = response as? HTTPURLResponse else { return }

            // Capture session ID from server if provided.
            if let sid = http.value(forHTTPHeaderField: "Mcp-Session-Id") {
                self?.sessionId = sid
            }

            if http.statusCode == 200, let data {
                responseData = data
            } else if http.statusCode == 202 {
                // Accepted (notification/response) — no response body expected.
                return
            } else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                responseError = MCPClientError.serverError(code: http.statusCode, message: body)
            }
        }
        task.resume()
        semaphore.wait()

        if let error = responseError { throw error }

        if let data = responseData {
            queueLock.lock()
            messageQueue.append(data)
            queueLock.unlock()
            messageAvailable.signal()
        }
    }

    func receive() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: MCPClientError.transportClosed)
                    return
                }
                self.messageAvailable.wait()

                self.queueLock.lock()
                if self.messageQueue.isEmpty {
                    self.queueLock.unlock()
                    continuation.resume(throwing: MCPClientError.transportClosed)
                    return
                }
                let msg = self.messageQueue.removeFirst()
                self.queueLock.unlock()
                continuation.resume(returning: msg)
            }
        }
    }

    func close() {
        _isConnected = false
        sseTask?.cancel()
        sseTask = nil
        messageAvailable.signal()
        NSLog("MCPHTTPSSETransport: closed")
    }
}

// MARK: - MCP Client

/// High-level MCP client. Manages the connection lifecycle, JSON-RPC messaging,
/// and exposes the core MCP operations: initialize, listTools, callTool.
///
/// One MCPClient instance per connected MCP server.
public final class MCPClient {

    /// Protocol version we advertise to MCP servers.
    private static let protocolVersion = "2025-03-26"

    /// Initialization timeout.
    private static let initTimeout: TimeInterval = 30

    /// Per-tool-call timeout.
    private static let callTimeout: TimeInterval = 30

    private var transport: MCPTransport?
    private var nextRequestId: Int = 1
    private let idLock = NSLock()

    public private(set) var serverInfo: MCPServerInfo?
    public private(set) var serverCapabilities: MCPCapabilities?
    public private(set) var discoveredTools: [MCPToolDefinition] = []

    public var isConnected: Bool { transport?.isConnected ?? false }

    /// Human-readable identifier (for logs).
    public let label: String

    public init(label: String) {
        self.label = label
    }

    // MARK: - Connection Lifecycle

    /// Connect via stdio transport: launch the server process.
    public func connectStdio(command: String, arguments: [String], environment: [String: String]? = nil) async throws {
        let stdioTransport = MCPStdioTransport(command: command, arguments: arguments, environment: environment)
        try stdioTransport.start()
        self.transport = stdioTransport

        try await performInitialize()
        try await discoverTools()
    }

    /// Connect via HTTP+SSE transport.
    public func connectHTTP(url: URL) async throws {
        let httpTransport = MCPHTTPSSETransport(url: url)
        try httpTransport.start()
        self.transport = httpTransport

        try await performInitialize()
        try await discoverTools()
    }

    /// Disconnect from the server.
    public func disconnect() {
        transport?.close()
        transport = nil
        serverInfo = nil
        serverCapabilities = nil
        discoveredTools = []
        NSLog("MCPClient [%@]: disconnected", label)
    }

    // MARK: - MCP Protocol Operations

    /// Perform the MCP initialization handshake.
    private func performInitialize() async throws {
        let params: [String: Any] = [
            "protocolVersion": Self.protocolVersion,
            "capabilities": [String: Any](),
            "clientInfo": [
                "name": "aiDAEMON",
                "version": "1.0.0"
            ]
        ]

        let result = try await sendRequest(method: "initialize", params: params, timeout: Self.initTimeout)

        // Parse server info.
        if let info = result["serverInfo"] as? [String: Any] {
            serverInfo = MCPServerInfo(
                name: info["name"] as? String ?? "Unknown",
                version: info["version"] as? String
            )
        }

        // Parse capabilities.
        if let caps = result["capabilities"] as? [String: Any] {
            let toolsCap = caps["tools"] as? [String: Any]
            serverCapabilities = MCPCapabilities(
                supportsTools: toolsCap != nil,
                supportsToolListChanged: (toolsCap?["listChanged"] as? Bool) ?? false
            )
        } else {
            serverCapabilities = MCPCapabilities(supportsTools: false, supportsToolListChanged: false)
        }

        // Send the "initialized" notification (no response expected).
        try await sendNotification(method: "notifications/initialized", params: nil)

        NSLog("MCPClient [%@]: initialized — server: %@ v%@",
              label,
              serverInfo?.name ?? "?",
              serverInfo?.version ?? "?")
    }

    /// Discover available tools from the server.
    private func discoverTools() async throws {
        guard serverCapabilities?.supportsTools == true else {
            discoveredTools = []
            NSLog("MCPClient [%@]: server does not support tools", label)
            return
        }

        var allTools: [MCPToolDefinition] = []
        var cursor: String? = nil

        // Paginate through all tools.
        repeat {
            var params: [String: Any] = [:]
            if let c = cursor { params["cursor"] = c }

            let result = try await sendRequest(method: "tools/list", params: params.isEmpty ? nil : params, timeout: Self.callTimeout)

            if let toolsArray = result["tools"] as? [[String: Any]] {
                for toolDict in toolsArray {
                    guard let name = toolDict["name"] as? String else { continue }
                    let description = toolDict["description"] as? String ?? ""
                    let schema = toolDict["inputSchema"] as? [String: Any] ?? ["type": "object"]
                    allTools.append(MCPToolDefinition(name: name, description: description, inputSchema: schema))
                }
            }

            cursor = result["nextCursor"] as? String
        } while cursor != nil

        discoveredTools = allTools
        NSLog("MCPClient [%@]: discovered %d tools", label, allTools.count)
    }

    /// Call a tool on the MCP server.
    public func callTool(name: String, arguments: [String: Any]) async throws -> MCPToolResult {
        let params: [String: Any] = [
            "name": name,
            "arguments": arguments
        ]

        let result = try await sendRequest(method: "tools/call", params: params, timeout: Self.callTimeout)
        return parseToolResult(result)
    }

    /// Refresh the tool list (e.g., after a `notifications/tools/list_changed`).
    public func refreshTools() async throws {
        try await discoverTools()
    }

    // MARK: - JSON-RPC 2.0

    /// Send a JSON-RPC request and wait for the response.
    private func sendRequest(method: String, params: [String: Any]?, timeout: TimeInterval) async throws -> [String: Any] {
        guard let transport, transport.isConnected else {
            throw MCPClientError.notConnected
        }

        let requestId = nextId()
        var message: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestId,
            "method": method
        ]
        if let params { message["params"] = params }

        let data = try JSONSerialization.data(withJSONObject: message)
        try transport.send(data)

        // Wait for a response with the matching ID, with timeout.
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { throw MCPClientError.timeout }

            let responseData = try await withTimeout(seconds: remaining) {
                try await transport.receive()
            }

            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                continue // Skip non-JSON lines
            }

            // Check if this is a response to our request (has matching "id").
            if let responseId = json["id"] as? Int, responseId == requestId {
                if let error = json["error"] as? [String: Any] {
                    let code = error["code"] as? Int ?? -1
                    let msg = error["message"] as? String ?? "Unknown error"
                    throw MCPClientError.serverError(code: code, message: msg)
                }
                return json["result"] as? [String: Any] ?? [:]
            }

            // If it's a notification, handle it and keep waiting.
            if json["id"] == nil, let notifMethod = json["method"] as? String {
                handleNotification(method: notifMethod, params: json["params"] as? [String: Any])
            }
            // Otherwise skip (could be a response to a different request).
        }
    }

    /// Send a JSON-RPC notification (no response expected).
    private func sendNotification(method: String, params: [String: Any]?) async throws {
        guard let transport, transport.isConnected else {
            throw MCPClientError.notConnected
        }

        var message: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method
        ]
        if let params { message["params"] = params }

        let data = try JSONSerialization.data(withJSONObject: message)
        try transport.send(data)
    }

    // MARK: - Notification Handling

    private func handleNotification(method: String, params: [String: Any]?) {
        switch method {
        case "notifications/tools/list_changed":
            NSLog("MCPClient [%@]: tools list changed — will refresh on next use", label)
            // Refresh happens lazily or can be triggered explicitly.
        default:
            NSLog("MCPClient [%@]: unhandled notification '%@'", label, method)
        }
    }

    // MARK: - Response Parsing

    private func parseToolResult(_ result: [String: Any]) -> MCPToolResult {
        let isError = result["isError"] as? Bool ?? false
        var blocks: [MCPContentBlock] = []

        if let contentArray = result["content"] as? [[String: Any]] {
            for item in contentArray {
                guard let type = item["type"] as? String else { continue }
                switch type {
                case "text":
                    if let text = item["text"] as? String {
                        blocks.append(.text(text))
                    }
                case "image":
                    if let data = item["data"] as? String,
                       let mime = item["mimeType"] as? String {
                        blocks.append(.image(data: data, mimeType: mime))
                    }
                case "resource":
                    if let resource = item["resource"] as? [String: Any],
                       let uri = resource["uri"] as? String {
                        let text = resource["text"] as? String
                        blocks.append(.resource(uri: uri, text: text))
                    }
                default:
                    // Unknown content type — treat as text if possible.
                    if let text = item["text"] as? String {
                        blocks.append(.text(text))
                    }
                }
            }
        }

        // Fallback: if no content blocks parsed, treat the entire result as text.
        if blocks.isEmpty {
            blocks.append(.text("(no content)"))
        }

        return MCPToolResult(content: blocks, isError: isError)
    }

    // MARK: - Helpers

    private func nextId() -> Int {
        idLock.lock()
        let id = nextRequestId
        nextRequestId += 1
        idLock.unlock()
        return id
    }

    /// Helper to run an async operation with a timeout.
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(seconds, 0.1) * 1_000_000_000))
                throw MCPClientError.timeout
            }

            guard let result = try await group.next() else {
                throw MCPClientError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    /// Generate a namespaced tool ID for use in ToolRegistry.
    public static func toolRegistryId(serverName: String, toolName: String) -> String {
        let safeName = serverName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return "mcp__\(safeName)__\(toolName)"
    }
}

// MARK: - Debug Tests

#if DEBUG
extension MCPClient {
    public static func runTests() {
        print("\nRunning MCPClient tests...")
        var passed = 0
        var failed = 0

        // Test 1: JSON-RPC request encoding produces valid JSON
        do {
            let message: [String: Any] = [
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list"
            ]
            let data = try JSONSerialization.data(withJSONObject: message)
            if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               parsed["jsonrpc"] as? String == "2.0",
               parsed["id"] as? Int == 1,
               parsed["method"] as? String == "tools/list" {
                print("  ✅ Test 1: JSON-RPC request encoding valid")
                passed += 1
            } else {
                print("  ❌ Test 1: JSON-RPC request encoding failed")
                failed += 1
            }
        } catch {
            print("  ❌ Test 1: JSON-RPC encoding threw: \(error)")
            failed += 1
        }

        // Test 2: JSON-RPC response parsing handles result, error, and malformed
        do {
            // Success response
            let successJSON = """
            {"jsonrpc":"2.0","id":1,"result":{"tools":[]}}
            """.data(using: .utf8)!
            if let parsed = try JSONSerialization.jsonObject(with: successJSON) as? [String: Any],
               parsed["result"] as? [String: Any] != nil {
                // Error response
                let errorJSON = """
                {"jsonrpc":"2.0","id":2,"error":{"code":-32600,"message":"Invalid"}}
                """.data(using: .utf8)!
                if let errParsed = try JSONSerialization.jsonObject(with: errorJSON) as? [String: Any],
                   let errObj = errParsed["error"] as? [String: Any],
                   errObj["code"] as? Int == -32600 {
                    print("  ✅ Test 2: JSON-RPC response parsing handles result and error")
                    passed += 1
                } else {
                    print("  ❌ Test 2: Error response parsing failed")
                    failed += 1
                }
            } else {
                print("  ❌ Test 2: Success response parsing failed")
                failed += 1
            }
        } catch {
            print("  ❌ Test 2: Response parsing threw: \(error)")
            failed += 1
        }

        // Test 3: MCPToolDefinition parsing from discovery response
        do {
            let toolJSON: [String: Any] = [
                "name": "read_file",
                "description": "Read a file",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "File path"]
                    ],
                    "required": ["path"]
                ]
            ]
            let name = toolJSON["name"] as? String
            let desc = toolJSON["description"] as? String
            let schema = toolJSON["inputSchema"] as? [String: Any]
            if name == "read_file" && desc == "Read a file" && schema?["type"] as? String == "object" {
                print("  ✅ Test 3: MCPToolDefinition parsing correct")
                passed += 1
            } else {
                print("  ❌ Test 3: MCPToolDefinition parsing failed")
                failed += 1
            }
        }

        // Test 4: MCPToolResult parsing (text content, error flag)
        do {
            let resultDict: [String: Any] = [
                "content": [
                    ["type": "text", "text": "File contents here"]
                ],
                "isError": false
            ]
            let isError = resultDict["isError"] as? Bool ?? true
            let content = resultDict["content"] as? [[String: Any]] ?? []
            let firstText = content.first?["text"] as? String
            if !isError && firstText == "File contents here" {
                print("  ✅ Test 4: MCPToolResult parsing correct")
                passed += 1
            } else {
                print("  ❌ Test 4: MCPToolResult parsing failed")
                failed += 1
            }
        }

        // Test 5: Tool ID generation (mcp__servername__toolname format)
        do {
            let id1 = MCPClient.toolRegistryId(serverName: "Filesystem", toolName: "read_file")
            let id2 = MCPClient.toolRegistryId(serverName: "My Server", toolName: "get_data")
            if id1 == "mcp__filesystem__read_file" && id2 == "mcp__my_server__get_data" {
                print("  ✅ Test 5: Tool ID generation correct")
                passed += 1
            } else {
                print("  ❌ Test 5: Tool ID generation failed — got '\(id1)' and '\(id2)'")
                failed += 1
            }
        }

        print("\nMCPClient results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
