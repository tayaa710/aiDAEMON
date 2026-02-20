import Cocoa
import CoreGraphics
import Foundation

/// Tool executor for screen capture + vision analysis.
///
/// Security guarantees:
/// - Captures are in-memory only (never written to disk).
/// - Permission-gated by macOS Screen Recording access.
/// - JPEG data is generated only for upload to Claude vision and discarded immediately.
public final class ScreenCapture: ToolExecutor {

    public static let activityDidChangeNotification = Notification.Name("com.aidaemon.screenCaptureActivity")
    public static let activityStateUserInfoKey = "isActive"

    private static let maxResolution = CGSize(width: 1920, height: 1080)

    private let visionAnalyzer: VisionAnalyzer
    private let activityLock = NSLock()
    private var activeCaptureCount = 0

    public init(visionAnalyzer: VisionAnalyzer = VisionAnalyzer()) {
        self.visionAnalyzer = visionAnalyzer
    }

    // MARK: - ToolExecutor

    public func execute(arguments: [String: Any], completion: @escaping (ExecutionResult) -> Void) {
        Task { [weak self] in
            guard let self else {
                await MainActor.run {
                    completion(.error("Screen capture tool is unavailable."))
                }
                return
            }

            let result = await self.run(arguments: arguments)
            await MainActor.run {
                completion(result)
            }
        }
    }

    // MARK: - Public Capture API

    public func captureFullScreen() async -> NSImage? {
        guard await ensureScreenRecordingPermission() else { return nil }
        let bounds = CGDisplayBounds(CGMainDisplayID())
        return captureImage(screenBounds: bounds, listOption: [.optionOnScreenOnly, .excludeDesktopElements], windowID: kCGNullWindowID)
    }

    public func captureWindow(of app: String) async -> NSImage? {
        guard await ensureScreenRecordingPermission() else { return nil }
        guard let windowID = windowID(for: app) else { return nil }
        return captureImage(screenBounds: .null, listOption: .optionIncludingWindow, windowID: windowID)
    }

    public func captureRegion(rect: CGRect) async -> NSImage? {
        guard await ensureScreenRecordingPermission() else { return nil }
        let clipped = clippedToAvailableDisplays(rect.standardized)
        guard !clipped.isNull, clipped.width > 1, clipped.height > 1 else { return nil }
        return captureImage(screenBounds: clipped, listOption: [.optionOnScreenOnly, .excludeDesktopElements], windowID: kCGNullWindowID)
    }

    // MARK: - Internals

    private enum CaptureMode {
        case full
        case window(appName: String)
        case region(CGRect)

        var displayName: String {
            switch self {
            case .full: return "full screen"
            case .window(let appName): return "window (\(appName))"
            case .region: return "region"
            }
        }
    }

    private func run(arguments: [String: Any]) async -> ExecutionResult {
        markCaptureActivity(started: true)
        defer { markCaptureActivity(started: false) }

        guard await ensureScreenRecordingPermission() else {
            return .error(
                "Screen Recording permission required.",
                details: "Grant permission in System Settings → Privacy & Security → Screen Recording, then relaunch aiDAEMON."
            )
        }

        let modeResult = resolveMode(from: arguments)
        guard let mode = modeResult.mode else {
            return .error("Invalid screen capture request.", details: modeResult.reason)
        }

        let prompt = resolvedPrompt(from: arguments, mode: mode)

        let image: NSImage?
        switch mode {
        case .full:
            image = await captureFullScreen()
        case .window(let appName):
            image = await captureWindow(of: appName)
        case .region(let rect):
            image = await captureRegion(rect: rect)
        }

        guard let image else {
            return .error(
                "Unable to capture the requested screen content.",
                details: "Check Screen Recording permission and ensure the target window/region is visible."
            )
        }

        do {
            let analysis = try await visionAnalyzer.analyze(image: image, prompt: prompt)
            let jpegBytes = Self.jpegData(from: image, quality: 0.75)?.count ?? 0
            let sizeKB = max(1, Int(Double(jpegBytes) / 1024.0))
            let dimensions = "\(Int(image.size.width))x\(Int(image.size.height))"

            // Include the primary display dimensions so Claude can convert
            // percentage-based vision coordinates to absolute pixels.
            let screenBounds = CGDisplayBounds(CGMainDisplayID())
            let screenDims = "\(Int(screenBounds.width))x\(Int(screenBounds.height))"

            return .ok(
                "Vision analysis completed.",
                details: "Capture mode: \(mode.displayName)\nImage: \(dimensions), ~\(sizeKB)KB JPEG (in-memory)\nScreen dimensions: \(screenDims)\n\n\(analysis)"
            )
        } catch {
            return .error(
                "Screen capture succeeded but vision analysis failed.",
                details: error.localizedDescription
            )
        }
    }

