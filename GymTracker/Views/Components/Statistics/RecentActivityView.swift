import SwiftData
import SwiftUI

/// Zeigt die letzten 5 Workouts in einer kompakten Liste an.
///
/// Diese View ist Teil der StatisticsView-Modularisierung (Phase 3).
/// Sie stellt kürzlich durchgeführte Trainings mit Datum und Übungsanzahl dar.
///
/// **Verantwortlichkeiten:**
/// - Abfrage der letzten 5 Workouts aus SwiftData
/// - Anzeige von Workout-Namen, Datum und Übungsanzahl
/// - Formatierung mit deutschem Datumsformat
/// - Empty State für neue User ohne Workouts
///
/// **Design:**
/// - Kompakte Liste mit Namen, Datum und Übungsanzahl
/// - Deutsche Lokalisierung für Datumsanzeigen
/// - Sekundäre Textfarben für Metadaten
/// - Padding für konsistentes Layout
///
/// **Performance:**
/// - SwiftData @Query mit Limit (prefix 5)
/// - Lazy evaluation der Workout-Liste
/// - Minimale View-Hierarchie
///
/// **Verwendung:**
/// ```swift
/// RecentActivityView()
///     .padding(.horizontal, 20)
/// ```
///
/// - Version: 1.0
/// - SeeAlso: `StatisticsView`, `MostUsedExercisesView`
struct RecentActivityView: View {
    @Query(sort: [SortDescriptor(\WorkoutEntity.date, order: .reverse)])
    private var workoutEntities: [WorkoutEntity]

    @Environment(\.modelContext) private var modelContext

    /// Die letzten 5 Workouts für die Anzeige
    private var recentWorkouts: [Workout] {
        workoutEntities.prefix(5).map { Workout(entity: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Letzte Aktivität")
                .font(.headline)

            if recentWorkouts.isEmpty {
                // Empty State
                Text("Noch keine Workouts aufgezeichnet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                // Workout Liste
                ForEach(recentWorkouts) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .fontWeight(.medium)

                            Text(formatDate(workout.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(workout.exercises.count) Übungen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .appEdgePadding()
    }

    // MARK: - Private Helpers

    /// Formatiert ein Datum im deutschen Format (z.B. "15. Oktober 2025")
    /// - Parameter date: Das zu formatierende Datum
    /// - Returns: Formatierter Datumsstring
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ExerciseEntity.self,
        ExerciseSetEntity.self,
        WorkoutExerciseEntity.self,
        WorkoutEntity.self,
        WorkoutSessionEntity.self,
        UserProfileEntity.self,
        configurations: config
    )

    // Seed test data
    let bench = ExerciseEntity(
        id: UUID(),
        name: "Bankdrücken",
        muscleGroupsRaw: ["chest"],
        descriptionText: "",
        instructions: [],
        createdAt: Date()
    )

    let squat = ExerciseEntity(
        id: UUID(),
        name: "Kniebeugen",
        muscleGroupsRaw: ["legs"],
        descriptionText: "",
        instructions: [],
        createdAt: Date()
    )

    let benchSet1 = ExerciseSetEntity(
        id: UUID(), reps: 10, weight: 60, restTime: 90, completed: false)
    let benchSet2 = ExerciseSetEntity(
        id: UUID(), reps: 8, weight: 65, restTime: 90, completed: false)
    let benchWE = WorkoutExerciseEntity(id: UUID(), exercise: bench, sets: [benchSet1, benchSet2])

    let squatSet1 = ExerciseSetEntity(
        id: UUID(), reps: 8, weight: 80, restTime: 120, completed: false)
    let squatWE = WorkoutExerciseEntity(id: UUID(), exercise: squat, sets: [squatSet1])

    let w1 = WorkoutEntity(
        id: UUID(),
        name: "Push Day",
        date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
        exercises: [benchWE],
        defaultRestTime: 90,
        duration: 3600,
        notes: ""
    )

    let w2 = WorkoutEntity(
        id: UUID(),
        name: "Leg Day",
        date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
        exercises: [squatWE],
        defaultRestTime: 120,
        duration: 3000,
        notes: ""
    )

    container.mainContext.insert(bench)
    container.mainContext.insert(squat)
    container.mainContext.insert(w1)
    container.mainContext.insert(w2)

    return NavigationStack {
        RecentActivityView()
    }
    .modelContainer(container)
}
