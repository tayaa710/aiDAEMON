import Foundation

// MARK: - Command Types

/// All supported command types from the LLM
public enum CommandType: String, Codable, CaseIterable {
    case APP_OPEN
    case FILE_SEARCH
    case WINDOW_MANAGE
    case SYSTEM_INFO
    case FILE_OP
    case PROCESS_MANAGE
    case QUICK_ACTION
}

// MARK: - Command Structure

/// Parsed command from LLM JSON output
public struct Command: Codable {
    public let type: CommandType
    public let target: String?
    public let query: String?
    public let parameters: [String: AnyCodable]?
    public let confidence: Double?

    public init(type: CommandType, target: String? = nil, query: String? = nil, parameters: [String: AnyCodable]? = nil, confidence: Double? = nil) {
        self.type = type
        self.target = target
        self.query = query
        self.parameters = parameters
        self.confidence = confidence
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for heterogeneous JSON parameters
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
}

// MARK: - Parser Errors

public enum CommandParserError: Error, LocalizedError {
    case invalidJSON(String)
    case missingType
    case unknownCommandType(String)
    case missingRequiredField(String)
    case invalidFormat(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail):
            return "Invalid JSON: \(detail)"
        case .missingType:
            return "Command is missing 'type' field"
        case .unknownCommandType(let type):
            return "Unknown command type: \(type)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFormat(let detail):
            return "Invalid format: \(detail)"
        }
    }
}

// MARK: - CommandParser

/// Parses LLM JSON output into structured Command objects
public struct CommandParser {

    /// Parse JSON string into Command struct
    /// - Parameter json: Raw JSON string from LLM output
    /// - Returns: Parsed Command object
    /// - Throws: CommandParserError if parsing fails
    public static func parse(_ json: String) throws -> Command {
        // Strip any leading/trailing whitespace or markdown code fences
        var cleanJSON = json.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown JSON code fences if present
        if cleanJSON.hasPrefix("```json") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "")
        }
        if cleanJSON.hasPrefix("```") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "")
        }
        if cleanJSON.hasSuffix("```") {
            cleanJSON = String(cleanJSON.dropLast(3))
        }
        cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract first valid JSON object if there's extra text
        if let jsonStart = cleanJSON.firstIndex(of: "{"),
           let jsonEnd = findMatchingBrace(in: cleanJSON, startingAt: jsonStart) {
            cleanJSON = String(cleanJSON[jsonStart...jsonEnd])
        }

        // Decode JSON
        guard let data = cleanJSON.data(using: .utf8) else {
            throw CommandParserError.invalidJSON("Could not convert to UTF-8")
        }

        let decoder = JSONDecoder()
        let command: Command

        do {
            command = try decoder.decode(Command.self, from: data)
        } catch {
            throw CommandParserError.invalidJSON(error.localizedDescription)
        }

        // Validate command structure
        try validate(command)

        return command
    }

    /// Validate that command has required fields
    private static func validate(_ command: Command) throws {
        // All commands should have a confidence score (but we won't fail if missing)
        // Type is already validated by Codable enum

        // Check type-specific required fields
        switch command.type {
        case .APP_OPEN:
            guard command.target != nil else {
                throw CommandParserError.missingRequiredField("target")
            }
        case .FILE_SEARCH:
            // FILE_SEARCH can have empty query with kind filter
            break
        case .WINDOW_MANAGE:
            // target can be "frontmost", "all", or specific app
            break
        case .SYSTEM_INFO:
            // target specifies what info (ip_address, disk_space, etc)
            break
        case .FILE_OP:
            guard command.target != nil else {
                throw CommandParserError.missingRequiredField("target")
            }
        case .PROCESS_MANAGE:
            guard command.target != nil else {
                throw CommandParserError.missingRequiredField("target")
            }
        case .QUICK_ACTION:
            guard command.target != nil else {
                throw CommandParserError.missingRequiredField("target")
            }
        }
    }

    /// Find matching closing brace for JSON object
    private static func findMatchingBrace(in string: String, startingAt start: String.Index) -> String.Index? {
        var depth = 0
        var inString = false
        var escapeNext = false

        var currentIndex = start
        while currentIndex < string.endIndex {
            let char = string[currentIndex]

            if escapeNext {
                escapeNext = false
                currentIndex = string.index(after: currentIndex)
                continue
            }

            if char == "\\" {
                escapeNext = true
                currentIndex = string.index(after: currentIndex)
                continue
            }

            if char == "\"" {
                inString.toggle()
                currentIndex = string.index(after: currentIndex)
                continue
            }

            if !inString {
                if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        return currentIndex
                    }
                }
            }

            currentIndex = string.index(after: currentIndex)
        }

        return nil
    }
}

