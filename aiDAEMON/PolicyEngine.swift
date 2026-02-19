import Foundation

// MARK: - Policy Decision

/// Outcome of evaluating a proposed tool call against autonomy and safety policy.
public enum PolicyDecision {
    case allow
    case requireConfirmation(reason: String)
    case deny(reason: String)
}

// MARK: - Policy Engine

/// Enforces execution policy for tool calls before they reach ToolRegistry.execute().
///
/// Security goals:
/// - Unknown tools are never auto-trusted.
/// - Path traversal patterns are denied for file/path-like arguments.
/// - Dangerous tools always require explicit confirmation.
/// - Level 0 requires confirmation for all tools.
public final class PolicyEngine {

    public static let shared = PolicyEngine()

    private init() {}

    // MARK: - Public API

    /// Evaluate whether a tool call should run immediately, require confirmation, or be denied.
    public func evaluate(
        toolId: String,
        arguments: [String: Any],
        autonomyLevel: AutonomyLevel = .current
    ) -> PolicyDecision {
        let sanitized = sanitize(arguments: arguments)

        if containsPathTraversal(in: sanitized) {
            return .deny(reason: "Blocked unsafe path traversal pattern in tool arguments.")
        }

        guard let tool = ToolRegistry.shared.definition(for: toolId) else {
            return .requireConfirmation(reason: "Tool '\(toolId)' is unknown. Confirm before continuing.")
        }

        switch autonomyLevel {
        case .confirmAll:
            return .requireConfirmation(reason: confirmationReason(for: tool))
        case .autoExecute:
            switch tool.riskLevel {
            case .safe, .caution:
                return .allow
            case .dangerous:
                return .requireConfirmation(reason: confirmationReason(for: tool))
            }
        case .fullyAuto:
            // Scope controls are added in a later milestone; dangerous still confirms.
            switch tool.riskLevel {
            case .dangerous:
                return .requireConfirmation(reason: confirmationReason(for: tool))
            case .safe, .caution:
                return .allow
            }
        }
    }

    /// Sanitizes all string arguments (keys and values) before policy checks/execution.
    public func sanitize(arguments: [String: Any]) -> [String: Any] {
        var cleaned: [String: Any] = [:]
        for (key, value) in arguments {
            let cleanKey = sanitizeString(key)
            cleaned[cleanKey] = sanitizeValue(value)
        }
        return cleaned
    }

    /// Convenience helper for confirmation UI severity mapping.
    public func safetyLevel(for toolId: String) -> SafetyLevel {
        guard let risk = ToolRegistry.shared.definition(for: toolId)?.riskLevel else {
            return .dangerous
        }
        switch risk {
        case .safe: return .safe
        case .caution: return .caution
        case .dangerous: return .dangerous
        }
    }

    // MARK: - Sanitization

    private func sanitizeValue(_ value: Any) -> Any {
        if let string = value as? String {
            return sanitizeString(string)
        }
        if let dict = value as? [String: Any] {
            return sanitize(arguments: dict)
        }
        if let array = value as? [Any] {
            return array.map { sanitizeValue($0) }
        }
        return value
    }

    private func sanitizeString(_ input: String) -> String {
        let filtered = input.unicodeScalars.filter { scalar in
            let v = scalar.value
            return v >= 32 || v == 9 || v == 10 || v == 13
        }
        let trimmed = String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 1000 {
            return String(trimmed.prefix(1000))
        }
        return trimmed
    }

    // MARK: - Path traversal detection

    private let pathKeyHints: [String] = [
        "path", "file", "folder", "directory", "dir", "destination", "source", "target", "query"
    ]

    private func containsPathTraversal(in arguments: [String: Any]) -> Bool {
        for (key, value) in arguments {
            if containsPathTraversal(value: value, keyHint: key) {
                return true
            }
        }
        return false
    }

    private func containsPathTraversal(value: Any, keyHint: String?) -> Bool {
        if let dict = value as? [String: Any] {
            for (nestedKey, nestedValue) in dict {
                if containsPathTraversal(value: nestedValue, keyHint: nestedKey) {
                    return true
                }
            }
            return false
        }

        if let array = value as? [Any] {
            for item in array {
                if containsPathTraversal(value: item, keyHint: keyHint) {
                    return true
                }
            }
            return false
        }

        guard let stringValue = value as? String else {
            return false
        }

        let key = keyHint?.lowercased() ?? ""
        guard pathKeyHints.contains(where: { key.contains($0) }) else {
            return false
        }

        let lowered = stringValue.lowercased()
        return lowered == ".."
            || lowered.contains("../")
            || lowered.contains("/..")
            || lowered.contains("..\\")
            || lowered.contains("\\..")
    }

    // MARK: - Copy

    private func confirmationReason(for tool: ToolDefinition) -> String {
        switch tool.riskLevel {
        case .dangerous:
            return "Tool '\(tool.id)' is dangerous and requires explicit approval."
        case .caution:
            return "Tool '\(tool.id)' modifies system state. Confirm to continue."
        case .safe:
            return "Autonomy Level 0 requires confirmation before running '\(tool.id)'."
        }
    }
}
