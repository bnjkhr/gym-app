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
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 0.5)
                Button {
                    showingAddWorkout = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Neues Workout anlegen")
                            .font(.headline)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.purple)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 6)
            }
            .background(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 0)
            .zIndex(1)
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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline)

                Text(workout.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(workout.exercises.count) Übungen")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
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
