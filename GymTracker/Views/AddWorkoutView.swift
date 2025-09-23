import SwiftUI

struct AddWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var workoutName = ""
    @State private var selectedDate = Date()
    @State private var notes = ""
    @State private var durationMinutes: Double = 45
    @State private var selectedExercises: [ExerciseSelection] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $workoutName)

                    DatePicker("Datum", selection: $selectedDate, displayedComponents: [.date])

                    TextField("Notizen (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Übungen") {
                    if selectedExercises.isEmpty {
                        Text("Füge Übungen hinzu, um Sätze und Gewichte vorzubereiten.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach($selectedExercises) { $selection in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selection.exercise.name)
                                            .font(.headline)

                                        if let tooltip = lastSavedDescription(for: selection.exercise) {
                                            Text(tooltip)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        removeExercise(selection)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Stepper(value: $selection.setCount, in: 1...10) {
                                    Label("Sätze: \(selection.setCount)", systemImage: "square.stack.3d.up.fill")
                                        .labelStyle(.titleAndIcon)
                                }

                                HStack {
                                    Label("Gewicht", systemImage: "scalemass.fill")
                                        .labelStyle(.titleAndIcon)
                                    Spacer()
                                    TextField("kg", value: $selection.weight, format: .number.precision(.fractionLength(1)))
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.decimalPad)
                                        .frame(maxWidth: 120)
                                    Text("kg")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Menu {
                        ForEach(workoutStore.exercises) { exercise in
                            let alreadySelected = isExerciseSelected(exercise)
                            Button {
                                addExercise(exercise)
                            } label: {
                                Label(exercise.name, systemImage: alreadySelected ? "checkmark" : "plus")
                            }
                            .disabled(alreadySelected)
                        }
                    } label: {
                        Label("Übung hinzufügen", systemImage: "plus.circle")
                    }
                }

                Section("Dauer") {
                    VStack(alignment: .leading, spacing: 12) {
                        Slider(value: $durationMinutes, in: 20...120, step: 5) {
                            Text("Dauer in Minuten")
                        }

                        HStack {
                            Text("\(Int(durationMinutes)) Minuten")
                                .font(.headline)

                            Spacer()

                            Text("Idealer Bereich: 45-75")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Neues Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        saveWorkout()
                    }
                    .disabled(workoutName.isEmpty || selectedExercises.isEmpty)
                }
            }
        }
    }

    private func saveWorkout() {
        let workoutExercises = selectedExercises.map { selection in
            let sets = (0..<selection.setCount).map { _ in
                ExerciseSet(reps: 0, weight: selection.weight)
            }

            return WorkoutExercise(exercise: selection.exercise, sets: sets)
        }

        let workout = Workout(
            name: workoutName,
            date: selectedDate,
            exercises: workoutExercises,
            duration: durationMinutes * 60,
            notes: notes
        )

        workoutStore.addWorkout(workout)
        dismiss()
    }

    private func addExercise(_ exercise: Exercise) {
        guard !isExerciseSelected(exercise) else { return }

        let metrics = workoutStore.lastMetrics(for: exercise)
        let selection = ExerciseSelection(
            exercise: exercise,
            weight: metrics?.weight ?? 20,
            setCount: metrics?.setCount ?? 3
        )

        selectedExercises.append(selection)
    }

    private func removeExercise(_ selection: ExerciseSelection) {
        selectedExercises.removeAll { $0.id == selection.id }
    }

    private func isExerciseSelected(_ exercise: Exercise) -> Bool {
        selectedExercises.contains { $0.exercise.id == exercise.id }
    }

    private func lastSavedDescription(for exercise: Exercise) -> String? {
        guard let metrics = workoutStore.lastMetrics(for: exercise) else { return nil }
        let formattedWeight = metrics.weight.formatted(.number.precision(.fractionLength(1)))
        return "Zuletzt: \(metrics.setCount) Sätze • \(formattedWeight) kg"
    }

    private struct ExerciseSelection: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var weight: Double
        var setCount: Int
    }
}

#Preview {
    AddWorkoutView()
        .environmentObject(WorkoutStore())
}
