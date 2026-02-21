// UIStateProvider.swift
// aiDAEMON
//
// M043: UI State Provider + AX Tools
// Produces compact text snapshots of the computer state for Claude's context,
// and provides AX action/find executors for the tool-use loop.

import Cocoa
import ApplicationServices

// MARK: - UIStateProvider

/// Produces a compact text snapshot of the current computer state:
/// frontmost app, visible windows, and AX tree of the frontmost app.
/// Registered as the executor for `get_ui_state`.
final class UIStateProvider: ToolExecutor {

    /// Sub-executors for AX action and find tools.
    let actionExecutor: AXActionExecutor
    let findExecutor: AXFindExecutor

    private let axService = AccessibilityService.shared

    /// Cache: last snapshot text and timestamp.
    private var cachedSnapshot: String?
    private var cacheTimestamp: Date = .distantPast
    private let cacheTTL: TimeInterval = 0.5

    init() {
        actionExecutor = AXActionExecutor()
        findExecutor = AXFindExecutor()

        // After any AX action, invalidate cached snapshot so next get_ui_state is fresh.
        actionExecutor.onActionCompleted = { [weak self] in
            self?.invalidateCache()
        }
    }

    /// Invalidate the cached snapshot so the next get_ui_state returns fresh data.
    func invalidateCache() {
        cachedSnapshot = nil
        cacheTimestamp = .distantPast
    }

    // MARK: - ToolExecutor (get_ui_state)

    func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        Task {
            let snapshot = await getSnapshot()
            completion(.ok(snapshot))
        }
    }

    // MARK: - Snapshot Generation

    func getSnapshot() async -> String {
        // Return cached if fresh
        if let cached = cachedSnapshot, Date().timeIntervalSince(cacheTimestamp) < cacheTTL {
            return cached
        }

        var lines: [String] = ["=== Computer State ==="]

        // Layer 1: Frontmost app info
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        if let app = frontmostApp {
            let name = app.localizedName ?? "Unknown"
            let pid = app.processIdentifier
            let bundle = app.bundleIdentifier ?? "unknown"
            lines.append("Frontmost: \(name) (pid:\(pid), bundle:\(bundle))")
        } else {
            lines.append("Frontmost: (none)")
        }

        // Layer 1b: Visible windows
        let windowLine = buildWindowList()
        lines.append("Windows: \(windowLine)")
        lines.append("")

        // Layer 2: AX tree of frontmost app
        if let snapshot = await axService.walkFrontmostApp(maxDepth: 8, maxElements: 200) {
            let appName = frontmostApp?.localizedName ?? "App"
            lines.append("--- \(appName) UI Tree ---")
            lines.append(axService.formatTree(snapshot))
        } else if !axService.isAccessibilityEnabled {
            lines.append("(Accessibility permission not granted — enable aiDAEMON in System Settings > Privacy & Security > Accessibility)")
        } else {
            lines.append("(No AX tree available for frontmost app)")
        }

        let text = lines.joined(separator: "\n")
        cachedSnapshot = text
        cacheTimestamp = Date()
        return text
    }

    // MARK: - Window List

    private func buildWindowList() -> String {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return "(unable to read windows)"
        }

        var windowDescs: [String] = []
        for info in windowInfoList {
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue } // layer 0 = normal windows

            let title = info[kCGWindowName as String] as? String
            var desc = ownerName
            if let t = title, !t.isEmpty {
                let truncated = t.count > 40 ? String(t.prefix(37)) + "..." : t
                desc += " \"\(truncated)\""
            }

            if let bounds = info[kCGWindowBounds as String] as? [String: Any],
               let w = bounds["Width"] as? CGFloat,
               let h = bounds["Height"] as? CGFloat {
                desc += " \(Int(w))x\(Int(h))"
            }

            windowDescs.append(desc)

            if windowDescs.count >= 10 { break }
        }

        return windowDescs.isEmpty ? "(no visible windows)" : windowDescs.joined(separator: " | ")
    }
}

// MARK: - AXActionExecutor

/// Executes accessibility actions on elements by ref.
/// Registered as the executor for `ax_action`.
final class AXActionExecutor: ToolExecutor {

    private let axService = AccessibilityService.shared

    /// Called after an action completes so the UI state cache can be invalidated.
    var onActionCompleted: (() -> Void)?

    func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        guard let ref = arguments["ref"] as? String else {
            completion(.error("Missing required parameter 'ref'"))
            return
        }
        guard let action = arguments["action"] as? String else {
            completion(.error("Missing required parameter 'action'"))
            return
        }

