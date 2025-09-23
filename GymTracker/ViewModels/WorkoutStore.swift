import Foundation
import SwiftUI

class WorkoutStore: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var workouts: [Workout] = []
    @Published var weeklyGoal: Int = 5

    init() {
        loadSampleData()
    }

    func addExercise(_ exercise: Exercise) {
        guard !exercises.contains(where: { $0.id == exercise.id || $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame }) else { return }
        exercises.append(exercise)
    }

    func updateExercise(_ exercise: Exercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[index] = exercise

        workouts = workouts.map { workout in
            var updatedWorkout = workout
            updatedWorkout.exercises = workout.exercises.map { workoutExercise in
                var mutableExercise = workoutExercise
                if workoutExercise.exercise.id == exercise.id {
                    mutableExercise.exercise = exercise
                }
                return mutableExercise
            }
            return updatedWorkout
        }
    }

    func addWorkout(_ workout: Workout) {
        workouts.insert(workout, at: 0)
    }

    func updateWorkout(_ workout: Workout) {
        guard let index = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        workouts[index] = workout
    }

    func exercise(named name: String) -> Exercise {
        if let existing = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }

        let newExercise = Exercise(name: name, muscleGroups: [], description: "")
        exercises.append(newExercise)
        return newExercise
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        workouts
            .filter { $0.id != workout.id && $0.date < workout.date }
            .sorted { $0.date > $1.date }
            .first
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
        let removedExercises = indexSet.map { exercises[$0] }
        exercises.remove(atOffsets: indexSet)

        workouts = workouts.map { workout in
            var updatedWorkout = workout
            updatedWorkout.exercises.removeAll { workoutExercise in
                removedExercises.contains(where: { $0.id == workoutExercise.exercise.id })
            }
            return updatedWorkout
        }
    }

    func deleteWorkout(at indexSet: IndexSet) {
        workouts.remove(atOffsets: indexSet)
    }

    private func loadSampleData() {
        let sampleExercises = [
            Exercise(name: "Chest Press", muscleGroups: [.chest, .triceps], description: "Maschinen-gestützte Brustpresse"),
            Exercise(name: "Chest Fly", muscleGroups: [.chest], description: "Fly-Maschine für definierte Brustmuskulatur"),
            Exercise(name: "Leg Press", muscleGroups: [.legs, .glutes], description: "Kraftvolle Beinpressen-Session"),
            Exercise(name: "Leg Extension", muscleGroups: [.legs], description: "Quadrizeps-Isolation an der Maschine"),
            Exercise(name: "Wadenheben", muscleGroups: [.legs], description: "Gezieltes Wadenheben an der Maschine"),
            Exercise(name: "Crunch", muscleGroups: [.abs], description: "Crunch-Maschine für Core-Stabilität"),
            Exercise(name: "Lat Pulldown", muscleGroups: [.back, .biceps], description: "Latzug mit Fokus auf den breiten Rücken"),
            Exercise(name: "Seated Row", muscleGroups: [.back, .biceps], description: "Rudermaschine für den mittleren Rücken"),
            Exercise(name: "Leg Curl", muscleGroups: [.legs, .glutes], description: "Beincurl sitzend für hintere Oberschenkel"),
            Exercise(name: "Back Extension", muscleGroups: [.back, .glutes], description: "Rückenstrecker an der Maschine")
        ]

        exercises = sampleExercises

        workouts = [
            Workout(
                name: "Tag A – Push",
                exercises: [
                    WorkoutExercise(
                        exercise: sampleExercises[0],
                        sets: presetSets(reps: 10, range: "10-12", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[1],
                        sets: presetSets(reps: 10, range: "10-12", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[2],
                        sets: presetSets(reps: 10, range: "10-12", count: 4)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[3],
                        sets: presetSets(reps: 12, range: "12-15", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[4],
                        sets: presetSets(reps: 15, range: "15-20", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[5],
                        sets: presetSets(reps: 15, range: "15-20", count: 3)
                    )
                ],
                defaultRestTime: 90,
                notes: "Push-orientiertes Maschinen-Workout"
            ),
            Workout(
                name: "Tag B – Pull",
                exercises: [
                    WorkoutExercise(
                        exercise: sampleExercises[6],
                        sets: presetSets(reps: 10, range: "10-12", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[7],
                        sets: presetSets(reps: 10, range: "10-12", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[8],
                        sets: presetSets(reps: 12, range: "12-15", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[2],
                        sets: presetSets(reps: 12, range: "12-15", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[9],
                        sets: presetSets(reps: 12, range: "12-15", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[5],
                        sets: presetSets(reps: 15, range: "15-20", count: 3)
                    )
                ],
                defaultRestTime: 90,
                notes: "Pull-orientiertes Maschinen-Workout"
            ),
            Workout(
                name: "Tag C – Ganzkörper & Core",
                exercises: [
                    WorkoutExercise(exercise: sampleExercises[0], sets: presetSets(reps: 10, range: "10-12", count: 3)),
                    WorkoutExercise(exercise: sampleExercises[6], sets: presetSets(reps: 10, range: "10-12", count: 3)),
                    WorkoutExercise(exercise: sampleExercises[7], sets: presetSets(reps: 10, range: "10-12", count: 2)),
                    WorkoutExercise(exercise: sampleExercises[2], sets: presetSets(reps: 10, range: "10-12", count: 4)),
                    WorkoutExercise(exercise: sampleExercises[8], sets: presetSets(reps: 12, range: "12-15", count: 2)),
                    WorkoutExercise(exercise: sampleExercises[3], sets: presetSets(reps: 12, range: "12-15", count: 2)),
                    WorkoutExercise(exercise: sampleExercises[4], sets: presetSets(reps: 15, range: "15-20", count: 3)),
                    WorkoutExercise(exercise: sampleExercises[5], sets: presetSets(reps: 15, range: "15-20", count: 3)),
                    WorkoutExercise(exercise: sampleExercises[9], sets: presetSets(reps: 12, range: "12-15", count: 2))
                ],
                defaultRestTime: 90,
                notes: "Ganzkörperfokus mit Core-Finisher"
            )
        ]
    }

    private func presetSets(reps: Int, range _: String, count: Int) -> [ExerciseSet] {
        (0..<count).map { _ in
            ExerciseSet(reps: reps, weight: 0, restTime: 90, completed: false)
        }
    }
}

// MARK: - Analytics Helpers

extension WorkoutStore {
    struct ExerciseStats: Identifiable {
        struct HistoryPoint: Identifiable {
            let id = UUID()
            let date: Date
            let volume: Double
            let estimatedOneRepMax: Double
        }

        let id = UUID()
        let exercise: Exercise
        let totalVolume: Double
        let totalReps: Int
        let maxWeight: Double
        let estimatedOneRepMax: Double
        let history: [HistoryPoint]
    }

    var totalWorkoutCount: Int { workouts.count }

    var averageWorkoutsPerWeek: Double {
        guard let earliestDate = workouts.min(by: { $0.date < $1.date })?.date else { return 0 }
        let span = max(Date().timeIntervalSince(earliestDate), 1)
        let weeks = max(span / (7 * 24 * 60 * 60), 1)
        return Double(workouts.count) / weeks
    }

    var currentWeekStreak: Int {
        guard !workouts.isEmpty else { return 0 }
        let calendar = Calendar.current
        let weekStarts: Set<Date> = Set(workouts.compactMap { workout in
            calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: workout.date))
        })

        guard var cursor = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0
        }

        var streak = 0

        while weekStarts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    var averageDurationMinutes: Int {
        let durations = workouts.compactMap { $0.duration }
        guard !durations.isEmpty else { return 0 }
        let total = durations.reduce(0, +)
        return Int(total / Double(durations.count) / 60)
    }

    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)] {
        let calendar = Calendar.current
        let threshold = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()

        let filtered = workouts.filter { $0.date >= threshold }
        var totals: [MuscleGroup: Double] = [:]

        for workout in filtered {
            for exercise in workout.exercises {
                let volume = exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
                for muscle in exercise.exercise.muscleGroups {
                    totals[muscle, default: 0] += volume
                }
            }
        }

        return totals.sorted { $0.value > $1.value }
    }

    func exerciseStats(for exercise: Exercise) -> ExerciseStats? {
        let relevantWorkouts = workouts.filter { workout in
            workout.exercises.contains { $0.exercise.id == exercise.id }
        }

        guard !relevantWorkouts.isEmpty else { return nil }

        var totalVolume: Double = 0
        var totalReps: Int = 0
        var maxWeight: Double = 0
        var history: [ExerciseStats.HistoryPoint] = []

        for workout in relevantWorkouts.sorted(by: { $0.date < $1.date }) {
            let sets = workout.exercises
                .filter { $0.exercise.id == exercise.id }
                .flatMap { $0.sets }

            let volume = sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
            let reps = sets.reduce(0) { $0 + $1.reps }
            let maxSetWeight = sets.map { $0.weight }.max() ?? 0
            let oneRepMax = sets.map { estimateOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? maxSetWeight

            totalVolume += volume
            totalReps += reps
            maxWeight = max(maxWeight, maxSetWeight)

            history.append(
                ExerciseStats.HistoryPoint(
                    date: workout.date,
                    volume: volume,
                    estimatedOneRepMax: oneRepMax
                )
            )
        }

        let bestOneRepMax = history.map { $0.estimatedOneRepMax }.max() ?? maxWeight

        return ExerciseStats(
            exercise: exercise,
            totalVolume: totalVolume,
            totalReps: totalReps,
            maxWeight: maxWeight,
            estimatedOneRepMax: bestOneRepMax,
            history: history
        )
    }

    func workoutsByDay(in range: ClosedRange<Date>) -> [Date: [Workout]] {
        let calendar = Calendar.current
        return Dictionary(grouping: workouts.filter { range.contains($0.date) }) { workout in
            calendar.startOfDay(for: workout.date)
        }
    }

    private func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
}
