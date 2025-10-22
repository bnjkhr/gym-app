import SwiftData
import SwiftUI
import UIKit

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutStore: WorkoutStoreCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entity: WorkoutEntity
    @State private var workout: Workout

    var isActiveSession: Bool = false
    var onActiveSessionEnd: (() -> Void)? = nil

    init(
        entity: WorkoutEntity, isActiveSession: Bool = false,
        onActiveSessionEnd: (() -> Void)? = nil
    ) {
        self.entity = entity

        // Map exercises from entity to avoid empty array after app restart
        let sortedExercises = entity.exercises.sorted { $0.order < $1.order }
        let mappedExercises: [WorkoutExercise] = sortedExercises.compactMap { we in
            guard let exEntity = we.exercise else { return nil }
            let groups = exEntity.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
            let equipmentType = EquipmentType(rawValue: exEntity.equipmentTypeRaw) ?? .mixed
            let difficultyLevel =
                DifficultyLevel(rawValue: exEntity.difficultyLevelRaw) ?? .anfänger
            let exercise = Exercise(
                id: exEntity.id,
                name: exEntity.name,
                muscleGroups: groups,
                equipmentType: equipmentType,
                difficultyLevel: difficultyLevel,
                description: exEntity.descriptionText,
                instructions: exEntity.instructions,
                createdAt: exEntity.createdAt
            )
            let sets = we.sets.map { ExerciseSet(entity: $0) }
            return WorkoutExercise(id: we.id, exercise: exercise, sets: sets)
        }

        self._workout = State(
            initialValue: Workout(
                id: entity.id,
                name: entity.name,
                date: entity.date,
                exercises: mappedExercises,
                defaultRestTime: entity.defaultRestTime,
                duration: entity.duration,
                notes: entity.notes,
                isFavorite: entity.isFavorite
            ))
        self.isActiveSession = isActiveSession
        self.onActiveSessionEnd = onActiveSessionEnd
    }

    @State private var showingCompletionSheet = false
    @State private var completionDuration: TimeInterval = 0
    @State private var showingCompletionConfirmation = false
    @State private var showingReorderSheet = false
    @State private var selectedTab: ProgressTab = .overview
    @State private var editingNotes = false
    @State private var notesText = ""

    enum ProgressTab: String, CaseIterable {
        case overview = "Überblick"
        case progress = "Fortschritt"
        case changes = "Veränderung"
    }

    var body: some View {
        Group {
            if isActiveSession {
                // New horizontal swipe interface for active workouts
                ActiveWorkoutNavigationView(
                    workout: $workout,
                    workoutStore: workoutStore,
                    activeRestForThisWorkout: activeRestForThisWorkout,
                    isActiveRest: isActiveRest,
                    hasActiveRestState: hasActiveRestState,
                    toggleCompletion: toggleCompletion,
                    addSet: addSet,
                    removeSet: removeSet,
                    updateEntitySet: updateEntitySet,
                    appendEntitySet: appendEntitySet,
                    removeEntitySet: removeEntitySet,
                    previousValues: previousValues,
                    completeWorkout: completeWorkout,
                    hasExercises: hasExercises,
                    reorderEntityExercises: { exercises in
                        reorderEntityExercises(to: exercises)
                    },
                    finalizeCompletion: finalizeCompletion,
                    onActiveSessionEnd: onActiveSessionEnd
                )
                .navigationTitle(workout.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                // Original list-based interface for non-active workouts
                List {
                    // Tab selector
                    progressTabSelector

                    // Selected tab content
                    selectedTabContent

                    // Divider before exercises
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 0.5)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    exerciseSections

                    if isActiveSession && hasExercises {
                        // Divider before completion
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 0.5)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                        completionSection
                    }

                    // Notes section - always visible
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 0.5)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    Section("Notizen") {
                        if editingNotes {
                            VStack(alignment: .leading, spacing: 12) {
                                TextEditor(text: $notesText)
                                    .frame(minHeight: 80)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )

                                HStack {
                                    Button("Abbrechen") {
                                        notesText = workout.notes
                                        editingNotes = false
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Button("Speichern") {
                                        let trimmed = notesText.trimmingCharacters(
                                            in: .whitespacesAndNewlines)
                                        workout.notes = trimmed
                                        updateEntityNotes(trimmed)
                                        editingNotes = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppTheme.mossGreen)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                if workout.notes.isEmpty {
                                    Text("Tippe hier, um Notizen hinzuzufügen...")
                                        .foregroundStyle(.secondary)
                                        .italic()
                                } else {
                                    Text(workout.notes)
                                        .foregroundStyle(.primary)
                                }

                                Button {
                                    notesText = workout.notes
                                    editingNotes = true
                                } label: {
                                    HStack {
                                        Image(
                                            systemName: workout.notes.isEmpty
                                                ? "plus.circle" : "pencil")
                                        Text(
                                            workout.notes.isEmpty
                                                ? "Notizen hinzufügen" : "Notizen bearbeiten")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.turquoiseBoost)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationTitle(workout.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            // Safely remap the entity from the current ModelContext to avoid reading invalid snapshots
            let currentId = entity.id
            let descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate<WorkoutEntity> { workout in
                    workout.id == currentId
                })
            if let fresh = try? modelContext.fetch(descriptor).first {
                // Map exercises directly without batch fetching (SwiftData relationship issue)
                var mappedExercises: [WorkoutExercise] = []
                // Sort exercises by order to maintain correct sequence
                let sortedExercises = fresh.exercises.sorted { $0.order < $1.order }
                for we in sortedExercises {
                    if let exEntity = we.exercise {
                        let groups = exEntity.muscleGroupsRaw.compactMap {
                            MuscleGroup(rawValue: $0)
                        }
                        let equipmentType =
                            EquipmentType(rawValue: exEntity.equipmentTypeRaw) ?? .mixed
                        let difficultyLevel =
                            DifficultyLevel(rawValue: exEntity.difficultyLevelRaw) ?? .anfänger
                        let exercise = Exercise(
                            id: exEntity.id,
                            name: exEntity.name,
                            muscleGroups: groups,
                            equipmentType: equipmentType,
                            difficultyLevel: difficultyLevel,
                            description: exEntity.descriptionText,
                            instructions: exEntity.instructions,
                            createdAt: exEntity.createdAt
                        )
                        let sets = we.sets.map { ExerciseSet(entity: $0) }
                        mappedExercises.append(
                            WorkoutExercise(id: we.id, exercise: exercise, sets: sets))
                    }
                }

                self.workout = Workout(
                    id: fresh.id,
                    name: fresh.name,
                    date: fresh.date,
                    exercises: mappedExercises,
                    defaultRestTime: fresh.defaultRestTime,
                    duration: fresh.duration,
                    notes: fresh.notes,
                    isFavorite: fresh.isFavorite
                )
            }
            notesText = workout.notes
            if isActiveSession {
                WorkoutLiveActivityController.shared.start(
                    workoutId: workout.id, workoutName: workout.name)
            }
        }
        .sheet(isPresented: $showingCompletionSheet) {
            WorkoutCompletionSummaryView(
                name: workout.name,
                durationText: formattedDurationText,
                totalVolumeText: totalVolumeValueText,
                progressText: progressDeltaText
            ) {
                showingCompletionSheet = false
                dismiss()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingReorderSheet, onDismiss: nil) {
            ReorderExercisesSheet(
                exercises: workout.exercises,
                onCancel: {
                    showingReorderSheet = false
                },
                onSave: { reorderedExercises in
                    workout.exercises = reorderedExercises
                    reorderEntityExercises(to: reorderedExercises)
                    showingReorderSheet = false
                }
            )
        }

    }

    // MARK: - Tab Interface

    private var progressTabSelector: some View {
        Section {
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    ForEach(ProgressTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(selectedTab == tab ? Color.white : Color.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedTab == tab ? AppTheme.mossGreen : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: -35, leading: 16, bottom: -8, trailing: 16))
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        Section {
            switch selectedTab {
            case .overview:
                summaryContent
            case .progress:
                progressContent
            case .changes:
                changesContent
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    private var summaryContent: some View {
        VStack(spacing: 6) {
            summaryRow(title: "Volumen", value: totalVolumeValueText)
        }
        .padding(.vertical, -6)
    }

    private var progressContent: some View {
        VStack(spacing: 6) {
            HStack {
                summaryRow(title: "Letztes Gewicht", value: previousVolumeValueText)
                summaryRow(title: "Letztes Datum", value: previousDateText)
                summaryRow(title: "Übungen zuletzt", value: previousExerciseCountText)
            }

            // Personal Records Summary
            if !personalRecordsSummary.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                VStack(spacing: 4) {
                    Text("Personal Records")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4
                    ) {
                        ForEach(personalRecordsSummary, id: \.id) { record in
                            VStack(spacing: 2) {
                                Text(record.exerciseName)
                                    .font(.caption2)
                                    .lineLimit(1)

                                if record.maxWeight > 0 {
                                    Text("\(String(format: "%.0f", record.maxWeight)) kg")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("–")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, -6)
    }

    private var changesContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Gewicht")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(progressDeltaText)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
            }
            HStack {
                Text("Wiederholungen")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(repsDeltaText)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, -6)
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var exerciseSections: some View {
        ForEach(workout.exercises.indices, id: \.self) { exerciseIndex in
            exerciseSection(at: exerciseIndex)
        }
    }

    @ViewBuilder
    private func exerciseSection(at exerciseIndex: Int) -> some View {
        Section {
            ForEach(Array(workout.exercises[exerciseIndex].sets.enumerated()), id: \.element.id) {
                element in
                setRow(exerciseIndex: exerciseIndex, setIndex: element.offset)
            }

            addSetButton(for: exerciseIndex)
        } header: {
            exerciseHeader(for: exerciseIndex)
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func setRow(exerciseIndex: Int, setIndex: Int) -> some View {
        let previous = previousValues(for: exerciseIndex, setIndex: setIndex)
        let setBinding = createSetBinding(exerciseIndex: exerciseIndex, setIndex: setIndex)

        WorkoutSetCard(
            index: setIndex,
            set: setBinding,
            isActiveRest: isActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex),
            remainingSeconds: activeRestForThisWorkout?.remainingSeconds ?? 0,
            previousReps: previous.reps,
            previousWeight: previous.weight,
            currentExercise: workout.exercises[exerciseIndex].exercise,
            workoutStore: workoutStore,
            onRestTimeUpdated: { newValue in
                handleRestTimeUpdate(
                    exerciseIndex: exerciseIndex, setIndex: setIndex, newValue: newValue)
            },
            onToggleCompletion: {
                toggleCompletion(for: exerciseIndex, setIndex: setIndex)
            }
        )
        .listRowSeparator(.hidden)
        .id("exercise_\(exerciseIndex)_set_\(setIndex)")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                removeSet(at: setIndex, for: exerciseIndex)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func addSetButton(for exerciseIndex: Int) -> some View {
        Button {
            addSet(to: exerciseIndex)
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Satz hinzufügen")
        .buttonStyle(.bordered)
        .tint(AppTheme.mossGreen)
    }

    @ViewBuilder
    private func exerciseHeader(for exerciseIndex: Int) -> some View {
        ExerciseHeaderWithLastUsed(
            exercise: workout.exercises[exerciseIndex].exercise,
            workoutStore: workoutStore,
            isActiveSession: isActiveSession,
            onQuickFill: { weight, reps in
                quickFillExercise(exerciseIndex: exerciseIndex, weight: weight, reps: reps)
            },
            onLongPress: {
                prepareReorder()
            }
        )
        .padding(.vertical, 4)
    }

    private func createSetBinding(exerciseIndex: Int, setIndex: Int) -> Binding<ExerciseSet> {
        Binding(
            get: { workout.exercises[exerciseIndex].sets[setIndex] },
            set: {
                workout.exercises[exerciseIndex].sets[setIndex] = $0
                let exId = workout.exercises[exerciseIndex].id
                let setId = workout.exercises[exerciseIndex].sets[setIndex].id
                let newSet = workout.exercises[exerciseIndex].sets[setIndex]
                updateEntitySet(exerciseId: exId, setId: setId) { setEntity in
                    setEntity.reps = newSet.reps
                    setEntity.weight = newSet.weight
                }
            }
        )
    }

    private func handleRestTimeUpdate(exerciseIndex: Int, setIndex: Int, newValue: Double) {
        if isActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex) {
            workoutStore.setRest(remaining: Int(newValue), total: Int(newValue))
        }
        let exId = workout.exercises[exerciseIndex].id
        let setId = workout.exercises[exerciseIndex].sets[setIndex].id
        updateEntitySet(exerciseId: exId, setId: setId) { setEntity in
            setEntity.restTime = newValue
        }
    }

    private var completionSection: some View {
        Section {
            if showingCompletionConfirmation {
                VStack(spacing: 8) {
                    Text("Workout abschließen?")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 12) {
                        Button("Abbrechen", role: .destructive) {
                            showingCompletionConfirmation = false
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.powerOrange)

                        Button("Abschließen") {
                            finalizeCompletion()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.mossGreen)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }

            Button(action: completeWorkout) {
                HStack {
                    Spacer()
                    Label("Workout abschließen", systemImage: "checkmark.seal.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.white)
                        .font(.headline.weight(.semibold))
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.mossGreen)
            .controlSize(.large)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .id("completionSection")
    }

    // MARK: - Computed Properties

    private var totalVolume: Double {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private var totalVolumeValueText: String {
        "\(Int(totalVolume)) kg"
    }

    private var previousVolumeValueText: String {
        guard let previousVolume else { return "–" }
        return "\(Int(previousVolume)) kg"
    }

    private var previousDateText: String {
        if let prev = previousSessionSwiftData() {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.setLocalizedDateFormatFromTemplate("ddMMMy")
            return formatter.string(from: prev.date)
        }
        return "–"
    }

    private var previousExerciseCountText: String {
        if let prev = previousSessionSwiftData() {
            return "\(prev.exercises.count)"
        }
        return "–"
    }

    private var currentTotalReps: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
    }

    private var previousTotalReps: Int? {
        if let prev = previousSessionSwiftData() {
            return prev.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
        }
        return nil
    }

    private var progressDeltaText: String {
        guard let previousVolume else {
            return "Neu: kein Vergleich"
        }

        let delta = totalVolume - previousVolume
        let formattedDelta = Int(delta.magnitude)

        if delta == 0 {
            return "Gleich wie zuletzt"
        } else if delta > 0 {
            return "+\(formattedDelta) kg vs. letzte Session"
        } else {
            return "-\(formattedDelta) kg vs. letzte Session"
        }
    }

    private var repsDeltaText: String {
        guard let prevReps = previousTotalReps else {
            return "Neu: kein Vergleich"
        }
        let delta = currentTotalReps - prevReps
        if delta == 0 {
            return "Gleich wie zuletzt"
        } else if delta > 0 {
            return "+\(delta) Wdh. vs. letzte Session"
        } else {
            return "\(delta) Wdh. vs. letzte Session"
        }
    }

    private var personalRecordsSummary: [ExerciseRecord] {
        let exercisesInWorkout = workout.exercises.map { $0.exercise }
        return exercisesInWorkout.compactMap { exercise in
            workoutStore.getExerciseRecord(for: exercise)
        }
    }

    private var hasExercises: Bool {
        workout.exercises.contains { !$0.sets.isEmpty }
    }

    private var activeRestForThisWorkout: RestTimerState? {
        guard let state = workoutStore.restTimerStateManager.currentState,
            state.workoutId == workout.id
        else {
            return nil
        }
        return state
    }

    private var formattedDurationText: String {
        let duration = completionDuration > 0 ? completionDuration : (workout.duration ?? 0)
        guard duration > 0 else { return "–" }
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return seconds > 0 ? "\(minutes) min \(seconds) s" : "\(minutes) min"
        }
        return "\(seconds) s"
    }

    private var previousVolume: Double? {
        if let prev = previousSessionSwiftData() {
            let volume = prev.exercises.reduce(0) { partialResult, exercise in
                partialResult + exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
            }
            return volume
        }
        return nil
    }

    // MARK: - Helper Functions

    private func isActiveRest(exerciseIndex: Int, setIndex: Int) -> Bool {
        guard let state = activeRestForThisWorkout else { return false }
        return state.exerciseIndex == exerciseIndex && state.setIndex == setIndex
            && state.phase == .running
    }

    private func hasActiveRestState(exerciseIndex: Int, setIndex: Int) -> Bool {
        guard let state = activeRestForThisWorkout else { return false }
        return state.exerciseIndex == exerciseIndex && state.setIndex == setIndex
    }

    private func previousSessionSwiftData() -> WorkoutSessionV1? {
        let templateId: UUID? = workout.id
        let currentDate = workout.date
        let searchDate = isActiveSession ? Date() : currentDate

        let predicate = #Predicate<WorkoutSessionEntityV1> { entity in
            (entity.templateId == templateId) && (entity.date < searchDate)
        }
        var descriptor = FetchDescriptor<WorkoutSessionEntityV1>(
            predicate: predicate,
            sortBy: [SortDescriptor<WorkoutSessionEntityV1>(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            let entities = try modelContext.fetch(descriptor)
            if let entity = entities.first {
                return WorkoutSessionV1(entity: entity, in: modelContext)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    private func previousValues(for exerciseIndex: Int, setIndex: Int) -> (
        reps: Int?, weight: Double?
    ) {
        let currentExercise = workout.exercises[exerciseIndex].exercise

        // Use last-used metrics first (fast)
        if let lastUsedMetrics = workoutStore.completeLastMetrics(for: currentExercise),
            let weight = lastUsedMetrics.weight,
            let reps = lastUsedMetrics.reps
        {
            return (reps, weight)
        }

        // Fallback: Legacy method via session history
        return legacyPreviousValues(for: exerciseIndex, setIndex: setIndex)
    }

    private func legacyPreviousValues(for exerciseIndex: Int, setIndex: Int) -> (
        reps: Int?, weight: Double?
    ) {
        guard let prev = previousSessionSwiftData() else {
            return (nil, nil)
        }

        let currentExercise = workout.exercises[exerciseIndex].exercise
        guard
            let previousExercise = prev.exercises.first(where: {
                $0.exercise.id == currentExercise.id
            })
        else {
            return (nil, nil)
        }

        let sets = previousExercise.sets
        if sets.indices.contains(setIndex) {
            let reps = sets[setIndex].reps
            let weight = sets[setIndex].weight
            return (reps, weight)
        } else if let last = sets.last {
            return (last.reps, last.weight)
        } else {
            return (nil, nil)
        }
    }

    // MARK: - Actions

    private func toggleCompletion(for exerciseIndex: Int, setIndex: Int) {
        workout.exercises[exerciseIndex].sets[setIndex].completed.toggle()
        let exId = workout.exercises[exerciseIndex].id
        let setId = workout.exercises[exerciseIndex].sets[setIndex].id
        let completed = workout.exercises[exerciseIndex].sets[setIndex].completed

        updateEntitySet(exerciseId: exId, setId: setId) { setEntity in
            setEntity.completed = completed
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if workout.exercises[exerciseIndex].sets[setIndex].completed {
                let rest = Int(workout.exercises[exerciseIndex].sets[setIndex].restTime.rounded())
                workoutStore.startRest(
                    for: workout, exerciseIndex: exerciseIndex, setIndex: setIndex,
                    totalSeconds: rest)

                // Check if this was the last set of the current exercise
                if setIndex == workout.exercises[exerciseIndex].sets.count - 1 {
                    // This is the last set of this exercise
                    // Auto-advance to next exercise with visual feedback (only in active session)
                    if isActiveSession && exerciseIndex < workout.exercises.count - 1 {
                        // Add a small delay and then navigate with animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Trigger haptic feedback for smooth transition
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()

                            // Navigate to next exercise with notification
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToNextExercise"),
                                object: nil,
                                userInfo: ["nextExerciseIndex": exerciseIndex + 1]
                            )
                        }
                    } else if isActiveSession {
                        // This is the last set of the last exercise - navigate to completion
                        // Add a small delay and then navigate to completion with animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Trigger haptic feedback for completion
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()

                            // Navigate to workout completion screen
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToWorkoutCompletion"),
                                object: nil,
                                userInfo: [:]
                            )
                        }
                    }
                }
            } else if let state = activeRestForThisWorkout,
                state.exerciseIndex == exerciseIndex,
                state.setIndex == setIndex
            {
                workoutStore.stopRest()
            }
        }
    }

    private func completeWorkout() {
        showingCompletionConfirmation = true
    }

    private func finalizeCompletion() {
        workoutStore.stopRest()
        let elapsed = max(Date().timeIntervalSince(workout.date), 0)

        // Create a session workout with completion data for recording
        var sessionWorkout = workout
        sessionWorkout.duration = elapsed

        // Save the session record with current workout data
        print("💾 Speichere Session über WorkoutStore.recordSession")
        workoutStore.recordSession(from: sessionWorkout)

        // NOW reset the template: Update entity with current exercise structure but reset set completion
        resetWorkoutTemplateAfterCompletion()

        // End Live Activity when workout is completed
        if isActiveSession {
            WorkoutLiveActivityController.shared.end()
            print("🏁 Live Activity beendet nach Workout-Abschluss")
        }

        completionDuration = elapsed

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        showingCompletionSheet = true
        showingCompletionConfirmation = false

        // End the active session and navigate back
        if isActiveSession {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onActiveSessionEnd?()
            }
        }
    }

    private func resetWorkoutTemplateAfterCompletion() {
        // Update the template with current workout structure but reset completion states
        var templateWorkout = workout
        templateWorkout.duration = nil  // Reset duration for template
        templateWorkout.date = Date()  // Reset date to current time for future sessions

        // Reset all set completion states but keep the weights/reps
        for exerciseIndex in templateWorkout.exercises.indices {
            for setIndex in templateWorkout.exercises[exerciseIndex].sets.indices {
                templateWorkout.exercises[exerciseIndex].sets[setIndex].completed = false
            }
        }

        // Save the updated template
        workoutStore.updateWorkout(templateWorkout)
        print("🔄 Workout-Template für zukünftige Sessions zurückgesetzt")
    }

    private func addSet(to exerciseIndex: Int) {
        let templateSet = workout.exercises[exerciseIndex].sets.last
        let newSet = ExerciseSet(
            reps: templateSet?.reps ?? 0,
            weight: templateSet?.weight ?? 0,
            restTime: templateSet?.restTime ?? workout.defaultRestTime,
            completed: false
        )
        workout.exercises[exerciseIndex].sets.append(newSet)
        let exerciseId = workout.exercises[exerciseIndex].id
        if let last = workout.exercises[exerciseIndex].sets.last {
            appendEntitySet(exerciseId: exerciseId, newSet: last)
        }
    }

    private func removeSet(at setIndex: Int, for exerciseIndex: Int) {
        guard workout.exercises.indices.contains(exerciseIndex) else { return }
        guard workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }

        let isActive =
            activeRestForThisWorkout?.exerciseIndex == exerciseIndex
            && activeRestForThisWorkout?.setIndex == setIndex

        // Capture id for entity removal
        let setId = workout.exercises[exerciseIndex].sets[setIndex].id
        let exerciseId = workout.exercises[exerciseIndex].id

        workout.exercises[exerciseIndex].sets.remove(at: setIndex)

        removeEntitySet(exerciseId: exerciseId, setId: setId)

        if isActive {
            workoutStore.stopRest()
        } else if let state = activeRestForThisWorkout,
            state.exerciseIndex == exerciseIndex,
            state.setIndex >= workout.exercises[exerciseIndex].sets.count
        {
            workoutStore.stopRest()
        }
    }

    private func quickFillExercise(exerciseIndex: Int, weight: Double, reps: Int) {
        // Fill all incomplete sets with the provided values
        for setIndex in workout.exercises[exerciseIndex].sets.indices {
            if !workout.exercises[exerciseIndex].sets[setIndex].completed {
                workout.exercises[exerciseIndex].sets[setIndex].weight = weight
                workout.exercises[exerciseIndex].sets[setIndex].reps = reps

                let exId = workout.exercises[exerciseIndex].id
                let setId = workout.exercises[exerciseIndex].sets[setIndex].id
                updateEntitySet(exerciseId: exId, setId: setId) { setEntity in
                    setEntity.weight = weight
                    setEntity.reps = reps
                }
            }
        }
    }

    private func prepareReorder() {
        showingReorderSheet = true
    }

    // MARK: - Entity Persistence

    private func updateEntityNotes(_ notes: String) {
        entity.notes = notes
        do {
            try modelContext.save()
        } catch {
            print("❌ Fehler beim Speichern der Notizen: \(error)")
        }
    }

    private func updateEntitySet(exerciseId: UUID, setId: UUID, mutate: (ExerciseSetEntity) -> Void)
    {
        if let ex = entity.exercises.first(where: { $0.id == exerciseId }),
            let set = ex.sets.first(where: { $0.id == setId })
        {
            mutate(set)
            do {
                try modelContext.save()
            } catch {
                print("❌ Fehler beim Speichern des Satzes: \(error)")
            }
        }
    }

    private func appendEntitySet(exerciseId: UUID, newSet: ExerciseSet) {
        if let ex = entity.exercises.first(where: { $0.id == exerciseId }) {
            let e = ExerciseSetEntity(
                id: newSet.id, reps: newSet.reps, weight: newSet.weight, restTime: newSet.restTime,
                completed: newSet.completed)
            ex.sets.append(e)
            do {
                try modelContext.save()
                print("✅ Neuer Satz hinzugefügt")
            } catch {
                print("❌ Fehler beim Hinzufügen des Satzes: \(error)")
            }
        }
    }

    private func removeEntitySet(exerciseId: UUID, setId: UUID) {
        if let exIndex = entity.exercises.firstIndex(where: { $0.id == exerciseId }) {
            if let setIndex = entity.exercises[exIndex].sets.firstIndex(where: { $0.id == setId }) {
                let setEntity = entity.exercises[exIndex].sets.remove(at: setIndex)
                modelContext.delete(setEntity)
                do {
                    try modelContext.save()
                    print("✅ Satz gelöscht")
                } catch {
                    print("❌ Fehler beim Löschen des Satzes: \(error)")
                }
            }
        }
    }

    private func reorderEntityExercises(to newOrder: [WorkoutExercise]) {
        let lookup: [UUID: WorkoutExerciseEntity] = Dictionary(
            uniqueKeysWithValues: entity.exercises.map { ($0.id, $0) })
        entity.exercises = newOrder.compactMap { lookup[$0.id] }
        do {
            try modelContext.save()
            print("✅ Übungsreihenfolge gespeichert")
        } catch {
            print("❌ Fehler beim Speichern der Reihenfolge: \(error)")
        }
    }
}

// MARK: - Compatibility Extensions

extension View {
    @ViewBuilder
    fileprivate func onChangeCompat<Value: Equatable>(
        of value: Value, perform action: @escaping (Value) -> Void
    ) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value, initial: false) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

extension UIFont {
    fileprivate func rounded() -> UIFont {
        if let descriptor = self.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return self
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WorkoutEntity.self, WorkoutExerciseEntity.self, ExerciseSetEntity.self,
        ExerciseEntity.self, WorkoutSessionEntity.self, UserProfileEntity.self,
        configurations: config)
    let exercise = ExerciseEntity(id: UUID(), name: "Bankdrücken")
    let set = ExerciseSetEntity(id: UUID(), reps: 10, weight: 60, restTime: 90, completed: false)
    let we = WorkoutExerciseEntity(id: UUID(), exercise: exercise, sets: [set])
    let workout = WorkoutEntity(
        id: UUID(), name: "Push Day", exercises: [we], defaultRestTime: 90, notes: "Preview")
    container.mainContext.insert(workout)
    return NavigationStack {
        WorkoutDetailView(entity: workout, isActiveSession: true)
            .environmentObject(WorkoutStore())
    }
    .modelContainer(container)
}
