import SwiftUI

// MARK: - Confirmation State

/// Observable state that drives the confirmation dialog in the floating window.
final class ConfirmationState: ObservableObject {
    @Published var isPresented = false
    @Published var reason = ""
    @Published var level: SafetyLevel = .caution

    /// The command awaiting user approval.
    private(set) var pendingCommand: Command?
    private(set) var pendingUserInput: String?

    /// Callbacks set by the owner (FloatingWindow).
    var onApprove: (() -> Void)?
    var onCancel: (() -> Void)?

    func present(command: Command, userInput: String, reason: String, level: SafetyLevel) {
        self.pendingCommand = command
        self.pendingUserInput = userInput
        self.reason = reason
        self.level = level
        self.isPresented = true
    }

    func dismiss() {
        isPresented = false
        pendingCommand = nil
        pendingUserInput = nil
        onApprove = nil
        onCancel = nil
    }
}

// MARK: - Confirmation Dialog View

/// Inline confirmation view shown in the floating window when a command needs user approval.
struct ConfirmationDialogView: View {
    @ObservedObject var state: ConfirmationState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: state.level == .dangerous ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(headerColor)
                Text(state.level == .dangerous ? "Warning" : "Confirm Action")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(headerColor)
            }

            // Reason text
            Text(state.reason)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            // Buttons
            HStack(spacing: 10) {
                Spacer()

                Button(action: {
                    state.onCancel?()
                }) {
                    Text("Cancel")
                        .frame(minWidth: 60)
                }
                .keyboardShortcut(.cancelAction)

                Button(action: {
                    state.onApprove?()
                }) {
                    Text(state.level == .dangerous ? "Proceed Anyway" : "Approve")
                        .frame(minWidth: 60)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(state.level == .dangerous ? Color(nsColor: .systemRed) : Color.accentColor)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var headerColor: Color {
        switch state.level {
        case .dangerous:
            return Color(nsColor: .systemRed)
        case .caution:
            return Color(nsColor: .systemOrange)
        case .safe:
            return Color(nsColor: .systemGreen)
        }
    }

    private var backgroundColor: Color {
        switch state.level {
        case .dangerous:
            return Color(nsColor: .systemRed).opacity(0.10)
        case .caution:
            return Color(nsColor: .systemOrange).opacity(0.10)
        case .safe:
            return Color(nsColor: .systemGreen).opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch state.level {
        case .dangerous:
            return Color(nsColor: .systemRed).opacity(0.45)
        case .caution:
            return Color(nsColor: .systemOrange).opacity(0.45)
        case .safe:
            return Color(nsColor: .systemGreen).opacity(0.45)
        }
    }
}

// MARK: - Debug Tests

#if DEBUG
extension ConfirmationState {
    public static func runTests() {
        print("\nRunning ConfirmationDialog tests...")
        var passed = 0
        var failed = 0

        // Test 1: Initial state is not presented
        do {
            let state = ConfirmationState()
            if !state.isPresented && state.pendingCommand == nil {
                print("  \u{2705} Test 1: Initial state is not presented")
                passed += 1
            } else {
                print("  \u{274C} Test 1: Initial state should not be presented")
                failed += 1
            }
        }

        // Test 2: Present sets all fields correctly
        do {
            let state = ConfirmationState()
            let cmd = Command(type: .FILE_OP, target: "test.txt",
                              parameters: ["action": AnyCodable("delete")], confidence: 0.9)
            state.present(command: cmd, userInput: "delete test.txt",
                          reason: "This will delete test.txt", level: .caution)
            if state.isPresented &&
               state.pendingCommand?.type == .FILE_OP &&
               state.pendingUserInput == "delete test.txt" &&
               state.reason == "This will delete test.txt" &&
               state.level == .caution {
                print("  \u{2705} Test 2: Present sets all fields correctly")
                passed += 1
            } else {
                print("  \u{274C} Test 2: Present should set all fields")
                failed += 1
            }
        }

        // Test 3: Dismiss clears all fields
        do {
            let state = ConfirmationState()
            let cmd = Command(type: .FILE_OP, target: "test.txt", confidence: 0.9)
            state.present(command: cmd, userInput: "test", reason: "reason", level: .dangerous)
            state.onApprove = {}
            state.onCancel = {}
            state.dismiss()
            if !state.isPresented &&
               state.pendingCommand == nil &&
               state.pendingUserInput == nil &&
               state.onApprove == nil &&
               state.onCancel == nil {
                print("  \u{2705} Test 3: Dismiss clears all fields and callbacks")
                passed += 1
            } else {
                print("  \u{274C} Test 3: Dismiss should clear everything")
                failed += 1
            }
        }

        // Test 4: onApprove callback fires
        do {
            let state = ConfirmationState()
            var approved = false
            state.onApprove = { approved = true }
            state.onApprove?()
            if approved {
                print("  \u{2705} Test 4: onApprove callback fires")
                passed += 1
            } else {
                print("  \u{274C} Test 4: onApprove should fire")
                failed += 1
            }
        }

        // Test 5: onCancel callback fires
        do {
            let state = ConfirmationState()
            var cancelled = false
            state.onCancel = { cancelled = true }
            state.onCancel?()
            if cancelled {
                print("  \u{2705} Test 5: onCancel callback fires")
                passed += 1
            } else {
                print("  \u{274C} Test 5: onCancel should fire")
                failed += 1
            }
        }

        // Test 6: Caution-level command triggers confirmation (integration with validator)
        do {
            let cmd = Command(type: .FILE_OP, target: "~/Desktop/old.txt",
                              parameters: ["action": AnyCodable("delete")], confidence: 0.9)
            let result = CommandValidator.shared.validate(cmd)
            if case .needsConfirmation(_, let reason, let level) = result,
               level == .caution, !reason.isEmpty {
                print("  \u{2705} Test 6: FILE_OP delete triggers caution confirmation")
                passed += 1
            } else {
                print("  \u{274C} Test 6: FILE_OP delete should trigger caution confirmation")
                failed += 1
            }
        }

        // Test 7: Dangerous-level command triggers confirmation (integration with validator)
        do {
            let cmd = Command(type: .PROCESS_MANAGE, target: "Chrome",
                              parameters: ["action": AnyCodable("force_quit")], confidence: 0.9)
            let result = CommandValidator.shared.validate(cmd)
            if case .needsConfirmation(_, let reason, let level) = result,
               level == .dangerous, reason.contains("Chrome") {
                print("  \u{2705} Test 7: PROCESS_MANAGE force_quit triggers dangerous confirmation")
                passed += 1
            } else {
                print("  \u{274C} Test 7: PROCESS_MANAGE force_quit should trigger dangerous confirmation")
                failed += 1
            }
        }

        // Test 8: Safe command does NOT trigger confirmation
        do {
            let cmd = Command(type: .SYSTEM_INFO, target: "battery", confidence: 0.9)
            let result = CommandValidator.shared.validate(cmd)
            if case .valid = result {
                print("  \u{2705} Test 8: Safe command does not trigger confirmation")
                passed += 1
            } else {
                print("  \u{274C} Test 8: SYSTEM_INFO should be .valid (no confirmation)")
                failed += 1
            }
        }

        print("\nConfirmationDialog results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