// MARK: - Testing Helper

#if DEBUG
extension CommandParser {
    /// Test the parser with sample JSON inputs
    public static func runTests() {
        let tests: [(String, String)] = [
            // APP_OPEN
            (#"{"type": "APP_OPEN", "target": "https://youtube.com", "confidence": 0.95}"#, "APP_OPEN"),
            (#"{"type": "APP_OPEN", "target": "Safari", "confidence": 0.90}"#, "APP_OPEN"),

            // FILE_SEARCH
            (#"{"type": "FILE_SEARCH", "query": "tax", "parameters": {"kind": "pdf", "date": "2024"}, "confidence": 0.85}"#, "FILE_SEARCH"),

            // WINDOW_MANAGE
            (#"{"type": "WINDOW_MANAGE", "target": "frontmost", "parameters": {"position": "left_half"}, "confidence": 0.95}"#, "WINDOW_MANAGE"),

            // SYSTEM_INFO
            (#"{"type": "SYSTEM_INFO", "target": "ip_address", "confidence": 0.95}"#, "SYSTEM_INFO"),

            // FILE_OP
            (#"{"type": "FILE_OP", "target": "/path/to/file.txt", "parameters": {"action": "delete"}, "confidence": 0.90}"#, "FILE_OP"),

            // PROCESS_MANAGE
            (#"{"type": "PROCESS_MANAGE", "target": "Chrome", "parameters": {"action": "quit"}, "confidence": 0.90}"#, "PROCESS_MANAGE"),

            // QUICK_ACTION
            (#"{"type": "QUICK_ACTION", "target": "screenshot", "confidence": 0.95}"#, "QUICK_ACTION"),
        ]

        print("Running CommandParser tests...")
        var passed = 0
        var failed = 0

        for (json, expectedType) in tests {
            do {
                let command = try parse(json)
                if command.type.rawValue == expectedType {
                    passed += 1
                    print("✅ \(expectedType): \(command.description)")
                } else {
                    failed += 1
                    print("❌ Expected \(expectedType), got \(command.type.rawValue)")
                }
            } catch {
                failed += 1
                print("❌ Failed to parse \(expectedType): \(error)")
            }
        }

        print("\nResults: \(passed) passed, \(failed) failed")
    }
}
#endif

// MARK: - Convenience Extensions

extension Command {
    /// Get string parameter by key
    public func stringParam(_ key: String) -> String? {
        guard let params = parameters,
              let anyValue = params[key],
              let stringValue = anyValue.value as? String else {
            return nil
        }
        return stringValue
    }

    /// Get int parameter by key
    public func intParam(_ key: String) -> Int? {
        guard let params = parameters,
              let anyValue = params[key],
              let intValue = anyValue.value as? Int else {
            return nil
        }
        return intValue
    }

    /// Get bool parameter by key
    public func boolParam(_ key: String) -> Bool? {
        guard let params = parameters,
              let anyValue = params[key],
              let boolValue = anyValue.value as? Bool else {
            return nil
        }
        return boolValue
    }

    /// Human-readable description
    public var description: String {
        var parts = ["Command: \(type.rawValue)"]
        if let target = target {
            parts.append("Target: \(target)")
        }
        if let query = query {
            parts.append("Query: \(query)")
        }
        if let confidence = confidence {
            parts.append("Confidence: \(String(format: "%.0f%%", confidence * 100))")
        }
        return parts.joined(separator: ", ")
    }
}
