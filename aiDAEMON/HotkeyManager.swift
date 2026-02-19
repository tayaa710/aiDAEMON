import Cocoa
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let activateAssistant = Self(
        "activateAssistant",
        default: .init(.space, modifiers: [.command, .shift])
    )
    static let emergencyStop = Self(
        "emergencyStop",
        default: .init(.escape, modifiers: [.command, .shift])
    )
}

extension Notification.Name {
    static let hotkeyPressed = Notification.Name("HotkeyPressed")
    static let killSwitchPressed = Notification.Name("KillSwitchPressed")
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

        KeyboardShortcuts.onKeyUp(for: .emergencyStop) {
            NSLog("Kill switch hotkey pressed")
            NotificationCenter.default.post(name: .killSwitchPressed, object: nil)
        }

        isListening = true
        NSLog("Global hotkeys registered: Cmd+Shift+Space (toggle window), Cmd+Shift+Escape (kill switch)")
    }
}
