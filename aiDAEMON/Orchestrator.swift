import Foundation

// MARK: - UI Bridge Types

/// Confirmation payload surfaced to the UI when policy requires user approval.
public struct ToolConfirmationRequest {
    public let toolCall: ToolCall
    public let reason: String
    public let level: SafetyLevel
}

/// Final output for a single user turn handled by the orchestrator.
public struct OrchestratorTurnResult {
    public let responseText: String
    public let modelUsed: String
    public let wasCloud: Bool
    public let success: Bool
}

// MARK: - Orchestrator Errors

public enum OrchestratorError: Error, LocalizedError {
    case providerUnavailable
    case malformedResponse(String)
    case noToolResults
    case noFinalResponse
    case maxRoundsExceeded
    case timedOut
    case aborted
    case localModelUnavailable

    public var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            return "Claude is unavailable. Configure an Anthropic API key in Settings → Cloud."
        case .malformedResponse(let reason):
            return "Unexpected Claude response format: \(reason)"
        case .noToolResults:
            return "No tool results were produced for Claude."
        case .noFinalResponse:
            return "Claude did not provide a final response."
        case .maxRoundsExceeded:
            return "Stopped after 10 tool-use rounds to prevent an infinite loop."
        case .timedOut:
            return "Stopped after 90 seconds to prevent a stalled execution."
        case .aborted:
            return "Stopped."
        case .localModelUnavailable:
            return "Local model is not ready yet."
        }
    }
}

// MARK: - Orchestrator

/// Core agent loop using Claude's native `tool_use` protocol.
///
/// Primary path:
/// - Sends messages + tool schemas to Anthropic.
/// - Executes tool_use blocks through policy + ToolRegistry.
/// - Sends tool_result blocks back to Claude until end_turn.
///
/// Fallback path:
/// - If Anthropic is unavailable, runs the legacy local single-step flow so
///   local/offline baseline capability is preserved.
public final class Orchestrator {

    public static let shared = Orchestrator()

    /// Optional UI callbacks (set by FloatingWindow).
    public var onStatusUpdate: ((String) -> Void)?
    public var onConfirmationRequest: ((ToolConfirmationRequest) async -> Bool)?

    private let policyEngine = PolicyEngine.shared
    private let anthropicProvider = AnthropicModelProvider()
    private let maxRounds = 10
    private let totalTimeout: TimeInterval = 90

    private let stateLock = NSLock()
    private var abortRequested = false

    private init() {}

    // MARK: - Public API

    /// Entry point for a user turn.
    public func handleUserInput(text: String, conversation: Conversation) async -> OrchestratorTurnResult {
        setAbortRequested(false)
        if !anthropicProvider.isAvailable {
            anthropicProvider.refreshAvailability()
        }

        if anthropicProvider.isAvailable {
            return await runAgentLoop(text: text, conversation: conversation)
        }

        emitStatus("Cloud unavailable. Using local fallback...")
        return await runLegacyLocalTurn(text: text, conversation: conversation)
    }

    /// Emergency stop — cancels model requests and causes the loop to halt at the next checkpoint.
    public func abort() {
        setAbortRequested(true)
        anthropicProvider.abort()
        LLMManager.shared.abort()
    }

    // MARK: - Claude Tool-Use Loop

