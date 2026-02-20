import Cocoa
import CoreGraphics
import Foundation

/// High-level tool executor that chains screenshot → vision → mouse/keyboard → verify
/// into a single "computer_action" tool call. Claude can say "click the Compose button"
/// and this tool handles the full flow internally with retry logic.
///
/// Security guarantees:
/// - Requires both Screen Recording and Accessibility permissions.
/// - All mouse/keyboard events go through validated CGEvent APIs (no shell, no AppleScript).
/// - Screenshots are in-memory only (never written to disk).
/// - Each action has a maximum of 3 attempts to prevent infinite retry loops.
/// - 5-second wait between actions is configurable.
public final class ComputerControl: ToolExecutor {

    /// Maximum number of attempts per action before giving up.
    private static let maxAttempts = 3

    /// Default delay in seconds to wait for the screen to update after an action.
    private static let defaultActionDelay: TimeInterval = 2.0

    /// UserDefaults key for configurable action delay.
    static let actionDelayDefaultsKey = "computerControl.actionDelaySeconds"

    private let screenCapture: ScreenCapture
    private let mouseController: MouseController
    private let keyboardController: KeyboardController
    private let visionAnalyzer: VisionAnalyzer

    /// Closure that the orchestrator can set to emit real-time status messages.
    public var onStatusUpdate: ((String) -> Void)?

    public init(
        screenCapture: ScreenCapture = ScreenCapture(),
        mouseController: MouseController = MouseController(),
        keyboardController: KeyboardController = KeyboardController(),
        visionAnalyzer: VisionAnalyzer = VisionAnalyzer()
    ) {
        self.screenCapture = screenCapture
        self.mouseController = mouseController
        self.keyboardController = keyboardController
        self.visionAnalyzer = visionAnalyzer
    }

    // MARK: - ToolExecutor

