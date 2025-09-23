import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var showingAddWorkout = false

    var body: some View {
        NavigationView {
            List {
                ForEach(workoutStore.workouts) { workout in
                    WorkoutRowView(workout: workout)
                }
                .onDelete(perform: workoutStore.deleteWorkout)
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
                    .environmentObject(workoutStore)
            }
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

#Preview {
    WorkoutsView()
        .environmentObject(WorkoutStore())
}