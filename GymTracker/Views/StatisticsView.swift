import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    OverviewCardView()

                    MostUsedExercisesView()

                    RecentActivityView()
                }
                .padding()
            }
            .navigationTitle("Fortschritt")
        }
    }
}

struct OverviewCardView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var totalWorkouts: Int {
        workoutStore.workouts.count
    }

    var totalExercises: Int {
        workoutStore.exercises.count
    }

    var thisWeekWorkouts: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workoutStore.workouts.filter { $0.date >= oneWeekAgo }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Übersicht")
                .font(.headline)

            HStack(spacing: 20) {
                StatCard(title: "Workouts", value: "\(totalWorkouts)", color: .orange)
                StatCard(title: "Übungen", value: "\(totalExercises)", color: .blue)
                StatCard(title: "Diese Woche", value: "\(thisWeekWorkouts)", color: .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MostUsedExercisesView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var exerciseUsage: [(Exercise, Int)] {
        var usage: [UUID: Int] = [:]

        for workout in workoutStore.workouts {
            for workoutExercise in workout.exercises {
                usage[workoutExercise.exercise.id, default: 0] += 1
            }
        }

        return workoutStore.exercises
            .map { exercise in
                (exercise, usage[exercise.id] ?? 0)
            }
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
                            .foregroundColor(.orange)

                        Text(exercise.name)

                        Spacer()

                        Text("\(count)x")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RecentActivityView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var recentWorkouts: [Workout] {
        workoutStore.workouts
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Letzte Aktivität")
                .font(.headline)

            if recentWorkouts.isEmpty {
                Text("Noch keine Workouts aufgezeichnet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(recentWorkouts) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .fontWeight(.medium)

                            Text(workout.date, style: .date)
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
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatisticsView()
        .environmentObject(WorkoutStore())
}