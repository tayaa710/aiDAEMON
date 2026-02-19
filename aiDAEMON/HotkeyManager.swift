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
    static let hotkeyPressedDown = Notification.Name("HotkeyPressedDown")
    static let hotkeyPressedUp = Notification.Name("HotkeyPressedUp")
    static let killSwitchPressed = Notification.Name("KillSwitchPressed")
}

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var isListening = false
    private var activationKeyIsDown = false

    private init() {}

    func startListening() {
        guard !isListening else { return }

        KeyboardShortcuts.onKeyDown(for: .activateAssistant) { [weak self] in
            guard let self else { return }
            guard !self.activationKeyIsDown else { return }
            self.activationKeyIsDown = true
            NotificationCenter.default.post(name: .hotkeyPressedDown, object: nil)
        }

        KeyboardShortcuts.onKeyUp(for: .activateAssistant) {
            NotificationCenter.default.post(name: .hotkeyPressedUp, object: nil)
            self.activationKeyIsDown = false
        }

        KeyboardShortcuts.onKeyUp(for: .emergencyStop) {
            NSLog("Kill switch hotkey pressed")
            NotificationCenter.default.post(name: .killSwitchPressed, object: nil)
        }

        isListening = true
        NSLog("Global hotkeys registered: Cmd+Shift+Space (quick press toggle / hold voice), Cmd+Shift+Escape (kill switch)")
    }
}
