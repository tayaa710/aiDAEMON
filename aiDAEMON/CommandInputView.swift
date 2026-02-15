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
    let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("What do you want to do?", text: $state.text)
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .focused($isFocused)
            .onSubmit(submitCommand)
            .onAppear(perform: focusField)
            .onChange(of: state.focusTrigger) { _ in
                focusField()
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