    private func resolveMode(from arguments: [String: Any]) -> (mode: CaptureMode?, reason: String) {
        let rawMode = stringValue(for: ["mode", "captureMode", "capture"], in: arguments)?.lowercased()
        let target = stringValue(for: ["target"], in: arguments)
        let app = stringValue(for: ["app", "application", "windowApp"], in: arguments)

        let normalizedMode: String
        if let rawMode, !rawMode.isEmpty {
            normalizedMode = rawMode
        } else if let target, ["full", "window", "region"].contains(target.lowercased()) {
            normalizedMode = target.lowercased()
        } else if app != nil || (target != nil && !["full", "window", "region"].contains((target ?? "").lowercased())) {
            normalizedMode = "window"
        } else {
            normalizedMode = "full"
        }

        switch normalizedMode {
        case "full", "screen", "fullscreen", "entire":
            return (.full, "")

        case "window", "app":
            let appName = app ?? inferredWindowTarget(fromTarget: target) ?? frontmostExternalAppName()
            guard let appName, !appName.isEmpty else {
                return (nil, "Window capture requires an app name (`app: \"Safari\"`).")
            }
            return (.window(appName: appName), "")

        case "region", "rect", "rectangle", "area":
            guard
                let x = numberValue(arguments["x"]),
                let y = numberValue(arguments["y"]),
                let width = numberValue(arguments["width"]),
                let height = numberValue(arguments["height"]),
                width > 1,
                height > 1
            else {
                return (nil, "Region capture requires numeric `x`, `y`, `width`, and `height` values.")
            }
            return (.region(CGRect(x: x, y: y, width: width, height: height)), "")

        default:
            if let target, !target.isEmpty {
                return (.window(appName: target), "")
            }
            return (nil, "Unsupported mode '\(normalizedMode)'. Use `full`, `window`, or `region`.")
        }
    }

    private func resolvedPrompt(from arguments: [String: Any], mode: CaptureMode) -> String {
        if let raw = stringValue(for: ["prompt", "instruction"], in: arguments) {
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        switch mode {
        case .full:
            return VisionAnalyzer.PromptTemplate.describeScreen
        case .window:
            return "Describe what is visible in this app window. Include actionable UI elements and any key text."
        case .region:
            return "Describe this selected screen region and identify important controls, labels, and text."
        }
    }

    private func ensureScreenRecordingPermission() async -> Bool {
        await MainActor.run {
            if CGPreflightScreenCaptureAccess() {
                return true
            }
            _ = CGRequestScreenCaptureAccess()
            return CGPreflightScreenCaptureAccess()
        }
    }

    private func captureImage(
        screenBounds: CGRect,
        listOption: CGWindowListOption,
        windowID: CGWindowID
    ) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            screenBounds,
            listOption,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            return nil
        }

