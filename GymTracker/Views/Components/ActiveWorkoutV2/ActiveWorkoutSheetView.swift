//
//  ActiveWorkoutSheetView.swift
//  GymTracker
//
//  Phase 5: Active Workout Redesign
//  Main container for active workout modal sheet
//

import SwiftUI

/// Active Workout Modal Sheet (v2 Redesign)
///
/// **Key Changes from v1:**
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
///         workout: $workout,
///         workoutStore: workoutStore,
///         onDismiss: { /* cleanup */ }
///     )
/// }
/// ```
struct ActiveWorkoutSheetView: View {
    // MARK: - Properties

    @Binding var workout: Workout
    @ObservedObject var workoutStore: WorkoutStoreCoordinator

    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showingMenu = false
    @State private var showingFinishConfirmation = false
    @State private var currentTime = Date()  // For updating workout duration display
    @State private var exerciseSheetDetent: PresentationDetent = .large
    @State private var currentExerciseIndex: Int = 0  // Track current exercise for counter
    @State private var showAllExercises: Bool = false  // Toggle to show completed exercises
    @StateObject private var notificationManager = NotificationManager.shared

    // MARK: - Computed Properties

    /// Progress: completed sets / total sets
    private var progressText: String {
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        let completedSets = workout.exercises.flatMap { $0.sets }.filter { $0.completed }.count
        return "\(completedSets) / \(totalSets)"
    }

    /// Current workout duration (from startDate)
    private var workoutDuration: TimeInterval {
        workout.currentDuration
    }

