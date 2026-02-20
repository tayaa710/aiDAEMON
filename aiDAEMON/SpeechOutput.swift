import AppKit
import AVFoundation
import Foundation

struct SpeechVoiceOption: Identifiable, Hashable {
    let identifier: String
    let name: String
    let languageCode: String

    var id: String { identifier }

    var displayName: String {
        "\(name) (\(languageCode))"
    }
}

/// Text-to-speech manager for assistant responses.
/// Primary path is on-device AVSpeechSynthesizer for offline support.
@MainActor
final class SpeechOutput: NSObject, ObservableObject, @preconcurrency AVSpeechSynthesizerDelegate {
    static let shared = SpeechOutput()

    static let voiceModeDefaultsKey = "voice.mode.enabled"
    static let voiceEnabledDefaultsKey = "voice.output.enabled"
    static let useCloudTTSDefaultsKey = "voice.output.useCloudTTS"
    static let voiceIdentifierDefaultsKey = "voice.output.voiceIdentifier"
    static let speechRateDefaultsKey = "voice.output.rateMultiplier"
    static let deepgramTTSAPIKeyKeychainKey = SpeechInput.deepgramSTTAPIKeyKeychainKey

    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isTestingConnection: Bool = false
    @Published private(set) var lastTestResult: String?

    private let synthesizer = AVSpeechSynthesizer()
    /// Retains the player so it doesn't get deallocated mid-playback.
    private var audioPlayer: AVAudioPlayer?
    /// In-flight Deepgram request task so we can cancel it on stop().
    private var deepgramTask: Task<Void, Never>?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard Self.voiceOutputEnabled else { return }

        // Never stack utterances; newest response replaces prior speech.
        stop()
        lastErrorMessage = nil

