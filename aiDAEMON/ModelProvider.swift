import Foundation

// MARK: - ModelProvider Protocol
//
// Abstraction over local and cloud model backends.
// Both LocalModelProvider and (future) CloudModelProvider conform to this.
// LLMManager uses this protocol so the model backend is swappable.

public protocol ModelProvider {
    /// Human-readable name for this provider (e.g., "Local LLaMA 8B", "Groq Cloud")
    var providerName: String { get }

    /// Whether this provider is currently available for inference.
    /// Local: model loaded. Cloud: API key configured and network reachable.
    var isAvailable: Bool { get }

    /// Generate text from a prompt.
    /// - Parameters:
    ///   - prompt: The full prompt string to send to the model.
    ///   - params: Sampling/generation parameters.
    ///   - onToken: Optional streaming callback, called with each token as it's generated.
    ///              Not all providers support streaming — cloud providers may call this once with the full response.
    /// - Returns: The complete generated text.
    func generate(
        prompt: String,
        params: GenerationParams,
        onToken: ((String) -> Void)?
    ) async throws -> String

    /// Abort any in-progress generation. Safe to call if nothing is generating.
    func abort()
}
