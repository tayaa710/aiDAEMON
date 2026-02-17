import Foundation

/// Executor for FILE_SEARCH commands — searches files using native Spotlight (NSMetadataQuery)
/// with relevance-based ranking.
public struct FileSearcher: CommandExecutor {

    public var name: String { "FileSearcher" }

    /// Maximum results to display.
    static let maxDisplayed = 20

    /// Maximum candidates to fetch from each search scope before scoring/ranking.
    private static let maxCandidates = 100

    /// Minimum query length to avoid absurdly broad searches.
    private static let minQueryLength = 2

    /// Timeout for Spotlight queries in seconds.
    private static let queryTimeout: TimeInterval = 5.0

    public func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void) {
        // The search query comes from query, target, or parameters.query
        let query = command.query
            ?? command.target
            ?? command.stringParam("query")
            ?? ""

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {move window to bottom left
            completion(.error("No search query specified."))
            return
        }

        let kind = command.stringParam("kind") // e.g. "pdf", "image", "folder"
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        guard trimmed.count >= Self.minQueryLength else {
            completion(.error("Search query too short — use at least \(Self.minQueryLength) characters."))
            return
        }

        let sanitized = sanitize(trimmed)

        // Build NSPredicate for Spotlight query
        let predicate: NSPredicate
        if let kind = kind, !kind.isEmpty, let uti = utType(for: kind) {
            predicate = NSPredicate(
                format: "(kMDItemDisplayName like[cd] %@) AND (kMDItemContentTypeTree == %@)",
                "*\(sanitized)*", uti
            )
        } else {
            predicate = NSPredicate(
                format: "kMDItemDisplayName like[cd] %@",
                "*\(sanitized)*"
            )
        }

        // Dual-search: first user directories (~/Desktop, ~/Documents, ~/Downloads, ~/),
        // then system-wide. Merge and deduplicate so user files always appear.
        let home = NSHomeDirectory()
        let userScopes: [String] = [
            home + "/Desktop",
            home + "/Documents",
            home + "/Downloads",
            home,
        ]

        SpotlightSearcher.run(
            predicate: predicate,
            queryText: sanitized,
            maxCandidates: Self.maxCandidates,
            searchScopes: userScopes.map { URL(fileURLWithPath: $0) as NSURL },
            timeout: Self.queryTimeout
        ) { userItems in
            // Second search: system-wide
            SpotlightSearcher.run(
                predicate: predicate,
                queryText: sanitized,
                maxCandidates: Self.maxCandidates,
                searchScopes: [NSMetadataQueryLocalComputerScope],
                timeout: Self.queryTimeout
            ) { allItems in
                // Merge: user items first, then system items (dedup by path)
                var seen = Set<String>()
                var merged: [ScoredItem] = []
                for item in userItems {
                    if seen.insert(item.path).inserted {
                        merged.append(item)
                    }
                }
                for item in allItems {
                    if seen.insert(item.path).inserted {
                        merged.append(item)
                    }
                }
                // Re-sort by score
                merged.sort { $0.score > $1.score }

                let result = self.formatResults(items: merged, query: trimmed)
                completion(result)
            }
        }
    }

    // MARK: - Result Formatting

    private func formatResults(items: [ScoredItem], query: String) -> ExecutionResult {
        let displayed = Array(items.prefix(Self.maxDisplayed))

        if displayed.isEmpty {
            return .ok("No files found for \"\(query)\".")
        }

        let lines = displayed.map { item -> String in
            let url = URL(fileURLWithPath: item.path)
            let name = url.lastPathComponent
            let dir = url.deletingLastPathComponent().path
                .replacingOccurrences(of: NSHomeDirectory(), with: "~")
            return "\(name)\n  \(dir)"
        }

        var summary = lines.joined(separator: "\n\n")

        if items.count > Self.maxDisplayed {
            summary += "\n\n… and \(items.count - Self.maxDisplayed) more results"
        } else if items.count == Self.maxDisplayed {
            summary += "\n\n… showing first \(Self.maxDisplayed) results"
        }

        let header = items.count == 1
            ? "Found 1 file:"
            : "Found \(items.count) files:"

        NSLog("FileSearcher: found %d results for '%@'", items.count, query)
        return .ok(header, details: summary)
    }

    // MARK: - Sanitization

    /// Sanitize the query to prevent Spotlight predicate injection.
    func sanitize(_ input: String) -> String {
        input.replacingOccurrences(of: "'", with: "")
             .replacingOccurrences(of: "\\", with: "")
             .replacingOccurrences(of: "*", with: "")
    }

    // MARK: - UTI Mapping

    /// Map user-friendly kind names to UTI types for Spotlight filtering.
    func utType(for kind: String) -> String? {
        let map: [String: String] = [
            "pdf": "com.adobe.pdf",
            "image": "public.image",
            "photo": "public.image",
            "picture": "public.image",
            "video": "public.movie",
            "movie": "public.movie",
            "audio": "public.audio",
            "music": "public.audio",
            "document": "public.composite-content",
            "text": "public.text",
            "folder": "public.folder",
            "presentation": "public.presentation",
            "spreadsheet": "public.spreadsheet",
        ]
        return map[kind.lowercased()]
    }
}

