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
        case .success: return "Result"
        case .error: return "Error"
        case .loading: return "Processing"
        }
    }
}

final class ResultsState: ObservableObject {
    @Published var output: String?
    @Published var style: ResultStyle = .success

    var hasResults: Bool {
        guard let output else { return false }
        return !output.isEmpty
    }

    func show(_ output: String, style: ResultStyle) {
        self.output = output
        self.style = style
    }

    func clear() {
        output = nil
        style = .success
    }
}

struct ResultsView: View {
    let output: String
    let style: ResultStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if style == .loading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(style.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.textColor)
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
