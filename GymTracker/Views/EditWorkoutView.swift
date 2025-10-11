import SwiftUI
import SwiftData

// MARK: - Data Models

struct EditableSet: Identifiable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var duration: TimeInterval? // Für Cardio-Übungen
    var unit: SetUnit?          // Einheit
    var restTime: Double

    init(reps: Int = 10, weight: Double = 0, duration: TimeInterval? = nil, unit: SetUnit? = nil, restTime: Double = 90) {
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.unit = unit
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
}

// MARK: - Exercise Card State

/// Manages the UI state for each exercise card
struct ExerciseCardState {
    var isExpanded: Bool = false        // Show individual sets?
    var isQuickEditing: Bool = false    // Show quick edit view?

    // Bulk edit values (applied to all sets)
    var bulkSets: Int = 3
    var bulkReps: Int = 10
    var bulkWeight: Double = 80.0

    mutating func applyBulkToSets(_ sets: inout [EditableSet]) {
        // Ensure we have the right number of sets
        if sets.count < bulkSets {
            // Add more sets
            while sets.count < bulkSets {
                sets.append(EditableSet(reps: bulkReps, weight: bulkWeight, restTime: 90))
            }
        } else if sets.count > bulkSets {
            // Remove extra sets
            sets = Array(sets.prefix(bulkSets))
        }

        // Apply bulk values to all sets
        for i in 0..<sets.count {
            sets[i].reps = bulkReps
            sets[i].weight = bulkWeight
        }
    }
}

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
    @State private var showingExercisePicker = false

    // New state management
    @State private var cardStates: [UUID: ExerciseCardState] = [:]
    @State private var isReorderMode: Bool = false

    @Query(sort: [SortDescriptor(\ExerciseEntity.name, order: .forward)])
    private var exerciseEntities: [ExerciseEntity]

    init(entity: WorkoutEntity) {
        self.entity = entity
        _name = State(initialValue: entity.name)
        _notes = State(initialValue: entity.notes)
        _restTime = State(initialValue: entity.defaultRestTime)

        // WICHTIG: Sortiere die Übungen nach order BEVOR wir das editable Array erstellen!
        let sortedExercises = entity.exercises.sorted { $0.order < $1.order }

        let editable = sortedExercises.compactMap { we -> EditableExercise? in
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

        // Initialize card states with values from sets
        var initialStates: [UUID: ExerciseCardState] = [:]
        for exercise in editable {
            let firstSet = exercise.sets.first ?? EditableSet()
            initialStates[exercise.id] = ExerciseCardState(
                isExpanded: false,
                isQuickEditing: false,
                bulkSets: exercise.sets.count,
                bulkReps: firstSet.reps,
                bulkWeight: firstSet.weight
            )
        }
        _cardStates = State(initialValue: initialStates)

        // Debug logging
        print("🔍 [EditWorkoutView] Init - Workout: \(entity.name)")
        print("📋 [EditWorkoutView] Übungen geladen (sortiert nach order):")
        for (i, ex) in sortedExercises.enumerated() {
            print("  [\(i)] order=\(ex.order) \(ex.exercise?.name ?? "Unknown")")
        }
        print("📋 [EditWorkoutView] EditableExercises Array:")
        for (i, ed) in editable.enumerated() {
            let exName = sortedExercises.first(where: { $0.exercise?.id == ed.exerciseId })?.exercise?.name ?? "Unknown"
            print("  [\(i)] \(exName)")
        }
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
                                .foregroundStyle(.white.opacity(0.9))
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
                                            .foregroundStyle(.white.opacity(0.9))
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
                                            .foregroundStyle(.white.opacity(0.9))
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
                                    .foregroundStyle(.primary)
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
                                // New redesigned exercise cards
                                ForEach(Array($editableExercises.enumerated()), id: \.element.id) { index, $editable in
                                    VStack(spacing: 8) {
                                        // Collapsed Row (always visible)
                                        CollapsedExerciseRow(
                                            exerciseName: exerciseName(for: editable.exerciseId),
                                            setCount: editable.sets.count,
                                            avgReps: calculateAvgReps(editable.sets),
                                            avgWeight: calculateAvgWeight(editable.sets),
                                            isReorderMode: isReorderMode,
                                            onTap: {
                                                withAnimation(.spring(response: 0.3)) {
                                                    toggleQuickEdit(for: editable.id)
                                                }
                                            },
                                            onToggleExpand: {
                                                withAnimation(.spring(response: 0.3)) {
                                                    toggleExpanded(for: editable.id)
                                                }
                                            },
                                            onLongPress: {
                                                withAnimation(.spring(response: 0.3)) {
                                                    enterReorderMode()
                                                }
                                            },
                                            onDelete: {
                                                withAnimation(.spring(response: 0.3)) {
                                                    removeExerciseById(editable.exerciseId)
                                                    cardStates.removeValue(forKey: editable.id)
                                                }
                                            }
                                        )
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation(.spring(response: 0.3)) {
                                                    removeExerciseById(editable.exerciseId)
                                                    cardStates.removeValue(forKey: editable.id)
                                                }
                                            } label: {
                                                Label("Löschen", systemImage: "trash")
                                            }
                                        }

                                        // Quick Edit View (conditionally shown)
                                        if cardStates[editable.id]?.isQuickEditing == true {
                                            QuickEditView(
                                                sets: Binding(
                                                    get: { cardStates[editable.id]?.bulkSets ?? 3 },
                                                    set: { cardStates[editable.id]?.bulkSets = $0 }
                                                ),
                                                reps: Binding(
                                                    get: { cardStates[editable.id]?.bulkReps ?? 10 },
                                                    set: { cardStates[editable.id]?.bulkReps = $0 }
                                                ),
                                                weight: Binding(
                                                    get: { cardStates[editable.id]?.bulkWeight ?? 80 },
                                                    set: { cardStates[editable.id]?.bulkWeight = $0 }
                                                ),
                                                onApply: {
                                                    applyBulkEdit(to: editable.id)
                                                },
                                                onExpand: {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        cardStates[editable.id]?.isQuickEditing = false
                                                        cardStates[editable.id]?.isExpanded = true
                                                    }
                                                }
                                            )
                                        }

                                        // Expanded Set List (conditionally shown)
                                        if cardStates[editable.id]?.isExpanded == true {
                                            ExpandedSetListView(
                                                sets: $editable.sets,
                                                defaultRestTime: restTime,
                                                onCollapse: {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        cardStates[editable.id]?.isExpanded = false
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                // Reorder Mode Overlay
                if isReorderMode {
                    ReorderModeOverlay(
                        exercises: $editableExercises,
                        exerciseNames: Dictionary(uniqueKeysWithValues: exerciseEntities.map { ($0.id, $0.name) }),
                        onExit: {
                            withAnimation(.spring(response: 0.3)) {
                                isReorderMode = false
                            }
                        }
                    )
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
                    },
                    onRemove: { exercise in
                        removeExerciseById(exercise.id)
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveChanges()
                    }
                    .tint(AppTheme.mossGreen)
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || editableExercises.isEmpty)
                }
            }
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

        // Initialize card state for new exercise
        cardStates[newEditable.id] = ExerciseCardState(
            isExpanded: false,
            isQuickEditing: false,
            bulkSets: 3,
            bulkReps: 10,
            bulkWeight: 0
        )
    }

    private func removeExerciseById(_ exerciseId: UUID) {
        editableExercises.removeAll { $0.exerciseId == exerciseId }
    }

    private func deleteExercises(at offsets: IndexSet) {
        editableExercises.remove(atOffsets: offsets)
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        editableExercises.move(fromOffsets: source, toOffset: destination)
    }

    private func saveChanges() {
        print("💾 [EditWorkoutView] Speichere Workout: \(name)")
        print("📋 [EditWorkoutView] Reihenfolge vor dem Speichern:")
        let byId: [UUID: ExerciseEntity] = Dictionary(uniqueKeysWithValues: exerciseEntities.map { ($0.id, $0) })
        for (index, editable) in editableExercises.enumerated() {
            let exName = byId[editable.exerciseId]?.name ?? "Unknown"
            print("  [\(index)] \(exName) (ID: \(editable.exerciseId.uuidString.prefix(8)))")
        }

        entity.name = name
        entity.notes = notes
        entity.defaultRestTime = restTime

        // Clear existing exercises
        entity.exercises.removeAll()

        // Rebuild exercises with explicit order
        for (index, editable) in editableExercises.enumerated() {
            guard let exEntity = byId[editable.exerciseId] else {
                print("⚠️ [EditWorkoutView] Exercise nicht gefunden: \(editable.exerciseId)")
                continue
            }

            // Create WorkoutExerciseEntity with explicit order
            let we = WorkoutExerciseEntity(exercise: exEntity, order: index)

            // Create sets for this exercise
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

            entity.exercises.append(we)
        }

        // Explicit save with error handling
        do {
            try modelContext.save()
            print("✅ [EditWorkoutView] Workout gespeichert mit \(entity.exercises.count) Übungen")
            print("📋 [EditWorkoutView] Reihenfolge nach dem Speichern:")
            for (i, ex) in entity.exercises.enumerated() {
                print("  [\(i)] order=\(ex.order) exercise=\(ex.exercise?.name ?? "?")")
            }
        } catch {
            print("❌ [EditWorkoutView] Fehler beim Speichern: \(error)")
        }

        dismiss()
    }

    private func exerciseName(for id: UUID) -> String {
        exerciseEntities.first(where: { $0.id == id })?.name ?? "Übung"
    }

    // MARK: - New UI Interaction Helpers

    private func calculateAvgReps(_ sets: [EditableSet]) -> Int {
        guard !sets.isEmpty else { return 0 }
        let total = sets.reduce(0) { $0 + $1.reps }
        return total / sets.count
    }

    private func calculateAvgWeight(_ sets: [EditableSet]) -> Double {
        guard !sets.isEmpty else { return 0 }
        let total = sets.reduce(0.0) { $0 + $1.weight }
        return total / Double(sets.count)
    }

    private func toggleQuickEdit(for id: UUID) {
        // Close all other cards
        for key in cardStates.keys {
            if key != id {
                cardStates[key]?.isQuickEditing = false
                cardStates[key]?.isExpanded = false
            }
        }
        // Toggle this card
        cardStates[id]?.isQuickEditing.toggle()
        if cardStates[id]?.isQuickEditing == true {
            cardStates[id]?.isExpanded = false
        }
    }

    private func toggleExpanded(for id: UUID) {
        cardStates[id]?.isExpanded.toggle()
        if cardStates[id]?.isExpanded == true {
            cardStates[id]?.isQuickEditing = false
        }
    }

    private func applyBulkEdit(to id: UUID) {
        guard var state = cardStates[id],
              let index = editableExercises.firstIndex(where: { $0.id == id }) else { return }

        state.applyBulkToSets(&editableExercises[index].sets)
        cardStates[id] = state
    }

    private func enterReorderMode() {
        // Collapse all cards
        for key in cardStates.keys {
            cardStates[key]?.isQuickEditing = false
            cardStates[key]?.isExpanded = false
        }
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        // Enter reorder mode
        isReorderMode = true
    }
}

