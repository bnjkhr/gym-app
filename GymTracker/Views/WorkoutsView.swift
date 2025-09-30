import SwiftUI
import SwiftData

struct WorkoutsView: View {
    init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: .reverse)
    ])
    private var workoutEntities: [WorkoutEntity]

    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddWorkout = false

    var body: some View {
        List {
            ForEach(workoutEntities) { entity in
                NavigationLink {
                    WorkoutDetailView(entity: entity)
                        .environmentObject(workoutStore)
                } label: {
                    WorkoutRowView(workout: Workout(entity: entity, in: modelContext))
                }
            }
            .onDelete(perform: deleteWorkouts)
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
                .tint(AppTheme.darkPurple)
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
    func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            let entity = workoutEntities[index]
            modelContext.delete(entity)
        }
        try? modelContext.save()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutEntity.self, WorkoutExerciseEntity.self, ExerciseSetEntity.self, ExerciseEntity.self, WorkoutSessionEntity.self, UserProfileEntity.self, configurations: config)
    // Seed one workout
    let exercise = ExerciseEntity(id: UUID(), name: "Kniebeugen")
    let set = ExerciseSetEntity(id: UUID(), reps: 8, weight: 80, restTime: 120, completed: false)
    let we = WorkoutExerciseEntity(id: UUID(), exercise: exercise, sets: [set])
    let workout = WorkoutEntity(id: UUID(), name: "Leg Day", exercises: [we], defaultRestTime: 90)
    container.mainContext.insert(workout)
    return WorkoutsView()
        .environmentObject(WorkoutStore())
        .modelContainer(container)
}