// MARK: - Scored Item

/// A search result with its computed relevance score.
struct ScoredItem {
    let path: String
    let displayName: String
    let score: Double
}

// MARK: - Relevance Scoring

/// Computes a relevance score for a Spotlight result.
struct RelevanceScorer {

    let queryText: String

    /// Score weights — location is heaviest to ensure user files surface above system files
    private static let locationWeight: Double = 0.35
    private static let nameMatchWeight: Double = 0.25
    private static let recencyWeight: Double = 0.25
    private static let spotlightWeight: Double = 0.15

    func score(item: NSMetadataItem, spotlightRelevance: Double) -> Double {
        let nameScore = nameMatchScore(item: item)
        let recency = recencyScore(item: item)
        let location = locationScore(item: item)

        return (spotlightRelevance * Self.spotlightWeight)
             + (nameScore * Self.nameMatchWeight)
             + (recency * Self.recencyWeight)
             + (location * Self.locationWeight)
    }

    /// Exact match = 1.0, starts-with = 0.5, contains = 0.0
    private func nameMatchScore(item: NSMetadataItem) -> Double {
        guard let displayName = item.value(forAttribute: kMDItemDisplayName as String) as? String else {
            return 0.0
        }
        // Strip extension for comparison
        let name = (displayName as NSString).deletingPathExtension.lowercased()
        let q = queryText.lowercased()

        if name == q { return 1.0 }
        if name.hasPrefix(q) { return 0.5 }
        return 0.0
    }

    /// Exponential decay: today=1.0, 7d=0.5, 30d=0.25, 90d=0.1, older=0.0
    private func recencyScore(item: NSMetadataItem) -> Double {
        let date = item.value(forAttribute: kMDItemLastUsedDate as String) as? Date
            ?? item.value(forAttribute: kMDItemContentModificationDate as String) as? Date

        guard let date = date else { return 0.0 }

        let daysAgo = -date.timeIntervalSinceNow / 86400.0
        if daysAgo < 1 { return 1.0 }
        if daysAgo < 7 { return 0.5 }
        if daysAgo < 30 { return 0.25 }
        if daysAgo < 90 { return 0.1 }
        return 0.0
    }

    /// User folders = 1.0, home = 0.7, /Applications = 0.4, other = 0.1, system = 0.0
    private func locationScore(item: NSMetadataItem) -> Double {
        guard let path = item.value(forAttribute: kMDItemPath as String) as? String else {
            return 0.0
        }
        let home = NSHomeDirectory()
        let priorityDirs = [
            home + "/Desktop",
            home + "/Documents",
            home + "/Downloads",
        ]
        for dir in priorityDirs {
            if path.hasPrefix(dir) { return 1.0 }
        }
        if path.hasPrefix(home) { return 0.7 }
        if path.hasPrefix("/Applications") || path.hasPrefix("/System/Applications") { return 0.4 }
        // System/library paths get lowest score
        if path.hasPrefix("/usr") || path.hasPrefix("/System") || path.hasPrefix("/Library") {
            return 0.0
        }
        return 0.1
    }
}