        if Self.cloudTTSEnabled, Self.hasDeepgramKey {
            isSpeaking = true
            deepgramTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.speakWithDeepgram(text: cleaned)
                } catch {
                    if Task.isCancelled { return }
                    let msg = error.localizedDescription
                    NSLog("SpeechOutput: Deepgram TTS failed (\(msg)), falling back to on-device")
                    await MainActor.run {
                        self.lastErrorMessage = "Cloud TTS failed: \(msg) — using on-device voice"
                        self.speakOnDevice(text: cleaned)
                    }
                }
            }
            return
        }

        speakOnDevice(text: cleaned)
    }

    /// On-device AVSpeechSynthesizer fallback (always available offline).
    private func speakOnDevice(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = Self.speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        if let configuredVoice = Self.selectedVoice {
            utterance.voice = configuredVoice
        } else if let englishVoice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = englishVoice
        }

        synthesizer.speak(utterance)
    }

    /// Call Deepgram Aura TTS API and play the returned audio.
    private func speakWithDeepgram(text: String) async throws {
        guard let apiKey = KeychainHelper.load(key: Self.deepgramTTSAPIKeyKeychainKey) else {
            throw DeepgramTTSError.noAPIKey
        }

        var components = URLComponents(string: "https://api.deepgram.com/v1/speak")!
        components.queryItems = [
            URLQueryItem(name: "model", value: "aura-2-thalia-en"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "24000"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: String] = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepgramTTSError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = String(data: data.prefix(500), encoding: .utf8) ?? "no body"
            throw DeepgramTTSError.httpError(httpResponse.statusCode, detail)
        }
        guard !data.isEmpty else {
            throw DeepgramTTSError.emptyAudio
        }

        try Task.checkCancellation()

        // linear16 PCM @ 24kHz, mono, 16-bit little-endian
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24000,
            channels: 1,
            interleaved: true
        )!
        let frameCount = AVAudioFrameCount(data.count / 2) // 2 bytes per sample
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            throw DeepgramTTSError.bufferCreationFailed
        }
        pcmBuffer.frameLength = frameCount

        // Copy PCM data into the buffer
        data.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.baseAddress else { return }
            memcpy(pcmBuffer.int16ChannelData![0], src, data.count)
        }

        // Convert to WAV in memory so AVAudioPlayer can play it
        let wavData = try Self.wavData(from: pcmBuffer, format: audioFormat)

        try Task.checkCancellation()

        await MainActor.run { [weak self] in
            guard let self else { return }
            do {
                let player = try AVAudioPlayer(data: wavData)
                self.audioPlayer = player
                player.play()
                self.isSpeaking = true
                // Poll for completion since AVAudioPlayer delegate is tricky with @MainActor
                self.pollAudioPlayerCompletion()
            } catch {
                NSLog("SpeechOutput: AVAudioPlayer failed: \(error.localizedDescription)")
                self.isSpeaking = false
            }
        }
    }

    /// Poll until the audio player finishes, then reset `isSpeaking`.
    private func pollAudioPlayerCompletion() {
        Task { [weak self] in
            while let self = self, let player = self.audioPlayer, player.isPlaying {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if self.audioPlayer != nil, !(self.audioPlayer?.isPlaying ?? false) {
                    self.isSpeaking = false
                    self.audioPlayer = nil
                }
            }
        }
    }

    /// Wrap raw PCM data in a minimal WAV header so AVAudioPlayer can decode it.
    private static func wavData(from buffer: AVAudioPCMBuffer, format: AVAudioFormat) throws -> Data {
        let channels = UInt16(format.channelCount)
        let sampleRate = UInt32(format.sampleRate)
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = bitsPerSample / 8
        let dataSize = UInt32(buffer.frameLength) * UInt32(channels) * UInt32(bytesPerSample)
        let fileSize = 36 + dataSize

        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        header.append(littleEndian: fileSize)
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(littleEndian: UInt32(16)) // PCM chunk size
        header.append(littleEndian: UInt16(1))  // PCM format
        header.append(littleEndian: channels)
        header.append(littleEndian: sampleRate)
        header.append(littleEndian: sampleRate * UInt32(channels) * UInt32(bytesPerSample)) // byte rate
        header.append(littleEndian: channels * bytesPerSample) // block align
        header.append(littleEndian: bitsPerSample)
        header.append(contentsOf: "data".utf8)
        header.append(littleEndian: dataSize)

        // Append PCM samples
        let rawBytes = Data(bytes: buffer.int16ChannelData![0], count: Int(dataSize))
        header.append(rawBytes)
        return header
    }

    func stop() {
        deepgramTask?.cancel()
        deepgramTask = nil

        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        isSpeaking = false
    }

    func clearError() {
        lastErrorMessage = nil
    }

    /// Test the Deepgram TTS connection by synthesizing a short phrase and playing it.
    func testDeepgramConnection() {
        guard !isTestingConnection else { return }
        isTestingConnection = true
        lastTestResult = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.speakWithDeepgram(text: "Deepgram cloud voice is connected.")
                await MainActor.run {
                    self.lastTestResult = "Connected — playing test audio"
                    self.isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    self.lastTestResult = "Failed: \(error.localizedDescription)"
                    self.isTestingConnection = false
                }
            }
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    // MARK: - Settings Helpers

    static var voiceModeEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: voiceModeDefaultsKey) != nil else {
            return voiceOutputEnabled && SpeechInput.voiceInputEnabled
        }
        return defaults.bool(forKey: voiceModeDefaultsKey)
    }

    static func setVoiceModeEnabled(_ enabled: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: voiceModeDefaultsKey)
        defaults.set(enabled, forKey: SpeechInput.voiceEnabledDefaultsKey)
        defaults.set(enabled, forKey: voiceEnabledDefaultsKey)
    }

    static func refreshVoiceModeFlagFromCurrentSettings() {
        let enabled = SpeechInput.voiceInputEnabled && voiceOutputEnabled
        UserDefaults.standard.set(enabled, forKey: voiceModeDefaultsKey)
    }

    static var voiceOutputEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: voiceEnabledDefaultsKey) != nil else { return false }
        return defaults.bool(forKey: voiceEnabledDefaultsKey)
    }

    static var cloudTTSEnabled: Bool {
        UserDefaults.standard.bool(forKey: useCloudTTSDefaultsKey)
    }

    static var speechRateMultiplier: Double {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: speechRateDefaultsKey) != nil else { return 1.0 }
        return min(1.5, max(0.5, defaults.double(forKey: speechRateDefaultsKey)))
    }

    static var speechRate: Float {
        let base = AVSpeechUtteranceDefaultSpeechRate
        let candidate = base * Float(speechRateMultiplier)
        return min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, candidate))
    }

    static var selectedVoiceIdentifier: String? {
        let defaults = UserDefaults.standard
        let value = defaults.string(forKey: voiceIdentifierDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }
        return nil
    }

    static var selectedVoice: AVSpeechSynthesisVoice? {
        guard let identifier = selectedVoiceIdentifier else { return nil }
        return AVSpeechSynthesisVoice(identifier: identifier)
    }

    static var hasDeepgramKey: Bool {
        KeychainHelper.load(key: deepgramTTSAPIKeyKeychainKey) != nil
    }

    @discardableResult
    static func saveDeepgramKey(_ value: String) -> Bool {
        SpeechInput.saveDeepgramKey(value)
    }

    @discardableResult
    static func deleteDeepgramKey() -> Bool {
        SpeechInput.deleteDeepgramKey()
    }

    static func availableVoices() -> [SpeechVoiceOption] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices
            .map { SpeechVoiceOption(identifier: $0.identifier, name: $0.name, languageCode: $0.language) }
            .sorted {
                if $0.languageCode == $1.languageCode {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.languageCode.localizedCaseInsensitiveCompare($1.languageCode) == .orderedAscending
            }
    }
}

// MARK: - Deepgram TTS Errors

private enum DeepgramTTSError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(Int, String)
    case emptyAudio
    case bufferCreationFailed

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Deepgram API key not found in Keychain."
        case .invalidResponse:
            return "Invalid response from Deepgram TTS API."
        case .httpError(let code, let detail):
            return "Deepgram TTS HTTP \(code): \(detail)"
        case .emptyAudio:
            return "Deepgram TTS returned empty audio data."
        case .bufferCreationFailed:
            return "Failed to create audio buffer for Deepgram TTS output."
        }
    }
}

// MARK: - Data Little-Endian Helpers

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func append(littleEndian value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
