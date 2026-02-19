import SwiftUI

final class CommandInputState: ObservableObject {
    @Published var text: String = ""
    @Published private(set) var focusTrigger: Int = 0

    func clear() {
        text = ""
    }

    func requestFocus() {
        focusTrigger += 1
    }
}

struct CommandInputView: View {
    @ObservedObject var state: CommandInputState
    @ObservedObject var speechInput: SpeechInput
    let showsMicrophoneButton: Bool
    let onVoiceButtonTap: () -> Void
    let onUserInputDetected: () -> Void
    let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool
    @State private var pulseActive: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            TextField("What do you want to do?", text: $state.text)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isFocused)
                .onSubmit(submitCommand)

            if speechInput.isListening {
                VoiceWaveformView(level: speechInput.audioLevel)
                    .frame(width: 30, height: 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if showsMicrophoneButton {
                Button(action: onVoiceButtonTap) {
                    Image(systemName: speechInput.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(speechInput.isListening ? .red : .secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(speechInput.isListening ? 0.14 : 0.0))
                                .scaleEffect(speechInput.isListening && pulseActive ? 1.18 : 1.0)
                        )
                }
                .buttonStyle(.plain)
                .help(speechInput.isListening ? "Stop listening and submit" : "Start voice input")
            }
        }
        .onAppear {
            focusField()
            pulseActive = speechInput.isListening
        }
        .onChange(of: state.focusTrigger) { _ in
            focusField()
        }
        .onChange(of: speechInput.isListening) { listening in
            if listening {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseActive = true
                }
            } else {
                pulseActive = false
            }
        }
        .onChange(of: state.text) { value in
            guard !value.isEmpty else { return }
            guard !speechInput.isListening else { return }
            onUserInputDetected()
        }
    }

    private struct VoiceWaveformView: View {
        let level: Double

        var body: some View {
            TimelineView(.animation(minimumInterval: 0.08)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<4, id: \.self) { idx in
                        Capsule(style: .continuous)
                            .fill(Color.red.opacity(0.85))
                            .frame(width: 3, height: barHeight(for: idx, time: t))
                    }
                }
            }
        }

        private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
            let wave = abs(sin(time * 7 + Double(index) * 0.9))
            let amplitude = max(0.2, min(1, level))
            return CGFloat(4.0 + wave * (8.0 * amplitude + 1.5))
        }
    }

    private func submitCommand() {
        let command = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        onSubmit(command)
    }

    private func focusField() {
        DispatchQueue.main.async {
            isFocused = true
        }
    }
}
