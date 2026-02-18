import Foundation

// MARK: - LocalModelProvider
//
// Wraps the existing LLMBridge (llama.cpp) behind the ModelProvider protocol.
// All local inference goes through this provider. No network traffic.

public final class LocalModelProvider: ModelProvider {

    public let providerName = "Local LLaMA 8B"

    private let bridge: LLMBridge

    public init(bridge: LLMBridge = .shared) {
        self.bridge = bridge
    }

    public var isAvailable: Bool {
        bridge.isModelLoaded
    }

    public func generate(
        prompt: String,
        params: GenerationParams,
        onToken: ((String) -> Void)?
    ) async throws -> String {
        // Bridge uses synchronous generation on a background queue.
        // Wrap it in a checked continuation for async/await.
        try await withCheckedThrowingContinuation { continuation in
            bridge.generateAsync(
                prompt: prompt,
                params: params,
                onToken: onToken
            ) { result in
                switch result {
                case .success(let text):
                    continuation.resume(returning: text)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func abort() {
        bridge.abortGeneration()
    }
}
