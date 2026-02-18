import Foundation

public enum LLMManagerState: Equatable {
    case idle
    case loading
    case ready
    case generating
    case error(String)
}

public final class LLMManager: ObservableObject {
    public static let shared = LLMManager()

    @Published public private(set) var state: LLMManagerState = .idle

    /// The active model provider (local or cloud). Set after model loads.
    public private(set) var activeProvider: (any ModelProvider)?

    /// The provider currently generating (set during generation, cleared after).
    /// Used by abort() to cancel the correct provider.
    private var generatingProvider: (any ModelProvider)?

    /// The name of the provider that handled the last request.
    @Published public private(set) var lastProviderName: String = ""

    /// Whether the last request used the cloud provider.
    @Published public private(set) var lastWasCloud: Bool = false

    /// The routing reason for the last request (shown in UI for transparency).
    @Published public private(set) var lastRoutingReason: String = ""

    /// Manually set provider metadata (used when early abort bypasses the normal success path).
    public func setLastProvider(name: String, wasCloud: Bool, reason: String) {
        lastProviderName = name
        lastWasCloud = wasCloud
        lastRoutingReason = reason
        state = .ready
    }

    /// The model router (created after local model loads).
    public private(set) var router: ModelRouter?

    private let bridge = LLMBridge.shared
    private let queue = DispatchQueue(label: "com.aidaemon.llmmanager", qos: .userInitiated)

    private init() {}

    // MARK: - Model path

    // Use #filePath at compile time to locate the project source root.
    // This file is at <project>/aiDAEMON/LLMManager.swift, so parent of parent = project root.
    private static let sourceFileDir = (#filePath as NSString).deletingLastPathComponent
    private static let projectRoot = (sourceFileDir as NSString).deletingLastPathComponent

    public var defaultModelPath: String {
        let appDir = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
        let candidates = [
            // Next to the .app bundle (for production)
            (appDir as NSString).appendingPathComponent("Models/model.gguf"),
            // Project source root (for development via #filePath)
            (Self.projectRoot as NSString).appendingPathComponent("Models/model.gguf"),
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback
        return (Self.projectRoot as NSString).appendingPathComponent("Models/model.gguf")
    }

    // MARK: - Load

    public func loadModelAsync(path: String? = nil) {
        let modelPath = path ?? defaultModelPath
        DispatchQueue.main.async { self.state = .loading }

        queue.async { [weak self] in
            guard let self = self else { return }

            NSLog("LLMManager: Loading model from %@", modelPath)
            let success = self.bridge.loadModel(path: modelPath)

            DispatchQueue.main.async {
                if success {
                    NSLog("LLMManager: Model loaded successfully")
                    let localProvider = LocalModelProvider(bridge: self.bridge)
                    self.activeProvider = localProvider
                    self.rebuildRouter(local: localProvider)
                    self.state = .ready
                } else {
                    let errorDesc: String
                    if let err = ModelLoader.shared.lastError {
                        errorDesc = String(describing: err)
                    } else {
                        errorDesc = "Unknown error"
                    }
                    NSLog("LLMManager: Model load failed - %@", errorDesc)
                    self.state = .error("Model load failed: \(errorDesc)")
                }
            }
        }
    }

    /// Rebuild the router with current providers. Call after model load or when cloud config changes.
    public func rebuildRouter(local: (any ModelProvider)? = nil) {
        let localProv = local ?? activeProvider ?? LocalModelProvider(bridge: bridge)
        let cloudProv = CloudModelProvider()
        router = ModelRouter(local: localProv, cloud: cloudProv)
    }

    // MARK: - Generate

    public func generate(
        prompt: String,
        userInput: String = "",
        params: GenerationParams = .default,
        onToken: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // NOTE: Router is NOT rebuilt here. It's rebuilt on model load and when
        // the user changes cloud settings (via rebuildRouter()). Rebuilding on
        // every generate() was causing repeated Keychain access prompts.

        guard let router = router else {
            completion(.failure(LLMBridgeError.modelNotLoaded))
            return
        }

        let decision = router.route(input: userInput.isEmpty ? prompt : userInput)
        let provider = decision.provider

        guard provider.isAvailable else {
            // If the chosen provider isn't available, try the fallback
            if let fallbackProvider = router.fallback(for: provider), fallbackProvider.isAvailable {
                let fallbackDecision = RoutingDecision(
                    provider: fallbackProvider,
                    reason: "Primary unavailable — using \(fallbackProvider.providerName)"
                )
                executeGeneration(provider: fallbackProvider, decision: fallbackDecision,
                                  prompt: prompt, params: params, onToken: onToken,
                                  router: router, completion: completion)
                return
            }
            completion(.failure(LLMBridgeError.modelNotLoaded))
            return
        }

        executeGeneration(provider: provider, decision: decision,
                          prompt: prompt, params: params, onToken: onToken,
                          router: router, completion: completion)
    }

    private func executeGeneration(
        provider: any ModelProvider,
        decision: RoutingDecision,
        prompt: String,
        params: GenerationParams,
        onToken: ((String) -> Void)?,
        router: ModelRouter,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        self.generatingProvider = provider

        DispatchQueue.main.async {
            self.state = .generating
            self.lastRoutingReason = decision.reason
        }

        Task {
            do {
                let result = try await provider.generate(
                    prompt: prompt,
                    params: params,
                    onToken: onToken
                )
                await MainActor.run {
                    self.generatingProvider = nil
                    self.lastProviderName = provider.providerName
                    self.lastWasCloud = decision.isCloud
                    self.state = .ready
                    completion(.success(result))
                }
            } catch {
                // Fallback: if the primary provider failed, try the other one
                if let fallbackProvider = router.fallback(for: provider), fallbackProvider.isAvailable {
                    NSLog("ModelRouter: Primary (%@) failed: %@. Trying fallback (%@).",
                          provider.providerName,
                          error.localizedDescription,
                          fallbackProvider.providerName)
                    do {
                        let result = try await fallbackProvider.generate(
                            prompt: prompt,
                            params: params,
                            onToken: onToken
                        )
                        let fallbackIsCloud = fallbackProvider.providerName.lowercased().contains("cloud")
                        await MainActor.run {
                            self.generatingProvider = nil
                            self.lastProviderName = fallbackProvider.providerName
                            self.lastWasCloud = fallbackIsCloud
                            self.lastRoutingReason = "Fallback: \(provider.providerName) failed, used \(fallbackProvider.providerName)"
                            self.state = .ready
                            completion(.success(result))
                        }
                    } catch let fallbackError {
                        await MainActor.run {
                            self.generatingProvider = nil
                            self.state = .ready
                            completion(.failure(fallbackError))
                        }
                    }
                } else {
                    await MainActor.run {
                        self.generatingProvider = nil
                        self.state = .ready
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    public func abort() {
        // Abort the provider that's actually generating, not just the local one
        generatingProvider?.abort()
        generatingProvider = nil
    }

    public func unload() {
        bridge.unload()
        activeProvider = nil
        router = nil
        state = .idle
    }
}
