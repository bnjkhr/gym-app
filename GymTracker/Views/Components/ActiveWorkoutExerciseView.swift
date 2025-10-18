import SwiftUI
import UIKit

/// Single exercise page in active workout TabView
///
/// Displays one exercise with all its sets in a scrollable view optimized for active workout sessions.
/// Includes progress bar, exercise info, set cards, and add set button.
///
/// **Features:**
/// - Progress bar showing current exercise position
/// - Exercise name with long-press to reorder
/// - All sets with `ActiveWorkoutSetCard`
/// - Add set button
/// - Swipe-to-delete for sets
/// - Auto-dismiss keyboard on tap
///
/// **Layout:**
/// ```
/// [━━━━━━━━━━━━━━━━━━━━] Progress bar
/// Übung 1 von 5
/// Bankdrücken
///
/// [Set Card 1]
/// [Set Card 2]
/// ...
/// [+ Satz hinzufügen]
/// ```
///
/// **Usage:**
/// Used in `ActiveWorkoutNavigationView` TabView for each exercise.
struct ActiveWorkoutExerciseView: View {
    let exerciseIndex: Int
    let currentExerciseIndex: Int
    let totalExerciseCount: Int
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
                                    .fill(
                                        index <= currentExerciseIndex
                                            ? AppTheme.mossGreen : Color(.systemGray4)
                                    )
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                    .animation(
                                        .easeInOut(duration: 0.2), value: currentExerciseIndex)
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
                                            let generator = UIImpactFeedbackGenerator(
                                                style: .medium)
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
                            hasRestState: hasActiveRestState(exerciseIndex, setIndex),
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
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
