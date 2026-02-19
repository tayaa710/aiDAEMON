import AVFoundation
import SwiftUI

private enum SettingsTab: String {
    case general
    case cloud
    case integrations
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

            IntegrationsSettingsTab()
                .tabItem { Label("Integrations", systemImage: "puzzlepiece.extension") }
                .tag(SettingsTab.integrations)

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

    /// Autonomy level — stored as Int in UserDefaults "autonomy.level".
    /// 0 = confirm everything, 1 = auto-execute safe+caution (default), 2 = fully autonomous in approved scopes.
    @AppStorage("autonomy.level")
    private var autonomyLevel: Int = AutonomyLevel.autoExecute.rawValue

    @AppStorage(SpeechInput.voiceEnabledDefaultsKey)
    private var voiceInputEnabled: Bool = true

    @AppStorage(SpeechOutput.voiceModeDefaultsKey)
    private var voiceModeEnabled: Bool = false

    @AppStorage(SpeechOutput.voiceEnabledDefaultsKey)
    private var voiceOutputEnabled: Bool = false

    @AppStorage(SpeechInput.useCloudSTTDefaultsKey)
    private var useCloudSTT: Bool = false

    @AppStorage(SpeechOutput.useCloudTTSDefaultsKey)
    private var useCloudTTS: Bool = false

    @AppStorage(SpeechInput.pushToTalkStyleDefaultsKey)
    private var pushToTalkStyleRawValue: String = VoicePushToTalkStyle.holdHotkey.rawValue

    @AppStorage(SpeechInput.silenceTimeoutDefaultsKey)
    private var silenceTimeoutSeconds: Double = 2.0

    @AppStorage(SpeechOutput.voiceIdentifierDefaultsKey)
    private var selectedVoiceIdentifier: String = ""

    @AppStorage(SpeechOutput.speechRateDefaultsKey)
    private var voiceRateMultiplier: Double = 1.0

    @State private var deepgramAPIKeyInput: String = ""
    @State private var hasDeepgramAPIKey: Bool = SpeechOutput.hasDeepgramKey
    @State private var availableVoices: [SpeechVoiceOption] = []

