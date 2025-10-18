import SwiftUI

/// Empty state view when no workouts exist
///
/// Displays a friendly message encouraging the user to create their first workout.
///
/// **Features:**
/// - Icon illustration
/// - Informative message
/// - Instruction text
///
/// **Usage:**
/// ```swift
/// if displayWorkouts.isEmpty && folders.isEmpty {
///     EmptyWorkoutsView()
/// }
/// ```
struct EmptyWorkoutsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.functional")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Noch keine Workouts erstellt")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Erstelle dein erstes Workout oben.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    EmptyWorkoutsView()
}
