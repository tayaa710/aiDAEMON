import Cocoa

/// Supported window position commands.
enum WindowPosition: String, CaseIterable {
    case left_half
    case right_half
    case top_half
    case bottom_half
    case full_screen
    case center
    case top_left
    case top_right
    case bottom_left
    case bottom_right

    /// Calculate the target frame for this position on the given screen.
    func frame(on screen: NSRect) -> CGRect {
        let w = screen.width
        let h = screen.height
        let x = screen.origin.x
        let y = screen.origin.y

        switch self {
        case .left_half:
            return CGRect(x: x, y: y, width: w / 2, height: h)
        case .right_half:
            return CGRect(x: x + w / 2, y: y, width: w / 2, height: h)
        case .top_half:
            return CGRect(x: x, y: y + h / 2, width: w, height: h / 2)
        case .bottom_half:
            return CGRect(x: x, y: y, width: w, height: h / 2)
        case .full_screen:
            return CGRect(x: x, y: y, width: w, height: h)
        case .center:
            let cw = w * 0.6
            let ch = h * 0.6
            return CGRect(x: x + (w - cw) / 2, y: y + (h - ch) / 2, width: cw, height: ch)
        case .top_left:
            return CGRect(x: x, y: y + h / 2, width: w / 2, height: h / 2)
        case .top_right:
            return CGRect(x: x + w / 2, y: y + h / 2, width: w / 2, height: h / 2)
        case .bottom_left:
            return CGRect(x: x, y: y, width: w / 2, height: h / 2)
        case .bottom_right:
            return CGRect(x: x + w / 2, y: y, width: w / 2, height: h / 2)
        }
    }

    /// Human-readable description for display.
    var displayName: String {
        switch self {
        case .left_half: return "left half"
        case .right_half: return "right half"
        case .top_half: return "top half"
        case .bottom_half: return "bottom half"
        case .full_screen: return "full screen"
        case .center: return "center"
        case .top_left: return "top-left quarter"
        case .top_right: return "top-right quarter"
        case .bottom_left: return "bottom-left quarter"
        case .bottom_right: return "bottom-right quarter"
        }
    }
}

/// Executor for WINDOW_MANAGE commands — resizes and positions windows using the Accessibility API.
public struct WindowManager: CommandExecutor {
    private static var lastExternalAppPID: pid_t?

    public var name: String { "WindowManager" }

    static func rememberLastExternalApplication(_ app: NSRunningApplication?) {
        guard let app else { return }
        guard !isAssistantApplication(app) else { return }
        lastExternalAppPID = app.processIdentifier
    }

