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

    // MARK: - Generate

    public func generate(
        prompt: String,
        params: GenerationParams = .default,
        onToken: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard state == .ready else {
            let err = bridge.isModelLoaded
                ? LLMBridgeError.modelNotLoaded
                : LLMBridgeError.modelNotLoaded
            completion(.failure(err))
            return
        }

        DispatchQueue.main.async { self.state = .generating }

        bridge.generateAsync(prompt: prompt, params: params, onToken: onToken) { [weak self] result in
            DispatchQueue.main.async {
                self?.state = .ready
            }
            completion(result)
        }
    }

    public func abort() {
        bridge.abortGeneration()
    }

    public func unload() {
        bridge.unload()
        state = .idle
    }
}
