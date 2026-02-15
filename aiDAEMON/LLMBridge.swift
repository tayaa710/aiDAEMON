import Foundation
import LlamaSwift

public enum LLMBridgeError: Error {
    case modelNotLoaded
    case tokenizationFailed(prompt: String)
    case decodeFailed(code: Int32)
    case generationAborted
    case contextOverflow(requested: Int, available: Int)
}

public struct GenerationParams {
    public var maxTokens: Int32 = 256
    public var temperature: Float = 0.7
    public var topP: Float = 0.9
    public var topK: Int32 = 40
    public var repeatPenalty: Float = 1.1
    public var repeatPenaltyLastN: Int32 = 64

    public static let `default` = GenerationParams()

    public static let deterministic = GenerationParams(
        maxTokens: 256,
        temperature: 0.0,
        topP: 1.0,
        topK: 1,
        repeatPenalty: 1.1,
        repeatPenaltyLastN: 64
    )
}

public final class LLMBridge {
    public static let shared = LLMBridge()

    private var handle: ModelHandle?
    private let queue = DispatchQueue(label: "com.aidaemon.llmbridge", qos: .userInitiated)
    private var isGenerating = false

    public var isModelLoaded: Bool { handle != nil }

    private init() {}

    // MARK: - Load / Unload

    public func loadModel(path: String) -> Bool {
        unload()
        guard let loaded = ModelLoader.shared.loadModel(path: path) else {
            return false
        }
        handle = loaded
        return true
    }

    public func unload() {
        abortGeneration()
        handle = nil
    }

    // MARK: - Generation

    public func generate(
        prompt: String,
        params: GenerationParams = .default,
        onToken: ((String) -> Void)? = nil
    ) throws -> String {
        guard let handle = handle else {
            throw LLMBridgeError.modelNotLoaded
        }

        let vocab = llama_model_get_vocab(handle.model)
        let contextSize = llama_context_default_params().n_ctx

        // Tokenize the prompt
        let tokens = try tokenize(prompt: prompt, vocab: vocab, addBOS: true)

        let available = Int(contextSize) - tokens.count
        guard available > 0 else {
            throw LLMBridgeError.contextOverflow(
                requested: tokens.count,
                available: Int(contextSize)
            )
        }

        let maxGen = min(Int(params.maxTokens), available)

        // Clear KV cache for fresh generation
        let memory = llama_get_memory(handle.context)
        if let memory = memory {
            llama_memory_clear(memory, true)
        }

        // Decode the prompt tokens
        try decodePrompt(tokens: tokens, context: handle.context)

        // Set up sampler chain
        let sampler = buildSampler(params: params)
        defer { llama_sampler_free(sampler) }

        // Generate tokens one at a time
        isGenerating = true
        defer { isGenerating = false }

        var output = ""
        var currentPos = Int32(tokens.count)

        for _ in 0..<maxGen {
            guard isGenerating else {
                throw LLMBridgeError.generationAborted
            }

            let newToken = llama_sampler_sample(sampler, handle.context, -1)
            llama_sampler_accept(sampler, newToken)

            // Check for end-of-generation
            if llama_vocab_is_eog(vocab, newToken) {
                break
            }

            // Convert token to text
            let piece = tokenToPiece(token: newToken, vocab: vocab)
            output += piece
            onToken?(piece)

            // Decode the new token for next iteration
            var batch = llama_batch_init(1, 0, 1)
            defer { llama_batch_free(batch) }

            batch.n_tokens = 1
            batch.token[0] = newToken
            batch.pos[0] = currentPos
            batch.n_seq_id[0] = 1
            batch.seq_id[0]![0] = 0
            batch.logits[0] = 1

            let decodeResult = llama_decode(handle.context, batch)
            if decodeResult != 0 {
                throw LLMBridgeError.decodeFailed(code: decodeResult)
            }

            currentPos += 1
        }

        return output
    }

    public func abortGeneration() {
        isGenerating = false
    }

    // MARK: - Async generation

    public func generateAsync(
        prompt: String,
        params: GenerationParams = .default,
        onToken: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let result = try self.generate(prompt: prompt, params: params, onToken: onToken)
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Private Helpers

    private func tokenize(prompt: String, vocab: OpaquePointer!, addBOS: Bool) throws -> [llama_token] {
        let utf8 = prompt.utf8CString
        let maxTokens = Int32(utf8.count) + (addBOS ? 1 : 0)

        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        let nTokens = prompt.withCString { cStr in
            llama_tokenize(vocab, cStr, Int32(prompt.utf8.count), &tokens, maxTokens, addBOS, false)
        }

        guard nTokens >= 0 else {
            throw LLMBridgeError.tokenizationFailed(prompt: String(prompt.prefix(100)))
        }

        tokens.removeSubrange(Int(nTokens)...)
        return tokens
    }

    private func decodePrompt(tokens: [llama_token], context: OpaquePointer) throws {
        let batchSize = 512
        var pos: Int32 = 0

        for chunkStart in stride(from: 0, to: tokens.count, by: batchSize) {
            let chunkEnd = min(chunkStart + batchSize, tokens.count)
            let chunk = Array(tokens[chunkStart..<chunkEnd])
            let isLast = chunkEnd == tokens.count

            var batch = llama_batch_init(Int32(chunk.count), 0, 1)
            defer { llama_batch_free(batch) }

            batch.n_tokens = Int32(chunk.count)
            for (i, token) in chunk.enumerated() {
                batch.token[i] = token
                batch.pos[i] = pos + Int32(i)
                batch.n_seq_id[i] = 1
                batch.seq_id[i]![0] = 0
                batch.logits[i] = (isLast && i == chunk.count - 1) ? 1 : 0
            }

            let result = llama_decode(context, batch)
            if result != 0 {
                throw LLMBridgeError.decodeFailed(code: result)
            }

            pos += Int32(chunk.count)
        }
    }

    private func buildSampler(params: GenerationParams) -> UnsafeMutablePointer<llama_sampler> {
        let chainParams = llama_sampler_chain_default_params()
        let chain = llama_sampler_chain_init(chainParams)!

        // Repetition penalty
        llama_sampler_chain_add(chain, llama_sampler_init_penalties(
            params.repeatPenaltyLastN,
            params.repeatPenalty,
            0.0,  // frequency penalty
            0.0   // presence penalty
        ))

        if params.temperature <= 0 {
            // Greedy (deterministic) sampling
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        } else {
            // Top-K -> Top-P -> Temperature -> Distribution sampling
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(params.topK))
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(params.topP, 1))
            llama_sampler_chain_add(chain, llama_sampler_init_temp(params.temperature))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        }

        return chain
    }

    private func tokenToPiece(token: llama_token, vocab: OpaquePointer!) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        let len = llama_token_to_piece(vocab, token, &buf, 256, 0, false)
        if len > 0 {
            return String(cString: buf)
        }
        // For tokens needing more space
        if len < 0 {
            var bigBuf = [CChar](repeating: 0, count: Int(-len) + 1)
            let len2 = llama_token_to_piece(vocab, token, &bigBuf, Int32(-len) + 1, 0, false)
            if len2 > 0 {
                return String(cString: bigBuf)
            }
        }
        return ""
    }
}