        Task { [weak self] in
            do {
                switch action {
                case "press":
                    try await axService.pressElement(ref: ref)
                    self?.onActionCompleted?()
                    completion(.ok("Pressed element \(ref)"))

                case "set_value":
                    guard let value = arguments["value"] as? String else {
                        completion(.error("'set_value' action requires a 'value' parameter"))
                        return
                    }
                    try await axService.setValue(ref: ref, value: value)
                    self?.onActionCompleted?()
                    completion(.ok("Set value on \(ref) to: \(value)"))

                case "focus":
                    try await axService.focusElement(ref: ref)
                    self?.onActionCompleted?()
                    completion(.ok("Focused element \(ref)"))

                case "raise":
                    try await axService.raiseElement(ref: ref)
                    self?.onActionCompleted?()
                    completion(.ok("Raised element \(ref)"))

                case "show_menu":
                    try await axService.showMenu(ref: ref)
                    self?.onActionCompleted?()
                    completion(.ok("Opened menu on element \(ref)"))

                default:
                    completion(.error("Unknown action '\(action)'. Use: press, set_value, focus, raise, show_menu"))
                }
            } catch {
                completion(.error("ax_action failed: \(error.localizedDescription)"))
            }
        }
    }
}

// MARK: - AXFindExecutor

/// Searches the frontmost app's AX tree for elements matching role/title/value.
/// Registered as the executor for `ax_find`.
final class AXFindExecutor: ToolExecutor {

    private let axService = AccessibilityService.shared

    func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        let role = arguments["role"] as? String
        let title = arguments["title"] as? String
        let value = arguments["value"] as? String

        if role == nil && title == nil && value == nil {
            completion(.error("Provide at least one of: role, title, value"))
            return
        }

        Task {
            // Use searchFrontmostApp to append to the existing ref map instead of resetting it.
            // This preserves refs from prior get_ui_state calls.
            guard let snapshot = await axService.searchFrontmostApp(maxDepth: 8, maxElements: 200) else {
                if !axService.isAccessibilityEnabled {
                    completion(.error("Accessibility permission not granted."))
                } else {
                    completion(.error("No AX tree available for frontmost app."))
                }
                return
            }

            var matches: [(ref: String, desc: String)] = []
            collectMatches(snapshot: snapshot, role: role, title: title, value: value, matches: &matches)

            if matches.isEmpty {
                var criteria: [String] = []
                if let r = role { criteria.append("role=\(r)") }
                if let t = title { criteria.append("title~\(t)") }
                if let v = value { criteria.append("value~\(v)") }
                completion(.ok("No elements found matching: \(criteria.joined(separator: ", "))"))
                return
            }

            var lines = ["Found \(matches.count) element(s):"]
            for match in matches.prefix(20) {
                lines.append("  \(match.ref) \(match.desc)")
            }
            if matches.count > 20 {
                lines.append("  ... and \(matches.count - 20) more")
            }
            completion(.ok(lines.joined(separator: "\n")))
        }
    }

    private func collectMatches(
        snapshot: AXElementSnapshot,
        role: String?,
        title: String?,
        value: String?,
        matches: inout [(ref: String, desc: String)]
    ) {
        var isMatch = true

        if let role = role {
            if !snapshot.role.localizedCaseInsensitiveContains(role) {
                isMatch = false
            }
        }
        if let title = title, isMatch {
            let elementTitle = snapshot.title ?? ""
            let elementDesc = snapshot.elementDescription ?? ""
            if !elementTitle.localizedCaseInsensitiveContains(title)
                && !elementDesc.localizedCaseInsensitiveContains(title) {
                isMatch = false
            }
        }
        if let value = value, isMatch {
            let elementValue = snapshot.value ?? ""
            if !elementValue.localizedCaseInsensitiveContains(value) {
                isMatch = false
            }
        }

        if isMatch {
            var desc = snapshot.role
            if let t = snapshot.title, !t.isEmpty {
                desc += " \"\(t)\""
            }
            if let v = snapshot.value, !v.isEmpty {
                let truncated = v.count > 60 ? String(v.prefix(57)) + "..." : v
                desc += " value=\"\(truncated)\""
            }
            matches.append((ref: snapshot.ref, desc: desc))
        }

        for child in snapshot.children {
            collectMatches(snapshot: child, role: role, title: title, value: value, matches: &matches)
        }
    }
}
