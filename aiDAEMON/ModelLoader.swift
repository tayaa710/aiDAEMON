import Foundation
import LlamaSwift

public final class ModelHandle {
    public let model: OpaquePointer
    public let context: OpaquePointer
    public let sourcePath: String

    public init(model: OpaquePointer, context: OpaquePointer, sourcePath: String) {
        self.model = model
        self.context = context
        self.sourcePath = sourcePath
    }

    deinit {
        llama_free(context)
        llama_model_free(model)
    }
}

public enum ModelLoaderError: Error {
    case fileNotFound(path: String)
    case unreadableModelFile(path: String, reason: String)
    case invalidModelFile(path: String)
    case modelLoadFailed(path: String)
    case contextInitializationFailed(path: String)
}

public final class ModelLoader {
    public static let shared = ModelLoader()

    private static var backendInitialized = false
    private static let backendInitLock = NSLock()

    public private(set) var lastError: ModelLoaderError?
    public private(set) var lastLoadDuration: TimeInterval?
    public private(set) var loadingProgress: Double = 0

    private init() {}

    public func loadModel(path: String) -> ModelHandle? {
        let resolvedPath = NSString(string: path).expandingTildeInPath
        let modelURL = URL(fileURLWithPath: resolvedPath)

        lastError = nil
        lastLoadDuration = nil
        loadingProgress = 0

        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            return fail(.fileNotFound(path: resolvedPath))
        }

        if let headerError = validateGGUFHeader(at: modelURL) {
            return fail(headerError)
        }

        loadingProgress = 0.15
        ensureBackendInitialized()

        let start = CFAbsoluteTimeGetCurrent()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 0
        modelParams.use_mmap = true

        let maybeModel = resolvedPath.withCString { pathCString in
            llama_model_load_from_file(pathCString, modelParams)
        }

        guard let model = maybeModel else {
            return fail(.modelLoadFailed(path: resolvedPath))
        }

        loadingProgress = 0.85

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048
        contextParams.n_batch = 512

        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            return fail(.contextInitializationFailed(path: resolvedPath))
        }

        loadingProgress = 1.0
        let duration = CFAbsoluteTimeGetCurrent() - start
        lastLoadDuration = duration

        NSLog("Model loaded successfully in %.2f seconds: %@", duration, resolvedPath)
        return ModelHandle(model: model, context: context, sourcePath: resolvedPath)
    }

    private func fail(_ error: ModelLoaderError) -> ModelHandle? {
        lastError = error
        loadingProgress = 0
        NSLog("Model loading failed: %@", String(describing: error))
        return nil
    }

    private func validateGGUFHeader(at url: URL) -> ModelLoaderError? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }

            guard let header = try handle.read(upToCount: 4), header.count == 4 else {
                return .invalidModelFile(path: url.path)
            }

            if Array(header) != [0x47, 0x47, 0x55, 0x46] {
                return .invalidModelFile(path: url.path)
            }

            return nil
        } catch {
            return .unreadableModelFile(path: url.path, reason: error.localizedDescription)
        }
    }

    private func ensureBackendInitialized() {
        Self.backendInitLock.lock()
        defer { Self.backendInitLock.unlock() }

        guard !Self.backendInitialized else { return }
        llama_backend_init()
        Self.backendInitialized = true
    }
}