    public func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        Task { [weak self] in
            guard let self else {
                await MainActor.run {
                    completion(.error("Computer control tool is unavailable."))
                }
                return
            }

            let result = await self.run(arguments: arguments)
            await MainActor.run {
                completion(result)
            }
        }
    }

    // MARK: - Core Flow

    private func run(arguments: [String: Any]) async -> ExecutionResult {
        guard let action = stringValue(for: ["action", "description", "task"], in: arguments) else {
            return .error(
                "Missing action description.",
                details: "Provide an `action` parameter describing what to do, e.g., 'click the Compose button in Gmail'."
            )
        }

        let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAction.isEmpty else {
            return .error("Action description cannot be empty.")
        }

        // Determine action type from the description
        let actionType = classifyAction(trimmedAction)
        let actionDelay = UserDefaults.standard.double(forKey: Self.actionDelayDefaultsKey)
        let delay = actionDelay > 0 ? actionDelay : Self.defaultActionDelay

        for attempt in 1...Self.maxAttempts {
            emitStatus("Capturing screen (attempt \(attempt)/\(Self.maxAttempts))...")

            // Step 1: Capture screenshot
            guard let screenshot = await screenCapture.captureFullScreen() else {
                return .error(
                    "Screen capture failed.",
                    details: "Check Screen Recording permission in System Settings → Privacy & Security → Screen Recording."
                )
            }

            // Step 2: Ask Claude vision to analyze the screen and find the target
            emitStatus("Analyzing screen...")
            let visionPrompt = buildVisionPrompt(for: trimmedAction, actionType: actionType)

            let analysisText: String
            do {
                analysisText = try await visionAnalyzer.analyze(image: screenshot, prompt: visionPrompt)
            } catch {
                return .error(
                    "Vision analysis failed.",
                    details: error.localizedDescription
                )
            }

            // Step 3: Parse coordinates from vision response
            let parsed = visionAnalyzer.parse(analysisText)

            // Check if vision explicitly said element not found
            let analysisLowered = analysisText.lowercased()
            let elementNotFound = analysisLowered.contains("element not found")
                || analysisLowered.contains("not visible")
                || analysisLowered.contains("cannot find")
                || analysisLowered.contains("could not find")
                || analysisLowered.contains("don't see")
                || analysisLowered.contains("do not see")

            guard let coordinate = parsed.coordinates.first, !elementNotFound else {
                if attempt < Self.maxAttempts {
                    emitStatus("Target element not found on screen. Retrying...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                return .error(
                    "Could not locate the target element on screen after \(Self.maxAttempts) attempts.",
                    details: "Action: \(trimmedAction)\n\nWhat vision saw:\n\(analysisText)"
                )
            }

            // Step 4: Convert percentage coordinates to absolute pixels
            let screenBounds = CGDisplayBounds(CGMainDisplayID())
            let absX = Int((coordinate.xPercent / 100.0) * Double(screenBounds.width))
            let absY = Int((coordinate.yPercent / 100.0) * Double(screenBounds.height))

            emitStatus("Found target at (\(absX), \(absY)). Performing action...")

            // Step 5: Execute the action
            let actionResult = executeAction(
                actionType: actionType,
                x: absX,
                y: absY,
                action: trimmedAction,
                arguments: arguments
            )

            guard actionResult.success else {
                if attempt < Self.maxAttempts {
                    emitStatus("Action failed: \(actionResult.message). Retrying...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                return actionResult
            }

            // Step 6: Wait for screen to update
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            // Step 7: Verify by taking another screenshot
            emitStatus("Verifying action...")
            guard let verifyScreenshot = await screenCapture.captureFullScreen() else {
                // Verification capture failed, but action may have succeeded
                return .ok(
                    "Action performed at (\(absX), \(absY)) but verification screenshot failed.",
                    details: "Action: \(trimmedAction)\nCoordinates: (\(absX), \(absY))"
                )
            }

            let verifyPrompt = """
            BEFORE the action, I was trying to: "\(trimmedAction)"
            I interacted at pixel coordinates (\(absX), \(absY)).

            Look at this screenshot taken AFTER the action. Describe what you see NOW.

            Then answer ONE of these:
            - "SUCCESS:" followed by what changed (e.g., "SUCCESS: The File menu is now open")
            - "FAILED:" followed by why it didn't work (e.g., "FAILED: The screen looks the same, nothing changed")
            - "UNCLEAR:" if you can't tell

            Be honest. If the screen looks exactly the same as before, say FAILED.
            """

            let verifyText: String
            do {
                verifyText = try await visionAnalyzer.analyze(image: verifyScreenshot, prompt: verifyPrompt)
            } catch {
                // Verification analysis failed — report what we did but note the gap
                return .ok(
                    "Action performed at (\(absX), \(absY)). Could not verify result.",
                    details: "Action: \(trimmedAction)\nCoordinates: (\(absX), \(absY))\nVerification error: \(error.localizedDescription)"
                )
            }

            let verifyLowered = verifyText.lowercased()
            let isSuccess = verifyLowered.contains("success:")
            let isFailed = verifyLowered.contains("failed:")

            if isSuccess && !isFailed {
                return .ok(
                    "Computer action completed: \(trimmedAction)",
                    details: "Coordinates: (\(absX), \(absY))\nVerification: \(verifyText)"
                )
            }

            // Failed or unclear — retry if we have attempts left
            if attempt < Self.maxAttempts {
                emitStatus("Verification: action may not have worked. Retrying with fresh screenshot...")
                continue
            }

            // Last attempt — report what happened honestly
            if isFailed {
                return .error(
                    "Action did not succeed after \(Self.maxAttempts) attempts: \(trimmedAction)",
                    details: "Last coordinates: (\(absX), \(absY))\nVerification: \(verifyText)"
                )
            }

            // Unclear on last attempt — report honestly with verification text
            return .ok(
                "Action attempted: \(trimmedAction). Result uncertain.",
                details: "Coordinates: (\(absX), \(absY))\nVerification: \(verifyText)"
            )
        }

        return .error("Computer action failed after \(Self.maxAttempts) attempts: \(trimmedAction)")
    }

    // MARK: - Action Classification

    private enum ActionType {
        case click
        case doubleClick
        case rightClick
        case typeText(String)
        case generic
    }

    private func classifyAction(_ action: String) -> ActionType {
        let lowered = action.lowercased()

        if lowered.contains("double-click") || lowered.contains("double click") {
            return .doubleClick
        }
        if lowered.contains("right-click") || lowered.contains("right click") {
            return .rightClick
        }
        if lowered.hasPrefix("type ") || lowered.contains("type '") || lowered.contains("type \"") {
            let text = extractQuotedText(from: action) ?? extractTextAfter("type ", in: action)
            if let text, !text.isEmpty {
                return .typeText(text)
            }
        }
        if lowered.contains("click") || lowered.contains("press") || lowered.contains("tap")
            || lowered.contains("select") || lowered.contains("open") || lowered.contains("close") {
            return .click
        }

        return .generic
    }

    private func extractQuotedText(from text: String) -> String? {
        // Try single quotes first, then double quotes
        for quote in ["'", "\""] {
            let parts = text.components(separatedBy: quote)
            if parts.count >= 3 {
                return parts[1]
            }
        }
        return nil
    }

    private func extractTextAfter(_ prefix: String, in text: String) -> String? {
        guard let range = text.lowercased().range(of: prefix) else { return nil }
        let remainder = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder.isEmpty ? nil : remainder
    }

    // MARK: - Action Execution

    private func executeAction(
        actionType: ActionType,
        x: Int,
        y: Int,
        action: String,
        arguments: [String: Any]
    ) -> ExecutionResult {
        switch actionType {
        case .click:
            do {
                try mouseController.click(x: x, y: y)
                return .ok("Clicked at (\(x), \(y)).")
            } catch {
                return .error("Click failed.", details: error.localizedDescription)
            }

        case .doubleClick:
            do {
                try mouseController.doubleClick(x: x, y: y)
                return .ok("Double-clicked at (\(x), \(y)).")
            } catch {
                return .error("Double-click failed.", details: error.localizedDescription)
            }

        case .rightClick:
            do {
                try mouseController.rightClick(x: x, y: y)
                return .ok("Right-clicked at (\(x), \(y)).")
            } catch {
                return .error("Right-click failed.", details: error.localizedDescription)
            }

        case .typeText(let text):
            // Click to focus the element first, then type
            do {
                try mouseController.click(x: x, y: y)
                Thread.sleep(forTimeInterval: 0.15)
                try keyboardController.typeText(text: text)
                return .ok("Clicked at (\(x), \(y)) and typed \(text.count) characters.")
            } catch {
                return .error("Type action failed.", details: error.localizedDescription)
            }

        case .generic:
            // Default to click
            do {
                try mouseController.click(x: x, y: y)
                return .ok("Clicked at (\(x), \(y)) for action: \(action)")
            } catch {
                return .error("Action failed.", details: error.localizedDescription)
            }
        }
    }

    // MARK: - Vision Prompt Building

    private func buildVisionPrompt(for action: String, actionType: ActionType) -> String {
        let baseInstruction: String
        switch actionType {
        case .click, .generic:
            baseInstruction = "I need to CLICK on a specific UI element."
        case .doubleClick:
            baseInstruction = "I need to DOUBLE-CLICK on a specific UI element."
        case .rightClick:
            baseInstruction = "I need to RIGHT-CLICK on a specific UI element."
        case .typeText:
            baseInstruction = "I need to find a TEXT FIELD or INPUT AREA to click and type into."
        }

        return """
        \(baseInstruction)

        Action requested: "\(action)"

        INSTRUCTIONS:
        1. First, describe what you actually see on this screenshot. What app is visible? What state is it in?
        2. Look for the specific UI element needed for this action.
        3. If you find it, return its CENTER position as percentage coordinates.
        4. If you CANNOT find the element, say "ELEMENT NOT FOUND:" and explain what you see instead.

        COORDINATE FORMAT (required):
        x: NN%, y: NN%
        where x = horizontal (0% = left edge, 100% = right edge)
        and y = vertical (0% = top edge, 100% = bottom edge)

        IMPORTANT:
        - Point to the EXACT CENTER of the target element, not its edge.
        - Be precise. A few percent off means clicking the wrong thing.
        - If the element is not visible on screen, say so. Do NOT guess coordinates.
        - If the screen shows something unexpected (wrong app, dialog box, etc.), describe what you actually see.
        """
    }

    // MARK: - Helpers

    private func stringValue(for keys: [String], in arguments: [String: Any]) -> String? {
        for key in keys {
            if let value = arguments[key] as? String {
                return value
            }
        }
        return nil
    }

    private func emitStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatusUpdate?(status)
        }
    }
}
