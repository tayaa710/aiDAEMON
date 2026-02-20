// AccessibilityService.swift
// aiDAEMON
//
// Core Accessibility API wrapper for AX-first computer control.
// Walks UI element trees, reads attributes, performs actions, and searches elements.
// All AX calls are dispatched to a dedicated serial queue for thread safety.

import Cocoa
import ApplicationServices

// MARK: - Element Snapshot

/// A snapshot of an AX element's attributes, serializable for Claude context.
struct AXElementSnapshot {
    let ref: String
    let role: String
    let subrole: String?
    let title: String?
    let value: String?
    let elementDescription: String?
    let enabled: Bool
    let focused: Bool
    let frame: CGRect?
    let children: [AXElementSnapshot]
}

// MARK: - Element Reference Map

/// Maps per-turn string refs (@e1, @e2, ...) to live AXUIElement pointers.
/// Only mutated from the AX serial queue.
final class AXElementRefMap {
    private var refs: [String: AXUIElement] = [:]
    private var counter: Int = 0

    func nextRef(for element: AXUIElement) -> String {
        counter += 1
        let ref = "@e\(counter)"
        refs[ref] = element
        return ref
    }

    func element(for ref: String) -> AXUIElement? {
        refs[ref]
    }

    func clear() {
        refs.removeAll()
        counter = 0
    }

    var count: Int { counter }
}

// MARK: - Element Counter

/// Tracks how many elements have been visited during tree traversal.
/// Reference type so it's shared across recursive calls on the serial queue.
private final class ElementCounter {
    let max: Int
    private(set) var count: Int = 0

    init(max: Int) {
        self.max = max
    }

    var limitReached: Bool { count >= max }

    func increment() {
        count += 1
    }
}

// MARK: - Errors

enum AXServiceError: Error, LocalizedError {
    case accessibilityDisabled
    case elementNotFound(ref: String)
    case actionFailed(action: String, code: Int32)
    case setValueFailed(code: Int32)
    case appNotFound
    case invalidValue

    var errorDescription: String? {
        switch self {
        case .accessibilityDisabled:
            return "Accessibility permission not granted. Enable aiDAEMON in System Settings > Privacy & Security > Accessibility."
        case .elementNotFound(let ref):
            return "Element \(ref) not found. The UI may have changed — get a fresh UI state."
        case .actionFailed(let action, let code):
            return "AX action '\(action)' failed (error \(code))."
        case .setValueFailed(let code):
            return "Failed to set value (error \(code))."
        case .appNotFound:
            return "No frontmost application found."
        case .invalidValue:
            return "Invalid value for the operation."
        }
    }
}

// MARK: - AccessibilityService

/// Core Accessibility API wrapper. Thread-safe: all AX calls run on a dedicated serial queue.
final class AccessibilityService {
    static let shared = AccessibilityService()

    private let axQueue = DispatchQueue(label: "com.aidaemon.accessibility", qos: .userInitiated)

    /// Current turn's element reference map. Only mutated from axQueue.
    private var _refMap = AXElementRefMap()

    private init() {}

    // MARK: - Permission Check

    /// Whether Accessibility permission is granted. Safe to call from any thread.
    var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permission (shows system dialog).
    func promptForPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - App Targeting

    /// Create an AXUIElement for a running app by PID.
    func applicationElement(for pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// Create an AXUIElement for the frontmost application, or nil if none.
    func frontmostApplicationElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return applicationElement(for: app.processIdentifier)
    }