// MARK: - Exercise Card Component

struct ExerciseCard: View {
    @Binding var editable: EditableExercise
    let exerciseName: String
    let exerciseEntities: [ExerciseEntity]
    let defaultRestTime: Double
    let onDelete: () -> Void

    @State private var isExpanded = true
    @Environment(\.editMode) private var editMode

    // Hilfsvariable: Finde die aktuelle Exercise
    private var currentExercise: Exercise? {
        guard let entity = exerciseEntities.first(where: { $0.id == editable.exerciseId }) else {
            return nil
        }
        return Exercise(entity: entity)
    }

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
                            exercise: currentExercise,
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
                            let newSet = EditableSet(
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
    @Binding var set: EditableSet
    let exercise: Exercise?
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Set Number
            Text("\(setNumber)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
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

            // Weight OR Time Input (abhängig vom Übungstyp)
            if exercise?.isCardio == true {
                // Cardio: Zeit in Minuten
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zeit (min)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextField("0", value: Binding(
                        get: { Int((set.duration ?? 0) / 60) },
                        set: { set.duration = TimeInterval($0 * 60) }
                    ), format: .number)
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 80)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
            } else {
                // Kraft: Gewicht in kg
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

import SwiftUI

// MARK: - Collapsed Exercise Row

struct CollapsedExerciseRow: View {
    let exerciseName: String
    let setCount: Int
    let avgReps: Int
    let avgWeight: Double
    let isReorderMode: Bool
    let onTap: () -> Void
    let onToggleExpand: () -> Void
    let onLongPress: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Drag Handle (always visible for familiarity)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 30)
                .onLongPressGesture(minimumDuration: 0.5) {
                    onLongPress()
                }

            // Exercise Info - Tappable for quick edit
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(setCount) Sätze • \(avgReps) WDH • \(avgWeight, specifier: "%.1f")kg")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Expand/Collapse Toggle
            if !isReorderMode {
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(0)) // Will animate
                }

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
    }
}

