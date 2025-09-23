import Foundation

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var exercises: [WorkoutExercise]
    var defaultRestTime: TimeInterval
    var duration: TimeInterval?
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        exercises: [WorkoutExercise] = [],
        defaultRestTime: TimeInterval = 90,
        duration: TimeInterval? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.exercises = exercises
        self.defaultRestTime = defaultRestTime
        self.duration = duration
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case date
        case exercises
        case defaultRestTime
        case duration
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.date = try container.decode(Date.self, forKey: .date)
        self.exercises = try container.decode([WorkoutExercise].self, forKey: .exercises)
        self.defaultRestTime = try container.decodeIfPresent(TimeInterval.self, forKey: .defaultRestTime) ?? 90
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(date, forKey: .date)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(defaultRestTime, forKey: .defaultRestTime)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(notes, forKey: .notes)
    }
}

struct WorkoutExercise: Identifiable, Codable {
    let id: UUID
    var exercise: Exercise
    var sets: [ExerciseSet]

    init(id: UUID = UUID(), exercise: Exercise, sets: [ExerciseSet] = []) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
    }
}

struct ExerciseSet: Identifiable, Codable {
    let id: UUID
    var reps: Int
    var weight: Double
    var restTime: TimeInterval
    var completed: Bool

    init(id: UUID = UUID(), reps: Int, weight: Double, restTime: TimeInterval = 90, completed: Bool = false) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.restTime = restTime
        self.completed = completed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reps
        case weight
        case restTime
        case completed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.reps = try container.decode(Int.self, forKey: .reps)
        self.weight = try container.decode(Double.self, forKey: .weight)
        self.restTime = try container.decodeIfPresent(TimeInterval.self, forKey: .restTime) ?? 90
        self.completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reps, forKey: .reps)
        try container.encode(weight, forKey: .weight)
        try container.encode(restTime, forKey: .restTime)
        try container.encode(completed, forKey: .completed)
    }
}
