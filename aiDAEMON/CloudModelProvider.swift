import Foundation

// MARK: - CloudProviderType

/// Supported cloud LLM API backends.
///
/// OpenAI, Groq, Together AI, and Custom use the OpenAI-compatible chat completions format.
/// Anthropic uses its own Messages API format (different headers, body, and response shape).
///
/// The user's CHOICE of provider (this enum value) is stored in UserDefaults under "cloud.provider".
/// The API KEY for each provider is stored in macOS Keychain under the provider's `keychainKey`.
/// These two are always kept separate — UserDefaults never stores secrets.
public enum CloudProviderType: String, CaseIterable {
    case anthropic  = "Anthropic"
    case openAI     = "OpenAI"
    case groq       = "Groq"
    case togetherAI = "Together AI"
    case custom     = "Custom"

    /// The currently selected provider (reads from UserDefaults, defaults to OpenAI).
    /// NOTE: This default MUST match the @AppStorage default in CloudSettingsTab.
    public static var current: CloudProviderType {
        let stored = UserDefaults.standard.string(forKey: "cloud.provider") ?? ""
        return CloudProviderType(rawValue: stored) ?? .openAI
    }

    /// HTTPS endpoint for this provider.
    /// For "Custom", reads from UserDefaults "cloud.customEndpoint".
    var endpoint: String {
        switch self {
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .togetherAI:
            return "https://api.together.xyz/v1/chat/completions"
        case .custom:
            return UserDefaults.standard.string(forKey: "cloud.customEndpoint") ?? ""
        }
    }

    /// Default model identifier for this provider.
    /// For "Custom", reads from UserDefaults "cloud.customModel".
    var defaultModel: String {
        switch self {
        case .anthropic:
            return "claude-opus-4-5-20250929"
        case .openAI:
            return "gpt-4o-mini"
        case .groq:
            return "llama-3.1-70b-versatile"
        case .togetherAI:
            return "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo"
        case .custom:
            return UserDefaults.standard.string(forKey: "cloud.customModel") ?? ""
        }
    }

    /// Keychain account name for storing this provider's API key.
    /// This is the *lookup key*, never the secret value itself.
    var keychainKey: String {
        "cloud-apikey-\(rawValue)"
    }

    /// True for providers that use Anthropic's Messages API format.
    /// False for providers that use the OpenAI chat completions format.
    var usesAnthropicFormat: Bool {
        self == .anthropic
    }
}

// MARK: - CloudModelError

/// Errors that can be thrown by CloudModelProvider.generate().
public enum CloudModelError: Error, LocalizedError {
    case noAPIKey
    case insecureEndpoint(String)
    case invalidEndpointURL(String)
    case httpError(statusCode: Int, body: String)
    case invalidResponse
    case noContentInResponse
    case requestAborted

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Go to Settings → Cloud to add your key."
        case .insecureEndpoint(let url):
            return "Endpoint must use HTTPS. Insecure URL rejected: \(url)"
        case .invalidEndpointURL(let url):
            return "Invalid API endpoint URL: \(url)"
        case .httpError(let code, let body):
            switch code {
            case 401:
                return "Invalid API key (401). Please check your key in Settings → Cloud."
            case 429:
                return "Rate limit reached (429). Please wait a moment and try again."
            case 500...599:
                return "Cloud service error (\(code)). Please try again."
            default:
                return "API error (\(code)): \(body.prefix(200))"
            }
        case .invalidResponse:
            return "Received an unexpected response from the cloud model."
        case .noContentInResponse:
            return "Cloud model returned an empty response."
        case .requestAborted:
            return "Request was cancelled."
        }
    }
}

// MARK: - CloudModelProvider

/// Implements ModelProvider by sending prompts to a cloud LLM API over HTTPS.
///
/// Security properties (enforced in code, not just convention):
/// - API key is loaded from macOS Keychain at call time; never stored in a property or logged.
/// - HTTPS-only: requests to non-HTTPS endpoints are rejected before any network activity.
/// - API key appears only in the Authorization header; never in the prompt, response, or logs.
/// - No API key → isAvailable = false (graceful degradation, no crash, no error dialog).
public final class CloudModelProvider: ModelProvider {

    public let providerType: CloudProviderType

    public var providerName: String {
        "\(providerType.rawValue) Cloud"
    }

    /// Session-level cache of whether an API key exists in Keychain.
    /// Set once in init() — never re-checked on a timer. Only refreshAvailability()
    /// can update it. This eliminates repeated Keychain prompts during routing checks.
    ///
    /// Note: generate() still reads the actual key from Keychain at call time
    /// (security requirement). Once the user grants "Always Allow" in the Keychain
    /// dialog, that generate() access becomes silent and no prompts appear.
    private var cachedKeyExists: Bool

    /// True when an API key exists in the Keychain for this provider.
    public var isAvailable: Bool { cachedKeyExists }

