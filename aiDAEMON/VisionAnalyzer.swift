import Cocoa
import Foundation

// MARK: - Vision Analyzer Errors

public enum VisionAnalyzerError: Error, LocalizedError {
    case providerUnavailable
    case imageEncodingFailed
    case emptyPrompt
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            return "Vision analysis requires Anthropic Claude. Add an Anthropic API key in Settings → Cloud."
        case .imageEncodingFailed:
            return "Failed to prepare the screenshot for vision analysis."
        case .emptyPrompt:
            return "Vision prompt cannot be empty."
        case .emptyResponse:
            return "Vision analysis returned an empty response."
        }
    }
}

// MARK: - Vision Parse Types

public struct VisionCoordinate: Equatable {
    public let xPercent: Double
    public let yPercent: Double
}

public struct VisionParseResult {
    public let coordinates: [VisionCoordinate]
    public let elementDescriptions: [String]
    public let visibleText: [String]
}

// MARK: - Vision Analyzer

/// Captures Claude vision analysis for screenshots and extracts structured hints
/// (coordinates, UI element descriptions, and visible text snippets).
public final class VisionAnalyzer {

    /// Reusable vision prompt templates for common tasks.
    public enum PromptTemplate {
        public static let describeScreen =
            "Describe what's on this screen. Focus on visible apps, layout, and actionable UI elements."

        public static func findElement(_ label: String) -> String {
            "Find the UI element labeled '\(label)' and estimate its coordinates as percentages of screen width/height."
        }

        public static let foregroundApplication =
            "What application is in the foreground? Return the app name and what it is currently showing."

        public static let readMainContent =
            "Read all visible text in the main content area. Preserve important wording exactly."
    }

    private let anthropicProvider: AnthropicModelProvider
    private let timeoutSeconds: TimeInterval
    private let auditQueue = DispatchQueue(label: "com.aidaemon.visionAudit")

    public init(
        anthropicProvider: AnthropicModelProvider = AnthropicModelProvider(),
        timeoutSeconds: TimeInterval = 15
    ) {
        self.anthropicProvider = anthropicProvider
        self.timeoutSeconds = timeoutSeconds
    }

    /// Analyze a screenshot with Claude vision and return a concise textual summary
    /// plus parseable coordinate/text hints.
    public func analyze(image: NSImage, prompt: String) async throws -> String {
        let cleanedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedPrompt.isEmpty else {
            throw VisionAnalyzerError.emptyPrompt
        }

        if !anthropicProvider.isAvailable {
            anthropicProvider.refreshAvailability()
        }
        guard anthropicProvider.isAvailable else {
            throw VisionAnalyzerError.providerUnavailable
        }

        guard let jpegData = ScreenCapture.jpegData(from: image, quality: 0.75) else {
            throw VisionAnalyzerError.imageEncodingFailed
        }

        let raw = try await anthropicProvider.sendVisionPrompt(
            imageJPEGData: jpegData,
            prompt: cleanedPrompt,
            timeout: timeoutSeconds
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !raw.isEmpty else {
            throw VisionAnalyzerError.emptyResponse
        }

        recordVisionAuditEvent()

        let parsed = parse(raw)
        return format(raw: raw, parsed: parsed)
    }

    /// Extract coordinates, UI element descriptors, and visible text fragments from raw model output.
    public func parse(_ rawText: String) -> VisionParseResult {
        VisionParseResult(
            coordinates: extractCoordinates(from: rawText),
            elementDescriptions: extractElementDescriptions(from: rawText),
            visibleText: extractVisibleText(from: rawText)
        )
    }

    // MARK: - Parsing helpers

    private func extractCoordinates(from text: String) -> [VisionCoordinate] {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        var found: [VisionCoordinate] = []
        var seen = Set<String>()

        // Pattern 1: "45%, 62%"
        let tuplePattern = #"(\d{1,3}(?:\.\d+)?)\s*%\s*[,/]\s*(\d{1,3}(?:\.\d+)?)\s*%"#
        found.append(contentsOf: extractCoordinates(
            in: normalized,
            pattern: tuplePattern,
            xGroup: 1,
            yGroup: 2,
            seen: &seen
        ))

        // Pattern 2: "x: 45% ... y: 62%"
        let axisPattern = #"(?i)x\s*[:=]\s*(\d{1,3}(?:\.\d+)?)\s*%[^%]{0,120}?y\s*[:=]\s*(\d{1,3}(?:\.\d+)?)\s*%"#
        found.append(contentsOf: extractCoordinates(
            in: normalized,
            pattern: axisPattern,
            xGroup: 1,
            yGroup: 2,
            seen: &seen
        ))

        return found
    }

    private func extractCoordinates(
        in text: String,
        pattern: String,
        xGroup: Int,
        yGroup: Int,
        seen: inout Set<String>
    ) -> [VisionCoordinate] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var coordinates: [VisionCoordinate] = []
        for match in matches {
            guard
                match.numberOfRanges > max(xGroup, yGroup),
                let x = Double(nsText.substring(with: match.range(at: xGroup))),
                let y = Double(nsText.substring(with: match.range(at: yGroup)))
            else { continue }

            let boundedX = max(0, min(100, x))
            let boundedY = max(0, min(100, y))
            let key = String(format: "%.2f,%.2f", boundedX, boundedY)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            coordinates.append(VisionCoordinate(xPercent: boundedX, yPercent: boundedY))
        }

        return coordinates
    }

