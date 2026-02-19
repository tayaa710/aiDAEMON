import Cocoa
import CoreGraphics
import Foundation

/// Tool executor for moving/clicking the mouse via CGEvent.
///
/// Security guarantees:
/// - Requires Accessibility permission.
/// - Validates coordinates before dispatching events.
/// - Never shells out; uses native macOS APIs only.
public final class MouseController: ToolExecutor {

    private static let moveToClickDelay: TimeInterval = 0.05
    private static let doubleClickGap: TimeInterval = 0.05

    private enum ClickType: String {
        case single
        case double
        case right
    }

    private enum MouseControllerError: LocalizedError {
        case invalidCoordinates(String)
        case invalidClickType(String)
        case eventCreationFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidCoordinates(let details):
                return details
            case .invalidClickType(let value):
                return "Unsupported clickType '\(value)'. Use single, double, or right."
            case .eventCreationFailed(let details):
                return details
            }
        }
    }

    public init() {}

    // MARK: - ToolExecutor

    public func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        guard ensureAccessibilityPermission(promptIfNeeded: true) else {
            completion(.error(
                "Accessibility permission required.",
                details: "aiDAEMON needs Accessibility access to control the mouse.\nGo to System Settings → Privacy & Security → Accessibility and enable aiDAEMON."
            ))
            return
        }

        guard let x = intValue(arguments["x"]), let y = intValue(arguments["y"]) else {
            completion(.error(
                "Invalid mouse coordinates.",
                details: "Provide integer `x` and `y` values."
            ))
            return
        }

        let rawClickType = (arguments["clickType"] as? String)?.lowercased() ?? ClickType.single.rawValue
        guard let clickType = ClickType(rawValue: rawClickType) else {
            completion(.error("Invalid mouse click request.", details: MouseControllerError.invalidClickType(rawClickType).localizedDescription))
            return
        }

        do {
            switch clickType {
            case .single:
                try click(x: x, y: y)
                completion(.ok("Clicked at (\(x), \(y))."))
            case .double:
                try doubleClick(x: x, y: y)
                completion(.ok("Double-clicked at (\(x), \(y))."))
            case .right:
                try rightClick(x: x, y: y)
                completion(.ok("Right-clicked at (\(x), \(y))."))
            }
        } catch {
            completion(.error("Mouse action failed.", details: error.localizedDescription))
        }
    }

    // MARK: - Public API

    public func moveTo(x: Int, y: Int) throws {
        let point = try validatedPoint(x: x, y: y)
        try postMouseEvent(
            type: .mouseMoved,
            point: point,
            button: .left,
            clickState: 0
        )
    }

    public func click(x: Int, y: Int) throws {
        try moveTo(x: x, y: y)
        Thread.sleep(forTimeInterval: Self.moveToClickDelay)

        let point = CGPoint(x: x, y: y)
        try postMouseEvent(type: .leftMouseDown, point: point, button: .left, clickState: 1)
        try postMouseEvent(type: .leftMouseUp, point: point, button: .left, clickState: 1)
    }

    public func doubleClick(x: Int, y: Int) throws {
        try moveTo(x: x, y: y)
        Thread.sleep(forTimeInterval: Self.moveToClickDelay)

        let point = CGPoint(x: x, y: y)
        try postMouseEvent(type: .leftMouseDown, point: point, button: .left, clickState: 1)
        try postMouseEvent(type: .leftMouseUp, point: point, button: .left, clickState: 1)
        Thread.sleep(forTimeInterval: Self.doubleClickGap)
        try postMouseEvent(type: .leftMouseDown, point: point, button: .left, clickState: 2)
        try postMouseEvent(type: .leftMouseUp, point: point, button: .left, clickState: 2)
    }

    public func rightClick(x: Int, y: Int) throws {
        try moveTo(x: x, y: y)
        Thread.sleep(forTimeInterval: Self.moveToClickDelay)

        let point = CGPoint(x: x, y: y)
        try postMouseEvent(type: .rightMouseDown, point: point, button: .right, clickState: 1)
        try postMouseEvent(type: .rightMouseUp, point: point, button: .right, clickState: 1)
    }

    // MARK: - Internals

    private func validatedPoint(x: Int, y: Int) throws -> CGPoint {
        guard x >= 0, y >= 0 else {
            throw MouseControllerError.invalidCoordinates("Coordinates must be non-negative.")
        }

        let point = CGPoint(x: x, y: y)
        guard isOnScreen(point) else {
            throw MouseControllerError.invalidCoordinates("Coordinates (\(x), \(y)) are outside the visible screen area.")
        }

        return point
    }

    private func isOnScreen(_ point: CGPoint) -> Bool {
        let bounds = activeDisplayBounds()
        guard !bounds.isEmpty else { return false }
        return bounds.contains { $0.contains(point) }
    }

    private func activeDisplayBounds() -> [CGRect] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success else {
            return []
        }

        var displayIDs = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            return []
        }

        return Array(displayIDs.prefix(Int(displayCount))).map { CGDisplayBounds($0) }
    }

    private func postMouseEvent(
        type: CGEventType,
        point: CGPoint,
        button: CGMouseButton,
        clickState: Int64
    ) throws {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else {
            throw MouseControllerError.eventCreationFailed("Unable to create mouse event \(type.rawValue).")
        }

        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        event.post(tap: .cghidEventTap)
    }

    private func intValue(_ raw: Any?) -> Int? {
        switch raw {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let double as Double:
            return Int(double)
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
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
