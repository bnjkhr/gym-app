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
            let sets = we.sets.map { set in
                EditableSet(
                    reps: set.reps,
                    weight: set.weight,
                    restTime: set.restTime
                )
            }
            return EditableExercise(
                exerciseId: exId,
                sets: sets.isEmpty ? [EditableSet()] : sets
            )
        }
        _editableExercises = State(initialValue: editable)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Details")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            TextField("Workout-Name", text: $name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.15))
                                )

                            TextField("Notizen (optional)", text: $notes, axis: .vertical)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(2...4)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.15))
                                )

                            HStack {
                                Text("Standard-Pause")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Spacer()
                                HStack(spacing: 12) {
                                    Button {
                                        restTime = max(30, restTime - 10)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }

                                    Text("\(Int(restTime))s")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                        .monospacedDigit()
                                        .frame(minWidth: 50)

                                    Button {
                                        restTime = min(240, restTime + 10)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.deepBlue, AppTheme.powerOrange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)

                        // Exercises Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Übungen")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button {
                                    showingExercisePicker = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18))
                                        Text("Hinzufügen")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(AppTheme.mossGreen)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)

                            if editableExercises.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "figure.strengthtraining.functional")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)
                                    Text("Noch keine Übungen")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text("Füge Übungen hinzu, um dein Workout zu erstellen")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(AppTheme.cardBackground)
                                )
                            } else {
                                ForEach(Array($editableExercises.enumerated()), id: \.element.id) { index, $editable in
                                    ExerciseCard(
                                        editable: $editable,
                                        exerciseName: exerciseName(for: editable.exerciseId),
                                        exerciseEntities: exerciseEntities,
                                        defaultRestTime: restTime,
                                        onDelete: {
                                            let indexToRemove = index
                                            withAnimation {
                                                _ = editableExercises.remove(at: indexToRemove)
                                            }
                                        }
                                    )
                                }
                                .onMove { sourceIndices, destination in
                                    editableExercises.move(fromOffsets: sourceIndices, toOffset: destination)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Bearbeiten")
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
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .tint(AppTheme.powerOrange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        EditButton()
                            .tint(AppTheme.turquoiseBoost)

                        Button("Speichern") {
                            saveChanges()
                        }
                        .tint(AppTheme.mossGreen)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || editableExercises.isEmpty)
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
    }

    private func isExerciseAlreadySelected(_ exercise: Exercise) -> Bool {
        editableExercises.contains { $0.exerciseId == exercise.id }
    }

    private func addExerciseFromPicker(_ exercise: Exercise) {
        guard !isExerciseAlreadySelected(exercise) else { return }
        let defaultSets = [
            EditableSet(reps: 10, weight: 0, restTime: restTime),
            EditableSet(reps: 10, weight: 0, restTime: restTime),
            EditableSet(reps: 10, weight: 0, restTime: restTime)
        ]
        let newEditable = EditableExercise(
            exerciseId: exercise.id,
            sets: defaultSets
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
            // Create a set for each EditableSet with individual weight/reps
            for editableSet in editable.sets {
                let set = ExerciseSetEntity(
                    id: UUID(),
                    reps: editableSet.reps,
                    weight: editableSet.weight,
                    restTime: editableSet.restTime,
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

    struct EditableSet: Identifiable {
        let id = UUID()
        var reps: Int
        var weight: Double
        var restTime: Double

        init(reps: Int = 10, weight: Double = 0, restTime: Double = 90) {
            self.reps = reps
            self.weight = weight
            self.restTime = restTime
        }
    }

    struct EditableExercise: Identifiable {
        let id = UUID()
        var exerciseId: UUID
        var sets: [EditableSet]

        init(exerciseId: UUID, sets: [EditableSet]) {
            self.exerciseId = exerciseId
            self.sets = sets
        }

        init(workoutExercise: WorkoutExercise) {
            self.exerciseId = workoutExercise.exercise.id
            self.sets = workoutExercise.sets.map { set in
                EditableSet(
                    reps: set.reps,
                    weight: set.weight,
                    restTime: set.restTime
                )
            }
            if self.sets.isEmpty {
                self.sets = [EditableSet()]
            }
        }
    }
}

// MARK: - Exercise Card Component

struct ExerciseCard: View {
    @Binding var editable: EditWorkoutView.EditableExercise
    let exerciseName: String
    let exerciseEntities: [ExerciseEntity]
    let defaultRestTime: Double
    let onDelete: () -> Void

    @State private var isExpanded = true
    @Environment(\.editMode) private var editMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Drag Handle (nur im Edit-Modus sichtbar)
                if editMode?.wrappedValue == .active {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.turquoiseBoost)
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(exerciseEntities, id: \.id) { exEntity in
                        Button(exEntity.name) {
                            editable.exerciseId = exEntity.id
                        }
                    }
                } label: {
                    HStack {
                        Text(exerciseName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppTheme.cardBackground)

            if isExpanded {
                VStack(spacing: 0) {
                    // Sets List
                    ForEach(Array($editable.sets.enumerated()), id: \.element.id) { index, $set in
                        SetRow(
                            setNumber: index + 1,
                            set: $set,
                            onDelete: {
                                let indexToRemove = index
                                withAnimation {
                                    _ = editable.sets.remove(at: indexToRemove)
                                }
                            }
                        )
                        if index < editable.sets.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    // Add Set Button
                    Button {
                        withAnimation {
                            let newSet = EditWorkoutView.EditableSet(
                                reps: editable.sets.last?.reps ?? 10,
                                weight: editable.sets.last?.weight ?? 0,
                                restTime: defaultRestTime
                            )
                            editable.sets.append(newSet)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Satz hinzufügen")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.mossGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(AppTheme.cardBackground)
                }
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.08), lineWidth: 1)
        )
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Set Row Component

struct SetRow: View {
    let setNumber: Int
    @Binding var set: EditWorkoutView.EditableSet
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Set Number
            Text("\(setNumber)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(AppTheme.turquoiseBoost)
                )

            // Reps Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Wdh.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                TextField("10", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 60)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }

            // Weight Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Gewicht (kg)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                TextField("0.0", text: .init(
                    get: { set.weight > 0 ? String(format: "%.1f", set.weight) : "" },
                    set: { newValue in
                        if let weight = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                            set.weight = max(0, min(weight, 999.9))
                        } else if newValue.isEmpty {
                            set.weight = 0
                        }
                    }
                ))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 80)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }

            Spacer()

            // Delete Button
            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

