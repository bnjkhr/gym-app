import SwiftData
import SwiftUI

/// Displays the top 5 most frequently used exercises
struct MostUsedExercisesView: View {
    @Query(sort: [SortDescriptor(\WorkoutEntity.date, order: .reverse)])
    private var workoutEntities: [WorkoutEntity]

    @Query(sort: [SortDescriptor(\ExerciseEntity.name, order: .forward)])
    private var exerciseEntities: [ExerciseEntity]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    private var displayWorkouts: [Workout] {
        workoutEntities.map { Workout(entity: $0) }
    }

    var exerciseUsage: [(Exercise, Int)] {
        let workouts = displayWorkouts
        let catalog: [Exercise] = {
            // Fresh fetch to avoid invalid snapshots
            let descriptor = FetchDescriptor<ExerciseEntity>(sortBy: [
                SortDescriptor(\.name, order: .forward)
            ])
            let freshList = (try? modelContext.fetch(descriptor)) ?? []
            return safeMapExercises(freshList, in: modelContext)
        }()
        var usage: [UUID: Int] = [:]
        for workout in workouts {
            for workoutExercise in workout.exercises {
                usage[workoutExercise.exercise.id, default: 0] += 1
            }
        }
        return
            catalog
            .map { exercise in (exercise, usage[exercise.id] ?? 0) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Beliebteste Übungen")
                .font(.headline)

            if exerciseUsage.isEmpty {
                Text("Noch keine Workouts aufgezeichnet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(exerciseUsage.enumerated()), id: \.offset) { index, item in
                    let (exercise, count) = item
                    HStack {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundColor(
                                colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)

                        Text(exercise.name)

                        Spacer()

                        Text("\(count)x")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .appEdgePadding()
    }
}
