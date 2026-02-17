import Foundation

// MARK: - Safety Level

/// Classifies how safe a command is to execute without user confirmation.
public enum SafetyLevel {
    /// No confirmation needed — read-only or completely benign.
    case safe
    /// Confirmation recommended — destructive but reversible (e.g. move to Trash).
    case caution
    /// Confirmation required — irreversible or high-impact (e.g. force quit, kill process).
    case dangerous
}

// MARK: - Validation Result

/// The outcome of validating a Command before execution.
public enum ValidationResult {
    /// Command is valid and safe — proceed to execute.
    case valid(Command)
    /// Command is valid but needs user confirmation before executing.
    case needsConfirmation(Command, reason: String, level: SafetyLevel)
    /// Command was rejected — do not execute, show reason to user.
    case rejected(reason: String)
}

// MARK: - Command Validator

/// Validates and sanitizes Commands before execution.
/// Sits between CommandParser and CommandRegistry.execute in the pipeline.
///
/// Responsibilities:
/// 1. **Sanitize** — strip control characters, null bytes; enforce field length limits.
/// 2. **Validate required fields** — ensure each command type has what it needs.
/// 3. **Classify safety** — determine if a command needs confirmation or is outright rejected.
/// 4. **Resolve paths** — expand ~ and detect path traversal attempts in file-related commands.
public struct CommandValidator {

    public static let shared = CommandValidator()

    // Maximum length for any individual string field
    private static let maxFieldLength = 500

    // MARK: - Public API

    /// Validate and sanitize a command, returning a `ValidationResult`.
    public func validate(_ command: Command) -> ValidationResult {
        // Step 1: Sanitize all string fields
        let sanitized = sanitize(command)

        // Step 2: Validate required fields for the command type
        if let rejectionReason = validateRequiredFields(sanitized) {
            return .rejected(reason: rejectionReason)
        }

        // Step 3: Resolve file paths (FILE_OP, FILE_SEARCH)
        if let pathRejection = validatePaths(sanitized) {
            return .rejected(reason: pathRejection)
        }

        // Step 4: Classify safety and return appropriate result
        let safety = classifySafety(sanitized)
        switch safety {
        case .safe:
            return .valid(sanitized)
        case .caution, .dangerous:
            return .needsConfirmation(
                sanitized,
                reason: confirmationReason(for: sanitized),
                level: safety
            )
        }
    }

    // MARK: - Sanitization

    /// Sanitize all string fields in a Command, returning a new sanitized Command.
    private func sanitize(_ command: Command) -> Command {
        Command(
            type: command.type,
            target: sanitizeString(command.target),
            query: sanitizeString(command.query),
            parameters: sanitizeParameters(command.parameters),
            confidence: command.confidence
        )
    }

    /// Strip null bytes and non-printable control characters; truncate to maxFieldLength.
    /// Returns nil if input is nil; returns nil for empty strings after cleaning.
    private func sanitizeString(_ input: String?) -> String? {
        guard let input, !input.isEmpty else { return nil }

        // Allow printable ASCII + Unicode + common whitespace (tab, newline, CR)
        let cleaned = input.unicodeScalars.filter { scalar in
            let v = scalar.value
            return v >= 32 || v == 9 || v == 10 || v == 13
        }
        .map(Character.init)
        .reduce(into: "") { $0.append($1) }

        let truncated = cleaned.count > Self.maxFieldLength
            ? String(cleaned.prefix(Self.maxFieldLength))
            : cleaned

        return truncated.isEmpty ? nil : truncated
    }

    /// Sanitize each key and string value in a parameters dict.
    private func sanitizeParameters(_ params: [String: AnyCodable]?) -> [String: AnyCodable]? {
        guard let params, !params.isEmpty else { return params }

        var cleaned = [String: AnyCodable]()
        for (key, value) in params {
            let cleanKey = sanitizeString(key) ?? key
            if let strVal = value.value as? String {
                cleaned[cleanKey] = AnyCodable(sanitizeString(strVal) ?? "")
            } else {
                cleaned[cleanKey] = value
            }
        }
        return cleaned
    }

    // MARK: - Required Field Validation