    private func runAgentLoop(text: String, conversation: Conversation) async -> OrchestratorTurnResult {
        let deadline = Date().addingTimeInterval(totalTimeout)

        // Ensure enabled MCP integrations are connected so Claude sees their tools.
        let manager = MCPServerManager.shared
        let hasPendingIntegrations = manager.servers.contains { server in
            guard server.enabled else { return false }
            return !(manager.statuses[server.id]?.isConnected ?? false)
        }
        if hasPendingIntegrations {
            emitStatus("Connecting integrations...")
        }
        await manager.ensureEnabledServersReady(maxWaitSeconds: 30)

        let systemPrompt = buildSystemPrompt()
        let tools = ToolRegistry.shared.anthropicToolDefinitions()
        var messages = buildAnthropicMessages(conversation: conversation, currentInput: text)
        var rounds = 0

        do {
            while true {
                try throwIfAborted()
                try throwIfPast(deadline)

                emitStatus("Thinking...")

                let response = try await anthropicProvider.sendWithTools(
                    messages: messages,
                    system: systemPrompt,
                    tools: tools
                )

                try throwIfAborted()

                // Anthropic requires assistant tool_use blocks be preserved in history
                // before the subsequent user tool_result message.
                messages.append([
                    "role": "assistant",
                    "content": response.rawContentBlocks
                ])

                let responseText = response.textContent
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                switch response.stopReason {
                case .endTurn:
                    let finalText = responseText.isEmpty ? "Done." : responseText
                    return OrchestratorTurnResult(
                        responseText: finalText,
                        modelUsed: anthropicProvider.providerName,
                        wasCloud: true,
                        success: true
                    )

                case .toolUse:
                    rounds += 1
                    if rounds > maxRounds {
                        throw OrchestratorError.maxRoundsExceeded
                    }
                    let toolResults = try await processToolUseBlocks(
                        response.toolUseBlocks,
                        deadline: deadline
                    )
                    guard !toolResults.isEmpty else {
                        throw OrchestratorError.noToolResults
                    }

                    messages.append([
                        "role": "user",
                        "content": toolResults
                    ])

                case .maxTokens:
                    let partial = responseText.isEmpty
                        ? "I hit the response length limit before finishing."
                        : responseText
                    return OrchestratorTurnResult(
                        responseText: partial,
                        modelUsed: anthropicProvider.providerName,
                        wasCloud: true,
                        success: false
                    )

                case .stopSequence, .unknown:
                    if !responseText.isEmpty {
                        return OrchestratorTurnResult(
                            responseText: responseText,
                            modelUsed: anthropicProvider.providerName,
                            wasCloud: true,
                            success: true
                        )
                    }
                    throw OrchestratorError.noFinalResponse
                }
            }
        } catch let error as OrchestratorError {
            return OrchestratorTurnResult(
                responseText: error.localizedDescription,
                modelUsed: anthropicProvider.providerName,
                wasCloud: true,
                success: false
            )
        } catch {
            return OrchestratorTurnResult(
                responseText: "Agent loop failed: \(error.localizedDescription)",
                modelUsed: anthropicProvider.providerName,
                wasCloud: true,
                success: false
            )
        }
    }

    private func processToolUseBlocks(
        _ blocks: [AnthropicToolUseBlock],
        deadline: Date
    ) async throws -> [[String: Any]] {
        guard !blocks.isEmpty else {
            throw OrchestratorError.malformedResponse("stop_reason=tool_use but no tool_use blocks were returned")
        }

        var toolResults: [[String: Any]] = []

        for block in blocks {
            try throwIfAborted()
            try throwIfPast(deadline)

            let sanitizedArgs = policyEngine.sanitize(arguments: block.input)
            let call = ToolCall(toolId: block.name, arguments: sanitizedArgs)

            switch ToolRegistry.shared.validate(call: call) {
            case .invalid(let reason):
                let content = "Tool validation failed for '\(block.name)': \(reason)"
                toolResults.append(toolResultPayload(toolUseID: block.id, content: content, isError: true))
                continue
            case .valid:
                break
            }

            let decision = policyEngine.evaluate(
                toolId: block.name,
                arguments: sanitizedArgs,
                autonomyLevel: .current
            )

            switch decision {
            case .deny(let reason):
                let content = "Denied by policy: \(reason)"
                toolResults.append(toolResultPayload(toolUseID: block.id, content: content, isError: true))

            case .requireConfirmation(let reason):
                let level = policyEngine.safetyLevel(for: block.name)
                let approved = await requestConfirmation(
                    ToolConfirmationRequest(toolCall: call, reason: reason, level: level)
                )
                try throwIfAborted()

                guard approved else {
                    let content = "User denied tool '\(block.name)'."
                    toolResults.append(toolResultPayload(toolUseID: block.id, content: content, isError: true))
                    continue
                }

                let execResult = try await executeTool(call, deadline: deadline)
                toolResults.append(
                    toolResultPayload(
                        toolUseID: block.id,
                        content: formatExecutionResult(execResult),
                        isError: !execResult.success
                    )
                )

            case .allow:
                let execResult = try await executeTool(call, deadline: deadline)
                toolResults.append(
                    toolResultPayload(
                        toolUseID: block.id,
                        content: formatExecutionResult(execResult),
                        isError: !execResult.success
                    )
                )
            }
        }

        return toolResults
    }

