import Foundation

struct Workout: Identifiable, Codable {
    let id = UUID()
    var name: String
    var date: Date
    var exercises: [WorkoutExercise]
    var duration: TimeInterval?
    var notes: String

    init(
        name: String,
        date: Date = Date(),
        exercises: [WorkoutExercise] = [],
        duration: TimeInterval? = nil,
        notes: String = ""
    ) {
        self.name = name
        self.date = date
        self.exercises = exercises
        self.duration = duration
        self.notes = notes
    }
}

struct WorkoutExercise: Identifiable, Codable {
    let id = UUID()
    var exercise: Exercise
    var sets: [ExerciseSet]

    init(exercise: Exercise, sets: [ExerciseSet] = []) {
        self.exercise = exercise
        self.sets = sets
    }
}

struct ExerciseSet: Identifiable, Codable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var restTime: TimeInterval?
    var completed: Bool

    init(reps: Int, weight: Double, restTime: TimeInterval? = nil, completed: Bool = false) {
        self.reps = reps
        self.weight = weight
        self.restTime = restTime
        self.completed = completed
    }
}