    /// Returns an error string if required fields are missing or invalid, nil if valid.
    private func validateRequiredFields(_ command: Command) -> String? {
        switch command.type {
        case .APP_OPEN:
            guard let target = command.target, !target.isBlank else {
                return "An app name or URL is required to open an application."
            }

        case .FILE_SEARCH:
            let queryText = command.query ?? command.target
            guard let q = queryText, !q.isBlank else {
                return "A search term is required to search for files."
            }
            guard q.trimmingCharacters(in: .whitespaces).count >= 2 else {
                return "Search term must be at least 2 characters."
            }

        case .WINDOW_MANAGE:
            let position = command.target
                ?? (command.parameters?["position"]?.value as? String)
            guard let p = position, !p.isBlank else {
                return "A window position is required (e.g. left half, full screen)."
            }

        case .SYSTEM_INFO:
            guard let target = command.target, !target.isBlank else {
                return "An info type is required (e.g. battery, disk space, memory)."
            }

        case .FILE_OP:
            guard let target = command.target, !target.isBlank else {
                return "A file path is required for file operations."
            }

        case .PROCESS_MANAGE:
            guard let target = command.target, !target.isBlank else {
                return "A process or app name is required."
            }

        case .QUICK_ACTION:
            guard let target = command.target, !target.isBlank else {
                return "An action is required (e.g. screenshot, lock screen)."
            }
        }

        return nil
    }

    // MARK: - Path Validation

    /// Check for path traversal and other path-related issues in file commands.
    /// Returns a rejection reason if the path is unsafe, nil if OK.
    private func validatePaths(_ command: Command) -> String? {
        guard command.type == .FILE_OP || command.type == .FILE_SEARCH else {
            return nil
        }

        let pathFields = [command.target, command.query].compactMap { $0 }

        for raw in pathFields {
            // Check for path traversal sequences (../../etc)
            if raw.contains("../") || raw.contains("/..") || raw == ".." {
                return "Path traversal sequences are not allowed: \"\(raw)\""
            }

            // Check for null bytes embedded in path strings (after sanitization this should
            // never trigger, but be explicit)
            if raw.contains("\0") {
                return "Invalid characters in path: \"\(raw)\""
            }
        }

        return nil
    }

    // MARK: - Safety Classification

    private func classifySafety(_ command: Command) -> SafetyLevel {
        switch command.type {
        // Read-only operations — always safe
        case .SYSTEM_INFO, .FILE_SEARCH:
            return .safe

        // Opening apps/URLs — safe (user explicitly requested it)
        case .APP_OPEN:
            return .safe

        // Window positioning — non-destructive and reversible
        case .WINDOW_MANAGE:
            return .safe

        // File operations — depends on the action
        case .FILE_OP:
            let action = (command.parameters?["action"]?.value as? String ?? "").lowercased()
            switch action {
            case "delete", "remove", "trash":
                return .caution     // Goes to Trash — reversible
            case "move", "rename", "create", "mkdir", "copy":
                return .caution     // Potentially irreversible if overwriting
            default:
                return .caution     // Unknown file op: ask to be safe
            }

        // Process management — quitting or killing processes
        case .PROCESS_MANAGE:
            let action = (command.parameters?["action"]?.value as? String ?? "").lowercased()
            switch action {
            case "force_quit", "force quit", "kill", "kill_port":
                return .dangerous   // Unsaved work can be lost
            default:
                return .caution     // Graceful quit: mildly destructive
            }

        // Quick actions
        case .QUICK_ACTION:
            let target = (command.target ?? "").lowercased()
            if target.contains("empty") || target.contains("trash") {
                return .caution     // Emptying Trash is irreversible
            }
            return .safe
        }
    }

    private func confirmationReason(for command: Command) -> String {
        switch command.type {
        case .FILE_OP:
            let action = command.parameters?["action"]?.value as? String ?? "modify"
            let target = command.target ?? "the file"
            return "This will \(action) \"\(target)\". Do you want to continue?"

        case .PROCESS_MANAGE:
            let action = command.parameters?["action"]?.value as? String ?? "quit"
            let target = command.target ?? "the process"
            return "This will \(action) \"\(target)\". Any unsaved work may be lost. Continue?"

        case .QUICK_ACTION:
            let target = command.target ?? "this action"
            return "This will perform: \(target). Continue?"

        default:
            return "Confirm this action?"
        }
    }
}