// MARK: - Quick Edit View

struct QuickEditView: View {
    @Binding var sets: Int
    @Binding var reps: Int
    @Binding var weight: Double
    let onApply: () -> Void
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Für alle Sätze")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // Sätze
                VStack(spacing: 6) {
                    Text("Sätze")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.6))
                    TextField("3", value: $sets, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(width: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                        .onChange(of: sets) { _, _ in onApply() }
                }

                // WDH
                VStack(spacing: 6) {
                    Text("WDH")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.6))
                    TextField("10", value: $reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(width: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                        .onChange(of: reps) { _, _ in onApply() }
                }

                // Gewicht
                VStack(spacing: 6) {
                    Text("Gewicht")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.6))
                    HStack(spacing: 4) {
                        TextField("80", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(12)
                            .frame(width: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .onChange(of: weight) { _, _ in onApply() }
                        Text("kg")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
            }

            // Link to individual edit
            Button(action: onExpand) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                    Text("Sätze einzeln bearbeiten")
                        .font(.caption)
                }
                .foregroundStyle(AppTheme.turquoiseBoost)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Expanded Set List View

struct ExpandedSetListView: View {
    @Binding var sets: [EditableSet]
    let defaultRestTime: Double
    let onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            headerView
            tableHeaderView
            setListView
            addSetButton
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var headerView: some View {
        HStack {
            Text("Einzelne Sätze")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))

            Spacer()

            Button(action: onCollapse) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                    Text("Einklappen")
                        .font(.caption)
                }
                .foregroundStyle(AppTheme.turquoiseBoost)
            }
        }
    }

    private var tableHeaderView: some View {
        HStack(spacing: 8) {
            Text("Satz")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.5))
                .frame(width: 40, alignment: .leading)

            Text("WDH")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.5))
                .frame(width: 55, alignment: .center)

            Text("kg")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.5))
                .frame(width: 60, alignment: .center)

            Text("Pause")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.5))
                .frame(width: 55, alignment: .center)

            Spacer()
                .frame(width: 24)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(6)
    }

    private var setListView: some View {
        ForEach(sets) { set in
            if let index = sets.firstIndex(where: { $0.id == set.id }) {
                SetRowEditView(
                    setNumber: index + 1,
                    set: $sets[index],
                    onDelete: {
                        withAnimation {
                            sets.removeAll { $0.id == set.id }
                        }
                    }
                )
            }
        }
    }

    private var addSetButton: some View {
        Button(action: {
            let lastSet = sets.last ?? EditableSet(reps: 10, weight: 80, restTime: defaultRestTime)
            sets.append(EditableSet(reps: lastSet.reps, weight: lastSet.weight, restTime: defaultRestTime))
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("Satz hinzufügen")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.mossGreen)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Set Row Edit View

struct SetRowEditView: View {
    let setNumber: Int
    @Binding var set: EditableSet
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            setNumberView
            repsField
            weightField
            restTimeField
            Spacer()
            deleteButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var setNumberView: some View {
        Text("\(setNumber)")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary.opacity(0.7))
            .frame(width: 40, alignment: .leading)
    }

    private var repsField: some View {
        TextField("10", value: $set.reps, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(6)
            .frame(width: 55)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
            )
    }

    private var weightField: some View {
        TextField("80", value: $set.weight, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(6)
            .frame(width: 60)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
            )
    }

    private var restTimeField: some View {
        TextField("90", value: $set.restTime, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(6)
            .frame(width: 55)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
            )
    }

    private var deleteButton: some View {
        Button {
            onDelete()
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.red.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reorder Mode Overlay

struct ReorderModeOverlay: View {
    @Binding var exercises: [EditableExercise]
    let exerciseNames: [UUID: String]
    let onExit: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onExit() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Übungen neu anordnen")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button(action: onExit) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.mossGreen)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)

                // Draggable List
                List {
                    ForEach(exercises, id: \.id) { exercise in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)

                            Text(exerciseNames[exercise.exerciseId] ?? "Unknown")
                                .font(.system(size: 16, weight: .medium))

                            Spacer()

                            Text("\(exercise.sets.count) Sätze")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(AppTheme.cardBackground)
                    }
                    .onMove { from, to in
                        exercises.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .background(AppTheme.background)
            .cornerRadius(20)
            .padding(.horizontal, 20)
            .padding(.vertical, 60)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