    /// Get the frontmost app's name and PID.
    func frontmostAppInfo() -> (name: String, pid: pid_t)? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let name = app.localizedName else { return nil }
        return (name, app.processIdentifier)
    }

    // MARK: - Tree Traversal

    /// Walk the AX tree from root and return a snapshot. Resets the element ref map.
    /// - Parameters:
    ///   - root: The root AXUIElement to walk (typically from applicationElement(for:))
    ///   - maxDepth: Maximum tree depth to traverse (default 10)
    ///   - maxElements: Maximum total elements to visit (default 500)
    /// - Returns: A snapshot of the tree, or nil if accessibility is disabled or tree is empty.
    func walkTree(root: AXUIElement, maxDepth: Int = 10, maxElements: Int = 500) async -> AXElementSnapshot? {
        guard isAccessibilityEnabled else { return nil }

        return await withCheckedContinuation { continuation in
            axQueue.async { [self] in
                _refMap = AXElementRefMap()
                let counter = ElementCounter(max: maxElements)
                let snapshot = buildSnapshot(element: root, depth: 0, maxDepth: maxDepth, counter: counter)
                continuation.resume(returning: snapshot)
            }
        }
    }

    /// Walk the frontmost app's tree. Convenience wrapper.
    func walkFrontmostApp(maxDepth: Int = 10, maxElements: Int = 500) async -> AXElementSnapshot? {
        guard let root = frontmostApplicationElement() else { return nil }
        return await walkTree(root: root, maxDepth: maxDepth, maxElements: maxElements)
    }

    private func buildSnapshot(element: AXUIElement, depth: Int, maxDepth: Int, counter: ElementCounter) -> AXElementSnapshot? {
        guard depth < maxDepth, !counter.limitReached else { return nil }

        let role = stringAttribute(element, kAXRoleAttribute as CFString)
        // Skip elements with no role — they are typically non-interactive containers
        guard let elementRole = role else { return nil }

        counter.increment()
        let ref = _refMap.nextRef(for: element)

        let subrole = stringAttribute(element, kAXSubroleAttribute as CFString)
        let title = stringAttribute(element, kAXTitleAttribute as CFString)
        let value = valueAsString(element)
        let desc = stringAttribute(element, kAXDescriptionAttribute as CFString)
        let enabled = boolAttribute(element, kAXEnabledAttribute as CFString) ?? true
        let focused = boolAttribute(element, kAXFocusedAttribute as CFString) ?? false
        let frame = frameAttribute(element)

        // Recurse into children
        var childSnapshots: [AXElementSnapshot] = []
        if !counter.limitReached, let children = childrenAttribute(element) {
            for child in children {
                if counter.limitReached { break }
                if let childSnapshot = buildSnapshot(element: child, depth: depth + 1, maxDepth: maxDepth, counter: counter) {
                    childSnapshots.append(childSnapshot)
                }
            }
        }

        return AXElementSnapshot(
            ref: ref,
            role: elementRole,
            subrole: subrole,
            title: title,
            value: value,
            elementDescription: desc,
            enabled: enabled,
            focused: focused,
            frame: frame,
            children: childSnapshots
        )
    }

    // MARK: - Attribute Helpers

    private func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        if let num = value as? NSNumber {
            return num.boolValue
        }
        return nil
    }

    /// Read the value attribute and convert to a string representation.
    /// Handles String, NSNumber, NSURL, NSAttributedString.
    private func valueAsString(_ element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard result == .success, let val = value else { return nil }

        if let str = val as? String { return str }
        if let num = val as? NSNumber { return num.stringValue }
        if let url = val as? NSURL { return url.absoluteString }
        if let attrStr = val as? NSAttributedString { return attrStr.string }
        return nil
    }

    /// Read position + size as a CGRect.
    private func frameAttribute(_ element: AXUIElement) -> CGRect? {
        var posValue: AnyObject?
        var sizeValue: AnyObject?

        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)

        guard posResult == .success, sizeResult == .success,
              let posRef = posValue, CFGetTypeID(posRef) == AXValueGetTypeID(),
              let sizeRef = sizeValue, CFGetTypeID(sizeRef) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    /// Read children elements.
    private func childrenAttribute(_ element: AXUIElement) -> [AXUIElement]? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? [AXUIElement]
    }

    // MARK: - Action Execution

    /// Press (click/activate) an element by ref.
    func pressElement(ref: String) async throws {
        guard isAccessibilityEnabled else { throw AXServiceError.accessibilityDisabled }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            axQueue.async { [self] in
                guard let element = _refMap.element(for: ref) else {
                    continuation.resume(throwing: AXServiceError.elementNotFound(ref: ref))
                    return
                }
                let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
                if result == .success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AXServiceError.actionFailed(action: "press", code: result.rawValue))
                }
            }
        }
    }

    /// Set the value of an element (e.g., text field content) by ref.
    func setValue(ref: String, value: String) async throws {
        guard isAccessibilityEnabled else { throw AXServiceError.accessibilityDisabled }
        guard !value.isEmpty else { throw AXServiceError.invalidValue }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            axQueue.async { [self] in
                guard let element = _refMap.element(for: ref) else {
                    continuation.resume(throwing: AXServiceError.elementNotFound(ref: ref))
                    return
                }
                let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef)
                if result == .success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AXServiceError.setValueFailed(code: result.rawValue))
                }
            }
        }
    }

    /// Focus an element by ref.
    func focusElement(ref: String) async throws {
        guard isAccessibilityEnabled else { throw AXServiceError.accessibilityDisabled }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            axQueue.async { [self] in
                guard let element = _refMap.element(for: ref) else {
                    continuation.resume(throwing: AXServiceError.elementNotFound(ref: ref))
                    return
                }
                let result = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                if result == .success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AXServiceError.actionFailed(action: "focus", code: result.rawValue))
                }
            }
        }
    }

    /// Raise a window element to the front by ref.
    func raiseElement(ref: String) async throws {
        guard isAccessibilityEnabled else { throw AXServiceError.accessibilityDisabled }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            axQueue.async { [self] in
                guard let element = _refMap.element(for: ref) else {
                    continuation.resume(throwing: AXServiceError.elementNotFound(ref: ref))
                    return
                }
                let result = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
                if result == .success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AXServiceError.actionFailed(action: "raise", code: result.rawValue))
                }
            }
        }
    }

    /// Open the menu for an element by ref.
    func showMenu(ref: String) async throws {
        guard isAccessibilityEnabled else { throw AXServiceError.accessibilityDisabled }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            axQueue.async { [self] in
                guard let element = _refMap.element(for: ref) else {
                    continuation.resume(throwing: AXServiceError.elementNotFound(ref: ref))
                    return
                }
                let result = AXUIElementPerformAction(element, kAXShowMenuAction as CFString)
                if result == .success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AXServiceError.actionFailed(action: "showMenu", code: result.rawValue))
                }
            }
        }
    }

    // MARK: - Element Search

    /// Search for an element by role and title (case-insensitive substring match).
    /// Adds found element to the current ref map. Returns the ref, or nil if not found.
    func findElement(role: String, title: String, root: AXUIElement? = nil, maxDepth: Int = 10) async -> String? {
        guard isAccessibilityEnabled else { return nil }
        let rootElement = root ?? frontmostApplicationElement() ?? AXUIElementCreateSystemWide()

        return await withCheckedContinuation { continuation in
            axQueue.async { [self] in
                let ref = searchByRoleAndTitle(element: rootElement, role: role, title: title, depth: 0, maxDepth: maxDepth)
                continuation.resume(returning: ref)
            }
        }
    }

    /// Search for an element by role and value (case-insensitive substring match).
    /// Adds found element to the current ref map. Returns the ref, or nil if not found.
    func findElement(role: String, value: String, root: AXUIElement? = nil, maxDepth: Int = 10) async -> String? {
        guard isAccessibilityEnabled else { return nil }
        let rootElement = root ?? frontmostApplicationElement() ?? AXUIElementCreateSystemWide()

        return await withCheckedContinuation { continuation in
            axQueue.async { [self] in
                let ref = searchByRoleAndValue(element: rootElement, role: role, value: value, depth: 0, maxDepth: maxDepth)
                continuation.resume(returning: ref)
            }
        }
    }

    /// Find the currently focused element. Returns the ref, or nil if none found.
    func findFocusedElement(root: AXUIElement? = nil, maxDepth: Int = 10) async -> String? {
        guard isAccessibilityEnabled else { return nil }
        let rootElement = root ?? frontmostApplicationElement() ?? AXUIElementCreateSystemWide()

        return await withCheckedContinuation { continuation in
            axQueue.async { [self] in
                let ref = searchFocused(element: rootElement, depth: 0, maxDepth: maxDepth)
                continuation.resume(returning: ref)
            }
        }
    }

    /// Find the first editable text field/area. Returns the ref, or nil if none found.
    func findEditableElement(root: AXUIElement? = nil, maxDepth: Int = 10) async -> String? {
        guard isAccessibilityEnabled else { return nil }
        let rootElement = root ?? frontmostApplicationElement() ?? AXUIElementCreateSystemWide()

        return await withCheckedContinuation { continuation in
            axQueue.async { [self] in
                let ref = searchEditable(element: rootElement, depth: 0, maxDepth: maxDepth)
                continuation.resume(returning: ref)
            }
        }
    }

    // MARK: - Search Helpers (called on axQueue)

    private func searchByRoleAndTitle(element: AXUIElement, role: String, title: String, depth: Int, maxDepth: Int) -> String? {
        guard depth < maxDepth else { return nil }

        let elementRole = stringAttribute(element, kAXRoleAttribute as CFString)
        let elementTitle = stringAttribute(element, kAXTitleAttribute as CFString)

        if elementRole == role, elementTitle?.localizedCaseInsensitiveContains(title) == true {
            return _refMap.nextRef(for: element)
        }

        if let children = childrenAttribute(element) {
            for child in children {
                if let ref = searchByRoleAndTitle(element: child, role: role, title: title, depth: depth + 1, maxDepth: maxDepth) {
                    return ref
                }
            }
        }
        return nil
    }

    private func searchByRoleAndValue(element: AXUIElement, role: String, value: String, depth: Int, maxDepth: Int) -> String? {
        guard depth < maxDepth else { return nil }

        let elementRole = stringAttribute(element, kAXRoleAttribute as CFString)
        let elementValue = valueAsString(element)

        if elementRole == role, elementValue?.localizedCaseInsensitiveContains(value) == true {
            return _refMap.nextRef(for: element)
        }

        if let children = childrenAttribute(element) {
            for child in children {
                if let ref = searchByRoleAndValue(element: child, role: role, value: value, depth: depth + 1, maxDepth: maxDepth) {
                    return ref
                }
            }
        }
        return nil
    }

    private func searchFocused(element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        guard depth < maxDepth else { return nil }

        if boolAttribute(element, kAXFocusedAttribute as CFString) == true {
            return _refMap.nextRef(for: element)
        }

        if let children = childrenAttribute(element) {
            for child in children {
                if let ref = searchFocused(element: child, depth: depth + 1, maxDepth: maxDepth) {
                    return ref
                }
            }
        }
        return nil
    }

    private func searchEditable(element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        guard depth < maxDepth else { return nil }

        let role = stringAttribute(element, kAXRoleAttribute as CFString)
        if role == "AXTextField" || role == "AXTextArea" {
            if boolAttribute(element, kAXEnabledAttribute as CFString) ?? true {
                return _refMap.nextRef(for: element)
            }
        }

        if let children = childrenAttribute(element) {
            for child in children {
                if let ref = searchEditable(element: child, depth: depth + 1, maxDepth: maxDepth) {
                    return ref
                }
            }
        }
        return nil
    }

    // MARK: - Ref Map Management

    /// Reset the element reference map (call at the start of a new turn or before walkTree).
    func resetRefs() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            axQueue.async { [self] in
                _refMap = AXElementRefMap()
                continuation.resume()
            }
        }
    }

    /// Number of elements in the current ref map.
    var refCount: Int {
        // Note: reading .count is a simple Int read and is safe enough for diagnostics.
        _refMap.count
    }

    // MARK: - Formatting

    /// Format a snapshot tree as compact text for Claude's context.
    ///
    /// Example output:
    /// ```
    /// @e1 AXApplication "TextEdit"
    ///   @e2 AXWindow "Untitled"
    ///     @e3 AXScrollArea
    ///       @e4 AXTextArea value="Hello world" [focused]
    ///     @e5 AXToolbar
    ///       @e6 AXButton "Bold"
    /// ```
    func formatTree(_ snapshot: AXElementSnapshot, indent: Int = 0) -> String {
        var lines: [String] = []
        let pad = String(repeating: "  ", count: indent)

        var desc = "\(pad)\(snapshot.ref) \(snapshot.role)"
        if let title = snapshot.title, !title.isEmpty {
            desc += " \"\(title)\""
        }
        if let value = snapshot.value, !value.isEmpty {
            let truncated = value.count > 80 ? String(value.prefix(80)) + "..." : value
            desc += " value=\"\(truncated)\""
        }
        if let subrole = snapshot.subrole {
            desc += " (\(subrole))"
        }
        if let d = snapshot.elementDescription, !d.isEmpty, d != snapshot.title {
            desc += " desc=\"\(d)\""
        }
        if !snapshot.enabled {
            desc += " [disabled]"
        }
        if snapshot.focused {
            desc += " [focused]"
        }

        lines.append(desc)

        for child in snapshot.children {
            lines.append(formatTree(child, indent: indent + 1))
        }

        return lines.joined(separator: "\n")
    }
}