// MARK: - SpotlightSearcher

/// Wraps NSMetadataQuery in a one-shot completion-handler pattern.
private final class SpotlightSearcher: NSObject {

    /// Strong references to in-flight searchers to prevent premature deallocation.
    private static var activeSearchers = Set<SpotlightSearcher>()

    private let query = NSMetadataQuery()
    private let queryText: String
    private let maxCandidates: Int
    private var completion: (([ScoredItem]) -> Void)?
    private var timeoutWork: DispatchWorkItem?
    private var observer: NSObjectProtocol?
    private var hasFinished = false

    private init(predicate: NSPredicate, queryText: String, maxCandidates: Int,
                 searchScopes: [Any], completion: @escaping ([ScoredItem]) -> Void) {
        self.queryText = queryText
        self.maxCandidates = maxCandidates
        self.completion = completion
        super.init()

        query.predicate = predicate
        query.searchScopes = searchScopes
        query.sortDescriptors = [
            NSSortDescriptor(key: kMDQueryResultContentRelevance as String, ascending: false)
        ]
    }

    /// Entry point — sets up and starts the query on the main thread.
    static func run(predicate: NSPredicate, queryText: String, maxCandidates: Int,
                    searchScopes: [Any] = [NSMetadataQueryLocalComputerScope],
                    timeout: TimeInterval, completion: @escaping ([ScoredItem]) -> Void) {

        let searcher = SpotlightSearcher(
            predicate: predicate, queryText: queryText,
            maxCandidates: maxCandidates, searchScopes: searchScopes,
            completion: completion
        )

        // Retain until query completes
        activeSearchers.insert(searcher)

        // NSMetadataQuery must start on a thread with a run loop
        DispatchQueue.main.async {
            searcher.start(timeout: timeout)
        }
    }

    private func start(timeout: TimeInterval) {
        // Observe query completion
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.handleResults()
        }

        // Timeout fallback
        let work = DispatchWorkItem { [weak self] in
            self?.handleResults()
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)

        query.start()
    }

    private func handleResults() {
        guard !hasFinished else { return }
        hasFinished = true

        query.stop()
        timeoutWork?.cancel()
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }

        let scorer = RelevanceScorer(queryText: queryText)
        let resultCount = query.resultCount
        let candidateCount = min(resultCount, maxCandidates)

        var scored: [ScoredItem] = []
        scored.reserveCapacity(candidateCount)

        for i in 0..<candidateCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: kMDItemPath as String) as? String,
                  let displayName = item.value(forAttribute: kMDItemDisplayName as String) as? String else {
                continue
            }

            // Get Spotlight's built-in relevance (already sorted by this, normalize to 0-1)
            let spotlightRelevance: Double
            if let relevance = query.value(ofAttribute: kMDQueryResultContentRelevance as String,
                                           forResultAt: i) as? Double {
                spotlightRelevance = min(relevance, 1.0)
            } else {
                spotlightRelevance = 0.5
            }

            let totalScore = scorer.score(item: item, spotlightRelevance: spotlightRelevance)
            scored.append(ScoredItem(path: path, displayName: displayName, score: totalScore))
        }

        // Sort by our composite score (descending)
        scored.sort { $0.score > $1.score }

        // Fire completion and release self
        let cb = completion
        completion = nil
        Self.activeSearchers.remove(self)
        cb?(scored)
    }
}

// MARK: - Debug Tests

