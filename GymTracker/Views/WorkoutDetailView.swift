import SwiftUI
import UIKit
import SwiftData





// MARK: - MuscleGroup Extension
extension MuscleGroup {
    var displayName: String {
        switch self {
        case .chest: return "Brust"
        case .back: return "Rücken"
        case .shoulders: return "Schultern"
        case .biceps: return "Bizeps"
        case .triceps: return "Trizeps"
        case .legs: return "Beine"
        case .glutes: return "Gesäß"
        case .abs: return "Bauch"
        case .cardio: return "Cardio"
        case .forearms: return "Unterarme"
        case .calves: return "Waden"
        case .trapezius: return "Trapezmuskel"
        case .lowerBack: return "Unterer Rücken"
        case .upperBack: return "Oberer Rücken"
        case .fullBody: return "Ganzkörper"
        case .hips: return "Hüfte"
        case .core: return "Rumpf"
        case .hamstrings: return "Beinbeuger"
        case .lats: return "Latissimus"
        case .grip: return "Griffkraft"
        case .arms: return "Arme"
        case .adductors: return "Adduktoren"
        case .obliques: return "Schräge Bauchmuskeln"
        case .hipFlexors: return "Hüftbeuger"
        case .traps: return "Trapez"
        case .coordination: return "Koordination"
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entity: WorkoutEntity
    @State private var workout: Workout

    var isActiveSession: Bool = false
    var onActiveSessionEnd: (() -> Void)? = nil

    init(entity: WorkoutEntity, isActiveSession: Bool = false, onActiveSessionEnd: (() -> Void)? = nil) {
        self.entity = entity
        self._workout = State(initialValue: Workout(
            id: entity.id,
            name: entity.name,
            date: entity.date,
            exercises: [],
            defaultRestTime: entity.defaultRestTime,
            duration: entity.duration,
            notes: entity.notes,
            isFavorite: entity.isFavorite
        ))
        self.isActiveSession = isActiveSession
        self.onActiveSessionEnd = onActiveSessionEnd
    }

    // Lokaler Timer-State entfernt – wir nutzen den zentralen Store
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

                    if let activeRest = activeRestForThisWorkout, activeRest.remainingSeconds > 0 || activeRest.isRunning {
                        // Divider before rest timer
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 0.5)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                        restTimerSection(activeRest: activeRest)
                            .id("activeRest")
                    }

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
                                        let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                                        Image(systemName: workout.notes.isEmpty ? "plus.circle" : "pencil")
                                        Text(workout.notes.isEmpty ? "Notizen hinzufügen" : "Notizen bearbeiten")
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
            let descriptor = FetchDescriptor<WorkoutEntity>(predicate: #Predicate<WorkoutEntity> { workout in
                workout.id == currentId
            })
            if let fresh = try? modelContext.fetch(descriptor).first {
                // Map exercises directly without batch fetching (SwiftData relationship issue)
                var mappedExercises: [WorkoutExercise] = []
                // Sort exercises by order to maintain correct sequence
                let sortedExercises = fresh.exercises.sorted { $0.order < $1.order }
                for we in sortedExercises {
                    if let exEntity = we.exercise {
                        let groups = exEntity.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
                        let equipmentType = EquipmentType(rawValue: exEntity.equipmentTypeRaw) ?? .mixed
                        let difficultyLevel = DifficultyLevel(rawValue: exEntity.difficultyLevelRaw) ?? .anfänger
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
                        mappedExercises.append(WorkoutExercise(id: we.id, exercise: exercise, sets: sets))
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
                WorkoutLiveActivityController.shared.start(workoutName: workout.name)
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
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
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

    private func restTimerSection(activeRest: WorkoutStore.ActiveRestState) -> some View {
        Section("Pause") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Aktive Pause: \(activeRest.setIndex + 1) • \(workout.exercises[safe: activeRest.exerciseIndex]?.exercise.name ?? "Übung")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(formatTime(activeRest.remainingSeconds))
                    .font(.system(size: activeRest.isRunning ? 36 : 28, weight: .bold))
                    .contentTransition(.numericText())
                    .monospacedDigit()
                    .animation(.easeInOut(duration: 0.2), value: activeRest.isRunning)

                HStack(spacing: 4) {
                    if activeRest.isRunning {
                        Button(role: .cancel) {
                            workoutStore.pauseRest()
                        } label: {
                            Text("Anhalten")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppTheme.powerOrange, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            workoutStore.addRest(seconds: 15)
                        } label: {
                            Text("+15s")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppTheme.turquoiseBoost, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            workoutStore.stopRest()
                        } label: {
                            Text("Beenden")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppTheme.powerOrange, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Timer pausiert
                        Button {
                            workoutStore.resumeRest()
                        } label: {
                            Text("Fortsetzen")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppTheme.mossGreen, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            workoutStore.stopRest()
                        } label: {
                            Text("Beenden")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppTheme.powerOrange, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: activeRest.isRunning)
            }
        }
        .listRowBackground(Color.clear)
    }

    private var exerciseSections: some View {
        ForEach(workout.exercises.indices, id: \.self) { exerciseIndex in
            exerciseSection(at: exerciseIndex)
        }
    }
    
    @ViewBuilder
    private func exerciseSection(at exerciseIndex: Int) -> some View {
        Section {
            ForEach(Array(workout.exercises[exerciseIndex].sets.enumerated()), id: \.element.id) { element in
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
                handleRestTimeUpdate(exerciseIndex: exerciseIndex, setIndex: setIndex, newValue: newValue)
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

    private var durationText: String {
        if let duration = workout.duration {
            return "\(Int(duration / 60)) Minuten"
        }
        return "Dauer offen"
    }

    private var workoutTotalSets: Int {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.count
        }
    }

    private var totalVolume: Double {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private var totalVolumeText: String {
        "Volumen: \(totalVolumeValueText)"
    }

    private var totalVolumeValueText: String {
        "\(Int(totalVolume)) kg"
    }

    // MARK: - Previous session via SwiftData (fallback to store if unavailable)
    private func previousSessionSwiftData() -> WorkoutSession? {
        let templateId: UUID? = workout.id
        let currentDate = workout.date
        
        // Für aktive Sessions: Verwende das aktuelle Datum statt des Workout-Datums
        let searchDate = isActiveSession ? Date() : currentDate
        
        let predicate = #Predicate<WorkoutSessionEntity> { entity in
            (entity.templateId == templateId) && (entity.date < searchDate)
        }
        var descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor<WorkoutSessionEntity>(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        do {
            let entities = try modelContext.fetch(descriptor)
            
            if let entity = entities.first {
                return WorkoutSession(entity: entity, in: modelContext)
            } else {
                return nil
            }
        } catch {
            return nil
        }
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
    
    // MARK: - Personal Records
    
    private var personalRecordsSummary: [ExerciseRecord] {
        let exercisesInWorkout = workout.exercises.map { $0.exercise }
        return exercisesInWorkout.compactMap { exercise in
            workoutStore.getExerciseRecord(for: exercise)
        }
    }

    private var hasExercises: Bool {
        workout.exercises.contains { !$0.sets.isEmpty }
    }

    private var activeRestForThisWorkout: WorkoutStore.ActiveRestState? {
        guard let state = workoutStore.activeRestState, state.workoutId == workout.id else { return nil }
        return state
    }

    private func isActiveRest(exerciseIndex: Int, setIndex: Int) -> Bool {
        guard let state = activeRestForThisWorkout else { return false }
        return state.exerciseIndex == exerciseIndex && state.setIndex == setIndex && state.isRunning
    }

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
                workoutStore.startRest(for: workout, exerciseIndex: exerciseIndex, setIndex: setIndex, totalSeconds: rest)
                
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
                      state.setIndex == setIndex {
                workoutStore.stopRest()
            }
        }
    }
    
    private func completeWorkout() {
        showingCompletionConfirmation = true
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
        templateWorkout.duration = nil // Reset duration for template
        templateWorkout.date = Date() // Reset date to current time for future sessions
        
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

        let isActive = activeRestForThisWorkout?.exerciseIndex == exerciseIndex &&
                       activeRestForThisWorkout?.setIndex == setIndex

        // Capture id for entity removal
        let setId = workout.exercises[exerciseIndex].sets[setIndex].id
        let exerciseId = workout.exercises[exerciseIndex].id

        workout.exercises[exerciseIndex].sets.remove(at: setIndex)

        removeEntitySet(exerciseId: exerciseId, setId: setId)

        if isActive {
            workoutStore.stopRest()
        } else if let state = activeRestForThisWorkout,
                  state.exerciseIndex == exerciseIndex,
                  state.setIndex >= workout.exercises[exerciseIndex].sets.count {
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

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    /// Optimierte previousValues - nutzt zuerst Last-Used Felder, dann Fallback auf Session-Historie
    private func previousValues(for exerciseIndex: Int, setIndex: Int) -> (reps: Int?, weight: Double?) {
        let currentExercise = workout.exercises[exerciseIndex].exercise
        
        // 🚀 NEU: Zuerst Last-Used Felder prüfen (super schnell!)
        if let lastUsedMetrics = workoutStore.completeLastMetrics(for: currentExercise),
           let weight = lastUsedMetrics.weight,
           let reps = lastUsedMetrics.reps {
            return (reps, weight)
        }
        
        // Fallback: Alte Methode über Session-Historie (langsamer)
        return legacyPreviousValues(for: exerciseIndex, setIndex: setIndex)
    }
    
    /// Legacy-Fallback für previousValues - iteriert durch Session-Historie
    private func legacyPreviousValues(for exerciseIndex: Int, setIndex: Int) -> (reps: Int?, weight: Double?) {
        guard let prev = previousSessionSwiftData() else {
            return (nil, nil)
        }
        
        let currentExercise = workout.exercises[exerciseIndex].exercise
        guard let previousExercise = prev.exercises.first(where: { $0.exercise.id == currentExercise.id }) else {
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
    
    private func updateEntityNotes(_ notes: String) {
        entity.notes = notes
        do {
            try modelContext.save()
        } catch {
            print("❌ Fehler beim Speichern der Notizen: \(error)")
        }
    }

    private func updateEntityDuration(_ duration: TimeInterval, date: Date) {
        entity.duration = duration
        entity.date = date
        try? modelContext.save()
    }

    private func updateEntitySet(exerciseId: UUID, setId: UUID, mutate: (ExerciseSetEntity) -> Void) {
        if let ex = entity.exercises.first(where: { $0.id == exerciseId }),
           let set = ex.sets.first(where: { $0.id == setId }) {
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
            let e = ExerciseSetEntity(id: newSet.id, reps: newSet.reps, weight: newSet.weight, restTime: newSet.restTime, completed: newSet.completed)
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
        let lookup: [UUID: WorkoutExerciseEntity] = Dictionary(uniqueKeysWithValues: entity.exercises.map { ($0.id, $0) })
        entity.exercises = newOrder.compactMap { lookup[$0.id] }
        do {
            try modelContext.save()
            print("✅ Übungsreihenfolge gespeichert")
        } catch {
            print("❌ Fehler beim Speichern der Reihenfolge: \(error)")
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Custom TextField with Select All Functionality
private struct SelectAllTextField<Value: Numeric & LosslessStringConvertible>: UIViewRepresentable {
    @Binding var value: Value
    let placeholder: String
    let keyboardType: UIKeyboardType
    var uiFont: UIFont? = nil
    var textColor: UIColor? = nil
    var tintColor: UIColor? = nil
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = keyboardType
        textField.placeholder = placeholder
        textField.textAlignment = .center
        if let uiFont { textField.font = uiFont }
        if let textColor { textField.textColor = textColor }
        if let tintColor { textField.tintColor = tintColor }
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange), for: .editingChanged)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if let uiFont { uiView.font = uiFont }
        if let textColor { uiView.textColor = textColor }
        if let tintColor { uiView.tintColor = tintColor }
        
        let stringValue: String
        if Value.self == Double.self {
            // For weight fields (Double)
            let doubleValue = value as? Double ?? 0
            if doubleValue > 0 {
                stringValue = String(format: "%.1f", doubleValue).replacingOccurrences(of: ".0", with: "")
            } else {
                stringValue = ""
            }
        } else if Value.self == Int.self {
            // For rep fields (Int)
            let intValue = value as? Int ?? 0
            stringValue = intValue > 0 ? String(intValue) : ""
        } else {
            // Fallback for other types
            stringValue = String(describing: value)
        }
        
        if uiView.text != stringValue && !uiView.isFirstResponder {
            uiView.text = stringValue
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: SelectAllTextField
        
        init(_ parent: SelectAllTextField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            let text = textField.text ?? ""
            let cleanText = text.replacingOccurrences(of: ",", with: ".")
            
            if let newValue = Value(cleanText) {
                parent.value = newValue
            } else if text.isEmpty {
                if let zeroValue = Value("0") {
                    parent.value = zeroValue
                }
            }
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Select all text when editing begins
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Allow only numeric input, comma and dot for decimal fields
            if parent.keyboardType == .decimalPad {
                let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".,"))
                let characterSet = CharacterSet(charactersIn: string)
                
                // Prevent multiple decimal separators
                if (string == "." || string == ",") {
                    let currentText = textField.text ?? ""
                    if currentText.contains(".") || currentText.contains(",") {
                        return false
                    }
                }
                
                return allowedCharacters.isSuperset(of: characterSet)
            } else {
                // For number pad (reps), only allow digits
                let allowedCharacters = CharacterSet.decimalDigits
                let characterSet = CharacterSet(charactersIn: string)
                return allowedCharacters.isSuperset(of: characterSet)
            }
        }
    }
}

private struct WorkoutSetCard: View {
    let index: Int
    @Binding var set: ExerciseSet
    var isActiveRest: Bool
    var remainingSeconds: Int
    var previousReps: Int?
    var previousWeight: Double?
    var currentExercise: Exercise? // New parameter to check for records
    var workoutStore: WorkoutStore? // New parameter to check for records
    var onRestTimeUpdated: (Double) -> Void
    var onToggleCompletion: () -> Void

    @State private var showingRestEditor = false
    @State private var restMinutes: Int = 0
    @State private var restSeconds: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 28, weight: .semibold))

                verticalSeparator

                HStack(spacing: 6) {
                    VStack(spacing: 2) {
                        ZStack(alignment: .center) {
                            // Hidden baseline provider to align with large numbers
                            Text("0")
                                .font(.system(size: 28, weight: .semibold))
                                .opacity(0)
                            SelectAllTextField(
                                value: $set.reps,
                                placeholder: "0",
                                keyboardType: .numberPad,
                                uiFont: UIFont.systemFont(ofSize: 28, weight: .semibold),
                                textColor: set.completed ? UIColor.systemGray3 : nil
                            )
                            .multilineTextAlignment(.center)
                            .frame(width: 80)
                        }
                        
                        // Previous reps value
                        if let prevReps = previousReps {
                            Text("zuletzt: \(prevReps)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ")
                                .font(.caption2)
                        }
                    }
                }

                verticalSeparator

                VStack(spacing: 2) {
                    ZStack(alignment: .center) {
                        // Hidden baseline provider to align with large numbers
                        Text("0")
                            .font(.system(size: 28, weight: .semibold))
                            .opacity(0)
                        SelectAllTextField(
                            value: $set.weight,
                            placeholder: "0",
                            keyboardType: .decimalPad,
                            uiFont: UIFont.systemFont(ofSize: 28, weight: .semibold),
                            textColor: set.completed ? UIColor.systemGray3 : nil
                        )
                        .multilineTextAlignment(.center)
                        .frame(width: 104)
                    }
                    .overlay(alignment: .trailing) {
                        Text("kg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 2)
                    }
                    
                    // Previous weight value
                    if let prevWeight = previousWeight, prevWeight > 0 {
                        Text("zuletzt: \(prevWeight, specifier: "%.1f") kg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" ")
                            .font(.caption2)
                    }
                }

                Spacer(minLength: 8)

                verticalSeparator

                Button(action: onToggleCompletion) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(set.completed ? Color.white : AppTheme.mossGreen)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(set.completed ? AppTheme.mossGreen : AppTheme.mossGreen.opacity(0.15))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppTheme.mossGreen, lineWidth: set.completed ? 0 : 1)
                        )
                        .accessibilityLabel(set.completed ? "Satz zurücksetzen" : "Satz abschließen")
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: set.completed)
            }

            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Pause: \(formattedTime)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                restMinutes = Int(set.restTime) / 60
                restSeconds = Int(set.restTime) % 60
                showingRestEditor = true
            }


        }
        .padding(.vertical, 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: set.completed)
        .sheet(isPresented: $showingRestEditor) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Pausenzeit")
                        .font(.headline)

                    HStack(spacing: 24) {
                        VStack {
                            Text("Min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Minuten", selection: $restMinutes) {
                                ForEach(0..<11, id: \.self) { m in
                                    Text("\(m)").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        VStack {
                            Text("Sek")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Sekunden", selection: $restSeconds) {
                                ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id: \.self) { s in
                                    Text("\(s)").tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 160)

                    Button("Übernehmen") {
                        let total = Double(restMinutes * 60 + restSeconds)
                        set.restTime = max(0, min(total, 600))
                        onRestTimeUpdated(set.restTime)
                        showingRestEditor = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.mossGreen)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            showingRestEditor = false
                        }
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    private var formattedTime: String {
        let seconds = Int(set.restTime)
        let minutes = seconds / 60
        let remaining = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remaining)
        } else {
            return "\(seconds) s"
        }
    }

    private var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 22)
    }
}

private struct WorkoutCompletionSummaryView: View {
    let name: String
    let durationText: String
    let totalVolumeText: String
    let progressText: String
    let dismissAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.mossGreen)

                VStack(spacing: 12) {
                    Text(name)
                        .font(.title2.weight(.semibold))
                    Text("Workout gespeichert")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 18) {
                    summaryRow(title: "Dauer", value: durationText)
                    summaryRow(title: "Volumen", value: totalVolumeText)
                    summaryRow(title: "Veränderung", value: progressText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

                Button("Zur Übersicht") {
                    dismissAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.mossGreen)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .toolbar(.hidden)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value, initial: false) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

private extension UIFont {
    func rounded() -> UIFont {
        if let descriptor = self.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return self
    }
}

// MARK: - Active Workout Navigation View

private struct ActiveWorkoutNavigationView: View {
    @Binding var workout: Workout
    let workoutStore: WorkoutStore
    let activeRestForThisWorkout: WorkoutStore.ActiveRestState?
    let isActiveRest: (Int, Int) -> Bool
    let toggleCompletion: (Int, Int) -> Void
    let addSet: (Int) -> Void
    let removeSet: (Int, Int) -> Void
    let updateEntitySet: (UUID, UUID, (ExerciseSetEntity) -> Void) -> Void
    let appendEntitySet: (UUID, ExerciseSet) -> Void
    let removeEntitySet: (UUID, UUID) -> Void
    let previousValues: (Int, Int) -> (reps: Int?, weight: Double?)
    let completeWorkout: () -> Void
    let hasExercises: Bool
    let reorderEntityExercises: ([WorkoutExercise]) -> Void
    let finalizeCompletion: () -> Void
    let onActiveSessionEnd: (() -> Void)?
    
    @State private var currentExerciseIndex: Int = 0
    @State private var showingCompletionConfirmation = false
    @State private var autoAdvancePending = false
    @State private var showingAutoAdvanceIndicator = false
    @State private var showingReorderSheet = false
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main content with TabView or Empty State
                if workout.exercises.isEmpty {
                    // Empty state when no exercises
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "dumbbell")
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            Text("Keine Übungen")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Dieses Workout hat noch keine Übungen.\nFüge Übungen hinzu, um zu starten.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                    }
                    .padding()
                } else {
                    TabView(selection: $currentExerciseIndex) {
                        ForEach(workout.exercises.indices, id: \.self) { exerciseIndex in
                            ActiveWorkoutExerciseView(
                                exerciseIndex: exerciseIndex,
                                currentExerciseIndex: currentExerciseIndex,
                                totalExerciseCount: workout.exercises.count,
                                workout: $workout,
                                workoutStore: workoutStore,
                                activeRestForThisWorkout: activeRestForThisWorkout,
                                isActiveRest: isActiveRest,
                                toggleCompletion: toggleCompletion,
                                addSet: addSet,
                                removeSet: removeSet,
                                updateEntitySet: updateEntitySet,
                                appendEntitySet: appendEntitySet,
                                removeEntitySet: removeEntitySet,
                                previousValues: previousValues,
                                onReorderRequested: {
                                    showingReorderSheet = true
                                }
                            )
                            .tag(exerciseIndex)
                        }

                        // Completion screen as last page
                        if hasExercises {
                            ActiveWorkoutCompletionView(
                                workout: workout,
                                showingConfirmation: $showingCompletionConfirmation,
                                completeAction: {
                                    // Rufe die finale Abschluss-Logik auf
                                    finalizeCompletion()
                                }
                            )
                            .tag(workout.exercises.count)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.6), value: currentExerciseIndex)
                }
            }
            
            // Auto-advance indicator overlay
            if showingAutoAdvanceIndicator {
                AutoAdvanceIndicator(
                    nextExerciseName: nextExerciseDisplayName
                )
            }

            // Rest timer overlay - centered and floating
            if let activeRest = activeRestForThisWorkout {
                ZStack {
                    // Semi-transparent background that allows scrolling
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    RestTimerOverlay(
                        activeRest: activeRest,
                        workout: workout,
                        workoutStore: workoutStore,
                        navigateToExercise: { exerciseIndex in
                            withAnimation(.easeInOut(duration: 0.6)) {
                                currentExerciseIndex = exerciseIndex
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showingReorderSheet, onDismiss: nil) {
            ReorderExercisesSheet(
                exercises: workout.exercises,
                onCancel: {
                    showingReorderSheet = false
                },
                onSave: { reorderedExercises in
                    workout.exercises = reorderedExercises
                    reorderEntityExercises(reorderedExercises)
                    
                    // Adjust current index if needed to prevent out of bounds
                    if currentExerciseIndex >= workout.exercises.count {
                        currentExerciseIndex = max(0, workout.exercises.count - 1)
                    }
                    showingReorderSheet = false
                }
            )
        }
        .onReceive(workoutStore.$activeRestState) { restState in
            // Only auto-navigate to exercise with active rest if we're not pending an auto-advance
            if !autoAdvancePending,
               let restState = restState,
               restState.workoutId == workout.id,
               restState.exerciseIndex < workout.exercises.count,
               currentExerciseIndex != restState.exerciseIndex {

                // Don't navigate backwards to previous exercise if we just auto-advanced
                // This prevents the "bounce back" behavior when rest timer ticks
                let isNavigatingToPreviousExercise = restState.exerciseIndex < currentExerciseIndex
                
                if !isNavigatingToPreviousExercise {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        currentExerciseIndex = restState.exerciseIndex
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToNextExercise"))) { notification in
            // Auto-navigate to next exercise after completing last set
            if let nextIndex = notification.userInfo?["nextExerciseIndex"] as? Int,
               nextIndex < workout.exercises.count {
                autoAdvancePending = true
                
                // Show auto-advance indicator before navigation
                showingAutoAdvanceIndicator = true
                
                // Navigate after a brief visual feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // Use a smooth slide animation for auto-advance
                    withAnimation(.easeInOut(duration: 0.8)) {
                        currentExerciseIndex = nextIndex
                        showingAutoAdvanceIndicator = false
                    }
                    
                    // Reset the flag after navigation is complete (longer delay to prevent conflicts)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        autoAdvancePending = false
                   }
               }
           }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToWorkoutCompletion"))) { notification in
            // Auto-navigate to workout completion screen after completing last set of last exercise
            autoAdvancePending = true
            
            // Show auto-advance indicator before navigation
            showingAutoAdvanceIndicator = true
            
            // Navigate after a brief visual feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Use a smooth slide animation for auto-advance to completion
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentExerciseIndex = workout.exercises.count // Navigate to completion screen
                    showingAutoAdvanceIndicator = false
                }
                
                // Reset the flag after navigation is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    autoAdvancePending = false
                }
            }
        }
    }
    
    private var nextExerciseDisplayName: String {
        if currentExerciseIndex >= workout.exercises.count - 1 {
            return "Workout abschließen"
        }
        return workout.exercises[safe: currentExerciseIndex + 1]?.exercise.name ?? "Nächste Übung"
    }
}

// MARK: - Exercise Header Card (kept for compatibility but no longer used in active workout)

private struct ActiveWorkoutExerciseView: View {
    let exerciseIndex: Int
    let currentExerciseIndex: Int
    let totalExerciseCount: Int
    @Binding var workout: Workout
    let workoutStore: WorkoutStore
    let activeRestForThisWorkout: WorkoutStore.ActiveRestState?
    let isActiveRest: (Int, Int) -> Bool
    let toggleCompletion: (Int, Int) -> Void
    let addSet: (Int) -> Void
    let removeSet: (Int, Int) -> Void
    let updateEntitySet: (UUID, UUID, (ExerciseSetEntity) -> Void) -> Void
    let appendEntitySet: (UUID, ExerciseSet) -> Void
    let removeEntitySet: (UUID, UUID) -> Void
    let previousValues: (Int, Int) -> (reps: Int?, weight: Double?)
    let onReorderRequested: () -> Void
    