    private func executeTool(_ call: ToolCall, deadline: Date) async throws -> ExecutionResult {
        try throwIfAborted()
        try throwIfPast(deadline)

        emitStatus(statusText(for: call))

        return await withCheckedContinuation { continuation in
            ToolRegistry.shared.execute(call: call) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Local fallback (legacy single-step path)

    private func runLegacyLocalTurn(text: String, conversation: Conversation) async -> OrchestratorTurnResult {
        let manager = LLMManager.shared
        guard manager.state == .ready else {
            return OrchestratorTurnResult(
                responseText: OrchestratorError.localModelUnavailable.localizedDescription,
                modelUsed: "Local LLaMA 8B",
                wasCloud: false,
                success: false
            )
        }

        do {
            try throwIfAborted()
            emitStatus("Thinking...")

            let prompt = buildLegacyPrompt(userInput: text, conversation: conversation)
            let generation = await generateLegacy(prompt: prompt, userInput: text)

            try throwIfAborted()

            switch generation {
            case .failure(let error):
                return OrchestratorTurnResult(
                    responseText: "Generation failed: \(error.localizedDescription)",
                    modelUsed: manager.lastProviderName.isEmpty ? "Local LLaMA 8B" : manager.lastProviderName,
                    wasCloud: manager.lastWasCloud,
                    success: false
                )

            case .success(let output):
                let parsed = try CommandParser.parse(output.trimmingCharacters(in: .whitespacesAndNewlines))
                let validation = CommandValidator.shared.validate(parsed)

                let validatedCommand: Command
                switch validation {
                case .rejected(let reason):
                    return OrchestratorTurnResult(
                        responseText: "Command blocked: \(reason)",
                        modelUsed: manager.lastProviderName,
                        wasCloud: manager.lastWasCloud,
                        success: false
                    )
                case .needsConfirmation(let cmd, let reason, let level):
                    let request = ToolConfirmationRequest(
                        toolCall: toolCall(from: cmd),
                        reason: reason,
                        level: level
                    )
                    let approved = await requestConfirmation(request)
                    guard approved else {
                        return OrchestratorTurnResult(
                            responseText: "Action cancelled.",
                            modelUsed: manager.lastProviderName,
                            wasCloud: manager.lastWasCloud,
                            success: false
                        )
                    }
                    validatedCommand = cmd
                case .valid(let cmd):
                    validatedCommand = cmd
                }

                try throwIfAborted()

                emitStatus(statusText(for: toolCall(from: validatedCommand)))
                let exec = await executeCommand(validatedCommand)
                let context = "\(text) → \(readableCommandType(validatedCommand.type))"
                var message = context + "\n\n" + exec.message
                if let details = exec.details {
                    message += "\n" + details
                }

                return OrchestratorTurnResult(
                    responseText: message,
                    modelUsed: manager.lastProviderName,
                    wasCloud: manager.lastWasCloud,
                    success: exec.success
                )
            }
        } catch let error as OrchestratorError {
            return OrchestratorTurnResult(
                responseText: error.localizedDescription,
                modelUsed: manager.lastProviderName.isEmpty ? "Local LLaMA 8B" : manager.lastProviderName,
                wasCloud: manager.lastWasCloud,
                success: false
            )
        } catch {
            return OrchestratorTurnResult(
                responseText: "Local fallback failed: \(error.localizedDescription)",
                modelUsed: manager.lastProviderName.isEmpty ? "Local LLaMA 8B" : manager.lastProviderName,
                wasCloud: manager.lastWasCloud,
                success: false
            )
        }
    }

    private func generateLegacy(prompt: String, userInput: String) async -> Result<String, Error> {
        await withCheckedContinuation { continuation in
            LLMManager.shared.generate(
                prompt: prompt,
                userInput: userInput,
                params: PromptBuilder.commandParams,
                onToken: nil
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func executeCommand(_ command: Command) async -> ExecutionResult {
        await withCheckedContinuation { continuation in
            CommandRegistry.shared.execute(command) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func buildLegacyPrompt(userInput: String, conversation: Conversation) -> String {
        let recentMessages = conversation.recentMessages()
        let routingDecision = LLMManager.shared.router?.route(input: userInput)
        let useConversationalPrompt = recentMessages.count > 1

        if useConversationalPrompt {
            let historyMessages = Array(recentMessages.dropLast())
            let isCloud = routingDecision?.isCloud == true
            let historyBudget = isCloud ? 12000 : 6000
            return PromptBuilder.buildConversationalPrompt(
                messages: historyMessages,
                currentInput: userInput,
                maxHistoryChars: historyBudget
            )
        }

        return PromptBuilder.buildCommandPrompt(userInput: userInput)
    }

    // MARK: - Message Construction

    private func buildAnthropicMessages(conversation: Conversation, currentInput: String) -> [[String: Any]] {
        let recent = Array(conversation.recentMessages().suffix(10))
        var messages: [[String: Any]] = []

        for message in recent {
            if message.role == .system { continue }
            let role = message.role == .assistant ? "assistant" : "user"
            let content = sanitizeMessageContent(message.content)
            guard !content.isEmpty else { continue }
            messages.append([
                "role": role,
                "content": content
            ])
        }

        let sanitizedCurrent = sanitizeMessageContent(currentInput)
        if let last = messages.last,
           let lastRole = last["role"] as? String,
           let lastContent = last["content"] as? String,
           lastRole == "user",
           lastContent == sanitizedCurrent {
            return messages
        }

        messages.append([
            "role": "user",
            "content": sanitizedCurrent
        ])
        return messages
    }

    private func sanitizeMessageContent(_ text: String) -> String {
        let filtered = text.unicodeScalars.filter { scalar in
            let v = scalar.value
            return v >= 32 || v == 9 || v == 10 || v == 13
        }
        let clean = String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count > 4000 {
            return String(clean.prefix(4000))
        }
        return clean
    }

    private func buildSystemPrompt() -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let username = NSUserName()
        let home = NSHomeDirectory()
        return """
        You are aiDAEMON, a JARVIS-style AI companion for macOS.
        Current date/time: \(now)
        Current user: \(username)
        Home directory: \(home)

        Behavior requirements:
        - Execute tasks by calling tools when actions are needed.
        - Use tool results to adapt your next step (reactive loop).
        - Never invent tool results. If a tool returns an error, report it accurately.
        - If a tool fails, try an alternative or explain the actual error to the user.
        - Keep final user-facing responses concise and concrete.
        - Respect safety constraints and policy denials.
        - You are running as the current macOS user. Do not assume a different username.
        """
    }

    // MARK: - Helpers

    private func requestConfirmation(_ request: ToolConfirmationRequest) async -> Bool {
        guard let callback = onConfirmationRequest else {
            return false
        }
        return await callback(request)
    }

    private func toolResultPayload(toolUseID: String, content: String, isError: Bool) -> [String: Any] {
        var payload: [String: Any] = [
            "type": "tool_result",
            "tool_use_id": toolUseID,
            "content": content
        ]
        if isError {
            payload["is_error"] = true
        }
        return payload
    }

    private func formatExecutionResult(_ result: ExecutionResult) -> String {
        if let details = result.details, !details.isEmpty {
            return "\(result.message)\n\(details)"
        }
        return result.message
    }

    private func statusText(for call: ToolCall) -> String {
        switch call.toolId {
        case "app_open":
            let target = (call.arguments["target"] as? String) ?? "application"
            return "Opening \(target)..."
        case "file_search":
            let query = (call.arguments["query"] as? String) ?? (call.arguments["target"] as? String) ?? "files"
            return "Searching for \(query)..."
        case "window_manage":
            return "Adjusting window..."
        case "system_info":
            return "Checking system info..."
        default:
            return "Running \(call.toolId)..."
        }
    }

    private func toolCall(from command: Command) -> ToolCall {
        var arguments: [String: Any] = [:]
        if let target = command.target {
            arguments["target"] = target
        }
        if let query = command.query {
            arguments["query"] = query
        }
        if let params = command.parameters {
            for (key, value) in params {
                arguments[key] = value.value
            }
        }

        if command.type == .WINDOW_MANAGE,
           arguments["position"] == nil,
           let target = command.target,
           !target.isEmpty {
            arguments["position"] = target
            if arguments["target"] == nil || (arguments["target"] as? String) == target {
                arguments["target"] = "frontmost"
            }
        }

        return ToolCall(toolId: toolId(for: command.type), arguments: arguments)
    }

    private func toolId(for commandType: CommandType) -> String {
        switch commandType {
        case .APP_OPEN: return "app_open"
        case .FILE_SEARCH: return "file_search"
        case .WINDOW_MANAGE: return "window_manage"
        case .SYSTEM_INFO: return "system_info"
        case .FILE_OP: return "file_op"
        case .PROCESS_MANAGE: return "process_manage"
        case .QUICK_ACTION: return "quick_action"
        }
    }

    private func readableCommandType(_ type: CommandType) -> String {
        switch type {
        case .APP_OPEN: return "Open Application"
        case .FILE_SEARCH: return "Search Files"
        case .WINDOW_MANAGE: return "Manage Window"
        case .SYSTEM_INFO: return "System Information"
        case .FILE_OP: return "File Operation"
        case .PROCESS_MANAGE: return "Manage Process"
        case .QUICK_ACTION: return "Quick Action"
        }
    }

    private func throwIfPast(_ deadline: Date) throws {
        if Date() > deadline {
            throw OrchestratorError.timedOut
        }
    }

    private func throwIfAborted() throws {
        if Task.isCancelled || isAbortRequested() {
            throw OrchestratorError.aborted
        }
    }

    private func emitStatus(_ status: String) {
        let clean = status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onStatusUpdate?(clean)
        }
    }

    private func setAbortRequested(_ value: Bool) {
        stateLock.lock()
        abortRequested = value
        stateLock.unlock()
    }

    private func isAbortRequested() -> Bool {
        stateLock.lock()
        let value = abortRequested
        stateLock.unlock()
        return value
    }
}
