import SwiftUI

/// Fixierte Bottom Action Bar für Active Workout View (v2)
///
/// Eine am unteren Bildschirmrand fixierte Bar mit 3 Action-Buttons:
/// - Links: Repeat/History (zeigt vorherige Werte)
/// - Mitte: Plus (Add Set/Exercise) - groß und prominent
/// - Rechts: Reorder (Übungen neu ordnen)
///
/// **Features:**
/// - Fixiert am unteren Rand (safeArea aware)
/// - Shadow für visuellen Lift
/// - Gleichmäßige Verteilung der Buttons
/// - Prominent Plus-Button in der Mitte
///
/// **Layout:**
/// ```
/// [🔄 Repeat]  [➕ Plus (groß)]  [↕️ Reorder]
/// ```
///
/// **Usage:**
/// ```swift
/// BottomActionBar(
///     onRepeat: { /* Show last workout values */ },
///     onAdd: { /* Add new set or exercise */ },
///     onReorder: { /* Show reorder sheet */ }
/// )
/// ```
struct BottomActionBar: View {
    var onRepeat: (() -> Void)?
    var onAdd: (() -> Void)?
    var onReorder: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // Left: Repeat/History Button
            Button {
                onRepeat?()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                    Text("History")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(onRepeat == nil)
            .opacity(onRepeat == nil ? 0.3 : 1.0)

            // Center: Add Button (prominent)
            Button {
                onAdd?()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.mossGreen)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(onAdd == nil)
            .opacity(onAdd == nil ? 0.3 : 1.0)

            // Right: Reorder Button
            Button {
                onReorder?()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title2)
                    Text("Reorder")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(onReorder == nil)
            .opacity(onReorder == nil ? 0.3 : 1.0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
        )
    }
}

// MARK: - Previews

#Preview("All Actions Enabled") {
    VStack {
        Spacer()

        // Simulated content
        VStack {
            Text("Workout Content")
                .font(.headline)
            Text("Scroll to see action bar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Action Bar
        BottomActionBar(
            onRepeat: {
                print("Repeat tapped")
            },
            onAdd: {
                print("Add tapped")
            },
            onReorder: {
                print("Reorder tapped")
            }
        )
    }
    .ignoresSafeArea(edges: .bottom)
}

#Preview("Only Add Enabled") {
    VStack {
        Spacer()

        Text("Only Plus Button Active")
            .font(.headline)

        BottomActionBar(
            onRepeat: nil,  // Disabled
            onAdd: {
                print("Add tapped")
            },
            onReorder: nil  // Disabled
        )
    }
    .ignoresSafeArea(edges: .bottom)
}

#Preview("In Scroll View") {
    ZStack(alignment: .bottom) {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(1...20, id: \.self) { index in
                    HStack {
                        Text("Exercise \(index)")
                            .font(.headline)
                        Spacer()
                        Text("3 sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
            .padding(.bottom, 80)  // Space for bottom bar
        }

        // Floating Action Bar
        BottomActionBar(
            onRepeat: {
                print("Repeat")
            },
            onAdd: {
                print("Add")
            },
            onReorder: {
                print("Reorder")
            }
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark Mode") {
    VStack {
        Spacer()

        Text("Dark Mode")
            .font(.headline)
            .foregroundStyle(.white)

        BottomActionBar(
            onRepeat: { print("Repeat") },
            onAdd: { print("Add") },
            onReorder: { print("Reorder") }
        )
    }
    .background(Color.black)
    .environment(\.colorScheme, .dark)
    .ignoresSafeArea(edges: .bottom)
}

#Preview("With Custom Colors") {
    VStack {
        Spacer()

        Text("Active Workout")
            .font(.title)
            .fontWeight(.bold)

        BottomActionBar(
            onRepeat: { print("Repeat") },
            onAdd: { print("Add") },
            onReorder: { print("Reorder") }
        )
    }
    .background(
        LinearGradient(
            colors: [AppTheme.deepBlue, AppTheme.powerOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .ignoresSafeArea(edges: .bottom)
}
