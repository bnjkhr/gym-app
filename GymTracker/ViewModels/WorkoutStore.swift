import Foundation
import SwiftUI

class WorkoutStore: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var workouts: [Workout] = []

    init() {
        loadSampleData()
    }

    func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
    }

    func addWorkout(_ workout: Workout) {
        workouts.append(workout)
    }

    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        let sortedWorkouts = workouts.sorted { $0.date > $1.date }

        for workout in sortedWorkouts {
            if let workoutExercise = workout.exercises.first(where: { $0.exercise.id == exercise.id }) {
                let setCount = max(workoutExercise.sets.count, 1)
                let weight = workoutExercise.sets.last?.weight ?? 0
                return (weight, setCount)
            }
        }

        return nil
    }

    func deleteExercise(at indexSet: IndexSet) {
        exercises.remove(atOffsets: indexSet)
    }

    func deleteWorkout(at indexSet: IndexSet) {
        workouts.remove(atOffsets: indexSet)
    }

    private func loadSampleData() {
        let sampleExercises = [
            Exercise(name: "Bankdrücken", muscleGroups: [.chest, .triceps], description: "Klassische Brustübung"),
            Exercise(name: "Kniebeugen", muscleGroups: [.legs, .glutes], description: "Grundübung für die Beine"),
            Exercise(name: "Kreuzheben", muscleGroups: [.back, .legs], description: "Ganzkörperübung"),
            Exercise(name: "Klimmzüge", muscleGroups: [.back, .biceps], description: "Rückenübung mit Körpergewicht"),
            Exercise(name: "Schulterdrücken", muscleGroups: [.shoulders, .triceps], description: "Schulterübung")
        ]

        exercises = sampleExercises

        let calendar = Calendar.current
        let today = Date()

        let pushDay = Workout(
            name: "Push Momentum",
            date: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            exercises: [
                WorkoutExercise(
                    exercise: sampleExercises[0],
                    sets: [
                        ExerciseSet(reps: 8, weight: 80, restTime: 90, completed: true),
                        ExerciseSet(reps: 8, weight: 78, restTime: 90, completed: true)
                    ]
                ),
                WorkoutExercise(
                    exercise: sampleExercises[4],
                    sets: [
                        ExerciseSet(reps: 10, weight: 40, restTime: 75, completed: true)
                    ]
                )
            ],
            duration: 65 * 60,
            notes: "Fokus auf kontrollierte Exzentrik"
        )

        let pullDay = Workout(
            name: "Pull Elevate",
            date: calendar.date(byAdding: .day, value: -3, to: today) ?? today,
            exercises: [
                WorkoutExercise(
                    exercise: sampleExercises[3],
                    sets: [
                        ExerciseSet(reps: 6, weight: 0, restTime: 120, completed: true),
                        ExerciseSet(reps: 5, weight: 0, restTime: 120, completed: true)
                    ]
                ),
                WorkoutExercise(
                    exercise: sampleExercises[2],
                    sets: [
                        ExerciseSet(reps: 5, weight: 110, restTime: 150, completed: true)
                    ]
                )
            ],
            duration: 58 * 60,
            notes: "Griffweite variieren"
        )

        let legs = Workout(
            name: "Leg Resilience",
            date: calendar.date(byAdding: .day, value: -5, to: today) ?? today,
            exercises: [
                WorkoutExercise(
                    exercise: sampleExercises[1],
                    sets: [
                        ExerciseSet(reps: 6, weight: 100, restTime: 150, completed: true),
                        ExerciseSet(reps: 6, weight: 102.5, restTime: 150, completed: true)
                    ]
                ),
                WorkoutExercise(
                    exercise: sampleExercises[2],
                    sets: [
                        ExerciseSet(reps: 5, weight: 120, restTime: 150, completed: true)
                    ]
                )
            ],
            duration: 70 * 60,
            notes: "Abschluss mit leichtem Core-Finisher"
        )

        workouts = [pushDay, pullDay, legs]
    }
}
