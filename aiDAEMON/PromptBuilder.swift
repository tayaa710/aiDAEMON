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
        - WINDOW_MANAGE: Resize, move, or close windows
        - SYSTEM_INFO: Check or show system status (ip, disk, cpu, battery, memory, hostname, os version, uptime)
        - FILE_OP: File operations (move, rename, delete, create)
        - PROCESS_MANAGE: Quit, restart, or kill processes
        - QUICK_ACTION: Perform system actions (screenshot, empty trash, DND, lock screen)

        Use SYSTEM_INFO for questions about system status. Use QUICK_ACTION only for actions that change something.
        SYSTEM_INFO targets: ip_address, disk_space, cpu_usage, battery, memory, hostname, os_version, uptime.

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

        User: "how much ram do i have"
        {"type": "SYSTEM_INFO", "target": "memory", "confidence": 0.95}

        User: "disk space"
        {"type": "SYSTEM_INFO", "target": "disk_space", "confidence": 0.95}

        User: "quit chrome"
        {"type": "PROCESS_MANAGE", "target": "Google Chrome", "parameters": {"action": "quit"}, "confidence": 0.90}

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
    /// - Returns: A formatted prompt with conversation context + current input.
    public static func buildConversationalPrompt(messages: [Message], currentInput: String) -> String {
        let sanitizedInput = sanitize(currentInput)

        // If no history, fall back to the simple prompt
        guard !messages.isEmpty else {
            return systemPrompt + "User: \"\(sanitizedInput)\"\n"
        }

        var prompt = systemPrompt

        // Add conversation context header
        prompt += "Recent conversation (for context — use this to resolve references like \"it\", \"that\", etc.):\n"

        // Append each message as context, with a character budget to avoid overflowing
        // Local model: ~2048 tokens for history (~6000 chars at ~3 chars/token)
        // Cloud model: more generous, but we cap the same for simplicity
        let maxHistoryChars = 6000
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

        prompt += "\nNow respond to this new input. Output JSON only, no explanation.\n"
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