// MARK: - String Helper

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Debug Tests

#if DEBUG
extension CommandValidator {
    public static func runTests() {
        print("\nRunning CommandValidator tests...")
        var passed = 0
        var failed = 0
        let validator = CommandValidator.shared

        // Test 1: Valid SYSTEM_INFO passes through as .valid
        do {
            let cmd = Command(type: .SYSTEM_INFO, target: "battery", confidence: 0.9)
            if case .valid = validator.validate(cmd) {
                print("  ✅ Test 1: Valid SYSTEM_INFO is .valid")
                passed += 1
            } else {
                print("  ❌ Test 1: Valid SYSTEM_INFO should be .valid")
                failed += 1
            }
        }

        // Test 2: SYSTEM_INFO with missing target is .rejected
        do {
            let cmd = Command(type: .SYSTEM_INFO, target: nil, confidence: 0.9)
            if case .rejected = validator.validate(cmd) {
                print("  ✅ Test 2: SYSTEM_INFO with nil target is .rejected")
                passed += 1
            } else {
                print("  ❌ Test 2: SYSTEM_INFO with nil target should be .rejected")
                failed += 1
            }
        }

        // Test 3: Valid APP_OPEN is .valid
        do {
            let cmd = Command(type: .APP_OPEN, target: "Safari", confidence: 0.95)
            if case .valid = validator.validate(cmd) {
                print("  ✅ Test 3: Valid APP_OPEN is .valid")
                passed += 1
            } else {
                print("  ❌ Test 3: Valid APP_OPEN should be .valid")
                failed += 1
            }
        }

        // Test 4: FILE_SEARCH with 1-char query is .rejected
        do {
            let cmd = Command(type: .FILE_SEARCH, query: "x", confidence: 0.9)
            if case .rejected = validator.validate(cmd) {
                print("  ✅ Test 4: FILE_SEARCH with 1-char query is .rejected")
                passed += 1
            } else {
                print("  ❌ Test 4: FILE_SEARCH with 1-char query should be .rejected")
                failed += 1
            }
        }

        // Test 5: FILE_SEARCH with valid query is .valid
        do {
            let cmd = Command(type: .FILE_SEARCH, query: "report", confidence: 0.9)
            if case .valid = validator.validate(cmd) {
                print("  ✅ Test 5: Valid FILE_SEARCH is .valid")
                passed += 1
            } else {
                print("  ❌ Test 5: Valid FILE_SEARCH should be .valid")
                failed += 1
            }
        }

        // Test 6: Path traversal in FILE_OP target is .rejected
        do {
            let cmd = Command(type: .FILE_OP, target: "../../../etc/passwd",
                              parameters: ["action": AnyCodable("read")], confidence: 0.9)
            if case .rejected(let reason) = validator.validate(cmd) {
                if reason.contains("traversal") {
                    print("  ✅ Test 6: Path traversal in FILE_OP is .rejected with correct message")
                    passed += 1
                } else {
                    print("  ❌ Test 6: Rejection message should mention 'traversal', got: \(reason)")
                    failed += 1
                }
            } else {
                print("  ❌ Test 6: Path traversal should be .rejected")
                failed += 1
            }
        }

        // Test 7: Control characters are stripped from target
        do {
            let dirty = "Safari\0\u{01}\u{7F}"
            let cmd = Command(type: .APP_OPEN, target: dirty, confidence: 0.9)
            if case .valid(let cleaned) = validator.validate(cmd) {
                let t = cleaned.target ?? ""
                if !t.contains("\0") && !t.contains("\u{01}") {
                    print("  ✅ Test 7: Control characters stripped from target")
                    passed += 1
                } else {
                    print("  ❌ Test 7: Control characters not removed; target='\(t)'")
                    failed += 1
                }
            } else {
                print("  ❌ Test 7: Command with stripped target should be .valid")
                failed += 1
            }
        }

        // Test 8: String exceeding maxFieldLength is truncated
        do {
            let longString = String(repeating: "a", count: 600)
            let cmd = Command(type: .APP_OPEN, target: longString, confidence: 0.9)
            if case .valid(let cleaned) = validator.validate(cmd) {
                let t = cleaned.target ?? ""
                if t.count == 500 {
                    print("  ✅ Test 8: Overlong target truncated to 500 chars")
                    passed += 1
                } else {
                    print("  ❌ Test 8: Expected 500 chars, got \(t.count)")
                    failed += 1
                }
            } else {
                print("  ❌ Test 8: Truncated long target should still be .valid")
                failed += 1
            }
        }

        // Test 9: FILE_OP delete needs confirmation (.caution)
        do {
            let cmd = Command(type: .FILE_OP, target: "~/Desktop/old.txt",
                              parameters: ["action": AnyCodable("delete")], confidence: 0.9)
            if case .needsConfirmation(_, _, let level) = validator.validate(cmd), level == .caution {
                print("  ✅ Test 9: FILE_OP delete needs .caution confirmation")
                passed += 1
            } else {
                print("  ❌ Test 9: FILE_OP delete should require .caution confirmation")
                failed += 1
            }
        }

        // Test 10: PROCESS_MANAGE force_quit needs .dangerous confirmation
        do {
            let cmd = Command(type: .PROCESS_MANAGE, target: "Chrome",
                              parameters: ["action": AnyCodable("force_quit")], confidence: 0.9)
            if case .needsConfirmation(_, _, let level) = validator.validate(cmd), level == .dangerous {
                print("  ✅ Test 10: PROCESS_MANAGE force_quit needs .dangerous confirmation")
                passed += 1
            } else {
                print("  ❌ Test 10: PROCESS_MANAGE force_quit should require .dangerous")
                failed += 1
            }
        }

        // Test 11: WINDOW_MANAGE is .valid (non-destructive)
        do {
            let cmd = Command(type: .WINDOW_MANAGE, target: "left_half", confidence: 0.9)
            if case .valid = validator.validate(cmd) {
                print("  ✅ Test 11: WINDOW_MANAGE is .valid (non-destructive)")
                passed += 1
            } else {
                print("  ❌ Test 11: WINDOW_MANAGE should be .valid")
                failed += 1
            }
        }

        // Test 12: WINDOW_MANAGE with blank target is .rejected
        do {
            let cmd = Command(type: .WINDOW_MANAGE, target: "   ", confidence: 0.9)
            if case .rejected = validator.validate(cmd) {
                print("  ✅ Test 12: WINDOW_MANAGE with blank target is .rejected")
                passed += 1
            } else {
                print("  ❌ Test 12: WINDOW_MANAGE with blank target should be .rejected")
                failed += 1
            }
        }

        // Test 13: Confirmation reason contains target name
        do {
            let cmd = Command(type: .PROCESS_MANAGE, target: "Finder",
                              parameters: ["action": AnyCodable("force_quit")], confidence: 0.9)
            if case .needsConfirmation(_, let reason, _) = validator.validate(cmd) {
                if reason.contains("Finder") {
                    print("  ✅ Test 13: Confirmation reason mentions target app name")
                    passed += 1
                } else {
                    print("  ❌ Test 13: Confirmation reason should mention 'Finder', got: \(reason)")
                    failed += 1
                }
            } else {
                print("  ❌ Test 13: PROCESS_MANAGE force_quit should need confirmation")
                failed += 1
            }
        }

        // Test 14: FILE_SEARCH uses query field if target is nil
        do {
            let cmd = Command(type: .FILE_SEARCH, query: "tax returns", confidence: 0.9)
            if case .valid(let cleaned) = validator.validate(cmd) {
                if cleaned.query == "tax returns" {
                    print("  ✅ Test 14: FILE_SEARCH resolves query field correctly")
                    passed += 1
                } else {
                    print("  ❌ Test 14: query field should be preserved")
                    failed += 1
                }
            } else {
                print("  ❌ Test 14: FILE_SEARCH with query field should be .valid")
                failed += 1
            }
        }

        // Test 15: Empty string target treated as missing
        do {
            let cmd = Command(type: .APP_OPEN, target: "", confidence: 0.9)
            if case .rejected = validator.validate(cmd) {
                print("  ✅ Test 15: APP_OPEN with empty string target is .rejected")
                passed += 1
            } else {
                print("  ❌ Test 15: APP_OPEN with empty string target should be .rejected")
                failed += 1
            }
        }

        print("\nCommandValidator results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