    private func extractElementDescriptions(from text: String) -> [String] {
        let keywords = ["button", "field", "textbox", "input", "menu", "dialog", "link", "dropdown", "tab"]
        let lines = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var results: [String] = []
        for line in lines {
            let lowered = line.lowercased()
            if keywords.contains(where: { lowered.contains($0) }) {
                results.append(line)
            }
        }
        return Array(results.prefix(6))
    }

    private func extractVisibleText(from text: String) -> [String] {
        let lines = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var snippets: [String] = []
        for line in lines {
            let lowered = line.lowercased()
            if lowered.contains("text:") || lowered.contains("visible text") || lowered.hasPrefix("\"") {
                snippets.append(line)
            }
        }
        return Array(snippets.prefix(8))
    }

    private func format(raw: String, parsed: VisionParseResult) -> String {
        var sections: [String] = [raw]

        if !parsed.coordinates.isEmpty {
            let coords = parsed.coordinates.map {
                String(format: "(x: %.1f%%, y: %.1f%%)", $0.xPercent, $0.yPercent)
            }.joined(separator: ", ")
            sections.append("Parsed coordinates: \(coords)")
        }

        if !parsed.elementDescriptions.isEmpty {
            sections.append("Parsed UI elements: \(parsed.elementDescriptions.joined(separator: " | "))")
        }

        if !parsed.visibleText.isEmpty {
            sections.append("Parsed text snippets: \(parsed.visibleText.joined(separator: " | "))")
        }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Audit

    /// Temporary audit trail for vision usage until the full audit system lands (M049).
    /// This records only event metadata, never screenshot content.
    private func recordVisionAuditEvent() {
        auditQueue.async {
            let formatter = ISO8601DateFormatter()
            let timestamp = formatter.string(from: Date())
            let line = "\(timestamp) vision analysis performed\n"
            guard let data = line.data(using: .utf8) else { return }

            do {
                let fileManager = FileManager.default
                let directory = URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Application Support/com.aidaemon", isDirectory: true)
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

                let fileURL = directory.appendingPathComponent("vision-audit.log")
                if !fileManager.fileExists(atPath: fileURL.path) {
                    try data.write(to: fileURL, options: .atomic)
                    return
                }

                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                NSLog("VisionAnalyzer: failed to append audit event: %@", error.localizedDescription)
            }
        }
    }
}
