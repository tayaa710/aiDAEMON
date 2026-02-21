// TurnMetrics.swift
// aiDAEMON
//
// M046: Lightweight per-turn metrics tracker for orchestrator instrumentation.

import Foundation

/// Tracks metrics for a single orchestrator turn: timing, tool usage, and context lock events.
public final class TurnMetrics {
    public let startTime: Date
    public var endTime: Date?

    public private(set) var totalToolCalls: Int = 0
    public private(set) var axToolCalls: Int = 0
    public private(set) var visionToolCalls: Int = 0
    public private(set) var wrongTargetEvents: Int = 0

    public var success: Bool = true

    public init() {
        startTime = Date()
    }

    public var elapsedSeconds: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    public func finish() {
        endTime = Date()
    }

    // MARK: - Tool Categorization

    /// AX-first tools (instant, free, accurate).
    private static let axToolIDs: Set<String> = [
        "get_ui_state", "ax_action", "ax_find"
    ]

    /// Vision/screenshot tools (slow, expensive fallback).
    private static let visionToolIDs: Set<String> = [
        "screen_capture", "computer_action"
    ]

    /// Record a tool call and categorize it.
    public func recordToolCall(toolId: String) {
        totalToolCalls += 1
        if Self.axToolIDs.contains(toolId) {
            axToolCalls += 1
        } else if Self.visionToolIDs.contains(toolId) {
            visionToolCalls += 1
        }
    }

    /// Record a context lock failure (wrong app frontmost).
    public func recordWrongTarget() {
        wrongTargetEvents += 1
    }

    // MARK: - Summary

    /// Compact one-line summary for display in the chat UI.
    public var summary: String {
        let elapsed = String(format: "%.1fs", elapsedSeconds)
        let toolsDesc: String
        if totalToolCalls == 0 {
            toolsDesc = "0 tools"
        } else {
            toolsDesc = "\(totalToolCalls) tools (\(axToolCalls) AX, \(visionToolCalls) vision)"
        }
        let targetDesc = wrongTargetEvents == 0 ? "no wrong-target" : "\(wrongTargetEvents) wrong-target"
        return "[\(elapsed) | \(toolsDesc) | \(targetDesc)]"
    }
}