    public func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void) {
        // Parse the position parameter
        let positionStr = command.stringParam("position")
            ?? command.target
            ?? ""

        guard let position = resolvePosition(positionStr) else {
            let valid = WindowPosition.allCases.map { $0.rawValue }.joined(separator: ", ")
            completion(.error(
                "Unknown window position: \"\(positionStr)\"",
                details: "Supported positions: \(valid)"
            ))
            return
        }

        // Check Accessibility permission
        guard AXIsProcessTrusted() else {
            // Prompt the user to grant Accessibility access
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            completion(.error(
                "Accessibility permission required.",
                details: "aiDAEMON needs Accessibility access to manage windows.\nGo to System Settings → Privacy & Security → Accessibility and enable aiDAEMON."
            ))
            return
        }

        // Resolve target app. If aiDAEMON is frontmost, fall back to the last app
        // that was active before the command palette opened.
        guard let targetApp = resolveTargetApplication(for: command) else {
            completion(.error(
                "No target application found.",
                details: "Open the target app and try the window command again."
            ))
            return
        }

        let appElement = AXUIElementCreateApplication(targetApp.processIdentifier)

        guard let axWindow = copyTargetWindow(from: appElement) else {
            completion(.error(
                "Could not get the target window.",
                details: "The app \"\(targetApp.localizedName ?? "Unknown")\" may not have an accessible, movable window."
            ))
            return
        }

        // Get the screen's visible frame (excludes menu bar and dock)
        guard let screenFrame = targetScreenVisibleFrame(for: axWindow) else {
            completion(.error("No screen available."))
            return
        }

        // Calculate target frame
        let targetFrame = position.frame(on: screenFrame)

        // AX coordinates: origin is top-left of primary screen.
        // NSScreen.visibleFrame origin is bottom-left.
        // Convert y: AX_y = primaryScreenHeight - NSScreen_y - height
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height
        let axX = targetFrame.origin.x
        let axY = primaryHeight - targetFrame.origin.y - targetFrame.height

        // Set position first, then size
        var position2D = CGPoint(x: axX, y: axY)
        var size2D = CGSize(width: targetFrame.width, height: targetFrame.height)

        guard let posValue = AXValueCreate(.cgPoint, &position2D),
              let sizeValue = AXValueCreate(.cgSize, &size2D) else {
            completion(.error("Failed to create AX values for window positioning."))
            return
        }

        let posResult = AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
        let sizeResult = AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)

        if posResult == .success && sizeResult == .success {
            let appName = targetApp.localizedName ?? "window"
            NSLog("WindowManager: moved %@ to %@", appName, position.displayName)
            completion(.ok("Moved \(appName) to \(position.displayName)"))
        } else {
            var errors: [String] = []
            if posResult != .success { errors.append("position (error \(posResult.rawValue))") }
            if sizeResult != .success { errors.append("size (error \(sizeResult.rawValue))") }
            completion(.error(
                "Failed to move window.",
                details: "Could not set \(errors.joined(separator: " and ")). The app may not support window resizing."
            ))
        }
    }

    /// Resolve a position string to a WindowPosition, handling aliases and fuzzy matching.
    func resolvePosition(_ input: String) -> WindowPosition? {
        let cleaned = input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        // Direct match
        if let pos = WindowPosition(rawValue: cleaned) {
            return pos
        }

        // Aliases
        let aliases: [String: WindowPosition] = [
            "left": .left_half,
            "right": .right_half,
            "top": .top_half,
            "bottom": .bottom_half,
            "full": .full_screen,
            "maximize": .full_screen,
            "maximise": .full_screen,
            "max": .full_screen,
            "fullscreen": .full_screen,
            "centered": .center,
            "middle": .center,
            "quarter_top_left": .top_left,
            "quarter_top_right": .top_right,
            "quarter_bottom_left": .bottom_left,
            "quarter_bottom_right": .bottom_right,
        ]

        return aliases[cleaned]
    }

    private func resolveTargetApplication(for command: Command) -> NSRunningApplication? {
        let targetHint = command.target?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let targetHint, !targetHint.isEmpty, !isFrontmostAlias(targetHint),
           let namedApp = findRunningApplication(named: targetHint) {
            Self.rememberLastExternalApplication(namedApp)
            return namedApp
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication, !Self.isAssistantApplication(frontmost) {
            Self.rememberLastExternalApplication(frontmost)
            return frontmost
        }

        if let remembered = Self.rememberedExternalApplication(), !remembered.isTerminated {
            return remembered
        }

        return nil
    }

    private static func isAssistantApplication(_ app: NSRunningApplication) -> Bool {
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return true
        }

        guard let assistantBundleID = Bundle.main.bundleIdentifier,
              let bundleID = app.bundleIdentifier else {
            return false
        }
        return assistantBundleID == bundleID
    }

    private func isFrontmostAlias(_ target: String) -> Bool {
        let normalized = target.lowercased()
        return normalized == "frontmost"
            || normalized == "current"
            || normalized == "focused"
            || normalized == "active"
    }

    private func findRunningApplication(named target: String) -> NSRunningApplication? {
        let normalizedTarget = target.lowercased()
        let regularApps = NSWorkspace.shared.runningApplications.filter { app in
            !app.isTerminated && app.activationPolicy == .regular
        }

        if let exactBundle = regularApps.first(where: { $0.bundleIdentifier?.lowercased() == normalizedTarget }) {
            return exactBundle
        }
        if let exactName = regularApps.first(where: { ($0.localizedName ?? "").lowercased() == normalizedTarget }) {
            return exactName
        }
        if let fuzzyName = regularApps.first(where: { ($0.localizedName ?? "").lowercased().contains(normalizedTarget) }) {
            return fuzzyName
        }

        return nil
    }

    private static func rememberedExternalApplication() -> NSRunningApplication? {
        guard let pid = lastExternalAppPID else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    private func copyTargetWindow(from appElement: AXUIElement) -> AXUIElement? {
        if let focused = copyAXElementAttribute(element: appElement, attribute: kAXFocusedWindowAttribute as CFString) {
            return focused
        }
        if let main = copyAXElementAttribute(element: appElement, attribute: kAXMainWindowAttribute as CFString) {
            return main
        }
        if let windows = copyAXWindowListAttribute(element: appElement, attribute: kAXWindowsAttribute as CFString) {
            return windows.first
        }
        return nil
    }

    private func copyAXElementAttribute(element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        guard result == .success,
              let valueRef,
              CFGetTypeID(valueRef) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(valueRef, to: AXUIElement.self)
    }

    private func copyAXWindowListAttribute(element: AXUIElement, attribute: CFString) -> [AXUIElement]? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        guard result == .success,
              let array = valueRef as? [Any] else {
            return nil
        }
        let windows = array.compactMap { item -> AXUIElement? in
            guard CFGetTypeID(item as CFTypeRef) == AXUIElementGetTypeID() else {
                return nil
            }
            return unsafeBitCast(item as CFTypeRef, to: AXUIElement.self)
        }
        return windows.isEmpty ? nil : windows
    }

    private func targetScreenVisibleFrame(for axWindow: AXUIElement) -> NSRect? {
        guard let windowFrame = currentFrame(for: axWindow) else {
            return NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
        }

        let midpoint = NSPoint(x: windowFrame.midX, y: windowFrame.midY)
        if let containingScreen = NSScreen.screens.first(where: { $0.frame.contains(midpoint) }) {
            return containingScreen.visibleFrame
        }
        if let intersectingScreen = NSScreen.screens.first(where: { $0.frame.intersects(windowFrame) }) {
            return intersectingScreen.visibleFrame
        }
        return NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
    }

    private func currentFrame(for axWindow: AXUIElement) -> CGRect? {
        guard let position = copyCGPointAttribute(element: axWindow, attribute: kAXPositionAttribute as CFString),
              let size = copyCGSizeAttribute(element: axWindow, attribute: kAXSizeAttribute as CFString) else {
            return nil
        }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let nsY = primaryHeight - position.y - size.height
        return CGRect(x: position.x, y: nsY, width: size.width, height: size.height)
    }

    private func copyCGPointAttribute(element: AXUIElement, attribute: CFString) -> CGPoint? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        guard result == .success,
              let valueRef,
              CFGetTypeID(valueRef) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(valueRef, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private func copyCGSizeAttribute(element: AXUIElement, attribute: CFString) -> CGSize? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        guard result == .success,
              let valueRef,
              CFGetTypeID(valueRef) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(valueRef, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }
        return size
    }
}

