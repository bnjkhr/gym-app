import SwiftUI
import SwiftData

struct EditWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entity: WorkoutEntity

    @State private var name: String
    @State private var notes: String
    @State private var restTime: Double
    @State private var editableExercises: [EditableExercise]
    @State private var showingExercisePickerIndex: Int?
    @State private var editMode: EditMode = .inactive
    @State private var showingExercisePicker = false

    @Query(sort: [SortDescriptor(\ExerciseEntity.name, order: .forward)])
    private var exerciseEntities: [ExerciseEntity]

    init(entity: WorkoutEntity) {
        self.entity = entity
        _name = State(initialValue: entity.name)
        _notes = State(initialValue: entity.notes)
        _restTime = State(initialValue: entity.defaultRestTime)
        let editable = entity.exercises.compactMap { we -> EditableExercise? in
            guard let exId = we.exercise?.id else { return nil }
            let firstSet = we.sets.first
            return EditableExercise(
                exerciseId: exId,
                setCount: max(we.sets.count, 1),
                reps: firstSet?.reps ?? 10,
                weight: firstSet?.weight ?? 0
            )
        }
        _editableExercises = State(initialValue: editable)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                    TextField("Notizen", text: $notes, axis: .vertical)
                        .textFieldStyle(.plain)
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
                                    ForEach(exerciseEntities, id: \.id) { exEntity in
                                        Button(exEntity.name) {
                                            editable.exerciseId = exEntity.id
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(exerciseName(for: editable.exerciseId))
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
                                            .textFieldStyle(.plain)
                                            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                                                if let textField = obj.object as? UITextField {
                                                    textField.selectAll(nil)
                                                }
                                            }
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Gewicht (kg)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("0.0", text: .init(
                                            get: { editable.weight > 0 ? String(format: "%.1f", editable.weight) : "" },
                                            set: { newValue in
                                                if let weight = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                                    editable.weight = max(0, min(weight, 999.9))
                                                } else if newValue.isEmpty {
                                                    editable.weight = 0
                                                }
                                            }
                                        ))
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.plain)
                                            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                                                if let textField = obj.object as? UITextField {
                                                    textField.selectAll(nil)
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteExercises)
                        .onMove(perform: moveExercises)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Workout bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    isSelected: { exercise in
                        isExerciseAlreadySelected(exercise)
                    },
                    onAdd: { exercise in
                        addExerciseFromPicker(exercise)
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
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

    private func isExerciseAlreadySelected(_ exercise: Exercise) -> Bool {
        editableExercises.contains { $0.exerciseId == exercise.id }
    }

    private func addExerciseFromPicker(_ exercise: Exercise) {
        guard !isExerciseAlreadySelected(exercise) else { return }
        let metricsReps = 10
        let setCount = 3
        let weight = 0.0
        let newEditable = EditableExercise(
            exerciseId: exercise.id,
            setCount: setCount,
            reps: metricsReps,
            weight: weight
        )
        editableExercises.append(newEditable)
    }

    private func deleteExercises(at offsets: IndexSet) {
        editableExercises.remove(atOffsets: offsets)
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        editableExercises.move(fromOffsets: source, toOffset: destination)
    }

    private func saveChanges() {
        entity.name = name
        entity.notes = notes
        entity.defaultRestTime = restTime
        // Rebuild exercises array from editable state
        // Resolve ExerciseEntity by id
        let byId: [UUID: ExerciseEntity] = Dictionary(uniqueKeysWithValues: exerciseEntities.map { ($0.id, $0) })
        var newExercises: [WorkoutExerciseEntity] = []
        for editable in editableExercises {
            guard let exEntity = byId[editable.exerciseId] else { continue }
            let we = WorkoutExerciseEntity(exercise: exEntity)
            for _ in 0..<editable.setCount {
                let set = ExerciseSetEntity(
                    id: UUID(),
                    reps: editable.reps,
                    weight: editable.weight,
                    restTime: restTime,
                    completed: false
                )
                we.sets.append(set)
            }
            newExercises.append(we)
        }
        entity.exercises = newExercises
        try? modelContext.save()
        dismiss()
    }

    private func exerciseName(for id: UUID) -> String {
        exerciseEntities.first(where: { $0.id == id })?.name ?? "Übung"
    }

    private struct EditableExercise: Identifiable {
        let id = UUID()
        var exerciseId: UUID
        var setCount: Int
        var reps: Int
        var weight: Double

        init(exerciseId: UUID, setCount: Int, reps: Int, weight: Double) {
            self.exerciseId = exerciseId
            self.setCount = setCount
            self.reps = reps
            self.weight = weight
        }

        init(workoutExercise: WorkoutExercise) {
            self.exerciseId = workoutExercise.exercise.id
            self.setCount = max(workoutExercise.sets.count, 1)
            self.reps = workoutExercise.sets.first?.reps ?? 10
            self.weight = workoutExercise.sets.first?.weight ?? 0
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutEntity.self, WorkoutExerciseEntity.self, ExerciseSetEntity.self, ExerciseEntity.self, configurations: config)
    let ex = ExerciseEntity(id: UUID(), name: "Bankdrücken")
    let set = ExerciseSetEntity(id: UUID(), reps: 10, weight: 60, restTime: 90, completed: false)
    let we = WorkoutExerciseEntity(id: UUID(), exercise: ex, sets: [set])
    let workout = WorkoutEntity(id: UUID(), name: "Push Day", exercises: [we], defaultRestTime: 90)
    container.mainContext.insert(workout)
    return NavigationStack {
        EditWorkoutView(entity: workout)
            .environmentObject(WorkoutStore())
    }
    .modelContainer(container)
}

