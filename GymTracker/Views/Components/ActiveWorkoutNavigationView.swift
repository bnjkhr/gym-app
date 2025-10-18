import SwiftUI

/// Horizontal swipe navigation for active workout sessions
///
/// Main container view for active workouts using TabView for horizontal page-based navigation.
/// Automatically advances to the next exercise after completing the last set.
///
/// **Features:**
/// - Horizontal swipe navigation between exercises
/// - Auto-advance to next exercise on last set completion
/// - Auto-navigate to completion screen
/// - Rest timer state synchronization
/// - Reorder exercises sheet
/// - Empty state when no exercises
/// - Auto-advance indicator overlay
///
/// **Navigation Flow:**
/// ```
/// Exercise 1 → Exercise 2 → ... → Exercise N → Completion Screen
/// ```
///
/// **Auto-Advance Triggers:**
/// - `NavigateToNextExercise` notification (after last set of exercise)
/// - `NavigateToWorkoutCompletion` notification (after last set of workout)
///
/// **Usage:**
/// Used in `WorkoutDetailView` when `isActiveSession == true`.
struct ActiveWorkoutNavigationView: View {
    @Binding var workout: Workout
    let workoutStore: WorkoutStoreCoordinator
    let activeRestForThisWorkout: RestTimerState?
    let isActiveRest: (Int, Int) -> Bool
    let hasActiveRestState: (Int, Int) -> Bool
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

                            Text(
                                "Dieses Workout hat noch keine Übungen.\nFüge Übungen hinzu, um zu starten."
                            )
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
                                hasActiveRestState: hasActiveRestState,
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
        .onReceive(workoutStore.restTimerStateManager.$currentState) { restState in
            // Only auto-navigate to exercise with active rest if we're not pending an auto-advance
            if !autoAdvancePending,
                let restState = restState,
                restState.workoutId == workout.id,
                restState.exerciseIndex < workout.exercises.count,
                currentExerciseIndex != restState.exerciseIndex
            {

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
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToNextExercise"))
        ) { notification in
            // Auto-navigate to next exercise after completing last set
            if let nextIndex = notification.userInfo?["nextExerciseIndex"] as? Int,
                nextIndex < workout.exercises.count
            {
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("NavigateToWorkoutCompletion"))
        ) { notification in
            // Auto-navigate to workout completion screen after completing last set of last exercise
            autoAdvancePending = true

            // Show auto-advance indicator before navigation
            showingAutoAdvanceIndicator = true

            // Navigate after a brief visual feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Use a smooth slide animation for auto-advance to completion
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentExerciseIndex = workout.exercises.count  // Navigate to completion screen
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

/// Helper extension for safe array access
extension Array {
    fileprivate subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
