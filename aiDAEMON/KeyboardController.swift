import Cocoa
import CoreGraphics
import Foundation

/// Tool executor for typing text and pressing keyboard shortcuts via CGEvent.
///
/// Security guarantees:
/// - Requires Accessibility permission.
/// - Types text via Unicode key events (no shell, no AppleScript).
/// - Enforces text length limit and strips control characters.
public final class KeyboardController: ToolExecutor {

    private static let characterDelay: TimeInterval = 0.03
    private static let maxTypeLength = 2000

    private struct KeySpec {
        let keyCode: CGKeyCode
        let modifiers: CGEventFlags
    }

    private enum KeyboardControllerError: LocalizedError {
        case invalidInput(String)
        case unsupportedKey(String)
        case unsupportedModifier(String)
        case eventCreationFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidInput(let details):
                return details
            case .unsupportedKey(let key):
                return "Unsupported key '\(key)'."
            case .unsupportedModifier(let modifier):
                return "Unsupported modifier '\(modifier)'."
            case .eventCreationFailed(let details):
                return details
            }
        }
    }

    private let keyCodeMap: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "return": 36, "enter": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
        "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
        "left": 123, "right": 124, "down": 125, "up": 126
    ]

    private let modifierFlagMap: [String: CGEventFlags] = [
        "cmd": .maskCommand,
        "command": .maskCommand,
        "shift": .maskShift,
        "option": .maskAlternate,
        "alt": .maskAlternate,
        "control": .maskControl,
        "ctrl": .maskControl
    ]

    public init() {}

    // MARK: - ToolExecutor

    public func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        guard ensureAccessibilityPermission(promptIfNeeded: true) else {
            completion(.error(
                "Accessibility permission required.",
                details: "aiDAEMON needs Accessibility access to send keyboard input.\nGo to System Settings → Privacy & Security → Accessibility and enable aiDAEMON."
            ))
            return
        }

        do {
            if let text = firstStringValue(for: ["text", "value", "target"], in: arguments) {
                try typeText(text: text)
                completion(.ok("Typed \(text.count) characters."))
                return
            }

            if let shortcut = firstStringValue(for: ["shortcut", "keys"], in: arguments) {
                try pressShortcut(shortcut: shortcut)
                completion(.ok("Pressed shortcut '\(shortcut)'."))
                return
            }

            if let key = firstStringValue(for: ["key"], in: arguments) {
                let modifiers = parseModifierList(arguments["modifiers"])
                try pressKey(key: key, modifiers: modifiers)
                let modifierLabel = modifiers.isEmpty ? "no modifiers" : modifiers.joined(separator: "+")
                completion(.ok("Pressed key '\(key)' (\(modifierLabel))."))
                return
            }

            completion(.error(
                "Invalid keyboard action request.",
                details: "Provide `text` for typing or `shortcut` for key combos."
            ))
        } catch {
            completion(.error("Keyboard action failed.", details: error.localizedDescription))
        }
    }

    // MARK: - Public API

    public func typeText(text: String) throws {
        guard text.count <= Self.maxTypeLength else {
            throw KeyboardControllerError.invalidInput(
                "Text is too long (\(text.count) chars). Maximum is \(Self.maxTypeLength) characters."
            )
        }

        let sanitized = sanitizeTypedText(text)
        guard !sanitized.isEmpty else {
            throw KeyboardControllerError.invalidInput("No typable characters remain after sanitization.")
        }

        let characters = Array(sanitized)
        for (index, character) in characters.enumerated() {
            try typeCharacter(character)
            if index < characters.count - 1 {
                Thread.sleep(forTimeInterval: Self.characterDelay)
            }
        }
    }

    public func pressKey(key: String, modifiers: [String] = []) throws {
        let keySpec = try resolveKeySpec(key: key, modifiers: modifiers)
        try postKeyEvent(keyCode: keySpec.keyCode, keyDown: true, modifiers: keySpec.modifiers)
        try postKeyEvent(keyCode: keySpec.keyCode, keyDown: false, modifiers: keySpec.modifiers)
    }

    public func pressShortcut(shortcut: String) throws {
        let parsed = try parseShortcut(shortcut)
        try pressKey(key: parsed.key, modifiers: parsed.modifiers)
    }

    // MARK: - Parsing

    private func resolveKeySpec(key: String, modifiers: [String]) throws -> KeySpec {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedKey.isEmpty else {
            throw KeyboardControllerError.invalidInput("Key cannot be empty.")
        }

        let keyCode: CGKeyCode
        if let mapped = keyCodeMap[normalizedKey] {
            keyCode = mapped
        } else if normalizedKey.count == 1, let mapped = keyCodeMap[normalizedKey] {
            keyCode = mapped
        } else {
            throw KeyboardControllerError.unsupportedKey(key)
        }

        var flags: CGEventFlags = []
        for modifier in modifiers {
            let normalizedModifier = modifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalizedModifier.isEmpty else { continue }
            guard let modifierFlag = modifierFlagMap[normalizedModifier] else {
                throw KeyboardControllerError.unsupportedModifier(modifier)
            }
            flags.insert(modifierFlag)
        }

        return KeySpec(keyCode: keyCode, modifiers: flags)
    }

    private func parseShortcut(_ shortcut: String) throws -> (key: String, modifiers: [String]) {
        let cleaned = shortcut.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else {
            throw KeyboardControllerError.invalidInput("Shortcut cannot be empty.")
        }

        let normalizedShortcut = cleaned
            .replacingOccurrences(of: "⌘", with: "cmd")
            .replacingOccurrences(of: "⇧", with: "shift")
            .replacingOccurrences(of: "⌥", with: "option")
            .replacingOccurrences(of: "^", with: "ctrl")

        let tokens = normalizedShortcut
            .split(separator: "+")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            throw KeyboardControllerError.invalidInput("Shortcut cannot be empty.")
        }

        if tokens.count == 1 {
            return (tokens[0], [])
        }

        let key = tokens.last ?? ""
        let modifiers = Array(tokens.dropLast())
        return (key, modifiers)
    }

    private func parseModifierList(_ raw: Any?) -> [String] {
        switch raw {
        case let list as [String]:
            return list
        case let list as [Any]:
            return list.compactMap { item in
                if let string = item as? String {
                    return string
                }
                return nil
            }
        case let string as String:
            return string
                .split(whereSeparator: { $0 == "," || $0 == "+" })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        default:
            return []
        }
    }

    // MARK: - Event Posting

    private func typeCharacter(_ character: Character) throws {
        var utf16Units = Array(String(character).utf16)
        guard !utf16Units.isEmpty else { return }

        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw KeyboardControllerError.eventCreationFailed("Unable to create keyboard unicode events.")
        }

        down.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        up.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool, modifiers: CGEventFlags) throws {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
            throw KeyboardControllerError.eventCreationFailed("Unable to create key event for keyCode \(keyCode).")
        }
        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Sanitization

    private func sanitizeTypedText(_ text: String) -> String {
        let filtered = text.unicodeScalars.filter { scalar in
            let value = scalar.value
            return value >= 32 && value != 127
        }
        return String(String.UnicodeScalarView(filtered))
    }

    // MARK: - Helpers

    private func firstStringValue(for keys: [String], in arguments: [String: Any]) -> String? {
        for key in keys {
            if let value = arguments[key] as? String {
                return value
            }
        }
        return nil
    }

    private func ensureAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        if promptIfNeeded {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        return AXIsProcessTrusted()
    }
}
