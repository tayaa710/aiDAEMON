import Foundation

// MARK: - Anthropic Model Selection

/// Claude model options available through the Anthropic API.
public enum AnthropicModel: String, CaseIterable {
    case sonnet = "claude-sonnet-4-5-20250929"
    case opus   = "claude-opus-4-6"

    var displayName: String {
        switch self {
        case .sonnet: return "Claude Sonnet 4.5 (Recommended)"
        case .opus:   return "Claude Opus 4.6 (Most Capable)"
        }
    }

    /// Reads the current selection from UserDefaults, defaults to Sonnet.
    static var current: AnthropicModel {
        let stored = UserDefaults.standard.string(forKey: "cloud.anthropicModel") ?? ""
        return AnthropicModel(rawValue: stored) ?? .sonnet
    }
}

// MARK: - Anthropic Tool-Use Response Types

public enum AnthropicStopReason: Equatable {
    case endTurn
    case toolUse
    case maxTokens
    case stopSequence
    case unknown(String?)

    init(apiValue: String?) {
        switch apiValue {
        case "end_turn": self = .endTurn
        case "tool_use": self = .toolUse
        case "max_tokens": self = .maxTokens
        case "stop_sequence": self = .stopSequence
        default: self = .unknown(apiValue)
        }
    }
}

public struct AnthropicToolUseBlock: Equatable {
    public let id: String
    public let name: String
    public let input: [String: Any]

    public static func == (lhs: AnthropicToolUseBlock, rhs: AnthropicToolUseBlock) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && NSDictionary(dictionary: lhs.input).isEqual(to: rhs.input)
    }
}

public struct AnthropicResponse {
    public let stopReason: AnthropicStopReason
    public let rawContentBlocks: [[String: Any]]
    public let textBlocks: [String]
    public let toolUseBlocks: [AnthropicToolUseBlock]

    public var textContent: String {
        textBlocks.joined()
    }
}

// MARK: - Anthropic Error

/// Errors specific to the Anthropic Messages API.
public enum AnthropicModelError: Error, LocalizedError {
    case noAPIKey
    case httpError(statusCode: Int, body: String)
    case invalidResponse
    case noContentInResponse
    case requestAborted

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No Anthropic API key configured. Go to Settings → Cloud to add your key."
        case .httpError(let code, let body):
            switch code {
            case 401:
                return "Invalid Anthropic API key (401). Check your key in Settings → Cloud."
            case 429:
                return "Anthropic rate limit reached (429). Please wait a moment and try again."
            case 529:
                return "Anthropic API is overloaded (529). Please try again in a few seconds."
            case 500...599:
                return "Anthropic service error (\(code)). Please try again."
            default:
                return "Anthropic API error (\(code)): \(body.prefix(200))"
            }
        case .invalidResponse:
            return "Received an unexpected response from Anthropic."
        case .noContentInResponse:
            return "Anthropic returned an empty response."
        case .requestAborted:
            return "Request was cancelled."
        }
    }
}

// MARK: - Anthropic Model Provider

/// Implements ModelProvider by sending prompts to the Anthropic Messages API.
///
/// The Anthropic API uses a DIFFERENT format from OpenAI:
///   - Endpoint: https://api.anthropic.com/v1/messages
///   - Auth: x-api-key header (not Bearer token)
///   - Request body: { "model", "max_tokens", "system", "messages" }
///   - Response: { "content": [{"type": "text", "text": "..."}], "stop_reason": "end_turn"|"tool_use" }
///
/// Security properties:
///   - API key loaded from Keychain at call time; never stored in a property.
///   - HTTPS only (hardcoded endpoint).
///   - Key appears only in x-api-key header; never in prompt, response, or logs.
public final class AnthropicModelProvider: ModelProvider {

    /// Keychain key for the Anthropic API key.
    public static let keychainKey = "anthropic-apikey"

    /// The Anthropic Messages API endpoint.
    private static let endpoint = "https://api.anthropic.com/v1/messages"

    /// Required API version header.
    private static let apiVersion = "2023-06-01"

    /// Session-level cache of whether an API key exists in Keychain.
    private var cachedKeyExists: Bool