// MARK: - Debug Tests

#if DEBUG
extension WindowManager {
    static func setRememberedExternalPIDForTesting(_ pid: pid_t?) {
        lastExternalAppPID = pid
    }

    static func rememberedExternalPIDForTesting() -> pid_t? {
        lastExternalAppPID
    }

    public static func runTests() {
        print("\nRunning WindowManager tests...")
        var passed = 0
        var failed = 0
        let manager = WindowManager()

        // Test 1: Executor name
        do {
            if manager.name == "WindowManager" {
                print("  \u{2705} Test 1: Executor name is 'WindowManager'")
                passed += 1
            } else {
                print("  \u{274C} Test 1: Expected 'WindowManager', got '\(manager.name)'")
                failed += 1
            }
        }

        // Test 2: Resolve known positions
        do {
            var allOk = true
            for pos in WindowPosition.allCases {
                if manager.resolvePosition(pos.rawValue) != pos {
                    print("  \u{274C} Test 2: Failed to resolve '\(pos.rawValue)'")
                    allOk = false
                }
            }
            if allOk {
                print("  \u{2705} Test 2: All \(WindowPosition.allCases.count) position strings resolve correctly")
                passed += 1
            } else {
                failed += 1
            }
        }

        // Test 3: Resolve aliases
        do {
            let cases: [(String, WindowPosition)] = [
                ("left", .left_half),
                ("right", .right_half),
                ("top", .top_half),
                ("bottom", .bottom_half),
                ("full", .full_screen),
                ("maximize", .full_screen),
                ("center", .center),
                ("centered", .center),
            ]
            var allOk = true
            for (alias, expected) in cases {
                if manager.resolvePosition(alias) != expected {
                    print("  \u{274C} Test 3: Alias '\(alias)' did not resolve to \(expected.rawValue)")
                    allOk = false
                }
            }
            if allOk {
                print("  \u{2705} Test 3: All aliases resolve correctly")
                passed += 1
            } else {
                failed += 1
            }
        }

        // Test 4: Resolve with hyphens and spaces
        do {
            let cases: [(String, WindowPosition)] = [
                ("left-half", .left_half),
                ("right half", .right_half),
                ("top-left", .top_left),
                ("bottom right", .bottom_right),
                ("full screen", .full_screen),
                ("FULL_SCREEN", .full_screen),
            ]
            var allOk = true
            for (input, expected) in cases {
                if manager.resolvePosition(input) != expected {
                    print("  \u{274C} Test 4: '\(input)' did not resolve to \(expected.rawValue)")
                    allOk = false
                }
            }
            if allOk {
                print("  \u{2705} Test 4: Hyphen/space/case variants resolve correctly")
                passed += 1
            } else {
                failed += 1
            }
        }

        // Test 5: Unknown position returns nil
        do {
            if manager.resolvePosition("banana") == nil {
                print("  \u{2705} Test 5: Unknown position 'banana' returns nil")
                passed += 1
            } else {
                print("  \u{274C} Test 5: Expected nil for unknown position 'banana'")
                failed += 1
            }
        }

        // Test 6: Frame calculations — left_half
        do {
            let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
            let frame = WindowPosition.left_half.frame(on: screen)
            if frame == CGRect(x: 0, y: 0, width: 960, height: 1080) {
                print("  \u{2705} Test 6: left_half frame is correct (0,0,960,1080)")
                passed += 1
            } else {
                print("  \u{274C} Test 6: left_half frame wrong: \(frame)")
                failed += 1
            }
        }

        // Test 7: Frame calculations — right_half
        do {
            let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
            let frame = WindowPosition.right_half.frame(on: screen)
            if frame == CGRect(x: 960, y: 0, width: 960, height: 1080) {
                print("  \u{2705} Test 7: right_half frame is correct (960,0,960,1080)")
                passed += 1
            } else {
                print("  \u{274C} Test 7: right_half frame wrong: \(frame)")
                failed += 1
            }
        }

        // Test 8: Frame calculations — full_screen
        do {
            let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
            let frame = WindowPosition.full_screen.frame(on: screen)
            if frame == CGRect(x: 0, y: 0, width: 1920, height: 1080) {
                print("  \u{2705} Test 8: full_screen frame is correct (0,0,1920,1080)")
                passed += 1
            } else {
                print("  \u{274C} Test 8: full_screen frame wrong: \(frame)")
                failed += 1
            }
        }

        // Test 9: Frame calculations — center (60% of screen)
        do {
            let screen = NSRect(x: 0, y: 0, width: 2000, height: 1000)
            let frame = WindowPosition.center.frame(on: screen)
            let expected = CGRect(x: 400, y: 200, width: 1200, height: 600)
            if frame == expected {
                print("  \u{2705} Test 9: center frame is correct (400,200,1200,600)")
                passed += 1
            } else {
                print("  \u{274C} Test 9: center frame wrong: \(frame), expected \(expected)")
                failed += 1
            }
        }

        // Test 10: Frame calculations — quarter positions
        do {
            let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
            let tl = WindowPosition.top_left.frame(on: screen)
            let tr = WindowPosition.top_right.frame(on: screen)
            let bl = WindowPosition.bottom_left.frame(on: screen)
            let br = WindowPosition.bottom_right.frame(on: screen)

            let allCorrect = tl == CGRect(x: 0, y: 540, width: 960, height: 540)
                && tr == CGRect(x: 960, y: 540, width: 960, height: 540)
                && bl == CGRect(x: 0, y: 0, width: 960, height: 540)
                && br == CGRect(x: 960, y: 0, width: 960, height: 540)

            if allCorrect {
                print("  \u{2705} Test 10: All quarter positions have correct frames")
                passed += 1
            } else {
                print("  \u{274C} Test 10: Quarter frames wrong: tl=\(tl) tr=\(tr) bl=\(bl) br=\(br)")
                failed += 1
            }
        }

        // Test 11: Frame on offset screen (multi-monitor)
        do {
            let screen = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
            let frame = WindowPosition.left_half.frame(on: screen)
            if frame == CGRect(x: 1920, y: 0, width: 960, height: 1080) {
                print("  \u{2705} Test 11: left_half on offset screen preserves origin")
                passed += 1
            } else {
                print("  \u{274C} Test 11: Offset screen frame wrong: \(frame)")
                failed += 1
            }
        }

        // Test 12: Empty position string returns error via execute
        do {
            let cmd = Command(type: .WINDOW_MANAGE, target: nil, confidence: 0.9)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            manager.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()

            if let r = testResult, !r.success {
                // Missing position should fail validation before any AX interaction.
                print("  \u{2705} Test 12: Missing position returns error")
                passed += 1
            } else {
                print("  \u{274C} Test 12: Expected error for missing position")
                failed += 1
            }
        }

        // Test 13: End-to-end parse WINDOW_MANAGE command
        do {
            let json = #"{"type": "WINDOW_MANAGE", "target": "frontmost", "parameters": {"position": "left_half"}, "confidence": 0.95}"#
            do {
                let cmd = try CommandParser.parse(json)
                if cmd.type == .WINDOW_MANAGE
                    && cmd.target == "frontmost"
                    && cmd.stringParam("position") == "left_half" {
                    print("  \u{2705} Test 13: Parse WINDOW_MANAGE command with position parameter")
                    passed += 1
                } else {
                    print("  \u{274C} Test 13: Parsed command has wrong values")
                    failed += 1
                }
            } catch {
                print("  \u{274C} Test 13: Parse failed: \(error)")
                failed += 1
            }
        }

        // Test 14: All WindowPosition cases have non-empty displayName
        do {
            var allOk = true
            for pos in WindowPosition.allCases {
                if pos.displayName.isEmpty {
                    print("  \u{274C} Test 14: \(pos.rawValue) has empty displayName")
                    allOk = false
                }
            }
            if allOk {
                print("  \u{2705} Test 14: All positions have non-empty displayName")
                passed += 1
            } else {
                failed += 1
            }
        }

        // Test 15: Current app is treated as assistant and excluded from fallback cache
        do {
            WindowManager.setRememberedExternalPIDForTesting(12345)
            WindowManager.rememberLastExternalApplication(NSRunningApplication.current)
            if WindowManager.rememberedExternalPIDForTesting() == 12345 {
                print("  \u{2705} Test 15: Current app does not overwrite remembered external app")
                passed += 1
            } else {
                print("  \u{274C} Test 15: Current app should not overwrite remembered external app")
                failed += 1
            }
        }

        // Test 16: Frontmost target aliases are recognized
        do {
            let aliases = ["frontmost", "current", "focused", "active", "FRONTMOST"]
            let allAliasesMatch = aliases.allSatisfy { manager.isFrontmostAlias($0) }
            if allAliasesMatch, !manager.isFrontmostAlias("safari") {
                print("  \u{2705} Test 16: Frontmost aliases resolve correctly")
                passed += 1
            } else {
                print("  \u{274C} Test 16: Frontmost alias detection failed")
                failed += 1
            }
        }

        print("\nWindowManager results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
