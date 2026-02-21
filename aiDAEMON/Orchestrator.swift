import Cocoa
import CoreGraphics
import Foundation

// MARK: - Foreground Context Lock

/// Tracks the expected frontmost app for context-lock verification.
/// Set when `get_ui_state` executes; checked before every action tool.
private struct ForegroundContext {
    let bundleID: String
    let pid: pid_t
    let appName: String
}

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

    /// Fires before each tool execution with the tool name. Lets the UI hide the
    /// floating window for computer-control tools so keyboard/mouse events reach
    /// the target app instead of aiDAEMON's own text field.
    public var onBeforeToolExecution: ((String) -> Void)?

    /// Fires after the full orchestrator turn completes so the UI can restore itself.
    public var onAfterTurnComplete: (() -> Void)?

    private let policyEngine = PolicyEngine.shared
    private let anthropicProvider = AnthropicModelProvider()
    private let maxRounds = 10
    private let totalTimeout: TimeInterval = 90

    private let stateLock = NSLock()
    private var abortRequested = false

    /// The expected frontmost app for this turn. Set by get_ui_state, checked before action tools.
    private var targetContext: ForegroundContext?

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
        // Reset per-turn state
        targetContext = nil

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
                    onAfterTurnComplete?()
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
                    onAfterTurnComplete?()
                    return OrchestratorTurnResult(
                        responseText: partial,
                        modelUsed: anthropicProvider.providerName,
                        wasCloud: true,
                        success: false
                    )

                case .stopSequence, .unknown:
                    if !responseText.isEmpty {
                        onAfterTurnComplete?()
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
            onAfterTurnComplete?()
            return OrchestratorTurnResult(
                responseText: error.localizedDescription,
                modelUsed: anthropicProvider.providerName,
                wasCloud: true,
                success: false
            )
        } catch {
            onAfterTurnComplete?()
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

    /// Tools that need the floating window hidden so events reach the target app.
    private static let computerControlTools: Set<String> = [
        "keyboard_type", "keyboard_shortcut", "mouse_click", "ax_action", "computer_action"
    ]

    /// Tools that require the foreground context lock check before execution.
    /// These tools interact with UI elements and must verify the correct app is frontmost.
    private static let contextLockedTools: Set<String> = [
        "keyboard_type", "keyboard_shortcut", "mouse_click", "ax_action", "computer_action"
    ]

    private func executeTool(_ call: ToolCall, deadline: Date) async throws -> ExecutionResult {
        try throwIfAborted()
        try throwIfPast(deadline)

        emitStatus(statusText(for: call))

        // Context lock: verify the correct app is frontmost before action tools.
        if Self.contextLockedTools.contains(call.toolId) {
            if let lockError = await verifyForegroundContext() {
                NSLog("Orchestrator: context lock FAILED for %@: %@", call.toolId, lockError)
                return .error(lockError)
            }
            NSLog("Orchestrator: context lock passed for %@", call.toolId)
        }

        // For computer-control tools, tell the UI to hide and activate the target app
        // so keyboard/mouse events reach the correct window.
        let isComputerControl = Self.computerControlTools.contains(call.toolId)
        if isComputerControl {
            onBeforeToolExecution?(call.toolId)
            // Give the OS time to complete the app activation before sending events.
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        let result = await withCheckedContinuation { continuation in
            ToolRegistry.shared.execute(call: call) { result in
                continuation.resume(returning: result)
            }
        }

        // After get_ui_state executes, capture the frontmost app as the target context.
        if call.toolId == "get_ui_state" {
            captureTargetContext()
        }

        return result
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
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        let screenWidth = Int(screenBounds.width)
        let screenHeight = Int(screenBounds.height)
        return """
        You are aiDAEMON — a JARVIS-style AI companion that controls this Mac. You are not a chatbot. You are an autonomous agent that takes action.

        Environment: \(username)@macOS | \(home) | \(screenWidth)x\(screenHeight) | \(now)

        YOUR PERSONALITY:
        - Be like JARVIS: competent, concise, proactive. Just do things — don't ask for permission on safe actions.
        - When the user says "open Safari and go to google.com" — just do it. Don't explain your plan first.
        - When the user says "write a haiku in TextEdit" — open TextEdit, write the haiku. Done.
        - Respond in 1-2 sentences max. "Done — opened Safari to google.com." Not a paragraph.
        - If something fails, say what went wrong briefly and try a different approach automatically.
        - You can handle multi-step tasks. Break them down and execute them one by one.
        - Treat the user's requests as natural conversation. "make this window bigger" = resize the frontmost window. "what's my battery at?" = check system info. "find my tax docs" = search files.

        HOW YOU CONTROL THE COMPUTER:
        When you need to interact with apps on screen, follow this approach automatically — the user should never need to tell you which tool to use:
        1. Call get_ui_state to see what's on screen (instant, free — gives you every button, menu, text field with refs like @e1).
        2. Use ax_action with the ref to press buttons, type in fields (set_value), focus elements, etc.
        3. Use ax_find if you need to search for something specific in a large app.
        4. After acting, call get_ui_state again to verify it worked. Don't assume — check.
        5. If AX tools can't see the element (non-native app, web content, canvas), fall back to screen_capture + computer_action.
        6. Use keyboard_shortcut for common shortcuts (cmd+c, cmd+v, cmd+t, cmd+w, etc.).
        7. Use keyboard_type only when set_value doesn't work for a text field.

        IMPORTANT — typing into apps:
        - Before typing text into ANY app, ALWAYS use ax_action with "focus" on the text field first, or use "set_value" to put text directly into it.
        - If you just opened an app, call get_ui_state first to find the text area, then focus it or set_value on it. Do NOT blindly use keyboard_type without a focused text field — it will cause error beeps.
        - Prefer ax_action set_value over keyboard_type whenever possible — it's faster and more reliable.

        For non-GUI tasks, use the right tool directly:
        - app_open: launch apps or open URLs
        - file_search: find files via Spotlight
        - window_manage: move/resize windows (left_half, right_half, full_screen, center, etc.)
        - system_info: battery, disk space, IP, memory, uptime, etc.

        RULES YOU MUST FOLLOW:
        - NEVER claim you did something without calling a tool. Every action requires a tool call.
        - NEVER invent or hallucinate tool results. Only report what actually happened.
        - If a tool returns an error, report the real error — don't say "Done" when it failed.
        - Don't make up element refs. Get them from get_ui_state or ax_find.
        - If the same approach fails twice, try something different.
        """
    }

    // MARK: - Foreground Context Lock

    /// Capture the current frontmost app as the target for this turn.
    /// Called after get_ui_state completes so subsequent actions verify against it.
    private func captureTargetContext() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let name = app.localizedName ?? "Unknown"
        let bundle = app.bundleIdentifier ?? "unknown"
        let pid = app.processIdentifier

        // Don't lock to aiDAEMON itself — we want to lock to the app Claude is targeting.
        if bundle == "com.aidaemon" { return }

        targetContext = ForegroundContext(bundleID: bundle, pid: pid, appName: name)
        NSLog("Orchestrator: target context set → %@ (pid:%d, bundle:%@)", name, pid, bundle)
    }

    /// Verify the target app is still frontmost. If not, try to re-activate it.
    /// Returns nil if the lock passes, or an error message string if it fails.
    private func verifyForegroundContext() async -> String? {
        guard let target = targetContext else {
            // No context set yet (get_ui_state hasn't been called). Allow the action
            // to proceed — the tool may be used independently.
            return nil
        }

        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            return "Context lock failed: no frontmost application detected. Action aborted."
        }

        let currentBundle = frontmost.bundleIdentifier ?? ""
        let currentPID = frontmost.processIdentifier

        // Allow if aiDAEMON is frontmost (the UI may be showing; onBeforeToolExecution will
        // hide it and activate the target app after this check passes).
        if currentBundle == "com.aidaemon" {
            return nil
        }

        // Match by bundle ID or PID (PID handles apps without bundle IDs).
        if currentBundle == target.bundleID || currentPID == target.pid {
            return nil  // Context lock passed
        }

        // Mismatch detected — try to re-activate the target app.
        emitStatus("Re-activating \(target.appName)...")
        NSLog("Orchestrator: context lock mismatch — expected %@ (pid:%d) but got %@ (pid:%d). Attempting re-activation.",
              target.appName, target.pid,
              frontmost.localizedName ?? "unknown", currentPID)

        let apps = NSWorkspace.shared.runningApplications
        if let targetApp = apps.first(where: { $0.processIdentifier == target.pid }) {
            targetApp.activate(options: [.activateIgnoringOtherApps])
            // Wait for macOS to complete the app switch.
            try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms

            // Re-check after activation attempt.
            if let recheck = NSWorkspace.shared.frontmostApplication {
                let recheckBundle = recheck.bundleIdentifier ?? ""
                let recheckPID = recheck.processIdentifier
                if recheckBundle == target.bundleID || recheckPID == target.pid {
                    NSLog("Orchestrator: re-activation succeeded for %@", target.appName)
                    return nil  // Re-activation succeeded
                }
            }
        }

        // Re-activation failed — abort the action.
        return "Context lock FAILED: Expected '\(target.appName)' (\(target.bundleID)) to be frontmost, but '\(frontmost.localizedName ?? "unknown")' (\(currentBundle)) is. Action aborted to prevent wrong-app interaction. Call get_ui_state again to refresh the target."
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
        case "screen_capture":
            return "Capturing screen..."
        case "mouse_click":
            return "Controlling mouse..."
        case "keyboard_type":
            return "Typing text..."
        case "keyboard_shortcut":
            return "Pressing shortcut..."
        case "computer_action":
            let action = (call.arguments["action"] as? String) ?? "controlling computer"
            let truncated = action.count > 50 ? String(action.prefix(47)) + "..." : action
            return "Computer control: \(truncated)"
        case "get_ui_state":
            return "Reading screen state..."
        case "ax_action":
            let action = (call.arguments["action"] as? String) ?? "action"
            let ref = (call.arguments["ref"] as? String) ?? ""
            return "AX \(action) on \(ref)..."
        case "ax_find":
            return "Searching UI elements..."
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
