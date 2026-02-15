import SwiftUI

enum ResultStyle {
    case success
    case error

    var textColor: Color {
        switch self {
        case .success:
            return Color(nsColor: .systemGreen)
        case .error:
            return Color(nsColor: .systemRed)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .success:
            return Color(nsColor: .systemGreen).opacity(0.10)
        case .error:
            return Color(nsColor: .systemRed).opacity(0.10)
        }
    }

    var borderColor: Color {
        switch self {
        case .success:
            return Color(nsColor: .systemGreen).opacity(0.45)
        case .error:
            return Color(nsColor: .systemRed).opacity(0.45)
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
            Text(style == .success ? "Result" : "Error")
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.textColor)

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