    private var exercise: WorkoutExercise {
        workout.exercises[exerciseIndex]
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Everything in one big container including progress and add button
                VStack(spacing: 0) {
                    // Progress indicator at the top
                    VStack(spacing: 12) {
                        // Progress bar
                        HStack(spacing: 4) {
                            ForEach(0..<totalExerciseCount, id: \.self) { index in
                                Rectangle()
                                    .fill(index <= currentExerciseIndex ? AppTheme.mossGreen : Color(.systemGray4))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                    .animation(.easeInOut(duration: 0.2), value: currentExerciseIndex)
                            }
                        }
                        
                        // Exercise info
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Übung \(currentExerciseIndex + 1) von \(totalExerciseCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 8) {
                                    Text(exercise.exercise.name)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .onLongPressGesture {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            onReorderRequested()
                                        }
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(20)
                    
                    // Separator after progress
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 0.5)
                        .padding(.horizontal, 20)
                    
                    // All sets
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { element in
                        let setIndex = element.offset
                        let previous = previousValues(exerciseIndex, setIndex)
                        let isLastSet = setIndex == exercise.sets.count - 1
                        
                        let setBinding = Binding(
                            get: { workout.exercises[exerciseIndex].sets[setIndex] },
                            set: {
                                workout.exercises[exerciseIndex].sets[setIndex] = $0
                                let exId = workout.exercises[exerciseIndex].id
                                let setId = workout.exercises[exerciseIndex].sets[setIndex].id
                                let newSet = workout.exercises[exerciseIndex].sets[setIndex]
                                updateEntitySet(exId, setId) { setEntity in
                                    setEntity.reps = newSet.reps
                                    setEntity.weight = newSet.weight
                                }
                            }
                        )
                        
                        ActiveWorkoutSetCard(
                            index: setIndex,
                            set: setBinding,
                            isActiveRest: isActiveRest(exerciseIndex, setIndex),
                            remainingSeconds: activeRestForThisWorkout?.remainingSeconds ?? 0,
                            previousReps: previous.reps,
                            previousWeight: previous.weight,
                            isLastSet: isLastSet,
                            currentExercise: workout.exercises[exerciseIndex].exercise,
                            workoutStore: workoutStore,
                            onRestTimeUpdated: { newValue in
                                if isActiveRest(exerciseIndex, setIndex) {
                                    // Update rest time logic here
                                }
                                let exId = workout.exercises[exerciseIndex].id
                                let setId = workout.exercises[exerciseIndex].sets[setIndex].id
                                updateEntitySet(exId, setId) { setEntity in
                                    setEntity.restTime = newValue
                                }
                            },
                            onToggleCompletion: {
                                toggleCompletion(exerciseIndex, setIndex)
                            },
                            onDeleteSet: {
                                removeSet(setIndex, exerciseIndex)
                            }
                        )
                        .onLongPressGesture {
                            // Option to remove set
                        }
                    }
                    
                    // Separator before add button
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 0.5)
                        .padding(.horizontal, 20)
                    
                    // Add set button inside the container
                    Button {
                        addSet(exerciseIndex)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Satz hinzufügen")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.mossGreen, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(20)
                }
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Exercise Header Card

private struct ExerciseHeaderCard: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.name)
                .font(.title)
                .fontWeight(.bold)
            
            if !exercise.muscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(exercise.muscleGroups, id: \.self) { group in
                            Text(group.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.mossGreen.opacity(0.1), in: Capsule())
                                .foregroundStyle(AppTheme.mossGreen)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            if !exercise.description.isEmpty {
                Text(exercise.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Active Workout Set Card

private struct ActiveWorkoutSetCard: View {
    let index: Int
    @Binding var set: ExerciseSet
    var isActiveRest: Bool
    var remainingSeconds: Int
    var previousReps: Int?
    var previousWeight: Double?
    let isLastSet: Bool
    var currentExercise: Exercise? // New parameter to check for records
    var workoutStore: WorkoutStore? // New parameter to check for records
    var onRestTimeUpdated: (Double) -> Void
    var onToggleCompletion: () -> Void
    var onDeleteSet: () -> Void

    @State private var showingRestEditor = false
    @State private var restMinutes: Int = 0
    @State private var restSeconds: Int = 0
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Set header
            HStack(alignment: .firstTextBaseline) {
                Text("SATZ \(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // Main input area
            HStack(spacing: 20) {
                // Reps input
                VStack(spacing: 8) {
                    Text("Wiederholungen")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    SelectAllTextField(
                        value: $set.reps,
                        placeholder: "0",
                        keyboardType: .numberPad,
                        uiFont: UIFont.systemFont(ofSize: 32, weight: .bold),
                        textColor: set.completed ? UIColor.systemGray3 : nil
                    )
                    .multilineTextAlignment(.center)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Previous reps value
                    if let prevReps = previousReps {
                        Text("zuletzt: \(prevReps)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" ")
                            .font(.caption2)
                    }
                }
                
                // Weight input
                VStack(spacing: 8) {
                    Text("Gewicht (kg)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    SelectAllTextField(
                        value: $set.weight,
                        placeholder: "0",
                        keyboardType: .decimalPad,
                        uiFont: UIFont.systemFont(ofSize: 32, weight: .bold),
                        textColor: set.completed ? UIColor.systemGray3 : nil
                    )
                    .multilineTextAlignment(.center)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Previous weight value
                    if let prevWeight = previousWeight, prevWeight > 0 {
                        Text("zuletzt: \(prevWeight, specifier: "%.1f") kg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" ")
                            .font(.caption2)
                    }
                }
            }
            
            // Rest time and completion button
            HStack(spacing: 12) {
                Button {
                    restMinutes = Int(set.restTime) / 60
                    restSeconds = Int(set.restTime) % 60
                    showingRestEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.caption)
                        Text("Pause: \(formattedTime)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5), in: Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    // Haptisches Feedback beim Tippen
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    onToggleCompletion()
                } label: {
                    if set.completed {
                        Image(systemName: "checkmark")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.mossGreen, in: Circle())
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.title3)
                            Text("Abschließen")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(AppTheme.mossGreen)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppTheme.mossGreen.opacity(0.1), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.mossGreen, lineWidth: 1)
                        )
                    }
                }
                .buttonStyle(.plain)
            }
            

        }
        .padding(20)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: set.completed)
        .overlay(alignment: .bottom) {
            // Add separator between sets (except for last set)
            if !isLastSet {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)
            }
        }
        .onLongPressGesture {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showingDeleteConfirmation = true
        }
        .confirmationDialog(
            "Satz \(index + 1) löschen?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                onDeleteSet()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .sheet(isPresented: $showingRestEditor) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Pausenzeit")
                        .font(.headline)

                    HStack(spacing: 24) {
                        VStack {
                            Text("Min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Minuten", selection: $restMinutes) {
                                ForEach(0..<11, id: \.self) { m in
                                    Text("\(m)").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        VStack {
                            Text("Sek")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Sekunden", selection: $restSeconds) {
                                ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id: \.self) { s in
                                    Text("\(s)").tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 160)

                    Button("Übernehmen") {
                        let total = Double(restMinutes * 60 + restSeconds)
                        set.restTime = max(0, min(total, 600))
                        onRestTimeUpdated(set.restTime)
                        showingRestEditor = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.mossGreen)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            showingRestEditor = false
                        }
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    private var formattedTime: String {
        let seconds = Int(set.restTime)
        let minutes = seconds / 60
        let remaining = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remaining)
        } else {
            return "\(seconds) s"
        }
    }

    private var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Active Workout Completion View

private struct ActiveWorkoutCompletionView: View {
    let workout: Workout
    @Binding var showingConfirmation: Bool
    let completeAction: () -> Void
    
    private var totalVolume: Double {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }
    
    private var completedSets: Int {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.filter { $0.completed }.count
        }
    }
    
    private var totalSets: Int {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.count
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Completion header
                VStack(spacing: 12) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.mossGreen)
                    
                    Text("Workout abschließen")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Du bist fast fertig!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Summary stats
                VStack(spacing: 16) {
                    StatRow(label: "Übungen", value: "\(workout.exercises.count)")
                    StatRow(label: "Abgeschlossene Sätze", value: "\(completedSets) / \(totalSets)")
                    StatRow(label: "Gesamtvolumen", value: "\(Int(totalVolume)) kg")
                }
                .padding(20)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                if showingConfirmation {
                    VStack(spacing: 16) {
                        Text("Workout wirklich abschließen?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("Die Session wird gespeichert und das Template zurückgesetzt.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 12) {
                            Button("Abbrechen") {
                                showingConfirmation = false
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                            Button("Abschließen") {
                                // Starkes haptisches Feedback für finale Bestätigung
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
                                showingConfirmation = false
                                completeAction()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.mossGreen)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                } else {
                    Button {
                        // Haptisches Feedback beim Workout-Abschluss
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        showingConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                            Text("Workout abschließen")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.mossGreen, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.mossGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Rest Timer Overlay

private struct RestTimerOverlay: View {
    let activeRest: WorkoutStore.ActiveRestState
    let workout: Workout
    let workoutStore: WorkoutStore
    let navigateToExercise: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise info
            HStack {
                Text("Pause: Satz \(activeRest.setIndex + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Spacer()
                Text(workout.exercises[safe: activeRest.exerciseIndex]?.exercise.name ?? "Übung")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            // Timer
            HStack(alignment: .center, spacing: 16) {
                Text(formatTime(activeRest.remainingSeconds))
                    .font(.system(size: activeRest.isRunning ? 28 : 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: activeRest.isRunning)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                Spacer()

                HStack(spacing: 10) {
                    if activeRest.isRunning {
                        Button { workoutStore.pauseRest() } label: {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.2), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))

                        Button { workoutStore.addRest(seconds: 15) } label: {
                            Text("+15s")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .fixedSize()
                        }
                        .frame(height: 44)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    } else {
                        Button { workoutStore.resumeRest() } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 44, height: 44)
                        .background(AppTheme.mossGreen.opacity(0.8), in: Circle())
                        .disabled(activeRest.remainingSeconds == 0)
                    }

                    Button { workoutStore.stopRest() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .background(AppTheme.powerOrange.opacity(0.8), in: Circle())
                }
            }

            // Progress bar for remaining time
            if activeRest.isRunning {
                let totalTime = activeRest.totalSeconds > 0 ? activeRest.totalSeconds : 90
                let progress = Double(activeRest.remainingSeconds) / Double(totalTime)

                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .scaleEffect(y: 2)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.deepBlue.opacity(0.95),
                    AppTheme.deepBlue.opacity(0.9),
                    Color.indigo.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: AppTheme.deepBlue.opacity(0.5), radius: 16, x: 0, y: 8)
        .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
        .scaleEffect(activeRest.isRunning ? 1.0 : 0.98)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: activeRest.isRunning)
        .onTapGesture {
            // Navigate to the exercise with active rest
            navigateToExercise(activeRest.exerciseIndex)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

// MARK: - Auto Advance Indicator

private struct AutoAdvanceIndicator: View {
    let nextExerciseName: String
    
    private var titleText: String {
        return nextExerciseName == "Workout abschließen" ? "Workout" : "Nächste Übung"
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Arrow icon with animation
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.mossGreen)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: true)
                    
                    Text(titleText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                
                Text(nextExerciseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .scaleEffect(1.0)
            .opacity(1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: true)
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutEntity.self, WorkoutExerciseEntity.self, ExerciseSetEntity.self, ExerciseEntity.self, WorkoutSessionEntity.self, UserProfileEntity.self, configurations: config)
    let exercise = ExerciseEntity(id: UUID(), name: "Bankdrücken")
    let set = ExerciseSetEntity(id: UUID(), reps: 10, weight: 60, restTime: 90, completed: false)
    let we = WorkoutExerciseEntity(id: UUID(), exercise: exercise, sets: [set])
    let workout = WorkoutEntity(id: UUID(), name: "Push Day", exercises: [we], defaultRestTime: 90, notes: "Preview")
    container.mainContext.insert(workout)
    return NavigationStack {
        WorkoutDetailView(entity: workout, isActiveSession: true)
            .environmentObject(WorkoutStore())
    }
    .modelContainer(container)
}

// MARK: - Reorder Exercises Sheet

private struct ReorderExercisesSheet: View {
    let exercises: [WorkoutExercise]
    let onCancel: () -> Void
    let onSave: ([WorkoutExercise]) -> Void
    
    @State private var reorderedExercises: [WorkoutExercise]
    
    init(exercises: [WorkoutExercise], onCancel: @escaping () -> Void, onSave: @escaping ([WorkoutExercise]) -> Void) {
        self.exercises = exercises
        self.onCancel = onCancel
        self.onSave = onSave
        self._reorderedExercises = State(initialValue: exercises)
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(reorderedExercises) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.exercise.name)
                                .font(.headline)
                            Text("\(exercise.sets.count) Sätze")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { indices, newOffset in
                    reorderedExercises.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reihenfolge ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        onSave(reorderedExercises)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
