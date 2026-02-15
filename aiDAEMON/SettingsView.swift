import SwiftUI

private enum SettingsTab: String {
    case general
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
