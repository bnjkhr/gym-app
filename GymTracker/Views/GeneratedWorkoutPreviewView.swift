import SwiftUI

struct GeneratedWorkoutPreviewView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var workout: Workout
    @Binding var workoutName: String
    @State private var isEditing = false
    @State private var editingWorkout: Workout

    let onSave: () -> Void
    let onDismiss: () -> Void

    init(workout: Workout, workoutName: Binding<String>, onSave: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self._workout = State(initialValue: workout)
        self._workoutName = workoutName
        self._editingWorkout = State(initialValue: workout)
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "sparkles.square.filled.on.square")
                                .font(.title)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dein perfektes Workout")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Basierend auf deinen Präferenzen erstellt")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.1))
                        )

                        // Workout Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout Name")
                                .font(.headline)
                            TextField("Mein Workout", text: $workoutName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Workout Stats
                    WorkoutStatsCard(workout: workout)

                    // Exercise List
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Übungen (\(workout.exercises.count))")
                                .font(.headline)
                            Spacer()
                            Button(isEditing ? "Fertig" : "Bearbeiten") {
                                if isEditing {
                                    workout = editingWorkout
                                }
                                isEditing.toggle()
                            }
                            .buttonStyle(.bordered)
                        }

                        if isEditing {
                            ForEach($editingWorkout.exercises) { $workoutExercise in
                                EditableExerciseCard(workoutExercise: $workoutExercise)
                            }
                            .onDelete { indexSet in
                                editingWorkout.exercises.remove(atOffsets: indexSet)
                            }
                        } else {
                            ForEach(workout.exercises) { workoutExercise in
                                ExercisePreviewCard(workoutExercise: workoutExercise)
                            }
                        }
                    }

                    // Workout Notes
                    if !workout.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trainingshinweise")
                                .font(.headline)
                            Text(workout.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Workout Vorschau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zurück") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(workoutName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct WorkoutStatsCard: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 20) {
            StatItem(
                title: "Übungen",
                value: "\(workout.exercises.count)",
                icon: "list.bullet"
            )

            Divider()

            StatItem(
                title: "Geschätzte Dauer",
                value: estimatedDuration,
                icon: "clock"
            )

            Divider()

            StatItem(
                title: "Pause",
                value: "\(Int(workout.defaultRestTime))s",
                icon: "pause.circle"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private var estimatedDuration: String {
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        let workingTime = totalSets * 30 // 30 Sekunden pro Satz
        let restTime = Int((Double(totalSets - 1) * workout.defaultRestTime))
        let totalMinutes = (workingTime + restTime) / 60
        return "\(totalMinutes) Min"
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExercisePreviewCard: View {
    let workoutExercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutExercise.exercise.name)
                        .font(.headline)
                    if !workoutExercise.exercise.muscleGroups.isEmpty {
                        Text(workoutExercise.exercise.muscleGroups.map { $0.rawValue }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(workoutExercise.sets.count) Sätze")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let firstSet = workoutExercise.sets.first {
                        Text("\(firstSet.reps) Wdh.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Set visualization
            HStack(spacing: 8) {
                ForEach(0..<min(workoutExercise.sets.count, 6), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 8)
                        .overlay(
                            Text("\(workoutExercise.sets[index].reps)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        )
                }
                if workoutExercise.sets.count > 6 {
                    Text("+\(workoutExercise.sets.count - 6)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }
}

struct EditableExerciseCard: View {
    @Binding var workoutExercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(workoutExercise.exercise.name)
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sätze")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper(value: Binding(
                        get: { workoutExercise.sets.count },
                        set: { newCount in
                            let currentCount = workoutExercise.sets.count
                            if newCount > currentCount {
                                let template = workoutExercise.sets.first ?? ExerciseSet(reps: 10, weight: 0, restTime: 90)
                                for _ in currentCount..<newCount {
                                    workoutExercise.sets.append(template)
                                }
                            } else if newCount < currentCount {
                                workoutExercise.sets = Array(workoutExercise.sets.prefix(newCount))
                            }
                        }
                    ), in: 1...10) {
                        Text("\(workoutExercise.sets.count)")
                            .font(.headline)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Wiederholungen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper(value: Binding(
                        get: { workoutExercise.sets.first?.reps ?? 10 },
                        set: { newReps in
                            for i in 0..<workoutExercise.sets.count {
                                workoutExercise.sets[i].reps = newReps
                            }
                        }
                    ), in: 1...50) {
                        Text("\(workoutExercise.sets.first?.reps ?? 10)")
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    let sampleWorkout = Workout(
        name: "Muskelaufbau - Mixed",
        exercises: [
            WorkoutExercise(
                exercise: Exercise(name: "Bankdrücken", muscleGroups: [.chest, .triceps], description: "Klassisches Bankdrücken"),
                sets: [
                    ExerciseSet(reps: 10, weight: 0, restTime: 90),
                    ExerciseSet(reps: 10, weight: 0, restTime: 90),
                    ExerciseSet(reps: 10, weight: 0, restTime: 90)
                ]
            )
        ],
        defaultRestTime: 90,
        notes: "🎯 Ziel: Muskelaufbau\n📊 Level: Fortgeschritten\n⏱️ Dauer: ~45 Minuten\n💡 Tipp: Kontrollierte Bewegungen"
    )

    GeneratedWorkoutPreviewView(
        workout: sampleWorkout,
        workoutName: .constant("Mein Workout"),
        onSave: {},
        onDismiss: {}
    )
    .environmentObject(WorkoutStore())
}