import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddWorkout = false

    var body: some View {
        List {
            ForEach(workoutStore.workouts) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: binding(for: workout))
                        .environmentObject(workoutStore)
                } label: {
                    WorkoutRowView(workout: workout)
                }
            }
            .onDelete(perform: workoutStore.deleteWorkout)
        }
        .padding(.bottom, 96)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                Text("Workouts")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    showingAddWorkout = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 18, x: 0, y: 8)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutView()
                .environmentObject(workoutStore)
        }
    }
}

struct WorkoutRowView: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.name)
                .font(.headline)

            Text(workout.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("\(workout.exercises.count) Übungen")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let duration = workout.duration {
                    Text("\(Int(duration / 60))min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private extension WorkoutsView {
    func binding(for workout: Workout) -> Binding<Workout> {
        guard let index = workoutStore.workouts.firstIndex(where: { $0.id == workout.id }) else {
            return .constant(workout)
        }

        return Binding(
            get: { workoutStore.workouts[index] },
            set: { workoutStore.workouts[index] = $0 }
        )
    }
}

#Preview {
    WorkoutsView()
        .environmentObject(WorkoutStore())
}