    /// Refresh the cached availability. Call this after saving or removing an API key in Settings.
    public func refreshAvailability() {
        cachedKeyExists = KeychainHelper.load(key: providerType.keychainKey) != nil
    }

    /// In-flight Task, held so abort() can cancel it.
    private var inflightTask: Task<String, Error>?

    public init(providerType: CloudProviderType = .current) {
        self.providerType = providerType
        // Read Keychain once at init to seed the session cache.
        // This is the only automatic Keychain read — all subsequent isAvailable checks
        // use the cached value. rebuildRouter() creates a new instance, so startup
        // still triggers one read, which is acceptable.
        cachedKeyExists = KeychainHelper.load(key: providerType.keychainKey) != nil
    }

    // MARK: - ModelProvider

    public func generate(
        prompt: String,
        params: GenerationParams,
        onToken: ((String) -> Void)?
    ) async throws -> String {

        // ── Step 1: Load API key from Keychain at call time ─────────────────────
        // The key is intentionally NOT stored in any instance property.
        guard let apiKey = KeychainHelper.load(key: providerType.keychainKey) else {
            throw CloudModelError.noAPIKey
        }

        // ── Step 2: Validate endpoint — HTTPS only ───────────────────────────────
        let endpointString = providerType.endpoint
        guard endpointString.hasPrefix("https://") else {
            throw CloudModelError.insecureEndpoint(endpointString)
        }
        guard let url = URL(string: endpointString) else {
            throw CloudModelError.invalidEndpointURL(endpointString)
        }

        // ── Step 3: Resolve model name ───────────────────────────────────────────
        // User override in UserDefaults takes priority; falls back to provider default.
        let modelName = UserDefaults.standard.string(forKey: "cloud.modelName")
            ?? providerType.defaultModel

        // ── Step 4: Build request — Anthropic format vs OpenAI-compatible format ─
        let bodyData: Data
        var request = URLRequest(url: url)
        request.httpMethod  = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("aiDAEMON/1.0",     forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30.0

        if providerType.usesAnthropicFormat {
            // Anthropic Messages API format:
            // - Auth: x-api-key header (not Authorization: Bearer)
            // - Extra header: anthropic-version
            // - max_tokens is required (not optional)
            let requestBody: [String: Any] = [
                "model":      modelName,
                "max_tokens": Int(params.maxTokens),
                "messages":   [["role": "user", "content": prompt]]
            ]
            bodyData = try JSONSerialization.data(withJSONObject: requestBody)
            request.setValue(apiKey,          forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01",    forHTTPHeaderField: "anthropic-version")
        } else {
            // OpenAI-compatible chat completions format (OpenAI, Groq, Together AI, Custom)
            let requestBody: [String: Any] = [
                "model":       modelName,
                "messages":    [["role": "user", "content": prompt]],
                "max_tokens":  Int(params.maxTokens),
                "temperature": Double(params.temperature),
                "top_p":       Double(params.topP)
            ]
            bodyData = try JSONSerialization.data(withJSONObject: requestBody)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData

        // ── Step 5: Execute request in a cancellable Task ────────────────────────
        let task = Task<String, Error> {
            let data: Data
            let response: URLResponse

            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw CloudModelError.requestAborted
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudModelError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw CloudModelError.httpError(statusCode: httpResponse.statusCode, body: body)
            }

            // ── Step 6: Parse response — Anthropic vs OpenAI-compatible ──────────
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CloudModelError.invalidResponse
            }

            let content: String

            if providerType.usesAnthropicFormat {
                // Anthropic response shape: {"content": [{"type": "text", "text": "..."}]}
                guard
                    let contentArray = json["content"] as? [[String: Any]],
                    let first        = contentArray.first,
                    let text         = first["text"] as? String,
                    !text.isEmpty
                else {
                    throw CloudModelError.noContentInResponse
                }
                content = text
            } else {
                // OpenAI-compatible response shape: {"choices": [{"message": {"content": "..."}}]}
                guard
                    let choices = json["choices"]        as? [[String: Any]],
                    let first   = choices.first,
                    let message = first["message"]       as? [String: Any],
                    let text    = message["content"]     as? String,
                    !text.isEmpty
                else {
                    throw CloudModelError.noContentInResponse
                }
                content = text
            }

            // Cloud responses arrive as a complete string (not streamed in this implementation).
            // Deliver the whole response as a single "token" callback for compatibility
            // with callers that display streaming output.
            onToken?(content)
            return content
        }

        inflightTask = task
        defer { inflightTask = nil }

        do {
            return try await task.value
        } catch is CancellationError {
            throw CloudModelError.requestAborted
        }
    }

    /// Cancel any in-flight request. Safe to call when idle.
    public func abort() {
        inflightTask?.cancel()
        inflightTask = nil
    }
}