        let raw = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return Self.resizeIfNeeded(raw, maxSize: Self.maxResolution)
    }

    private func frontmostExternalAppName() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return nil
        }
        return app.localizedName
    }

    private func inferredWindowTarget(fromTarget target: String?) -> String? {
        guard let target else { return nil }
        let cleaned = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let lowered = cleaned.lowercased()
        if ["full", "window", "region"].contains(lowered) {
            return nil
        }
        return cleaned
    }

    private func windowID(for appName: String) -> CGWindowID? {
        let normalizedApp = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedApp.isEmpty else { return nil }

        let matchingPids = Set(NSWorkspace.shared.runningApplications.compactMap { app -> pid_t? in
            guard !app.isTerminated else { return nil }
            let name = (app.localizedName ?? "").lowercased()
            let bundleID = (app.bundleIdentifier ?? "").lowercased()
            if name == normalizedApp || name.contains(normalizedApp) || normalizedApp.contains(name) || bundleID.contains(normalizedApp) {
                return app.processIdentifier
            }
            return nil
        })

        guard
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else {
            return nil
        }

        var best: (id: CGWindowID, area: CGFloat)?

        for window in windows {
            let ownerName = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let ownerPid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1

            if layer != 0 || alpha <= 0.01 {
                continue
            }

            let ownerMatches = matchingPids.contains(ownerPid)
                || ownerName == normalizedApp
                || ownerName.contains(normalizedApp)
                || normalizedApp.contains(ownerName)
            if !ownerMatches {
                continue
            }

            guard
                let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                bounds.width > 1,
                bounds.height > 1
            else {
                continue
            }

            guard let windowNumber = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value else {
                continue
            }

            let area = bounds.width * bounds.height
            if best == nil || area > best!.area {
                best = (id: CGWindowID(windowNumber), area: area)
            }
        }

        return best?.id
    }

    private func clippedToAvailableDisplays(_ rect: CGRect) -> CGRect {
        let allDisplays = NSScreen.screens
            .map(\.frame)
            .reduce(CGRect.null) { partial, frame in
                partial.union(frame)
            }
        guard !allDisplays.isNull else { return .null }
        return rect.intersection(allDisplays)
    }

    private func stringValue(for keys: [String], in arguments: [String: Any]) -> String? {
        for key in keys {
            if let value = arguments[key] as? String {
                return value
            }
        }
        return nil
    }

    private func numberValue(_ value: Any?) -> CGFloat? {
        switch value {
        case let intValue as Int:
            return CGFloat(intValue)
        case let doubleValue as Double:
            return CGFloat(doubleValue)
        case let number as NSNumber:
            return CGFloat(number.doubleValue)
        case let string as String:
            guard let parsed = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
            return CGFloat(parsed)
        default:
            return nil
        }
    }

    private func markCaptureActivity(started: Bool) {
        activityLock.lock()
        let wasActive = activeCaptureCount > 0
        if started {
            activeCaptureCount += 1
        } else {
            activeCaptureCount = max(0, activeCaptureCount - 1)
        }
        let isActive = activeCaptureCount > 0
        activityLock.unlock()

        guard wasActive != isActive else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.activityDidChangeNotification,
                object: nil,
                userInfo: [Self.activityStateUserInfoKey: isActive]
            )
        }
    }

    // MARK: - Image Helpers

    static func resizeIfNeeded(_ image: NSImage, maxSize: CGSize) -> NSImage {
        let current = image.size
        guard current.width > 0, current.height > 0 else { return image }

        let scale = min(
            maxSize.width / current.width,
            maxSize.height / current.height,
            1
        )
        guard scale < 1 else { return image }

        let targetSize = NSSize(
            width: floor(current.width * scale),
            height: floor(current.height * scale)
        )

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: current),
            operation: .copy,
            fraction: 1
        )
        resized.unlockFocus()
        return resized
    }

    /// JPEG encode helper used by both ScreenCapture and VisionAnalyzer.
    static func jpegData(from image: NSImage, quality: CGFloat, maxBytes: Int = 400_000) -> Data? {
        let resized = resizeIfNeeded(image, maxSize: maxResolution)
        guard
            let tiff = resized.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        var compression = quality
        var best: Data?

        while compression >= 0.4 {
            guard let data = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: compression]
            ) else {
                break
            }

            best = data
            if data.count <= maxBytes {
                return data
            }
            compression -= 0.1
        }

        return best
    }
}
