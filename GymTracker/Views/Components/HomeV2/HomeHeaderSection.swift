import SwiftUI

/// HomeHeaderSection - Greeting & Action Buttons
///
/// **Layout:**
/// ```
/// Guten Morgen,            🔒123  ⚙️
/// Ben!
/// ```
///
/// **Features:**
/// - Time-based Greeting
/// - User Name Display
/// - Locker Number Badge (tappable)
/// - Settings Button
///
/// **Usage:**
/// ```swift
/// HomeHeaderSection(
///     greeting: "Guten Morgen",
///     userName: "Ben",
///     lockerNumber: "123",
///     onShowSettings: { ... },
///     onShowLockerInput: { ... }
/// )
/// ```
struct HomeHeaderSection: View {
    // MARK: - Properties

    let greeting: String
    let userName: String
    let lockerNumber: String?

    var onShowSettings: (() -> Void)?
    var onShowLockerInput: (() -> Void)?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Greeting + Name
            VStack(alignment: .leading, spacing: 2) {
                let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmedName.isEmpty {
                    Text("\(greeting),")
                        .font(.system(size: 32, weight: .semibold, design: .default))
                        .foregroundStyle(HomeV2Theme.primaryText)
                    Text("\(trimmedName)!")
                        .font(.system(size: 32, weight: .semibold, design: .default))
                        .foregroundStyle(HomeV2Theme.primaryText)
                } else {
                    Text(greeting)
                        .font(.system(size: 32, weight: .semibold, design: .default))
                        .foregroundStyle(HomeV2Theme.primaryText)
                }
            }

            Spacer()

            // Locker Number Badge
            if let locker = lockerNumber, !locker.isEmpty {
                Button {
                    HapticManager.shared.light()
                    onShowLockerInput?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(locker)
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(HomeV2Theme.primaryButtonText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(HomeV2Theme.primaryButtonBackground)
                    )
                }
                .buttonStyle(.plain)
            }

            // Settings Button
            Button {
                HapticManager.shared.light()
                onShowSettings?()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(HomeV2Theme.primaryText)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(HomeV2Theme.secondaryButtonBackground)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("With Name & Locker") {
    VStack(spacing: 20) {
        HomeHeaderSection(
            greeting: "Guten Morgen",
            userName: "Ben",
            lockerNumber: "123",
            onShowSettings: { print("⚙️ Settings") },
            onShowLockerInput: { print("🔒 Locker Input") }
        )

        HomeHeaderSection(
            greeting: "Guten Tag",
            userName: "Anna",
            lockerNumber: "007",
            onShowSettings: { print("⚙️ Settings") },
            onShowLockerInput: { print("🔒 Locker Input") }
        )

        HomeHeaderSection(
            greeting: "Guten Abend",
            userName: "Max",
            lockerNumber: nil,
            onShowSettings: { print("⚙️ Settings") },
            onShowLockerInput: { print("🔒 Locker Input") }
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
}

#Preview("Without Name") {
    VStack(spacing: 20) {
        HomeHeaderSection(
            greeting: "Guten Morgen",
            userName: "",
            lockerNumber: "42",
            onShowSettings: { print("⚙️ Settings") },
            onShowLockerInput: { print("🔒 Locker Input") }
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        HomeHeaderSection(
            greeting: "Gute Nacht",
            userName: "Ben",
            lockerNumber: "999",
            onShowSettings: { print("⚙️ Settings") },
            onShowLockerInput: { print("🔒 Locker Input") }
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
    .preferredColorScheme(.dark)
}
