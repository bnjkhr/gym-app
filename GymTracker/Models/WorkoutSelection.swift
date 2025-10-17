import Foundation

/// Identifiziert ein ausgewähltes Workout für Navigation.
///
/// Dieses Type wird verwendet, um zwischen Views zu navigieren wenn ein
/// Workout ausgewählt wurde (z.B. zum Starten oder Bearbeiten).
///
/// **Verwendung:**
/// ```swift
/// @State private var selectedWorkout: WorkoutSelection?
///
/// // Workout auswählen
/// selectedWorkout = WorkoutSelection(id: workout.id)
///
/// // Navigation Destination
/// .sheet(item: $selectedWorkout) { selection in
///     WorkoutDetailView(workoutId: selection.id)
/// }
/// ```
///
/// - Version: 1.0
/// - SeeAlso: `WorkoutsHomeView`, `WorkoutsTabView`
struct WorkoutSelection: Identifiable, Hashable {
    let id: UUID
}
