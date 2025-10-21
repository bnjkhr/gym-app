//
//  EdgeCaseTests.swift
//  GymTracker
//
//  Edge case testing for Active Workout V2
//  Session 4 - Phase 7 Testing
//

import SwiftUI

/// Edge Case Test Scenarios for ActiveWorkoutSheetView
///
/// This file contains test scenarios to verify behavior in edge cases.
/// Run these in Preview to verify UI handles them gracefully.
struct ActiveWorkoutEdgeCasePreviews: View {
    var body: some View {
        Text("Use individual previews below")
    }
}

// MARK: - Test Data Generators

extension ActiveWorkoutEdgeCasePreviews {

    /// Edge Case 1: Empty Workout (0 exercises)
    static func emptyWorkout() -> Workout {
        Workout(
            name: "Empty Workout",
            exercises: [],
            targetMuscleGroups: [],
            startDate: Date()
        )
    }

    /// Edge Case 2: Single Exercise Workout
    static func singleExerciseWorkout() -> Workout {
        Workout(
            name: "Single Exercise",
            exercises: [
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Bench Press",
                        muscleGroups: [.chest],
                        equipmentType: .barbell
                    ),
                    sets: [
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                    ]
                )
            ],
            targetMuscleGroups: [.chest],
            startDate: Date()
        )
    }

    /// Edge Case 3: All Exercises Completed
    static func allCompletedWorkout() -> Workout {
        Workout(
            name: "All Completed",
            exercises: [
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Bench Press",
                        muscleGroups: [.chest],
                        equipmentType: .barbell
                    ),
                    sets: [
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: true),
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: true),
                    ]
                ),
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Squats",
                        muscleGroups: [.legs],
                        equipmentType: .barbell
                    ),
                    sets: [
                        ExerciseSet(reps: 10, weight: 120, restTime: 120, completed: true),
                        ExerciseSet(reps: 10, weight: 120, restTime: 120, completed: true),
                    ]
                ),
            ],
            targetMuscleGroups: [.chest, .legs],
            startDate: Date()
        )
    }

    /// Edge Case 4: Workout with 20+ Sets (Performance Test)
    static func manySetWorkout() -> Workout {
        var sets: [ExerciseSet] = []
        for i in 1...25 {
            sets.append(
                ExerciseSet(
                    reps: 8,
                    weight: Double(80 + i),
                    restTime: 90,
                    completed: i % 3 == 0  // Every 3rd set completed
                )
            )
        }

        return Workout(
            name: "High Volume Test",
            exercises: [
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Lat Pulldown",
                        muscleGroups: [.back],
                        equipmentType: .cable
                    ),
                    sets: sets
                )
            ],
            targetMuscleGroups: [.back],
            startDate: Date()
        )
    }

    /// Edge Case 5: Multiple Exercises with Mixed Completion
    static func mixedCompletionWorkout() -> Workout {
        Workout(
            name: "Mixed Progress",
            exercises: [
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Bench Press",
                        muscleGroups: [.chest],
                        equipmentType: .barbell
                    ),
                    sets: [
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: true),
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: true),
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: true),
                    ]
                ),
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Incline Press",
                        muscleGroups: [.chest],
                        equipmentType: .barbell
                    ),
                    sets: [
                        ExerciseSet(reps: 8, weight: 80, restTime: 90, completed: true),
                        ExerciseSet(reps: 8, weight: 80, restTime: 90, completed: false),
                        ExerciseSet(reps: 8, weight: 80, restTime: 90, completed: false),
                    ]
                ),
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Cable Flyes",
                        muscleGroups: [.chest],
                        equipmentType: .cable
                    ),
                    sets: [
                        ExerciseSet(reps: 12, weight: 30, restTime: 60, completed: false),
                        ExerciseSet(reps: 12, weight: 30, restTime: 60, completed: false),
                        ExerciseSet(reps: 12, weight: 30, restTime: 60, completed: false),
                    ]
                ),
            ],
            targetMuscleGroups: [.chest],
            startDate: Date()
        )
    }

    /// Edge Case 6: Workout with Very Long Exercise Names
    static func longNamesWorkout() -> Workout {
        Workout(
            name: "Very Long Exercise Names Test Case for UI Layout Verification",
            exercises: [
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Barbell Bench Press with Extra Wide Grip on Competition Bench",
                        muscleGroups: [.chest],
                        equipmentType: .barbell
                    ),
                    sets: [
                        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false)
                    ],
                    notes:
                        "This is a very long note that contains detailed information about the exercise execution, form cues, and personal records. It should test how the UI handles multi-line text overflow and layout constraints."
                )
            ],
            targetMuscleGroups: [.chest],
            startDate: Date()
        )
    }
}

// MARK: - Previews

#Preview("Edge Case 1: Empty Workout") {
    @Previewable @State var workout = ActiveWorkoutEdgeCasePreviews.emptyWorkout()
    @Previewable @StateObject var workoutStore = WorkoutStoreCoordinator()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: workoutStore,
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Edge Case 2: Single Exercise") {
    @Previewable @State var workout = ActiveWorkoutEdgeCasePreviews.singleExerciseWorkout()
    @Previewable @StateObject var workoutStore = WorkoutStoreCoordinator()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: workoutStore,
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Edge Case 3: All Completed") {
    @Previewable @State var workout = ActiveWorkoutEdgeCasePreviews.allCompletedWorkout()
    @Previewable @StateObject var workoutStore = WorkoutStoreCoordinator()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: workoutStore,
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Edge Case 4: 25 Sets (Performance)") {
    @Previewable @State var workout = ActiveWorkoutEdgeCasePreviews.manySetWorkout()
    @Previewable @StateObject var workoutStore = WorkoutStoreCoordinator()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: workoutStore,
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Edge Case 5: Mixed Completion") {
    @Previewable @State var workout = ActiveWorkoutEdgeCasePreviews.mixedCompletionWorkout()
    @Previewable @StateObject var workoutStore = WorkoutStoreCoordinator()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: workoutStore,
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Edge Case 6: Long Names") {
    @Previewable @State var workout = ActiveWorkoutEdgeCasePreviews.longNamesWorkout()
    @Previewable @StateObject var workoutStore = WorkoutStoreCoordinator()

    ActiveWorkoutSheetView(
        workout: $workout,
        workoutStore: workoutStore,
        onDismiss: { print("Dismissed") }
    )
}
