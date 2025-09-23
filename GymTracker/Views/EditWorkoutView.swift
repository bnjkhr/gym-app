import SwiftUI

struct EditWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @Binding var workout: Workout

    @State private var name: String
    @State private var notes: String
    @State private var restTime: Double
    @State private var editableExercises: [EditableExercise]
    @State private var showingExercisePickerIndex: Int?
    @State private var editMode: EditMode = .inactive

    init(workout: Binding<Workout>) {
        _workout = workout
        let value = workout.wrappedValue
        _name = State(initialValue: value.name)
        _notes = State(initialValue: value.notes)
        _restTime = State(initialValue: value.defaultRestTime)
        _editableExercises = State(initialValue: value.exercises.map { EditableExercise(workoutExercise: $0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Notizen", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    Stepper(value: $restTime, in: 30...240, step: 5) {
                        Text("Standard-Pause: \(Int(restTime))s")
                            .font(.subheadline)
                    }
                }

                Section(header: exercisesHeader) {
                    if editableExercises.isEmpty {
                        Text("Füge Übungen hinzu, um das Workout zu konfigurieren.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach($editableExercises) { $editable in
                            VStack(alignment: .leading, spacing: 12) {
                                Menu {
                                    ForEach(workoutStore.exercises) { exercise in
                                        Button(exercise.name) {
                                            editable.exercise = exercise
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(editable.exercise.name)
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Stepper(value: $editable.setCount, in: 1...10) {
                                    Text("Sätze: \(editable.setCount)")
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Wiederholungen")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("Wdh", value: $editable.reps, format: .number)
                                            .keyboardType(.numberPad)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Gewicht (kg)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("kg", value: $editable.weight, format: .number.precision(.fractionLength(1)))
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteExercises)
                        .onMove(perform: moveExercises)
                    }

                    Button {
                        addExercise()
                    } label: {
                        Label("Übung hinzufügen", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Workout bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                    Button("Speichern") { saveChanges() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || editableExercises.isEmpty)
                }
            }
            .environment(\.editMode, $editMode)
        }
    }

    private var exercisesHeader: some View {
        Text("Übungen")
    }

    private func addExercise() {
        let defaultExercise = workoutStore.exercises.first ?? workoutStore.exercise(named: "Neue Übung")
        editableExercises.append(EditableExercise(exercise: defaultExercise, setCount: 3, reps: 10, weight: 0))
    }

    private func deleteExercises(at offsets: IndexSet) {
        editableExercises.remove(atOffsets: offsets)
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        editableExercises.move(fromOffsets: source, toOffset: destination)
    }

    private func saveChanges() {
        workout.name = name
        workout.notes = notes
        workout.defaultRestTime = restTime
        workout.exercises = editableExercises.map { editable in
            let sets = (0..<editable.setCount).map { _ in
                ExerciseSet(reps: editable.reps, weight: editable.weight, restTime: restTime)
            }
            return WorkoutExercise(exercise: editable.exercise, sets: sets)
        }
        workoutStore.updateWorkout(workout)
        dismiss()
    }

    private struct EditableExercise: Identifiable {
        let id = UUID()
        var exercise: Exercise
        var setCount: Int
        var reps: Int
        var weight: Double

        init(exercise: Exercise, setCount: Int, reps: Int, weight: Double) {
            self.exercise = exercise
            self.setCount = setCount
            self.reps = reps
            self.weight = weight
        }

        init(workoutExercise: WorkoutExercise) {
            self.exercise = workoutExercise.exercise
            self.setCount = max(workoutExercise.sets.count, 1)
            self.reps = workoutExercise.sets.first?.reps ?? 10
            self.weight = workoutExercise.sets.first?.weight ?? 0
        }
    }
}

#Preview {
    NavigationStack {
        EditWorkoutView(workout: .constant(WorkoutStore().workouts.first!))
            .environmentObject(WorkoutStore())
    }
}