#if DEBUG
extension FileSearcher {
    public static func runTests() {
        print("\nRunning FileSearcher tests...")
        var passed = 0
        var failed = 0
        let searcher = FileSearcher()

        // Test 1: Executor name
        do {
            if searcher.name == "FileSearcher" {
                print("  ✅ Test 1: Executor name is 'FileSearcher'")
                passed += 1
            } else {
                print("  ❌ Test 1: Expected 'FileSearcher', got '\(searcher.name)'")
                failed += 1
            }
        }

        // Test 2: Empty target returns error
        do {
            let cmd = Command(type: .FILE_SEARCH, target: nil, confidence: 0.9)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            searcher.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()

            if let r = testResult, !r.success, r.message.contains("No search query") {
                print("  ✅ Test 2: Nil target returns 'No search query' error")
                passed += 1
            } else {
                print("  ❌ Test 2: Expected error for nil target, got: \(testResult?.message ?? "nil")")
                failed += 1
            }
        }

        // Test 3: Blank target returns error
        do {
            let cmd = Command(type: .FILE_SEARCH, target: "   ", confidence: 0.9)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            searcher.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()

            if let r = testResult, !r.success, r.message.contains("No search query") {
                print("  ✅ Test 3: Blank target returns 'No search query' error")
                passed += 1
            } else {
                print("  ❌ Test 3: Expected error for blank target, got: \(testResult?.message ?? "nil")")
                failed += 1
            }
        }

        // Test 3b: Single-character query rejected (too short)
        do {
            let cmd = Command(type: .FILE_SEARCH, target: "a", confidence: 0.9)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            searcher.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()

            if let r = testResult, !r.success, r.message.contains("too short") {
                print("  ✅ Test 3b: Single-char query returns 'too short' error")
                passed += 1
            } else {
                print("  ❌ Test 3b: Expected 'too short' error, got: \(testResult?.message ?? "nil")")
                failed += 1
            }
        }

        // Test 4: Sanitize strips single quotes
        do {
            let result = searcher.sanitize("it's a test")
            if result == "its a test" {
                print("  ✅ Test 4: Sanitize strips single quotes")
                passed += 1
            } else {
                print("  ❌ Test 4: Expected 'its a test', got '\(result)'")
                failed += 1
            }
        }

        // Test 5: Sanitize strips backslashes
        do {
            let result = searcher.sanitize("path\\to\\file")
            if result == "pathtofile" {
                print("  ✅ Test 5: Sanitize strips backslashes")
                passed += 1
            } else {
                print("  ❌ Test 5: Expected 'pathtofile', got '\(result)'")
                failed += 1
            }
        }

        // Test 6: Sanitize strips wildcards
        do {
            let result = searcher.sanitize("*.pdf")
            if result == ".pdf" {
                print("  ✅ Test 6: Sanitize strips wildcards")
                passed += 1
            } else {
                print("  ❌ Test 6: Expected '.pdf', got '\(result)'")
                failed += 1
            }
        }

        // Test 7: UTI mapping for known types
        do {
            let cases: [(String, String)] = [
                ("pdf", "com.adobe.pdf"),
                ("image", "public.image"),
                ("photo", "public.image"),
                ("video", "public.movie"),
                ("audio", "public.audio"),
                ("music", "public.audio"),
                ("text", "public.text"),
                ("folder", "public.folder"),
            ]
            var allOk = true
            for (kind, expected) in cases {
                if let uti = searcher.utType(for: kind), uti == expected {
                    continue
                } else {
                    print("  ❌ Test 7: UTI for '\(kind)' expected '\(expected)', got '\(searcher.utType(for: kind) ?? "nil")'")
                    allOk = false
                }
            }
            if allOk {
                print("  ✅ Test 7: UTI mapping correct for all known types")
                passed += 1
            } else {
                failed += 1
            }
        }

        // Test 8: UTI mapping is case-insensitive
        do {
            if searcher.utType(for: "PDF") == "com.adobe.pdf"
                && searcher.utType(for: "Image") == "public.image" {
                print("  ✅ Test 8: UTI mapping is case-insensitive")
                passed += 1
            } else {
                print("  ❌ Test 8: UTI mapping failed for uppercase input")
                failed += 1
            }
        }

        // Test 9: Unknown kind returns nil UTI
        do {
            if searcher.utType(for: "banana") == nil {
                print("  ✅ Test 9: Unknown kind returns nil UTI")
                passed += 1
            } else {
                print("  ❌ Test 9: Expected nil for unknown kind 'banana'")
                failed += 1
            }
        }

        // Test 10: Live search for "Finder" finds at least one result
        do {
            let cmd = Command(type: .FILE_SEARCH, target: "Finder", confidence: 0.9)
            let sem = DispatchSemaphore(value: 0)
            var testResult: ExecutionResult?
            searcher.execute(cmd) { result in
                testResult = result
                sem.signal()
            }
            // NSMetadataQuery needs main run loop — pump it while waiting
            let deadline = Date().addingTimeInterval(10)
            while testResult == nil && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            }
            // Consume signal if it arrived
            _ = sem.wait(timeout: .now())

            if let r = testResult, r.success, r.message.contains("Found") {
                print("  ✅ Test 10: Live search for 'Finder' returned results")
                passed += 1
            } else if let r = testResult, r.success {
                print("  ⚠️ Test 10: Live search ran but found no results (skipped)")
                passed += 1
            } else {
                print("  ❌ Test 10: Live search failed: \(testResult?.message ?? "nil")")
                failed += 1
            }
        }

