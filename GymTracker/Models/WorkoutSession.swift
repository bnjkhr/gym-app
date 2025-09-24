import Foundation

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let templateId: UUID?
    var name: String
    var date: Date
    var exercises: [WorkoutExercise]
    var defaultRestTime: TimeInterval
    var duration: TimeInterval?
    var notes: String

    init(
        id: UUID = UUID(),
        templateId: UUID?,
        name: String,
        date: Date,
        exercises: [WorkoutExercise],
        defaultRestTime: TimeInterval,
        duration: TimeInterval?,
        notes: String
    ) {
        self.id = id
        self.templateId = templateId
        self.name = name
        self.date = date
        self.exercises = exercises
        self.defaultRestTime = defaultRestTime
        self.duration = duration
        self.notes = notes
    }
}

extension Workout {
    init(session: WorkoutSession) {
        self.init(
            id: UUID(), // ✅ Neue ID für Template-Konvertierung
            name: session.name,
            date: session.date,
            exercises: session.exercises,
            defaultRestTime: session.defaultRestTime,
            duration: session.duration,
            notes: session.notes
        )
    }
}
