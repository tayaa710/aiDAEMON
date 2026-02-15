import Cocoa
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let activateAssistant = Self(
        "activateAssistant",
        default: .init(.space, modifiers: [.command, .shift])
    )
}

extension Notification.Name {
    static let hotkeyPressed = Notification.Name("HotkeyPressed")
}

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var isListening = false

    private init() {}

    func startListening() {
        guard !isListening else { return }

        KeyboardShortcuts.onKeyUp(for: .activateAssistant) {
            NSLog("Hotkey pressed")
            NotificationCenter.default.post(name: .hotkeyPressed, object: nil)
        }

        isListening = true
        NSLog("Global hotkey registered: Cmd+Shift+Space")
    }
}
