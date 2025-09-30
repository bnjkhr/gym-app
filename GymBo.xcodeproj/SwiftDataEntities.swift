#if false
import Foundation
import SwiftData

// MARK: - ExerciseEntity
@Model
final class ExerciseEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    // Persist muscle groups as raw values for stability
    var muscleGroupsRaw: [String]
    var descriptionText: String
    var instructions: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroupsRaw: [String] = [],
        descriptionText: String = "",
        instructions: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.muscleGroupsRaw = muscleGroupsRaw
        self.descriptionText = descriptionText
        self.instructions = instructions
        self.createdAt = createdAt
    }
}

// MARK: - ExerciseSetEntity
@Model
final class ExerciseSetEntity {
    @Attribute(.unique) var id: UUID
    var reps: Int
    var weight: Double
    var restTime: TimeInterval
    var completed: Bool

    init(
        id: UUID = UUID(),
        reps: Int,
        weight: Double,
        restTime: TimeInterval = 90,
        completed: Bool = false
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.restTime = restTime
        self.completed = completed
    }
}

// MARK: - WorkoutExerciseEntity
@Model
final class WorkoutExerciseEntity {
    @Attribute(.unique) var id: UUID
    // Relationship to the master Exercise catalog
    var exercise: ExerciseEntity
    // Ordered sets for this exercise within the workout
    var sets: [ExerciseSetEntity]

    init(
        id: UUID = UUID(),
        exercise: ExerciseEntity,
        sets: [ExerciseSetEntity] = []
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
    }
}

// MARK: - WorkoutEntity (Template)
@Model
final class WorkoutEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    var exercises: [WorkoutExerciseEntity]
    var defaultRestTime: TimeInterval
    var duration: TimeInterval?
    var notes: String
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        exercises: [WorkoutExerciseEntity] = [],
        defaultRestTime: TimeInterval = 90,
        duration: TimeInterval? = nil,
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.exercises = exercises
        self.defaultRestTime = defaultRestTime
        self.duration = duration
        self.notes = notes
        self.isFavorite = isFavorite
    }
}

// MARK: - WorkoutSessionEntity (History)
@Model
final class WorkoutSessionEntity {
    @Attribute(.unique) var id: UUID
    // Optional link back to a template workout
    var templateId: UUID?
    var name: String
    var date: Date
    var exercises: [WorkoutExerciseEntity]
    var defaultRestTime: TimeInterval
    var duration: TimeInterval?
    var notes: String

    init(
        id: UUID = UUID(),
        templateId: UUID?,
        name: String,
        date: Date,
        exercises: [WorkoutExerciseEntity],
        defaultRestTime: TimeInterval,
        duration: TimeInterval? = nil,
        notes: String = ""
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

// MARK: - UserProfileEntity
@Model
final class UserProfileEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var birthDate: Date?
    var weight: Double?
    // Persist profile goal and preferences as raw values
    var goalRaw: String
    var experienceRaw: String
    var equipmentRaw: String
    var preferredDurationRaw: Int

    var profileImageData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        birthDate: Date? = nil,
        weight: Double? = nil,
        goalRaw: String = "general",
        experienceRaw: String = "intermediate",
        equipmentRaw: String = "mixed",
        preferredDurationRaw: Int = 45,
        profileImageData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.weight = weight
        self.goalRaw = goalRaw
        self.experienceRaw = experienceRaw
        self.equipmentRaw = equipmentRaw
        self.preferredDurationRaw = preferredDurationRaw
        self.profileImageData = profileImageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Convenience mapping helpers (non-persisted)
extension ExerciseEntity {
    // Map raw muscle group strings to app enum when needed
    var muscleGroups: [String] { muscleGroupsRaw }
}

// Note: We intentionally keep mapping helpers minimal in Phase 1.
// In a later phase, we can add convenience initializers to convert from/to
// the existing structs (Exercise, Workout, WorkoutSession, UserProfile) safely.

#endif