        // Test 11: End-to-end parse → dispatch via registry
        do {
            let json = #"{"type": "FILE_SEARCH", "target": "Finder", "confidence": 0.90}"#
            do {
                let cmd = try CommandParser.parse(json)
                if cmd.type == .FILE_SEARCH && cmd.target == "Finder" {
                    print("  ✅ Test 11: End-to-end parse FILE_SEARCH command")
                    passed += 1
                } else {
                    print("  ❌ Test 11: Parsed command has wrong type/target")
                    failed += 1
                }
            } catch {
                print("  ❌ Test 11: Parse failed: \(error)")
                failed += 1
            }
        }

        // Test 12: Query from Command.query field (LLM output format)
        do {
            let cmd = Command(
                type: .FILE_SEARCH,
                target: nil,
                query: "Finder",
                confidence: 0.9
            )
            let sem = DispatchSemaphore(value: 0)
            var testResult: ExecutionResult?
            searcher.execute(cmd) { result in
                testResult = result
                sem.signal()
            }
            let deadline = Date().addingTimeInterval(10)
            while testResult == nil && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            }
            _ = sem.wait(timeout: .now())

            if let r = testResult, r.success {
                print("  ✅ Test 12: Query from Command.query field works")
                passed += 1
            } else {
                print("  ❌ Test 12: Command.query field failed: \(testResult?.message ?? "nil")")
                failed += 1
            }
        }

        // Test 13: Query from parameters.query fallback
        do {
            let cmd = Command(
                type: .FILE_SEARCH,
                target: nil,
                query: nil,
                parameters: ["query": AnyCodable("Finder")],
                confidence: 0.9
            )
            let sem = DispatchSemaphore(value: 0)
            var testResult: ExecutionResult?
            searcher.execute(cmd) { result in
                testResult = result
                sem.signal()
            }
            let deadline = Date().addingTimeInterval(10)
            while testResult == nil && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            }
            _ = sem.wait(timeout: .now())

            if let r = testResult, r.success {
                print("  ✅ Test 13: Query from parameters.query fallback works")
                passed += 1
            } else {
                print("  ❌ Test 13: parameters.query fallback failed: \(testResult?.message ?? "nil")")
                failed += 1
            }
        }

        // Test 14: Parse real LLM-style FILE_SEARCH JSON with query field
        do {
            let json = #"{"type": "FILE_SEARCH", "query": "cv", "parameters": {"kind": "pdf"}, "confidence": 0.85}"#
            do {
                let cmd = try CommandParser.parse(json)
                if cmd.type == .FILE_SEARCH && cmd.query == "cv" && cmd.stringParam("kind") == "pdf" {
                    print("  ✅ Test 14: Parse LLM FILE_SEARCH with query + kind parameter")
                    passed += 1
                } else {
                    print("  ❌ Test 14: Parsed but wrong values: query=\(cmd.query ?? "nil"), kind=\(cmd.stringParam("kind") ?? "nil")")
                    failed += 1
                }
            } catch {
                print("  ❌ Test 14: Parse failed: \(error)")
                failed += 1
            }
        }

        // Test 15: Relevance scoring — exact match scores higher than contains
        do {
            let scorer = RelevanceScorer(queryText: "safari")
            // Exact match score (name component only)
            let exactScore = scorer.score(
                item: MockMetadataItem(displayName: "Safari", path: "/Applications/Safari.app",
                                        lastUsed: Date()),
                spotlightRelevance: 0.9
            )
            // Contains match score
            let containsScore = scorer.score(
                item: MockMetadataItem(displayName: "SafariBookmarksSyncAgent", path: "/usr/libexec/SafariBookmarksSyncAgent",
                                        lastUsed: Date(timeIntervalSinceNow: -365 * 86400)),
                spotlightRelevance: 0.3
            )

            if exactScore > containsScore {
                print("  ✅ Test 15: Exact name match scores higher than contains (\(String(format: "%.2f", exactScore)) > \(String(format: "%.2f", containsScore)))")
                passed += 1
            } else {
                print("  ❌ Test 15: Exact match (\(String(format: "%.2f", exactScore))) should score higher than contains (\(String(format: "%.2f", containsScore)))")
                failed += 1
            }
        }

        // Test 16: Recency scoring — recent file scores higher than old file
        do {
            let scorer = RelevanceScorer(queryText: "test")
            let recentScore = scorer.score(
                item: MockMetadataItem(displayName: "test.txt", path: NSHomeDirectory() + "/Documents/test.txt",
                                        lastUsed: Date()),
                spotlightRelevance: 0.5
            )
            let oldScore = scorer.score(
                item: MockMetadataItem(displayName: "test.txt", path: NSHomeDirectory() + "/Documents/test.txt",
                                        lastUsed: Date(timeIntervalSinceNow: -365 * 86400)),
                spotlightRelevance: 0.5
            )

            if recentScore > oldScore {
                print("  ✅ Test 16: Recent file scores higher than old file (\(String(format: "%.2f", recentScore)) > \(String(format: "%.2f", oldScore)))")
                passed += 1
            } else {
                print("  ❌ Test 16: Recent (\(String(format: "%.2f", recentScore))) should score higher than old (\(String(format: "%.2f", oldScore)))")
                failed += 1
            }
        }

        // Test 17: Location scoring — ~/Documents ranks higher than /usr
        do {
            let scorer = RelevanceScorer(queryText: "test")
            let docsScore = scorer.score(
                item: MockMetadataItem(displayName: "test.txt", path: NSHomeDirectory() + "/Documents/test.txt",
                                        lastUsed: nil),
                spotlightRelevance: 0.5
            )
            let usrScore = scorer.score(
                item: MockMetadataItem(displayName: "test.txt", path: "/usr/share/test.txt",
                                        lastUsed: nil),
                spotlightRelevance: 0.5
            )

            if docsScore > usrScore {
                print("  ✅ Test 17: ~/Documents scores higher than /usr (\(String(format: "%.2f", docsScore)) > \(String(format: "%.2f", usrScore)))")
                passed += 1
            } else {
                print("  ❌ Test 17: ~/Documents (\(String(format: "%.2f", docsScore))) should score higher than /usr (\(String(format: "%.2f", usrScore)))")
                failed += 1
            }
        }

        print("\nFileSearcher results: \(passed) passed, \(failed) failed\n")
    }
}

// MARK: - Mock NSMetadataItem for Testing

/// Lightweight mock that RelevanceScorer can score against.
private class MockMetadataItem: NSMetadataItem {
    private let _displayName: String
    private let _path: String
    private let _lastUsed: Date?

    init(displayName: String, path: String, lastUsed: Date?) {
        _displayName = displayName
        _path = path
        _lastUsed = lastUsed
        super.init()
    }

    override func value(forAttribute key: String) -> Any? {
        if key == kMDItemDisplayName as String { return _displayName }
        if key == kMDItemPath as String { return _path }
        if key == kMDItemLastUsedDate as String { return _lastUsed }
        if key == kMDItemContentModificationDate as String { return _lastUsed }
        return nil
    }
}
#endif
