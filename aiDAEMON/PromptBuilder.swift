import Foundation

/// Builds structured prompts for the LLM to parse user commands into JSON.
public struct PromptBuilder {

    /// Generation parameters tuned for JSON command output.
    public static let commandParams = GenerationParams(
        maxTokens: 256,
        temperature: 0.1,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1,
        repeatPenaltyLastN: 64
    )

    // MARK: - Prompt template

    private static let systemPrompt = """
        You are a macOS command interpreter. Convert user intent to structured JSON.

        Available command types:
        - APP_OPEN: Open an application or URL
        - FILE_SEARCH: Find files using Spotlight
        - WINDOW_MANAGE: Move or resize a window (left_half, right_half, full_screen, etc.) — does NOT quit apps
        - SYSTEM_INFO: Check or show system status (ip, disk, cpu, battery, memory, hostname, os version, uptime)
        - FILE_OP: File operations (move, rename, delete, create)
        - PROCESS_MANAGE: Quit, restart, or kill a running app or process
        - QUICK_ACTION: Perform system actions (screenshot, empty trash, DND, lock screen)

        IMPORTANT: Use PROCESS_MANAGE (not WINDOW_MANAGE) when the user says "close", "quit", or "exit" an app.

        Use SYSTEM_INFO for questions about system status. Use QUICK_ACTION only for actions that change something.
        SYSTEM_INFO targets: ip_address, disk_space, cpu_usage, battery, battery_time, memory, hostname, os_version, uptime.
        Use battery_time when asking about time remaining, time to charge, or how long until fully charged.

        Output JSON only, no explanation.

        Example:
        User: "open youtube"
        {"type": "APP_OPEN", "target": "https://youtube.com", "confidence": 0.95}

        User: "find tax documents from 2024"
        {"type": "FILE_SEARCH", "query": "tax", "parameters": {"kind": "pdf", "date": "2024"}, "confidence": 0.85}

        User: "left half"
        {"type": "WINDOW_MANAGE", "target": "frontmost", "parameters": {"position": "left_half"}, "confidence": 0.95}

        User: "what's my ip"
        {"type": "SYSTEM_INFO", "target": "ip_address", "confidence": 0.95}

        User: "check battery"
        {"type": "SYSTEM_INFO", "target": "battery", "confidence": 0.95}

        User: "how long till fully charged"
        {"type": "SYSTEM_INFO", "target": "battery_time", "confidence": 0.95}

        User: "how much time remaining on battery"
        {"type": "SYSTEM_INFO", "target": "battery_time", "confidence": 0.95}

        User: "how much ram do i have"
        {"type": "SYSTEM_INFO", "target": "memory", "confidence": 0.95}

        User: "disk space"
        {"type": "SYSTEM_INFO", "target": "disk_space", "confidence": 0.95}

        User: "quit chrome"
        {"type": "PROCESS_MANAGE", "target": "Google Chrome", "parameters": {"action": "quit"}, "confidence": 0.90}

        User: "close notes"
        {"type": "PROCESS_MANAGE", "target": "Notes", "parameters": {"action": "quit"}, "confidence": 0.95}

        User: "close safari"
        {"type": "PROCESS_MANAGE", "target": "Safari", "parameters": {"action": "quit"}, "confidence": 0.95}

        User: "take a screenshot"
        {"type": "QUICK_ACTION", "target": "screenshot", "confidence": 0.95}

        """

    // MARK: - Public API

    /// Builds the full prompt for a user command.
    /// - Parameter userInput: The raw text the user typed.
    /// - Returns: A formatted prompt string ready for LLM inference.
    public static func buildCommandPrompt(userInput: String) -> String {
        let sanitized = sanitize(userInput)
        return systemPrompt + "User: \"\(sanitized)\"\n"
    }

    /// Builds a prompt that includes recent conversation history for context.
    /// This lets the model understand references like "it", "that app", etc.
    ///
    /// - Parameters:
    ///   - messages: Recent conversation messages to include as context.
    ///   - currentInput: The new user input to respond to.
    ///   - maxHistoryChars: Character budget for history (default 6000 ≈ 2048 tokens for local;
    ///                      pass 12000 for cloud where a larger context is available).
    /// - Returns: A formatted prompt with conversation context + current input.
    public static func buildConversationalPrompt(
        messages: [Message],
        currentInput: String,
        maxHistoryChars: Int = 6000
    ) -> String {
        let sanitizedInput = sanitize(currentInput)

        // If no history, fall back to the simple prompt
        guard !messages.isEmpty else {
            return systemPrompt + "User: \"\(sanitizedInput)\"\n"
        }

        var prompt = systemPrompt

        // Add conversation context header
        prompt += "Recent conversation (for context — use this to resolve references like \"it\", \"that\", etc.):\n"

        // Append each message as context, respecting the per-provider character budget:
        //   Local model  → maxHistoryChars 6000  ≈ 2048 tokens (preserves JSON output quality)
        //   Cloud model  → maxHistoryChars 12000 ≈ 4096 tokens (more context, smarter model)
        var historyChars = 0

        for message in messages {
            let role = message.role == .user ? "User" : "Assistant"
            let content = sanitize(message.content)
            let line = "[\(role)]: \(content)\n"

            if historyChars + line.count > maxHistoryChars {
                break
            }
            prompt += line
            historyChars += line.count
        }

        prompt += "\nNow respond to this new input. Resolve any pronouns (it, that, them, this) using the conversation above. Output JSON only, no explanation.\n"
        prompt += "User: \"\(sanitizedInput)\"\n"

        return prompt
    }

    // MARK: - Input sanitisation

    /// Removes characters that could break the prompt structure.
    static func sanitize(_ input: String) -> String {
        var result = input

        // Strip control characters (keep newlines/tabs for multiline queries)
        result = result.unicodeScalars
            .filter { !$0.properties.isNoncharacterCodePoint }
            .filter { $0 != "\0" }
            .map { String($0) }
            .joined()

        // Escape double-quotes so they don't break the "User: ..." wrapper
        result = result.replacingOccurrences(of: "\"", with: "\\\"")

        // Collapse excessive whitespace
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Trim
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Limit length to prevent context overflow
        if result.count > 500 {
            result = String(result.prefix(500))
        }

        return result
    }
}
