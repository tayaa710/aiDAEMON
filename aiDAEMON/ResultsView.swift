import SwiftUI

enum ResultStyle {
    case success
    case error
    case loading

    var textColor: Color {
        switch self {
        case .success:
            return Color(nsColor: .systemGreen)
        case .error:
            return Color(nsColor: .systemRed)
        case .loading:
            return Color(nsColor: .secondaryLabelColor)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .success:
            return Color(nsColor: .systemGreen).opacity(0.10)
        case .error:
            return Color(nsColor: .systemRed).opacity(0.10)
        case .loading:
            return Color(nsColor: .controlBackgroundColor).opacity(0.50)
        }
    }

    var borderColor: Color {
        switch self {
        case .success:
            return Color(nsColor: .systemGreen).opacity(0.45)
        case .error:
            return Color(nsColor: .systemRed).opacity(0.45)
        case .loading:
            return Color(nsColor: .separatorColor).opacity(0.45)
        }
    }

    var label: String {
        switch self {
        case .success: return "Success"
        case .error: return "Error"
        case .loading: return "Processing"
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .loading: return "" // uses ProgressView instead
        }
    }
}

final class ResultsState: ObservableObject {
    @Published var output: String?
    @Published var style: ResultStyle = .success
    @Published var modelBadge: String? = nil
    @Published var isCloudModel: Bool = false

    var hasResults: Bool {
        guard let output else { return false }
        return !output.isEmpty
    }

    func show(_ output: String, style: ResultStyle) {
        self.output = output
        self.style = style
    }

    func showWithBadge(_ output: String, style: ResultStyle, providerName: String, isCloud: Bool) {
        self.output = output
        self.style = style
        self.modelBadge = isCloud ? "Cloud" : "Local"
        self.isCloudModel = isCloud
    }

    func clear() {
        output = nil
        style = .success
        modelBadge = nil
        isCloudModel = false
    }
}

struct ResultsView: View {
    let output: String
    let style: ResultStyle
    var modelBadge: String? = nil
    var isCloudModel: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if style == .loading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: style.icon)
                        .foregroundStyle(style.textColor)
                        .font(.caption)
                }
                Text(style.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.textColor)

                Spacer()

                if let badge = modelBadge, style != .loading {
                    HStack(spacing: 3) {
                        Image(systemName: isCloudModel ? "cloud.fill" : "desktopcomputer")
                            .font(.system(size: 9))
                        Text(badge)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isCloudModel ? .blue : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill((isCloudModel ? Color.blue : Color.secondary).opacity(0.12))
                    )
                }
            }

            ScrollView {
                Text(output)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(style.textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.vertical, 2)
            }
            .frame(maxHeight: 300)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(style.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(style.borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Debug Tests

#if DEBUG
extension ResultsView {
    static func runTests() {
        print("\nRunning ResultsView tests...")
        var passed = 0
        var failed = 0

        // Test 1: Success style has checkmark icon and "Success" label
        do {
            let style = ResultStyle.success
            if style.icon == "checkmark.circle.fill" && style.label == "Success" {
                print("  ✅ Test 1: Success style has checkmark icon and 'Success' label")
                passed += 1
            } else {
                print("  ❌ Test 1: Expected checkmark.circle.fill/Success, got \(style.icon)/\(style.label)")
                failed += 1
            }
        }

        // Test 2: Error style has xmark icon and "Error" label
        do {
            let style = ResultStyle.error
            if style.icon == "xmark.circle.fill" && style.label == "Error" {
                print("  ✅ Test 2: Error style has xmark icon and 'Error' label")
                passed += 1
            } else {
                print("  ❌ Test 2: Expected xmark.circle.fill/Error, got \(style.icon)/\(style.label)")
                failed += 1
            }
        }

        // Test 3: Loading style has "Processing" label
        do {
            let style = ResultStyle.loading
            if style.label == "Processing" {
                print("  ✅ Test 3: Loading style has 'Processing' label")
                passed += 1
            } else {
                print("  ❌ Test 3: Expected Processing, got \(style.label)")
                failed += 1
            }
        }

        // Test 4: ResultsState show/clear lifecycle
        do {
            let state = ResultsState()
            guard !state.hasResults else {
                print("  ❌ Test 4: Initial state should have no results")
                failed += 1
                print("\nResultsView results: \(passed) passed, \(failed) failed\n")
                return
            }

            state.show("Hello", style: .success)
            guard state.hasResults, state.output == "Hello", state.style == .success else {
                print("  ❌ Test 4: show() did not set state correctly")
                failed += 1
                print("\nResultsView results: \(passed) passed, \(failed) failed\n")
                return
            }

            state.clear()
            guard !state.hasResults, state.output == nil else {
                print("  ❌ Test 4: clear() did not reset state")
                failed += 1
                print("\nResultsView results: \(passed) passed, \(failed) failed\n")
                return
            }

            print("  ✅ Test 4: ResultsState show/clear lifecycle works")
            passed += 1
        }

        // Test 5: All styles have distinct text colors
        do {
            let successColor = ResultStyle.success.textColor
            let errorColor = ResultStyle.error.textColor
            let loadingColor = ResultStyle.loading.textColor
            if successColor != errorColor && errorColor != loadingColor {
                print("  ✅ Test 5: All styles have distinct text colors")
                passed += 1
            } else {
                print("  ❌ Test 5: Styles share text colors")
                failed += 1
            }
        }

        // Test 6: Success and error styles have non-empty icons
        do {
            if !ResultStyle.success.icon.isEmpty && !ResultStyle.error.icon.isEmpty
                && ResultStyle.loading.icon.isEmpty {
                print("  ✅ Test 6: Success/error have icons, loading does not")
                passed += 1
            } else {
                print("  ❌ Test 6: Unexpected icon state")
                failed += 1
            }
        }

        print("\nResultsView results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
