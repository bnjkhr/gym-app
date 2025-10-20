import Foundation

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var exercises: [WorkoutExercise]
    var defaultRestTime: TimeInterval
    var duration: TimeInterval?
    var startDate: Date?  // ✅ NEU: Wann wurde die aktive Session gestartet?
    var notes: String
    var isFavorite: Bool
    var level: String?
    var workoutType: String?
    var estimatedDuration: String?
    var frequency: String?

    init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        exercises: [WorkoutExercise] = [],
        defaultRestTime: TimeInterval = 90,
        duration: TimeInterval? = nil,
        startDate: Date? = nil,  // ✅ NEU
        notes: String = "",
        isFavorite: Bool = false,
        level: String? = nil,
        workoutType: String? = nil,
        estimatedDuration: String? = nil,
        frequency: String? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.exercises = exercises
        self.defaultRestTime = defaultRestTime
        self.duration = duration
        self.startDate = startDate  // ✅ NEU
        self.notes = notes
        self.isFavorite = isFavorite
        self.level = level
        self.workoutType = workoutType
        self.estimatedDuration = estimatedDuration
        self.frequency = frequency
    }

    /// Computed Property: Aktuelle Dauer der laufenden Session
    /// - Returns: Live-Dauer seit startDate oder gespeicherte duration
    var currentDuration: TimeInterval {
        guard let start = startDate else {
            return duration ?? 0
        }
        return Date().timeIntervalSince(start)
    }

    /// Formatierte Darstellung der aktuellen Dauer (MM:SS)
    var formattedCurrentDuration: String {
        let totalSeconds = Int(currentDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case date
        case exercises
        case defaultRestTime
        case duration
        case startDate  // ✅ NEU
        case notes
        case isFavorite
        case level
        case workoutType
        case estimatedDuration
        case frequency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.date = try container.decode(Date.self, forKey: .date)
        self.exercises = try container.decode([WorkoutExercise].self, forKey: .exercises)
        self.defaultRestTime =
            try container.decodeIfPresent(TimeInterval.self, forKey: .defaultRestTime) ?? 90
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)  // ✅ NEU
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.level = try container.decodeIfPresent(String.self, forKey: .level)
        self.workoutType = try container.decodeIfPresent(String.self, forKey: .workoutType)
        self.estimatedDuration = try container.decodeIfPresent(
            String.self, forKey: .estimatedDuration)
        self.frequency = try container.decodeIfPresent(String.self, forKey: .frequency)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(date, forKey: .date)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(defaultRestTime, forKey: .defaultRestTime)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(startDate, forKey: .startDate)  // ✅ NEU
        try container.encode(notes, forKey: .notes)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(level, forKey: .level)
        try container.encodeIfPresent(workoutType, forKey: .workoutType)
        try container.encodeIfPresent(estimatedDuration, forKey: .estimatedDuration)
        try container.encodeIfPresent(frequency, forKey: .frequency)
    }
}

struct WorkoutExercise: Identifiable, Codable {
    let id: UUID
    var exercise: Exercise
    var sets: [ExerciseSet]
    var notes: String?  // ✅ NEU: Notizen zur Übung (z.B. "Felt heavy today")
    var restTimeToNext: TimeInterval?  // ✅ NEU: Pause bis zur nächsten Übung (z.B. 03:00)

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        sets: [ExerciseSet] = [],
        notes: String? = nil,  // ✅ NEU
        restTimeToNext: TimeInterval? = nil  // ✅ NEU
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.notes = notes  // ✅ NEU
        self.restTimeToNext = restTimeToNext  // ✅ NEU
    }

    /// Formatierte Darstellung der Pause zur nächsten Übung (MM:SS)
    var formattedRestTimeToNext: String? {
        guard let restTime = restTimeToNext, restTime > 0 else { return nil }
        let totalSeconds = Int(restTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

enum SetUnit: String, Codable, CaseIterable {
    case weight = "kg"
    case time = "min"
    case reps = "reps"
    case distance = "km"
}

struct ExerciseSet: Identifiable, Codable {
    let id: UUID
    var reps: Int
    var weight: Double
    var duration: TimeInterval?  // Für Cardio/zeitbasierte Übungen
    var unit: SetUnit?  // Einheit (kg, min, etc.)
    var restTime: TimeInterval
    var completed: Bool

    init(
        id: UUID = UUID(), reps: Int, weight: Double, duration: TimeInterval? = nil,
        unit: SetUnit? = nil, restTime: TimeInterval = 90, completed: Bool = false
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.unit = unit
        self.restTime = restTime
        self.completed = completed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reps
        case weight
        case duration
        case unit
        case restTime
        case completed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.reps = try container.decode(Int.self, forKey: .reps)
        self.weight = try container.decode(Double.self, forKey: .weight)
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.unit = try container.decodeIfPresent(SetUnit.self, forKey: .unit)
        self.restTime = try container.decodeIfPresent(TimeInterval.self, forKey: .restTime) ?? 90
        self.completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reps, forKey: .reps)
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encode(restTime, forKey: .restTime)
        try container.encode(completed, forKey: .completed)
    }
}