    /// In-flight request task for cancellation.
    private var inflightTask: Task<Any, Error>?

    // MARK: - ModelProvider

    public var providerName: String { "Anthropic Claude" }

    public var isAvailable: Bool { cachedKeyExists }

    /// Refresh the cached availability. Call after saving or removing the API key.
    public func refreshAvailability() {
        cachedKeyExists = KeychainHelper.load(key: Self.keychainKey) != nil
    }

    public init() {
        cachedKeyExists = KeychainHelper.load(key: Self.keychainKey) != nil
    }

    public func generate(
        prompt: String,
        params: GenerationParams,
        onToken: ((String) -> Void)?
    ) async throws -> String {
        let requestBody: [String: Any] = [
            "model": modelName(),
            "max_tokens": Int(params.maxTokens),
            "messages": [["role": "user", "content": prompt]]
        ]
        let response = try await performRequest(body: requestBody)
        let fullText = response.textContent
        guard !fullText.isEmpty else {
            throw AnthropicModelError.noContentInResponse
        }
        onToken?(fullText)
        return fullText
    }

    /// Sends a full Anthropic tool-use request and returns parsed mixed content blocks.
    public func sendWithTools(
        messages: [[String: Any]],
        system: String,
        tools: [[String: Any]]
    ) async throws -> AnthropicResponse {
        let requestBody: [String: Any] = [
            "model": modelName(),
            "max_tokens": 4096,
            "system": system,
            "messages": messages,
            "tools": tools
        ]
        return try await performRequest(body: requestBody)
    }

    public func abort() {
        inflightTask?.cancel()
        inflightTask = nil
    }

    // MARK: - Request/Response internals

    private func modelName() -> String {
        AnthropicModel.current.rawValue
    }

    private func performRequest(body: [String: Any]) async throws -> AnthropicResponse {
        guard let apiKey = KeychainHelper.load(key: Self.keychainKey) else {
            throw AnthropicModelError.noAPIKey
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        guard let url = URL(string: Self.endpoint) else {
            throw AnthropicModelError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("aiDAEMON/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30.0

        let task = Task<Any, Error> {
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw AnthropicModelError.requestAborted
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AnthropicModelError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                throw AnthropicModelError.httpError(statusCode: httpResponse.statusCode, body: bodyText)
            }

            return try self.parseAnthropicResponse(data: data)
        }

        inflightTask = task
        defer { inflightTask = nil }

        do {
            let value = try await task.value
            guard let parsed = value as? AnthropicResponse else {
                throw AnthropicModelError.invalidResponse
            }
            return parsed
        } catch is CancellationError {
            throw AnthropicModelError.requestAborted
        }
    }

    private func parseAnthropicResponse(data: Data) throws -> AnthropicResponse {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let contentArray = json["content"] as? [[String: Any]]
        else {
            throw AnthropicModelError.invalidResponse
        }

        let stopReason = AnthropicStopReason(apiValue: json["stop_reason"] as? String)
        var rawBlocks: [[String: Any]] = []
        var textBlocks: [String] = []
        var toolBlocks: [AnthropicToolUseBlock] = []

        for block in contentArray {
            guard let type = block["type"] as? String else { continue }

            switch type {
            case "text":
                guard let text = block["text"] as? String else { continue }
                textBlocks.append(text)
                rawBlocks.append(["type": "text", "text": text])

            case "tool_use":
                guard
                    let id = block["id"] as? String,
                    let name = block["name"] as? String
                else { continue }

                let input = block["input"] as? [String: Any] ?? [:]
                toolBlocks.append(AnthropicToolUseBlock(id: id, name: name, input: input))
                rawBlocks.append([
                    "type": "tool_use",
                    "id": id,
                    "name": name,
                    "input": input
                ])

            default:
                // Preserve unknown block types for forward compatibility.
                rawBlocks.append(block)
            }
        }

        return AnthropicResponse(
            stopReason: stopReason,
            rawContentBlocks: rawBlocks,
            textBlocks: textBlocks,
            toolUseBlocks: toolBlocks
        )
    }
}
