import Cocoa

/// Executor for APP_OPEN commands — opens applications by name and URLs in the default browser.
public struct AppLauncher: CommandExecutor {

    public var name: String { "AppLauncher" }

    public func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void) {
        guard let rawTarget = command.target, !rawTarget.isEmpty else {
            completion(.error("No application or URL specified."))
            return
        }

        let target = cleanTarget(rawTarget)

        // Determine if target looks like a URL
        if looksLikeURL(target) {
            openURL(target, completion: completion)
        } else {
            openApplication(target, completion: completion)
        }
    }

    /// Clean up LLM quirks from the target string.
    /// e.g. "safari://" → "safari", "Safari.app" → "Safari"
    private func cleanTarget(_ target: String) -> String {
        var cleaned = target.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip custom URL scheme suffix (e.g. "safari://" → "safari")
        // but preserve http:// and https:// URLs
        if let schemeRange = cleaned.range(of: "://"),
           !cleaned.lowercased().hasPrefix("http://"),
           !cleaned.lowercased().hasPrefix("https://") {
            let beforeScheme = String(cleaned[cleaned.startIndex..<schemeRange.lowerBound])
            let afterScheme = String(cleaned[schemeRange.upperBound...])
            // If nothing meaningful after "://", it was just "appname://"
            if afterScheme.isEmpty {
                cleaned = beforeScheme
            }
        }

        // Strip .app extension if present
        if cleaned.lowercased().hasSuffix(".app") {
            cleaned = String(cleaned.dropLast(4))
        }

        return cleaned
    }

    // MARK: - URL Opening

    private func looksLikeURL(_ target: String) -> Bool {
        let lowered = target.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            return true
        }
        // Bare domain patterns like "youtube.com", "google.com/search"
        let domainPattern = #"^[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}"#
        return target.range(of: domainPattern, options: .regularExpression) != nil
    }

    private func openURL(_ target: String, completion: @escaping (ExecutionResult) -> Void) {
        var urlString = target
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }

        guard let url = URL(string: urlString) else {
            completion(.error("Invalid URL: \(target)"))
            return
        }

        NSWorkspace.shared.open(url)
        NSLog("AppLauncher: opened URL %@", url.absoluteString)
        completion(.ok("Opened \(url.absoluteString)"))
    }

    // MARK: - Application Opening

    private func openApplication(_ target: String, completion: @escaping (ExecutionResult) -> Void) {
        // Try to find the app by name using NSWorkspace
        let workspace = NSWorkspace.shared

        // First try: full URL for application by name
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID(for: target)) {
            workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.error("Failed to open \(target): \(error.localizedDescription)"))
                    } else {
                        NSLog("AppLauncher: opened app via bundle ID – %@", target)
                        completion(.ok("Opened \(target)"))
                    }
                }
            }
            return
        }

        // Second try: search /Applications and /System/Applications by name
        if let appURL = findApplicationURL(named: target) {
            workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.error("Failed to open \(target): \(error.localizedDescription)"))
                    } else {
                        let appName = appURL.deletingPathExtension().lastPathComponent
                        NSLog("AppLauncher: opened app via path – %@", appName)
                        completion(.ok("Opened \(appName)"))
                    }
                }
            }
            return
        }

        completion(.error("Could not find application: \(target)",
                          details: "Make sure the app is installed and try the exact name (e.g. \"Safari\", \"Google Chrome\")."))
    }

    /// Search common application directories for an app matching the given name.
    private func findApplicationURL(named name: String) -> URL? {
        let searchDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/Applications/Utilities",
        ]

        let lowered = name.lowercased()

        for dir in searchDirs {
            let dirURL = URL(fileURLWithPath: dir)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for url in contents where url.pathExtension == "app" {
                let appName = url.deletingPathExtension().lastPathComponent.lowercased()
                if appName == lowered {
                    return url
                }
            }
        }

        // Fuzzy: check if name is contained in app name (e.g. "chrome" matches "Google Chrome")
        for dir in searchDirs {
            let dirURL = URL(fileURLWithPath: dir)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for url in contents where url.pathExtension == "app" {
                let appName = url.deletingPathExtension().lastPathComponent.lowercased()
                if appName.contains(lowered) || lowered.contains(appName) {
                    return url
                }
            }
        }

        return nil
    }

    /// Map common app names to bundle identifiers for faster lookup.
    private func bundleID(for name: String) -> String {
        let lowered = name.lowercased()
        let known: [String: String] = [
            "safari": "com.apple.Safari",
            "finder": "com.apple.finder",
            "mail": "com.apple.mail",
            "messages": "com.apple.MobileSMS",
            "notes": "com.apple.Notes",
            "calendar": "com.apple.iCal",
            "music": "com.apple.Music",
            "photos": "com.apple.Photos",
            "maps": "com.apple.Maps",
            "preview": "com.apple.Preview",
            "terminal": "com.apple.Terminal",
            "textedit": "com.apple.TextEdit",
            "system preferences": "com.apple.systempreferences",
            "system settings": "com.apple.systempreferences",
            "activity monitor": "com.apple.ActivityMonitor",
            "chrome": "com.google.Chrome",
            "google chrome": "com.google.Chrome",
            "firefox": "org.mozilla.firefox",
            "slack": "com.tinyspeck.slackmacgap",
            "spotify": "com.spotify.client",
            "discord": "com.hnc.Discord",
            "vscode": "com.microsoft.VSCode",
            "visual studio code": "com.microsoft.VSCode",
            "iterm": "com.googlecode.iterm2",
            "iterm2": "com.googlecode.iterm2",
            "xcode": "com.apple.dt.Xcode",
        ]
        return known[lowered] ?? "com.apple.\(name)"
    }
}
