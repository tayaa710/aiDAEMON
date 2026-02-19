import AVFoundation
import Foundation
import Speech

/// Configurable trigger style for voice input.
enum VoicePushToTalkStyle: String, CaseIterable, Identifiable {
    case holdHotkey = "hold_hotkey"
    case clickButton = "click_button"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .holdHotkey:
            return "Hold Cmd+Shift+Space"
        case .clickButton:
            return "Click Microphone Button"
        }
    }
}

enum SpeechInputStopReason {
    case manual
    case silenceTimeout
    case error
}

/// Voice transcription manager used by the floating window.
/// Primary path is on-device Apple speech recognition for offline support.
@MainActor
final class SpeechInput: NSObject, ObservableObject {
    static let shared = SpeechInput()

    static let voiceEnabledDefaultsKey = "voice.input.enabled"
    static let useCloudSTTDefaultsKey = "voice.input.useCloudSTT"
    static let pushToTalkStyleDefaultsKey = "voice.input.pushToTalkStyle"
    static let silenceTimeoutDefaultsKey = "voice.input.silenceTimeoutSeconds"
    static let deepgramSTTAPIKeyKeychainKey = "deepgram-stt-apikey"

    @Published private(set) var isListening: Bool = false
    @Published private(set) var transcript: String = ""
    @Published private(set) var audioLevel: Double = 0
    @Published private(set) var lastErrorMessage: String?

    var onTranscriptChanged: ((String) -> Void)?
    var onStopped: ((String, SpeechInputStopReason) -> Void)?
    var onError: ((String) -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var listeningStartedAt: Date?
    private var lastSpeechActivityAt: Date?

    private override init() {
        super.init()
    }

    @discardableResult
    func startListening() async -> Bool {
        guard !isListening else { return true }
        guard Self.voiceInputEnabled else {
            reportError("Voice input is disabled in Settings.")
            return false
        }

        clearLiveState()

        let permissionsGranted = await ensurePermissions()
        guard permissionsGranted else { return false }

        // Deepgram streaming is scaffolded by settings/key management in this milestone.
        // Runtime recognition remains on-device for guaranteed offline support.
        _ = Self.cloudSTTEnabled

        return startOnDeviceRecognition()
    }

    func stopListening(reason: SpeechInputStopReason = .manual) {
        guard isListening else { return }

        isListening = false
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        onStopped?(finalTranscript, reason)
    }

    func clearError() {
        lastErrorMessage = nil
    }

    // MARK: - Static Settings Helpers

    static var voiceInputEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: voiceEnabledDefaultsKey) != nil else { return true }
        return defaults.bool(forKey: voiceEnabledDefaultsKey)
    }

    static var cloudSTTEnabled: Bool {
        UserDefaults.standard.bool(forKey: useCloudSTTDefaultsKey)
    }

    static var pushToTalkStyle: VoicePushToTalkStyle {
        guard let rawValue = UserDefaults.standard.string(forKey: pushToTalkStyleDefaultsKey),
              let style = VoicePushToTalkStyle(rawValue: rawValue) else {
            return .holdHotkey
        }
        return style
    }

    static var silenceTimeoutSeconds: Double {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: silenceTimeoutDefaultsKey) != nil else { return 2.0 }
        return max(0.5, defaults.double(forKey: silenceTimeoutDefaultsKey))
    }

    static var hasDeepgramKey: Bool {
        KeychainHelper.load(key: deepgramSTTAPIKeyKeychainKey) != nil
    }

    @discardableResult
    static func saveDeepgramKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return KeychainHelper.save(key: deepgramSTTAPIKeyKeychainKey, value: trimmed)
    }

    @discardableResult
    static func deleteDeepgramKey() -> Bool {
        KeychainHelper.delete(key: deepgramSTTAPIKeyKeychainKey)
    }

    // MARK: - Internal

    private func clearLiveState() {
        transcript = ""
        audioLevel = 0
        lastErrorMessage = nil
        onTranscriptChanged?("")
    }

    private func startOnDeviceRecognition() -> Bool {
        guard let speechRecognizer else {
            reportError("Speech recognizer is not available for English (US).")
            return false
        }

        guard speechRecognizer.isAvailable else {
            reportError("Speech recognizer is temporarily unavailable.")
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            request.append(buffer)

            let level = SpeechInput.computeAudioLevel(from: buffer)
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            reportError("Could not start microphone audio engine: \(error.localizedDescription)")
            return false
        }

        isListening = true
        listeningStartedAt = Date()
        lastSpeechActivityAt = Date()
        startSilenceTimer()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                Task { @MainActor in
                    self.handlePartialTranscript(result.bestTranscription.formattedString)

                    if result.isFinal, self.isListening {
                        self.stopListening(reason: .silenceTimeout)
                    }
                }
            }

            if let error {
                Task { @MainActor in
                    guard self.isListening else { return }
                    self.reportError("Speech recognition failed: \(error.localizedDescription)")
                    self.stopListening(reason: .error)
                }
            }
        }

        return true
    }

    private func handlePartialTranscript(_ rawText: String) {
        let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = cleaned
        onTranscriptChanged?(cleaned)

        if !cleaned.isEmpty {
            lastSpeechActivityAt = Date()
        }
    }

    private func startSilenceTimer() {
        silenceTimer?.invalidate()

        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isListening else { return }

            let now = Date()
            let timeout = Self.silenceTimeoutSeconds
            let activityDate = self.lastSpeechActivityAt ?? self.listeningStartedAt ?? now
            if now.timeIntervalSince(activityDate) >= timeout {
                self.stopListening(reason: .silenceTimeout)
            }
        }
    }

    private func ensurePermissions() async -> Bool {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch micStatus {
        case .authorized:
            break
        case .notDetermined:
            let granted = await requestMicrophonePermission()
            guard granted else {
                reportError("Microphone access is required for voice input.")
                return false
            }
        case .restricted, .denied:
            reportError("Microphone access is denied. Enable it in System Settings > Privacy & Security > Microphone.")
            return false
        @unknown default:
            reportError("Microphone permission state is unknown.")
            return false
        }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        switch speechStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await requestSpeechPermission()
            guard granted else {
                reportError("Speech recognition access is required for voice input.")
                return false
            }
            return true
        case .restricted, .denied:
            reportError("Speech recognition access is denied. Enable it in System Settings > Privacy & Security > Speech Recognition.")
            return false
        @unknown default:
            reportError("Speech recognition permission state is unknown.")
            return false
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func reportError(_ message: String) {
        lastErrorMessage = message
        onError?(message)
    }

    private static func computeAudioLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<frameCount {
            let sample = channelData[index]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        // Scale to an intuitive 0...1 UI range.
        let normalized = min(1, max(0, Double(rms) * 22))
        return normalized
    }
}