    var body: some View {
        List {
            Section("Hotkey") {
                HStack {
                    Text("Activation Shortcut")
                    Spacer()
                    Text("Cmd+Shift+Space")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text("Quick press toggles the window. In voice mode, hold this shortcut to talk.")
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

            Section("Autonomy") {
                Picker("Action Mode", selection: $autonomyLevel) {
                    Text("Level 0 — Confirm Everything")
                        .tag(AutonomyLevel.confirmAll.rawValue)
                    Text("Level 1 — Auto-Execute (Recommended)")
                        .tag(AutonomyLevel.autoExecute.rawValue)
                    Text("Level 2 — Fully Autonomous (Coming Soon)")
                        .tag(AutonomyLevel.fullyAuto.rawValue)
                }

                switch AutonomyLevel(rawValue: autonomyLevel) ?? .autoExecute {
                case .confirmAll:
                    Text("Level 0: Every action requires your approval before executing. Most careful, most interruptions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .autoExecute:
                    Text("Level 1 (default): Safe and caution-level actions auto-execute. Only dangerous actions (delete files, terminal commands) require your approval.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .fullyAuto:
                    Text("Level 2: Fully autonomous within user-approved scopes. Coming in a future milestone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("Destructive actions (delete files, send email, kill processes, terminal) ALWAYS require confirmation, regardless of level.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Section("Voice Mode") {
                Toggle("Enable full voice mode (input + output)", isOn: voiceModeSelection)

                Text("You can also toggle this instantly from the floating window header.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Voice Input") {
                Toggle("Enable voice input", isOn: $voiceInputEnabled)

                Picker("Push-to-talk style", selection: pushToTalkStyleSelection) {
                    ForEach(VoicePushToTalkStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .disabled(!voiceInputEnabled)

                Toggle("Use cloud STT (Deepgram)", isOn: $useCloudSTT)
                    .disabled(!voiceInputEnabled)

                HStack {
                    Text("Auto-stop after silence")
                    Spacer()
                    Text(String(format: "%.1f sec", silenceTimeoutSeconds))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $silenceTimeoutSeconds, in: 1.0...5.0, step: 0.5)
                    .disabled(!voiceInputEnabled)

                if useCloudSTT {
                    HStack {
                        Text("Deepgram API key")
                        Spacer()
                        if hasDeepgramAPIKey {
                            Label("Configured", systemImage: "key.fill")
                                .foregroundStyle(.green)
                                .font(.footnote.weight(.medium))
                        } else {
                            Label("Not configured", systemImage: "key.slash")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }

                    SecureField(
                        hasDeepgramAPIKey ? "Key saved — paste a new key to replace" : "Paste Deepgram API key",
                        text: $deepgramAPIKeyInput
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Button("Save Key") {
                            saveDeepgramKey()
                        }
                        .disabled(deepgramAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Remove Key", role: .destructive) {
                            removeDeepgramKey()
                        }
                        .disabled(!hasDeepgramAPIKey)
                    }

                    Text("Deepgram STT key storage is enabled. Live cloud STT runtime is coming soon; voice input currently runs on-device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("On-device speech recognition works offline and keeps audio local.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Voice Output") {
                Toggle("Enable voice output", isOn: $voiceOutputEnabled)

                Picker("Voice", selection: $selectedVoiceIdentifier) {
                    Text("System Default").tag("")
                    ForEach(availableVoices) { voice in
                        Text(voice.displayName).tag(voice.identifier)
                    }
                }
                .disabled(!voiceOutputEnabled)

                HStack {
                    Text("Speech rate")
                    Spacer()
                    Text(String(format: "%.1fx", voiceRateMultiplier))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $voiceRateMultiplier, in: 0.5...1.5, step: 0.1)
                    .disabled(!voiceOutputEnabled)

                Toggle("Use cloud TTS (Deepgram)", isOn: $useCloudTTS)
                    .disabled(!voiceOutputEnabled)

                if useCloudTTS {
                    HStack {
                        Text("Deepgram API key")
                        Spacer()
                        if hasDeepgramAPIKey {
                            Label("Configured", systemImage: "key.fill")
                                .foregroundStyle(.green)
                                .font(.footnote.weight(.medium))
                        } else {
                            Label("Not configured", systemImage: "key.slash")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }

                    SecureField(
                        hasDeepgramAPIKey ? "Key saved — paste a new key to replace" : "Paste Deepgram API key",
                        text: $deepgramAPIKeyInput
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Button("Save Key") {
                            saveDeepgramKey()
                        }
                        .disabled(deepgramAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Remove Key", role: .destructive) {
                            removeDeepgramKey()
                        }
                        .disabled(!hasDeepgramAPIKey)
                    }

                    Text("Deepgram TTS key storage is enabled. Live cloud TTS runtime is coming soon; voice output currently runs on-device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("On-device speech synthesis works offline and speaks assistant replies aloud.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset)
        .onAppear {
            if UserDefaults.standard.object(forKey: SpeechOutput.voiceModeDefaultsKey) == nil {
                SpeechOutput.refreshVoiceModeFlagFromCurrentSettings()
            }
            voiceModeEnabled = SpeechOutput.voiceModeEnabled
            voiceRateMultiplier = SpeechOutput.speechRateMultiplier
            refreshDeepgramKeyStatus()
            refreshAvailableVoices()
        }
        .onChange(of: voiceInputEnabled) { _ in
            syncVoiceModeState()
        }
        .onChange(of: voiceOutputEnabled) { _ in
            syncVoiceModeState()
        }
    }

    private var themeSelection: Binding<ThemePreference> {
        Binding {
            ThemePreference(rawValue: themePreferenceRawValue) ?? .system
        } set: { newValue in
            themePreferenceRawValue = newValue.rawValue
        }
    }

    private var pushToTalkStyleSelection: Binding<VoicePushToTalkStyle> {
        Binding {
            VoicePushToTalkStyle(rawValue: pushToTalkStyleRawValue) ?? .holdHotkey
        } set: { newValue in
            pushToTalkStyleRawValue = newValue.rawValue
        }
    }

    private var voiceModeSelection: Binding<Bool> {
        Binding {
            voiceModeEnabled
        } set: { newValue in
            voiceModeEnabled = newValue
            SpeechOutput.setVoiceModeEnabled(newValue)
        }
    }

    private func syncVoiceModeState() {
        SpeechOutput.refreshVoiceModeFlagFromCurrentSettings()
        voiceModeEnabled = SpeechOutput.voiceModeEnabled
    }

    private func refreshAvailableVoices() {
        availableVoices = SpeechOutput.availableVoices()
        if !selectedVoiceIdentifier.isEmpty,
           !availableVoices.contains(where: { $0.identifier == selectedVoiceIdentifier }) {
            selectedVoiceIdentifier = ""
        }
    }

    private func refreshDeepgramKeyStatus() {
        hasDeepgramAPIKey = SpeechOutput.hasDeepgramKey
    }

    private func saveDeepgramKey() {
        guard SpeechOutput.saveDeepgramKey(deepgramAPIKeyInput) else { return }
        deepgramAPIKeyInput = ""
        refreshDeepgramKeyStatus()
    }

    private func removeDeepgramKey() {
        _ = SpeechOutput.deleteDeepgramKey()
        deepgramAPIKeyInput = ""
        refreshDeepgramKeyStatus()
    }
}

// MARK: - Cloud Settings Tab

private struct CloudSettingsTab: View {

    // Routing mode (Auto / Always Local / Always Cloud)
    @AppStorage("model.routingMode")
    private var routingModeRawValue: String = RoutingMode.auto.rawValue

    // Provider choice (non-secret — safe in UserDefaults).
    // Default is Anthropic — the primary cloud brain.
    @AppStorage("cloud.provider")
    private var providerRawValue: String = CloudProviderType.anthropic.rawValue

    // Anthropic model selection (non-secret — model name only)
    @AppStorage("cloud.anthropicModel")
    private var anthropicModelRawValue: String = AnthropicModel.sonnet.rawValue

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
        List {
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

            // ── Anthropic Model (only shown when .anthropic is selected) ──────────
            if selectedProvider == .anthropic {
                Section("Anthropic Model") {
                    Picker("Model", selection: $anthropicModelRawValue) {
                        ForEach(AnthropicModel.allCases, id: \.rawValue) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }
                    Text("Sonnet 4.5 is recommended for most tasks (fast and capable). Opus 4.6 is for maximum capability on complex multi-step plans.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
        .listStyle(.inset)
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
        case .anthropic:
            Link("Get an API key at console.anthropic.com →",
                 destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                .font(.footnote)
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
            do {
                var testParams = GenerationParams()
                testParams.maxTokens = 16
                // Anthropic uses its own provider class (different API format from OpenAI)
                if selectedProvider == .anthropic {
                    let provider = AnthropicModelProvider()
                    _ = try await provider.generate(
                        prompt: "Reply with exactly one word: OK",
                        params: testParams,
                        onToken: nil
                    )
                } else {
                    let provider = CloudModelProvider(providerType: selectedProvider)
                    _ = try await provider.generate(
                        prompt: "Reply with exactly one word: OK",
                        params: testParams,
                        onToken: nil
                    )
                }
                await MainActor.run {
                    testResult = .success
                    isTesting = false
                }
            } catch {
                let message = (error as? AnthropicModelError)?.errorDescription
                    ?? (error as? CloudModelError)?.errorDescription
                    ?? error.localizedDescription
                await MainActor.run {
                    testResult = .failure(message)
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Integrations Settings Tab

private struct IntegrationsSettingsTab: View {
    @ObservedObject private var manager = MCPServerManager.shared
    @State private var showingAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("MCP Servers")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)

            if manager.servers.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No MCP servers configured")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("MCP servers extend aiDAEMON with community tools — GitHub, Google Calendar, Notion, Brave Search, and 2,800+ more.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 350)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Server list
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.servers) { server in
                            MCPServerRow(
                                server: server,
                                status: manager.statuses[server.id] ?? .disconnected,
                                toolNames: manager.serverToolNames[server.id] ?? []
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMCPServerSheet()
        }
    }
}

private struct MCPServerRow: View {
    let server: MCPServerConfig
    let status: MCPServerStatus
    let toolNames: [String]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(server.name)
                        .font(.headline)
                    Text(status.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Connect/Disconnect
                if status.isConnected {
                    Button("Disconnect") {
                        MCPServerManager.shared.disconnect(serverId: server.id)
                    }
                    .controlSize(.small)
                } else if case .connecting = status {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button("Connect") {
                        Task { await MCPServerManager.shared.connect(serverId: server.id) }
                    }
                    .controlSize(.small)
                }

                // Expand tools
                if status.isConnected && !toolNames.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                // Remove
                Button(role: .destructive) {
                    MCPServerManager.shared.removeServer(id: server.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }

            // Expanded tool list
            if isExpanded && status.isConnected {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(toolNames, id: \.self) { name in
                        HStack(spacing: 4) {
                            Image(systemName: "wrench")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 2)
            }

            // Transport info
            HStack(spacing: 4) {
                Image(systemName: server.transport == .stdio ? "terminal" : "globe")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                if let cmd = server.command {
                    Text("\(cmd) \((server.arguments ?? []).joined(separator: " "))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let url = server.url {
                    Text(url)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting: return .yellow
        case .error: return .red
        case .disconnected: return .gray
        }
    }
}

private struct AddMCPServerSheet: View {
    @State private var name = ""
    @State private var transportType: MCPTransportType = .stdio
    @State private var command = ""
    @State private var arguments = ""
    @State private var url = ""
    @State private var envVarName = ""
    @State private var envVarValue = ""
    @State private var envVars: [(name: String, saved: Bool)] = []
    @State private var serverIdForEnv: UUID = UUID()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add MCP Server")
                .font(.title3.weight(.semibold))

            // Quick presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Add")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(MCPPreset.allCases) { preset in
                        Button {
                            addPreset(preset)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: preset.icon)
                                    .font(.title3)
                                Text(preset.displayName)
                                    .font(.caption)
                            }
                            .frame(width: 90, height: 60)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Divider()

            // Manual configuration
            VStack(alignment: .leading, spacing: 10) {
                Text("Custom Server")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Server Name", text: $name)

                Picker("Transport", selection: $transportType) {
                    ForEach(MCPTransportType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                if transportType == .stdio {
                    TextField("Command (e.g., npx)", text: $command)
                    TextField("Arguments (e.g., -y @modelcontextprotocol/server-filesystem /path)", text: $arguments)
                        .font(.system(size: 12, design: .monospaced))
                } else {
                    TextField("URL (https://...)", text: $url)
                        .font(.system(size: 12, design: .monospaced))
                }

                // Environment variables
                VStack(alignment: .leading, spacing: 4) {
                    Text("Environment Variables (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        TextField("Variable name", text: $envVarName)
                            .frame(width: 180)
                        SecureField("Value", text: $envVarValue)
                        Button("Add") {
                            addEnvVar()
                        }
                        .disabled(envVarName.isEmpty || envVarValue.isEmpty)
                        .controlSize(.small)
                    }
                    ForEach(envVars, id: \.name) { env in
                        HStack {
                            Text(env.name)
                                .font(.caption.monospaced())
                            Text(env.saved ? "(saved to Keychain)" : "")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Spacer()
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Server") {
                    addCustomServer()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480, height: 480)
    }

    private func addPreset(_ preset: MCPPreset) {
        let config = preset.makeConfig()
        if let keys = config.environmentKeys, !keys.isEmpty {
            // For presets with env vars, populate the custom form so user can enter keys.
            name = config.name
            command = config.command ?? ""
            arguments = (config.arguments ?? []).joined(separator: " ")
            transportType = .stdio
            serverIdForEnv = config.id
            for key in keys {
                envVars.append((name: key, saved: false))
            }
        } else {
            MCPServerManager.shared.addServer(config)
            dismiss()
        }
    }

    private func addEnvVar() {
        let trimmedName = envVarName.trimmingCharacters(in: .whitespaces)
        let trimmedValue = envVarValue.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedValue.isEmpty else { return }

        MCPServerManager.saveEnvironmentVariable(serverId: serverIdForEnv, name: trimmedName, value: trimmedValue)
        envVars.append((name: trimmedName, saved: true))
        envVarName = ""
        envVarValue = ""
    }

    private func addCustomServer() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let config: MCPServerConfig
        let envKeys = envVars.map { $0.name }

        switch transportType {
        case .stdio:
            let args = arguments
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: " ")
                .filter { !$0.isEmpty }
            config = MCPServerConfig(
                id: serverIdForEnv,
                name: trimmedName,
                transport: .stdio,
                command: command.trimmingCharacters(in: .whitespaces),
                arguments: args.isEmpty ? nil : args,
                environmentKeys: envKeys.isEmpty ? nil : envKeys,
                enabled: true
            )
        case .http:
            config = MCPServerConfig(
                id: serverIdForEnv,
                name: trimmedName,
                transport: .http,
                url: url.trimmingCharacters(in: .whitespaces),
                environmentKeys: envKeys.isEmpty ? nil : envKeys,
                enabled: true
            )
        }

        MCPServerManager.shared.addServer(config)
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
