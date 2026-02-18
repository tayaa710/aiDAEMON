import Foundation

// MARK: - RoutingMode

/// User preference for how requests are routed between local and cloud models.
/// Stored in UserDefaults under "model.routingMode".
public enum RoutingMode: String, CaseIterable {
    case auto         = "Auto"
    case alwaysLocal  = "Always Local"
    case alwaysCloud  = "Always Cloud"

    /// The currently selected routing mode (reads from UserDefaults, defaults to .auto).
    public static var current: RoutingMode {
        let stored = UserDefaults.standard.string(forKey: "model.routingMode") ?? ""
        return RoutingMode(rawValue: stored) ?? .auto
    }
}

// MARK: - RoutingDecision

/// The result of a routing decision — which provider to use and why.
public struct RoutingDecision {
    public let provider: any ModelProvider
    public let reason: String

    /// True if the decision selected the cloud provider.
    public var isCloud: Bool {
        provider.providerName.lowercased().contains("cloud")
    }
}

// MARK: - ModelRouter

/// Decides whether to use the local model or cloud model for each request.
///
/// Routing rules (in priority order):
/// 1. If user chose "Always Local" → local
/// 2. If user chose "Always Cloud" → cloud (if available), else local with warning
/// 3. If cloud is unavailable (no API key) → local
/// 4. Auto mode: simple commands → local, complex commands → cloud
///
/// Complexity heuristic (for Auto mode):
/// - Short commands with known single-action words → simple → local
/// - Commands with "and", "then", "after that", multiple verbs → complex → cloud
/// - Long commands (>80 chars) → complex → cloud
/// - Commands referencing screen content or multi-step workflows → complex → cloud
public final class ModelRouter {

    private let localProvider: any ModelProvider
    private let cloudProvider: any ModelProvider

    public init(local: any ModelProvider, cloud: any ModelProvider) {
        self.localProvider = local
        self.cloudProvider = cloud
    }

    /// Decide which provider to use for the given user input.
    public func route(input: String) -> RoutingDecision {
        let mode = RoutingMode.current

        switch mode {
        case .alwaysLocal:
            return RoutingDecision(
                provider: localProvider,
                reason: "User preference: Always Local"
            )

        case .alwaysCloud:
            if cloudProvider.isAvailable {
                return RoutingDecision(
                    provider: cloudProvider,
                    reason: "User preference: Always Cloud"
                )
            } else {
                return RoutingDecision(
                    provider: localProvider,
                    reason: "Cloud unavailable — falling back to local"
                )
            }

        case .auto:
            return autoRoute(input: input)
        }
    }

    /// Returns the fallback provider (the other one) if the primary fails.
    /// Returns nil if no fallback is available.
    public func fallback(for primary: any ModelProvider) -> (any ModelProvider)? {
        if primary.providerName == localProvider.providerName {
            return cloudProvider.isAvailable ? cloudProvider : nil
        } else {
            return localProvider.isAvailable ? localProvider : nil
        }
    }

    // MARK: - Auto Routing

    private func autoRoute(input: String) -> RoutingDecision {
        // If cloud isn't available, always use local
        guard cloudProvider.isAvailable else {
            return RoutingDecision(
                provider: localProvider,
                reason: "Cloud unavailable — using local"
            )
        }

        // If local isn't available, use cloud
        guard localProvider.isAvailable else {
            return RoutingDecision(
                provider: cloudProvider,
                reason: "Local model not loaded — using cloud"
            )
        }

        // Complexity heuristic
        if isComplex(input) {
            return RoutingDecision(
                provider: cloudProvider,
                reason: "Complex request — routed to cloud"
            )
        } else {
            return RoutingDecision(
                provider: localProvider,
                reason: "Simple request — routed to local"
            )
        }
    }

    // MARK: - Complexity Detection

    /// Heuristic to determine if an input is "complex" (benefits from cloud model).
    ///
    /// Simple indicators (local can handle):
    /// - Short input with a single known action verb
    /// - Direct commands: "open X", "find X", "move X", "show X"
    ///
    /// Complex indicators (cloud is better):
    /// - Multiple clauses joined by "and", "then", "after that"
    /// - Multiple verbs suggesting multi-step tasks
    /// - Long inputs (>80 characters) suggesting nuanced requests
    /// - References to screen content, workflows, or planning
    private func isComplex(_ input: String) -> Bool {
        let lowered = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Long inputs are likely complex
        if lowered.count > 80 {
            return true
        }

        // Multi-step connectors
        let multiStepMarkers = [" and then ", " then ", " after that ", " followed by ", " next ", " afterwards "]
        for marker in multiStepMarkers {
            if lowered.contains(marker) {
                return true
            }
        }

        // "and" joining two verb phrases (e.g., "open safari and move it")
        if lowered.contains(" and ") {
            let parts = lowered.components(separatedBy: " and ")
            if parts.count >= 2 && parts.allSatisfy({ containsActionVerb($0) }) {
                return true
            }
        }

        // Screen/vision/workflow keywords
        let complexKeywords = [
            "workflow", "set up", "configure", "schedule", "automate",
            "screen", "what do you see", "look at", "click on", "navigate to",
            "step by step", "help me", "how do i", "explain", "plan"
        ]
        for keyword in complexKeywords {
            if lowered.contains(keyword) {
                return true
            }
        }

        // Multiple verbs in the input suggest multi-step
        let verbCount = countActionVerbs(lowered)
        if verbCount >= 2 {
            return true
        }

        // Default: simple
        return false
    }

    /// Known single-action verbs the local model handles well.
    private static let actionVerbs = [
        "open", "launch", "start", "run",
        "find", "search", "locate", "look for",
        "move", "resize", "close", "minimize", "maximize", "fullscreen",
        "show", "check", "what", "tell", "get",
        "quit", "kill", "stop", "force quit",
        "take", "empty", "lock", "toggle"
    ]

    private func containsActionVerb(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for verb in Self.actionVerbs {
            if trimmed.hasPrefix(verb + " ") || trimmed == verb {
                return true
            }
        }
        return false
    }

    private func countActionVerbs(_ text: String) -> Int {
        var count = 0
        let words = text.split(separator: " ").map(String.init)
        for (i, word) in words.enumerated() {
            // Check single-word verbs
            for verb in Self.actionVerbs {
                let verbWords = verb.split(separator: " ").map(String.init)
                if verbWords.count == 1 && word == verbWords[0] {
                    // Only count if it looks like a verb position (start of clause)
                    if i == 0 || (i > 0 && ["and", "then", ","].contains(words[i - 1])) {
                        count += 1
                    }
                }
            }
        }
        return count
    }
}
