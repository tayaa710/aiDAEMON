import SwiftUI

private enum SettingsTab: String {
    case general
    case cloud
    case permissions
    case history
    case about
}

struct SettingsView: View {
    @AppStorage("settings.selectedTab")
    private var selectedTabRawValue: String = SettingsTab.general.rawValue

    var body: some View {
        TabView(selection: selectedTab) {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
                .tag(SettingsTab.general)

            CloudSettingsTab()
                .tabItem { Label("Cloud", systemImage: "cloud") }
                .tag(SettingsTab.cloud)

            PermissionsSettingsTab()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)

            HistorySettingsTab()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(SettingsTab.history)

            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 620, height: 430)
    }

    private var selectedTab: Binding<SettingsTab> {
        Binding {
            SettingsTab(rawValue: selectedTabRawValue) ?? .general
        } set: { newValue in
            selectedTabRawValue = newValue.rawValue
        }
    }
}

private struct GeneralSettingsTab: View {
    private enum ThemePreference: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system:
                return "System"
            case .light:
                return "Light"
            case .dark:
                return "Dark"
            }
        }
    }

    @AppStorage("settings.autoHideWindow")
    private var autoHideWindow: Bool = true

    @AppStorage("settings.useCompactWindow")
    private var useCompactWindow: Bool = true

    @AppStorage("settings.themePreference")
    private var themePreferenceRawValue: String = ThemePreference.system.rawValue

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Current Toggle Shortcut")
                    Spacer()
                    Text("Cmd+Shift+Space")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text("Custom hotkey selection will be added in a future milestone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Customize Hotkey (Coming Soon)") {}
                    .disabled(true)
            }

            Section("Appearance") {
                Picker("Theme", selection: themeSelection) {
                    ForEach(ThemePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .disabled(true)

                Text("Theme support is scaffolded now and will be wired to app styling later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Auto-hide floating window when focus changes", isOn: $autoHideWindow)
                Toggle("Use compact floating window defaults", isOn: $useCompactWindow)

                Text("These preferences persist through UserDefaults for future behavior wiring.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
    }

    private var themeSelection: Binding<ThemePreference> {
        Binding {
            ThemePreference(rawValue: themePreferenceRawValue) ?? .system
        } set: { newValue in
            themePreferenceRawValue = newValue.rawValue
        }
    }
}

// MARK: - Cloud Settings Tab

private struct CloudSettingsTab: View {

    // Routing mode (Auto / Always Local / Always Cloud)
    @AppStorage("model.routingMode")
    private var routingModeRawValue: String = RoutingMode.auto.rawValue

    // Provider choice (non-secret — safe in UserDefaults)
    @AppStorage("cloud.provider")
    private var providerRawValue: String = CloudProviderType.groq.rawValue

    // Custom provider configuration (non-secret)
    @AppStorage("cloud.customEndpoint")
    private var customEndpoint: String = ""

    @AppStorage("cloud.customModel")
    private var customModel: String = ""

    // Local UI state
    @State private var apiKeyInput: String = ""
    @State private var hasKey: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: CloudTestResult? = nil

    private enum CloudTestResult {
        case success
        case failure(String)
    }

    private var selectedProvider: CloudProviderType {
        CloudProviderType(rawValue: providerRawValue) ?? .groq
    }

    var body: some View {
        Form {
            // ── Routing Mode ─────────────────────────────────────────────────────
            Section("Model Routing") {
                Picker("Routing Mode", selection: $routingModeRawValue) {
                    ForEach(RoutingMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }

                switch RoutingMode(rawValue: routingModeRawValue) ?? .auto {
                case .auto:
                    Text("Simple commands use the fast local model. Complex requests use the cloud brain.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .alwaysLocal:
                    Text("All requests use the local model. No network traffic. Complex tasks may produce lower-quality results.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .alwaysCloud:
                    Text("All requests use the cloud model. Requires an API key. Better results but uses network for every request.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Provider ─────────────────────────────────────────────────────────
            Section("Provider") {
                Picker("Cloud Provider", selection: $providerRawValue) {
                    ForEach(CloudProviderType.allCases, id: \.rawValue) { provider in
                        Text(provider.rawValue).tag(provider.rawValue)
                    }
                }
                .onChange(of: providerRawValue) { _ in
                    apiKeyInput = ""
                    testResult = nil
                    refreshKeyStatus()
                    // Rebuild router with the new provider selection
                    LLMManager.shared.rebuildRouter()
                }

                providerHelpLink
            }

            // ── Custom Endpoint (only shown when .custom is selected) ─────────────
            if selectedProvider == .custom {
                Section("Custom Endpoint") {
                    TextField("Endpoint URL (https://...)", text: $customEndpoint)
                    TextField("Model Name", text: $customModel)
                    Text("Must use HTTPS. Compatible with any OpenAI chat-completions API.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // ── API Key ───────────────────────────────────────────────────────────
            Section("API Key") {
                HStack {
                    Text("Status")
                    Spacer()
                    keyStatusLabel
                }

                SecureField(
                    hasKey ? "Key saved — paste a new key to replace" : "Paste your API key here",
                    text: $apiKeyInput
                )

                HStack(spacing: 12) {
                    Button("Save Key") {
                        saveKey()
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Remove Key", role: .destructive) {
                        removeKey()
                    }
                    .disabled(!hasKey)
                }
            }

            // ── Test Connection ───────────────────────────────────────────────────
            Section("Connection") {
                HStack(spacing: 12) {
                    Button(isTesting ? "Testing…" : "Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting || !hasKey)

                    if let result = testResult {
                        testResultLabel(result)
                    }

                    Spacer()
                }

                if !hasKey {
                    Text("Save an API key above, then test the connection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .onAppear { refreshKeyStatus() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var keyStatusLabel: some View {
        if hasKey {
            Label("Configured", systemImage: "key.fill")
                .foregroundStyle(.green)
                .font(.footnote.weight(.medium))
        } else {
            Label("Not configured", systemImage: "key.slash")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private var providerHelpLink: some View {
        switch selectedProvider {
        case .openAI:
            Link("Get an API key at platform.openai.com →",
                 destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(.footnote)
        case .groq:
            Link("Get a free API key at console.groq.com →",
                 destination: URL(string: "https://console.groq.com")!)
                .font(.footnote)
        case .togetherAI:
            Link("Get an API key at api.together.ai →",
                 destination: URL(string: "https://api.together.ai")!)
                .font(.footnote)
        case .custom:
            Text("Enter your HTTPS endpoint URL and model name below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func testResultLabel(_ result: CloudTestResult) -> some View {
        switch result {
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.footnote.weight(.medium))
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.footnote)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func refreshKeyStatus() {
        hasKey = KeychainHelper.load(key: selectedProvider.keychainKey) != nil
    }

    private func saveKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        KeychainHelper.save(key: selectedProvider.keychainKey, value: trimmed)
        apiKeyInput = ""
        testResult = nil
        refreshKeyStatus()
        // Rebuild router so it picks up the new key
        LLMManager.shared.rebuildRouter()
    }

    private func removeKey() {
        KeychainHelper.delete(key: selectedProvider.keychainKey)
        apiKeyInput = ""
        testResult = nil
        refreshKeyStatus()
        // Rebuild router so it knows cloud is no longer available
        LLMManager.shared.rebuildRouter()
    }

    private func testConnection() {
        guard hasKey, !isTesting else { return }
        isTesting = true
        testResult = nil

        Task {
            let provider = CloudModelProvider(providerType: selectedProvider)
            do {
                var testParams = GenerationParams()
                testParams.maxTokens = 16
                _ = try await provider.generate(
                    prompt: "Reply with exactly one word: OK",
                    params: testParams,
                    onToken: nil
                )
                await MainActor.run {
                    testResult = .success
                    isTesting = false
                }
            } catch {
                let message = (error as? CloudModelError)?.errorDescription
                    ?? error.localizedDescription
                await MainActor.run {
                    testResult = .failure(message)
                    isTesting = false
                }
            }
        }
    }
}

private struct PermissionsSettingsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.title2.weight(.semibold))

            Text("Permission checks and grant flows are planned for milestones M025-M030.")
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    PermissionRow(title: "Accessibility", detail: "Status not checked yet")
                    PermissionRow(title: "Automation (Apple Events)", detail: "Status not checked yet")
                    PermissionRow(title: "Full Disk Access", detail: "Not required for MVP")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Current Status (Placeholder)")
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

private struct HistorySettingsTab: View {
    @AppStorage("settings.historyPreviewLimit")
    private var historyPreviewLimit: Int = 50

    @AppStorage("settings.showHistoryTimestamps")
    private var showHistoryTimestamps: Bool = true

    var body: some View {
        Form {
            Section("History Preview") {
                Stepper(value: $historyPreviewLimit, in: 25...500, step: 25) {
                    Text("Items to preview once history ships: \(historyPreviewLimit)")
                }

                Toggle("Show timestamps in history list", isOn: $showHistoryTimestamps)
            }

            Section("Status") {
                Text("Command history storage is planned for milestones M031-M035.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
    }
}

private struct AboutSettingsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("aiDAEMON")
                        .font(.title3.weight(.semibold))
                    Text("Version \(versionDescription)")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Open Source Dependencies")
                .font(.headline)

            Link("LlamaSwift", destination: URL(string: "https://github.com/mattt/llama.swift")!)
            Link("Sparkle", destination: URL(string: "https://github.com/sparkle-project/Sparkle")!)
            Link("KeyboardShortcuts", destination: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
