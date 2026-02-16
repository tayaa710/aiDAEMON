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
        - SYSTEM_INFO: Show system information
        - FILE_OP: File operations (move, rename, delete, create)
        - PROCESS_MANAGE: Quit, restart, or kill processes
        - QUICK_ACTION: System actions (screenshot, trash, DND)

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
