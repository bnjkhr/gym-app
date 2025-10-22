import Foundation

// V1 Legacy Model - Renamed to avoid conflict with V2 Domain Entity
// TODO: Migrate usages to V2 WorkoutSessionV1 (Domain/Entities/WorkoutSessionV1.swift)
struct WorkoutSessionV1: Identifiable, Codable {
    let id: UUID
    let templateId: UUID?
    var name: String
    var date: Date
    var exercises: [WorkoutExercise]
    var defaultRestTime: TimeInterval
    var duration: TimeInterval?
    var notes: String

    // Herzfrequenzdaten
    var minHeartRate: Int?
    var maxHeartRate: Int?
    var avgHeartRate: Int?

    init(
        id: UUID = UUID(),
        templateId: UUID?,
        name: String,
        date: Date,
        exercises: [WorkoutExercise],
        defaultRestTime: TimeInterval,
        duration: TimeInterval?,
        notes: String,
        minHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        avgHeartRate: Int? = nil
    ) {
        self.id = id
        self.templateId = templateId
        self.name = name
        self.date = date
        self.exercises = exercises
        self.defaultRestTime = defaultRestTime
        self.duration = duration
        self.notes = notes
        self.minHeartRate = minHeartRate
        self.maxHeartRate = maxHeartRate
        self.avgHeartRate = avgHeartRate
    }
}

extension Workout {
    init(session: WorkoutSessionV1) {
        self.init(
            id: UUID(),  // ✅ Neue ID für Template-Konvertierung
            name: session.name,
            date: session.date,
            exercises: session.exercises,
            defaultRestTime: session.defaultRestTime,
            duration: session.duration,
            notes: session.notes
        )
    }
}
