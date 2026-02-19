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

    private let synthesizer = AVSpeechSynthesizer()

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

        // Deepgram cloud TTS is an optional upgrade path; current runtime keeps
        // on-device synthesis as the guaranteed path (offline + no network dependency).
        if Self.cloudTTSEnabled, Self.hasDeepgramKey {
            NSLog("SpeechOutput: Cloud TTS enabled; using on-device fallback for this milestone")
        }

        let utterance = AVSpeechUtterance(string: cleaned)
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

    func stop() {
        guard synthesizer.isSpeaking || synthesizer.isPaused else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func clearError() {
        lastErrorMessage = nil
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
