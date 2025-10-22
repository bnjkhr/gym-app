//
//  ActiveWorkoutSheetView.swift
//  GymTracker
//
//  V2 Clean Architecture - Refactored
//  Main container for active workout modal sheet
//

import SwiftUI

/// Active Workout Modal Sheet (Clean Architecture)
///
/// **Key Changes from v1:**
/// - Uses SessionStore instead of WorkoutStoreCoordinator
/// - No direct SwiftData dependencies
/// - Pure presentation layer following Clean Architecture
/// - Modal sheet instead of full-screen TabView
/// - All exercises visible in ScrollView (not paginated)
/// - Conditional timer section at top
/// - Grabber for drag-to-dismiss
/// - Fixed bottom action bar
///
/// **Architecture:**
/// ```
/// ┌─────────────────────────────────┐
/// │ Grabber                         │
/// │ Header [Back] [Menu] [Finish]  │
/// ├─────────────────────────────────┤
/// │ TimerSection (conditional)      │ ← Only with active rest
/// ├─────────────────────────────────┤
/// │ ScrollView                      │
/// │   ├─ ActiveExerciseCard 1       │
/// │   ├─ ExerciseSeparator          │
/// │   ├─ ActiveExerciseCard 2       │
/// │   └─ ...                        │
/// ├─────────────────────────────────┤
/// │ BottomActionBar (fixed)         │
/// └─────────────────────────────────┘
/// ```
///
/// **Usage:**
/// ```swift
/// .sheet(isPresented: $showingActiveWorkout) {
///     ActiveWorkoutSheetView(
///         sessionStore: sessionStore,
///         onDismiss: { /* cleanup */ }
///     )
/// }
/// ```
struct ActiveWorkoutSheetView: View {
    // MARK: - Properties

    /// Session store (Clean Architecture)
    @ObservedObject var sessionStore: SessionStore

    /// Legacy rest timer manager (TODO: Migrate to Use Case)
    @ObservedObject var restTimerManager: RestTimerStateManager

    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showingMenu = false
    @State private var showingFinishConfirmation = false
    @State private var currentTime = Date()  // For updating workout duration display
    @State private var exerciseSheetDetent: PresentationDetent = .large
    @State private var currentExerciseIndex: Int = 0  // Track current exercise for counter
    @State private var showAllExercises: Bool = false  // Toggle to show completed exercises
    @StateObject private var notificationManager = InAppNotificationManager.shared

    // MARK: - Computed Properties

    /// Current workout session from store
    private var session: WorkoutSession? {
        sessionStore.currentSession
    }

    /// Convert WorkoutSession to legacy Workout for rendering
    /// TODO: Refactor child components to use WorkoutSession directly
    private var legacyWorkout: Workout? {
        guard let session = session else { return nil }
        return WorkoutSession.toLegacyWorkout(session)
    }

    /// Progress: completed sets / total sets
    private var progressText: String {
        guard let session = session else { return "0 / 0" }
        return "\(session.completedSets) / \(session.totalSets)"
    }

    /// Current workout duration (from startDate)
    private var workoutDuration: TimeInterval {
        session?.duration ?? 0
    }

    /// Exercise counter (e.g. "2 / 14")
    private var exerciseCounterText: String {
        guard let session = session else { return "0 / 0" }
        guard !session.exercises.isEmpty else { return "0 / 0" }
        return "\(currentExerciseIndex + 1) / \(session.exercises.count)"
    }