    /// Exercise counter (e.g. "2 / 14")
    private var exerciseCounterText: String {
        guard !workout.exercises.isEmpty else { return "0 / 0" }
        return "\(currentExerciseIndex + 1) / \(workout.exercises.count)"
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
                    restTimerManager: workoutStore.restTimerStateManager,
                    workoutStartDate: workout.startDate
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
                                if workout.exercises.isEmpty {
                                    emptyStateView
                                } else {
                                    exerciseListView
                                }
                            }
                        }
                        .onChange(of: workout.exercises.map { $0.sets.map { $0.completed } }) {
                            _, _ in
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
            initializeWorkout()
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

    private var exerciseListView: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, _ in
                let allSetsCompleted = workout.exercises[index].sets.allSatisfy { $0.completed }
                let shouldHide = allSetsCompleted && !showAllExercises

                if !shouldHide {
                    ActiveExerciseCard(
                        exercise: $workout.exercises[index],
                        exerciseIndex: index,
                        onToggleCompletion: { setIndex in
                            toggleSetCompletion(exerciseIndex: index, setIndex: setIndex)
                        },
                        onQuickAdd: { input in
                            handleQuickAdd(exerciseIndex: index, input: input)
                        },
                        onDeleteSet: { setIndex in
                            deleteSet(exerciseIndex: index, setIndex: setIndex)
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
            value: workout.exercises.map { $0.sets.map { $0.completed } }
        )
        .padding(.vertical, 12)
        .padding(.bottom, 80)  // Space for BottomActionBar
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

    // MARK: - Actions

    private func toggleSetCompletion(exerciseIndex: Int, setIndex: Int) {
        // Toggle completion
        workout.exercises[exerciseIndex].sets[setIndex].completed.toggle()

        let isCompleted = workout.exercises[exerciseIndex].sets[setIndex].completed

        if isCompleted {
            // Check if this is the last set of the exercise
            let isLastSet = (setIndex == workout.exercises[exerciseIndex].sets.count - 1)

            // Show completion notification only for last set
            if isLastSet {
                notificationManager.show("Nächste Übung", type: .success)
            }

            // Get rest time for this set
            let restTime = workout.exercises[exerciseIndex].sets[setIndex].restTime

            // Start rest timer
            let currentExerciseName = workout.exercises[exerciseIndex].exercise.name
            let nextExerciseName: String? = {
                // Next set in same exercise, or next exercise
                if setIndex < workout.exercises[exerciseIndex].sets.count - 1 {
                    return currentExerciseName
                } else if exerciseIndex < workout.exercises.count - 1 {
                    return workout.exercises[exerciseIndex + 1].exercise.name
                }
                return nil
            }()

            workoutStore.restTimerStateManager.startRest(
                for: workout,
                exercise: exerciseIndex,
                set: setIndex,
                duration: Int(restTime),
                currentExerciseName: currentExerciseName,
                nextExerciseName: nextExerciseName
            )
        }

        // TODO: Persist to SwiftData
    }

    private func handleQuickAdd(exerciseIndex: Int, input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Try to parse as "weight x reps"
        if let parsed = parseSetInput(trimmed) {
            // Valid set format - create new set
            let newSet = ExerciseSet(
                reps: parsed.reps,
                weight: parsed.weight,
                restTime: 90,  // Default rest time
                completed: false
            )

            workout.exercises[exerciseIndex].sets.append(newSet)
            print("✅ Added new set: \(parsed.weight)kg x \(parsed.reps) reps")
        } else {
            // Not a set format - save as note
            if workout.exercises[exerciseIndex].notes == nil {
                workout.exercises[exerciseIndex].notes = trimmed
            } else {
                workout.exercises[exerciseIndex].notes? += "\n" + trimmed
            }
            print("✅ Added note: \(trimmed)")
        }

        // Note: SwiftData persistence will auto-save when using @Binding
    }

    /// Parses input like "100 x 8" or "100x8" into (weight, reps)
    private func parseSetInput(_ input: String) -> (weight: Double, reps: Int)? {
        let pattern = #"^\s*(\d+(?:\.\d+)?)\s*[xX×]\s*(\d+)\s*$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input))
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

    private func deleteSet(exerciseIndex: Int, setIndex: Int) {
        workout.exercises[exerciseIndex].sets.remove(at: setIndex)

        // TODO: Persist to SwiftData
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

    private func initializeWorkout() {
        // Set startDate if not already set
        if workout.startDate == nil {
            workout.startDate = Date()
            print("✅ Workout started at \(Date())")
        }
    }

    private func startDurationTimer() {
        // Update currentTime every second to refresh workout duration display
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func finishWorkout() {
        // Stop any active rest timer
        workoutStore.restTimerStateManager.cancelRest()

        // Call dismiss callback
        onDismiss?()

        // Dismiss sheet
        dismiss()

        // TODO: Navigate to completion summary
        // TODO: Save workout to SwiftData
    }

    // MARK: - Auto-Scroll Logic

    private func checkAndScrollToNextExercise(proxy: ScrollViewProxy) {
        // Find first incomplete exercise
        for (index, exercise) in workout.exercises.enumerated() {
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
        if !workout.exercises.isEmpty {
            let lastIndex = workout.exercises.count - 1
            currentExerciseIndex = lastIndex
        }
    }
}

// MARK: - Previews

// Simple mock WorkoutStore for previews
class MockWorkoutStore: WorkoutStoreCoordinator {
    override init() {
        super.init()
    }
}

#Preview("Active Workout with Rest Timer") {
    @Previewable @State var workout = Workout(
        id: UUID(),
        name: "Push Day",
        date: Date(),
        exercises: [
            WorkoutExercise(
                exercise: Exercise(
                    name: "Bankdrücken",
                    muscleGroups: [.chest],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                    ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                    ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                ],
                notes: "Felt strong today"
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Incline Dumbbell Press",
                    muscleGroups: [.chest],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 10, weight: 35, restTime: 90, completed: false),
                    ExerciseSet(reps: 10, weight: 35, restTime: 90, completed: false),
                    ExerciseSet(reps: 10, weight: 35, restTime: 90, completed: false),
                ]
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Schulterdrücken",
                    muscleGroups: [.shoulders],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 10, weight: 25, restTime: 90, completed: false),
                    ExerciseSet(reps: 10, weight: 25, restTime: 90, completed: false),
                    ExerciseSet(reps: 10, weight: 25, restTime: 90, completed: false),
                ]
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Seitheben",
                    muscleGroups: [.shoulders],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 12, weight: 12, restTime: 60, completed: false),
                    ExerciseSet(reps: 12, weight: 12, restTime: 60, completed: false),
                    ExerciseSet(reps: 12, weight: 12, restTime: 60, completed: false),
                ]
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Trizeps Pushdown",
                    muscleGroups: [.arms],
                    equipmentType: .cable
                ),
                sets: [
                    ExerciseSet(reps: 12, weight: 40, restTime: 60, completed: false),
                    ExerciseSet(reps: 12, weight: 40, restTime: 60, completed: false),
                    ExerciseSet(reps: 12, weight: 40, restTime: 60, completed: false),
                ]
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Bizeps Curls",
                    muscleGroups: [.arms],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 10, weight: 15, restTime: 60, completed: false),
                    ExerciseSet(reps: 10, weight: 15, restTime: 60, completed: false),
                    ExerciseSet(reps: 10, weight: 15, restTime: 60, completed: false),
                ]
            ),
        ],
        startDate: Date().addingTimeInterval(-240)  // Started 4 mins ago
    )

    // Mock WorkoutStore
    @Previewable @StateObject var mockStore = MockWorkoutStore()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: mockStore
    )
    .onAppear {
        // Start a rest timer for preview
        mockStore.restTimerStateManager.startRest(
            for: workout,
            exercise: 0,
            set: 1,
            duration: 90,
            currentExerciseName: "Bankdrücken",
            nextExerciseName: "Bankdrücken"
        )
    }
}

#Preview("Active Workout - Empty State") {
    @Previewable @State var workout = Workout(
        id: UUID(),
        name: "Empty Workout",
        date: Date(),
        exercises: []
    )

    @Previewable @StateObject var mockStore = MockWorkoutStore()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: mockStore
    )
}

#Preview("Active Workout - Multiple Exercises") {
    @Previewable @State var workout = Workout(
        id: UUID(),
        name: "Full Body",
        date: Date(),
        exercises: [
            WorkoutExercise(
                exercise: Exercise(
                    name: "Squat",
                    muscleGroups: [.legs],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 5, weight: 140, restTime: 180, completed: true),
                    ExerciseSet(reps: 5, weight: 140, restTime: 180, completed: true),
                    ExerciseSet(reps: 5, weight: 140, restTime: 180, completed: true),
                ],
                restTimeToNext: 300  // 5 min rest to next exercise
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Bench Press",
                    muscleGroups: [.chest],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 5, weight: 100, restTime: 180, completed: false),
                    ExerciseSet(reps: 5, weight: 100, restTime: 180, completed: false),
                ],
                restTimeToNext: 300
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Deadlift",
                    muscleGroups: [.back, .legs],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 5, weight: 160, restTime: 180, completed: false)
                ]
            ),
        ],
        startDate: Date().addingTimeInterval(-600)  // Started 10 mins ago
    )

    @Previewable @StateObject var mockStore = MockWorkoutStore()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: mockStore
    )
}