    /// Check if all exercises are completed and hidden
    private var allExercisesCompletedAndHidden: Bool {
        guard let session = session else { return false }
        return !session.exercises.isEmpty
            && session.exercises.allSatisfy { $0.sets.allSatisfy { $0.completed } }
            && !showAllExercises
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background Layer: Header + Timer (fixed)
            VStack(spacing: 0) {
                // Header
                headerView

                // Timer Section (ALWAYS visible - shows rest timer OR workout duration)
                TimerSection(
                    restTimerManager: restTimerManager,
                    workoutStartDate: session?.startDate
                )

                Spacer()
            }
            .background(Color.black)

            // Foreground Layer: Draggable Exercise Sheet
            DraggableExerciseSheet {
                VStack(spacing: 0) {
                    // Exercise List with ScrollViewReader for auto-scroll
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                if session == nil {
                                    loadingStateView
                                } else if session?.exercises.isEmpty == true {
                                    emptyStateView
                                } else if allExercisesCompletedAndHidden {
                                    completedStateView
                                } else {
                                    exerciseListView
                                }
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(
                            of: session?.exercises.map { $0.sets.map { $0.completed } }
                        ) { _, _ in
                            // Check if last set of current exercise was completed
                            checkAndScrollToNextExercise(proxy: proxy)
                        }
                    }

                    // Bottom Action Bar (fixed at bottom of sheet)
                    BottomActionBar(
                        onRepeat: handleRepeat,
                        onAdd: handleAddExercise,
                        onReorder: handleReorder
                    )
                }
            }
            // Overlay: Universal In-App Notification
            NotificationPill(manager: notificationManager)
        }
        .background(Color.black)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)  // Using custom grabber
        .interactiveDismissDisabled(false)
        .onAppear {
            startDurationTimer()
        }
        .confirmationDialog(
            "Workout beenden?",
            isPresented: $showingFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button("Beenden", role: .destructive) {
                finishWorkout()
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            // Left side: Back button + Show/Hide Toggle
            HStack(spacing: 16) {
                // Back Button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                // Show/Hide completed exercises toggle
                Button {
                    HapticManager.shared.selection()
                    showAllExercises.toggle()
                } label: {
                    Image(systemName: showAllExercises ? "eye.fill" : "eye.slash.fill")
                        .font(.title3)
                        .foregroundStyle(showAllExercises ? .orange : .white)
                }
            }

            Spacer()

            // Center: Exercise counter (1/14, 2/14, etc.)
            Text(exerciseCounterText)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            // Right side: Beenden button
            Button {
                HapticManager.shared.warning()
                showingFinishConfirmation = true
            } label: {
                Text("Beenden")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Exercise List View

    @ViewBuilder
    private var exerciseListView: some View {
        if let workout = legacyWorkout, let session = session {
            // Use local @State wrapper for legacy components
            ExerciseListContent(
                session: session,
                workout: workout,
                showAllExercises: showAllExercises,
                onToggleCompletion: toggleSetCompletion,
                onQuickAdd: handleQuickAdd,
                onDeleteSet: deleteSet
            )
        }
    }

    // MARK: - Loading State View

    private var loadingStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Lade Workout...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "dumbbell")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Keine Übungen")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Füge Übungen hinzu, um zu starten.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                handleAddExercise()
            } label: {
                Label("Übung hinzufügen", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Completed State View

    private var completedStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Alle Übungen abgeschlossen! 🎉")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Tippe auf das Auge-Symbol, um alle Übungen anzuzeigen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                HapticManager.shared.light()
                showAllExercises = true
            } label: {
                Label("Alle Übungen anzeigen", systemImage: "eye.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func toggleSetCompletion(exerciseId: UUID, setId: UUID) {
        // Delegate to SessionStore (Clean Architecture)
        Task {
            await sessionStore.completeSet(exerciseId: exerciseId, setId: setId)

            // Show completion notification
            notificationManager.show("Set abgeschlossen", type: .success)

            // TODO: Start rest timer (migrate to Use Case)
            // For now, keep legacy rest timer integration
            if let session = session,
                let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }),
                let exercise = session.exercises.first(where: { $0.id == exerciseId }),
                let setIndex = exercise.sets.firstIndex(where: { $0.id == setId }),
                let set = exercise.sets.first(where: { $0.id == setId })
            {
                let isLastSet = (setIndex == exercise.sets.count - 1)

                if isLastSet {
                    notificationManager.show("Nächste Übung", type: .success)
                }

                // Get rest time
                let restTime = 90  // TODO: Get from set/exercise config

                // Get exercise names for timer
                let currentExerciseName = "Exercise \(exerciseIndex + 1)"  // TODO: Fetch from exercise DB
                let nextExerciseName: String? = {
                    if setIndex < exercise.sets.count - 1 {
                        return currentExerciseName
                    } else if exerciseIndex < session.exercises.count - 1 {
                        return "Exercise \(exerciseIndex + 2)"
                    }
                    return nil
                }()

                // Start rest timer (legacy integration)
                // TODO: Migrate to RestTimerUseCase
                // restTimerManager.startRest(...)
            }
        }
    }

    private func handleQuickAdd(exerciseId: UUID, input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // TODO: Implement AddSetUseCase or AddExerciseNoteUseCase
        print("TODO: Quick add '\(trimmed)' to exercise \(exerciseId)")

        // For now, parse as set or note
        if let parsed = parseSetInput(trimmed) {
            print("✅ Would add new set: \(parsed.weight)kg x \(parsed.reps) reps")
            // TODO: Call sessionStore.addSet(exerciseId:, weight:, reps:)
        } else {
            print("✅ Would add note: \(trimmed)")
            // TODO: Call sessionStore.addNote(exerciseId:, note:)
        }
    }

    /// Parses input like "100 x 8" or "100x8" into (weight, reps)
    private func parseSetInput(_ input: String) -> (weight: Double, reps: Int)? {
        let pattern = #"^\s*(\d+(?:\.\d+)?)\s*[xX×]\s*(\d+)\s*$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: input, range: NSRange(input.startIndex..., in: input))
        else {
            return nil
        }

        guard let weightRange = Range(match.range(at: 1), in: input),
            let weight = Double(input[weightRange]),
            let repsRange = Range(match.range(at: 2), in: input),
            let reps = Int(input[repsRange])
        else {
            return nil
        }

        return (weight, reps)
    }

    private func deleteSet(exerciseId: UUID, setId: UUID) {
        // TODO: Implement DeleteSetUseCase
        print("TODO: Delete set \(setId) from exercise \(exerciseId)")
    }

    private func handleRepeat() {
        print("Repeat last workout")
        // TODO: Implement repeat functionality
    }

    private func handleAddExercise() {
        print("Add exercise")
        // TODO: Show exercise picker
    }

    private func handleReorder() {
        print("Reorder exercises")
        // TODO: Show reorder sheet
    }

    private func startDurationTimer() {
        // Update currentTime every second to refresh workout duration display
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func finishWorkout() {
        // Haptic feedback for workout completion
        HapticManager.shared.success()

        // Stop any active rest timer
        restTimerManager.cancelRest()

        // Delegate to SessionStore (Clean Architecture)
        Task {
            await sessionStore.endSession()

            // Call dismiss callback
            onDismiss?()

            // Dismiss sheet
            dismiss()

            // TODO: Navigate to completion summary
        }
    }

    // MARK: - Auto-Scroll Logic

    private func checkAndScrollToNextExercise(proxy: ScrollViewProxy) {
        guard let session = session else { return }

        // Find first incomplete exercise
        for (index, exercise) in session.exercises.enumerated() {
            let allSetsCompleted = exercise.sets.allSatisfy { $0.completed }

            if !allSetsCompleted {
                // This is the first incomplete exercise
                // Update current exercise index for counter
                currentExerciseIndex = index

                // No scrolling needed - the fade-out animation handles the transition
                return
            }
        }

        // All exercises completed - update counter to last exercise
        if !session.exercises.isEmpty {
            let lastIndex = session.exercises.count - 1
            currentExerciseIndex = lastIndex
        }
    }
}

// MARK: - Helper Views

/// Wrapper view for exercise list with local state binding
/// This bridges Clean Architecture (WorkoutSession) with legacy components (Workout)
private struct ExerciseListContent: View {
    let session: WorkoutSession
    let workout: Workout
    let showAllExercises: Bool
    let onToggleCompletion: (UUID, UUID) -> Void
    let onQuickAdd: (UUID, String) -> Void
    let onDeleteSet: (UUID, UUID) -> Void

    @State private var localWorkout: Workout

    init(
        session: WorkoutSession,
        workout: Workout,
        showAllExercises: Bool,
        onToggleCompletion: @escaping (UUID, UUID) -> Void,
        onQuickAdd: @escaping (UUID, String) -> Void,
        onDeleteSet: @escaping (UUID, UUID) -> Void
    ) {
        self.session = session
        self.workout = workout
        self.showAllExercises = showAllExercises
        self.onToggleCompletion = onToggleCompletion
        self.onQuickAdd = onQuickAdd
        self.onDeleteSet = onDeleteSet
        self._localWorkout = State(initialValue: workout)
    }

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(localWorkout.exercises.enumerated()), id: \.element.id) {
                index, _ in
                let allSetsCompleted = localWorkout.exercises[index].sets.allSatisfy {
                    $0.completed
                }
                let shouldHide = allSetsCompleted && !showAllExercises

                if !shouldHide {
                    ActiveExerciseCard(
                        exercise: $localWorkout.exercises[index],
                        exerciseIndex: index,
                        onToggleCompletion: { setIndex in
                            // Map to Domain IDs
                            let exerciseId = session.exercises[index].id
                            let setId = session.exercises[index].sets[setIndex].id
                            onToggleCompletion(exerciseId, setId)
                        },
                        onQuickAdd: { input in
                            let exerciseId = session.exercises[index].id
                            onQuickAdd(exerciseId, input)
                        },
                        onDeleteSet: { setIndex in
                            let exerciseId = session.exercises[index].id
                            let setId = session.exercises[index].sets[setIndex].id
                            onDeleteSet(exerciseId, setId)
                        }
                    )
                    .padding(.horizontal)
                    .id("exercise_\(index)")  // ID for scrolling
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
            }
        }
        .animation(
            .timingCurve(0.2, 0.0, 0.0, 1.0, duration: 0.3),
            value: localWorkout.exercises.map { $0.sets.map { $0.completed } }
        )
        .padding(.vertical, 12)
        .padding(.bottom, 80)  // Space for BottomActionBar
        .onChange(of: session.exercises.map { $0.sets.map { $0.completed } }) { _, _ in
            // Sync from Domain to local state
            localWorkout = WorkoutSession.toLegacyWorkout(session)
        }
    }
}

// MARK: - Domain to Legacy Mapping

extension WorkoutSession {
    /// Temporary mapping helper: WorkoutSession → Workout
    /// TODO: Remove this once all child components use WorkoutSession directly
    static func toLegacyWorkout(_ session: WorkoutSession) -> Workout {
        // This is a simplified mapping - you'll need to implement full mapping
        // based on your actual Workout and Exercise models

        // For now, return a placeholder
        // TODO: Implement full mapping with Exercise lookup from repository
        return Workout(
            id: session.id,
            name: "Active Workout",  // TODO: Fetch workout name
            date: session.startDate,
            exercises: [],  // TODO: Map SessionExercise → WorkoutExercise
            startDate: session.startDate
        )
    }
}

// MARK: - Previews

#Preview("Active Workout with Session") {
    @Previewable @StateObject var sessionStore = SessionStore.previewWithSession
    @Previewable @StateObject var restTimerManager = RestTimerStateManager()

    ActiveWorkoutSheetView(
        sessionStore: sessionStore,
        restTimerManager: restTimerManager
    )
}

#Preview("Active Workout - Empty State") {
    @Previewable @StateObject var sessionStore = SessionStore.preview
    @Previewable @StateObject var restTimerManager = RestTimerStateManager()

    // Create empty session
    sessionStore.currentSession = WorkoutSession(
        id: UUID(),
        workoutId: UUID(),
        startDate: Date(),
        endDate: nil,
        exercises: [],
        state: .active
    )

    return ActiveWorkoutSheetView(
        sessionStore: sessionStore,
        restTimerManager: restTimerManager
    )
}
