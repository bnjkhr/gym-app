import Foundation
import SwiftData

// MARK: - ExerciseEntity
@Model
final class ExerciseEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    // Persist muscle groups as raw values for stability
    var muscleGroupsRaw: [String]
    var equipmentTypeRaw: String
    var descriptionText: String
    var instructions: [String]
    var createdAt: Date
    @Relationship(inverse: \WorkoutExerciseEntity.exercise) var usages: [WorkoutExerciseEntity] = []

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroupsRaw: [String] = [],
        equipmentTypeRaw: String = "mixed",
        descriptionText: String = "",
        instructions: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.muscleGroupsRaw = muscleGroupsRaw
        self.equipmentTypeRaw = equipmentTypeRaw
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
    var owner: WorkoutExerciseEntity?

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
    // Relationship to the master Exercise catalog. Do NOT cascade from usage to catalog; nullify reference when usage is deleted
    @Relationship(deleteRule: .nullify) var exercise: ExerciseEntity?
    // Ordered sets for this exercise within the workout
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSetEntity.owner) var sets: [ExerciseSetEntity]
    var workout: WorkoutEntity?
    var session: WorkoutSessionEntity?

    init(
        id: UUID = UUID(),
        exercise: ExerciseEntity? = nil,
        sets: [ExerciseSetEntity] = [],
        workout: WorkoutEntity? = nil,
        session: WorkoutSessionEntity? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.workout = workout
        self.session = session
    }
}

// MARK: - WorkoutEntity (Template)
@Model
final class WorkoutEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseEntity.workout) var exercises: [WorkoutExerciseEntity]
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
    
    /// Clean up any workout exercises that reference invalid exercise entities
    func cleanupInvalidExercises(modelContext: ModelContext) {
        let invalidExercises = exercises.filter { $0.exercise == nil }
        for invalidExercise in invalidExercises {
            modelContext.delete(invalidExercise)
        }
        if !invalidExercises.isEmpty {
            print("🧹 Cleaned up \(invalidExercises.count) invalid exercise references from workout: \(name)")
        }
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
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseEntity.session) var exercises: [WorkoutExerciseEntity]
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

// MARK: - ExerciseRecordEntity
@Model
final class ExerciseRecordEntity {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var exerciseName: String
    
    // Record types
    var maxWeight: Double
    var maxWeightReps: Int
    var maxWeightDate: Date
    
    var maxReps: Int
    var maxRepsWeight: Double
    var maxRepsDate: Date
    
    var bestEstimatedOneRepMax: Double
    var bestOneRepMaxWeight: Double
    var bestOneRepMaxReps: Int
    var bestOneRepMaxDate: Date
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        exerciseName: String,
        maxWeight: Double = 0,
        maxWeightReps: Int = 0,
        maxWeightDate: Date = Date(),
        maxReps: Int = 0,
        maxRepsWeight: Double = 0,
        maxRepsDate: Date = Date(),
        bestEstimatedOneRepMax: Double = 0,
        bestOneRepMaxWeight: Double = 0,
        bestOneRepMaxReps: Int = 0,
        bestOneRepMaxDate: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.maxWeight = maxWeight
        self.maxWeightReps = maxWeightReps
        self.maxWeightDate = maxWeightDate
        self.maxReps = maxReps
        self.maxRepsWeight = maxRepsWeight
        self.maxRepsDate = maxRepsDate
        self.bestEstimatedOneRepMax = bestEstimatedOneRepMax
        self.bestOneRepMaxWeight = bestOneRepMaxWeight
        self.bestOneRepMaxReps = bestOneRepMaxReps
        self.bestOneRepMaxDate = bestOneRepMaxDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - UserProfileEntity
@Model
final class UserProfileEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var birthDate: Date?
    var weight: Double?
    var height: Double?
    var biologicalSexRaw: Int16 // HKBiologicalSex.rawValue
    var healthKitSyncEnabled: Bool
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
        height: Double? = nil,
        biologicalSexRaw: Int16 = 0, // HKBiologicalSex.notSet
        healthKitSyncEnabled: Bool = false,
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
        self.height = height
        self.biologicalSexRaw = biologicalSexRaw
        self.healthKitSyncEnabled = healthKitSyncEnabled
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
    /// Deprecated: Accessing via this property can crash if the entity instance is invalidated.
    /// Use direct access to muscleGroupsRaw or refetch the entity from context.
    @available(*, deprecated, message: "Use direct access to muscleGroupsRaw or refetch the entity from context.")
    var muscleGroups: [String] { muscleGroupsRaw }
}

extension WorkoutExerciseEntity {
    /// Simple accessor that may return nil if invalidated - caller should handle gracefully
    var exerciseEntity: ExerciseEntity? { exercise }
    
    /// Simple check - may return false if invalidated
    var hasExercise: Bool { exercise != nil }
    
    /// Simple name accessor with fallback
    var exerciseName: String {
        exercise?.name ?? "Übung nicht verfügbar"
    }
}


// MARK: - Safe Entity Access Helpers

// Note: fetchExercise(by:in:) is defined in SwiftDataSafeMapping.swift

/// Safely fetch a WorkoutEntity by ID from the given context
/// - Parameters:
///   - id: The UUID of the workout to fetch
///   - context: The ModelContext to fetch from
/// - Returns: The fresh WorkoutEntity or nil if not found
func fetchWorkout(by id: UUID, in context: ModelContext) -> WorkoutEntity? {
    let descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate<WorkoutEntity> { entity in
            entity.id == id
        }
    )
    return try? context.fetch(descriptor).first
}

/// Safely fetch a WorkoutSessionEntity by ID from the given context
/// - Parameters:
///   - id: The UUID of the session to fetch
///   - context: The ModelContext to fetch from
/// - Returns: The fresh WorkoutSessionEntity or nil if not found
func fetchSession(by id: UUID, in context: ModelContext) -> WorkoutSessionEntity? {
    let descriptor = FetchDescriptor<WorkoutSessionEntity>(
        predicate: #Predicate<WorkoutSessionEntity> { entity in
            entity.id == id
        }
    )
    return try? context.fetch(descriptor).first
}

// MARK: - Entity Creation Helpers



extension WorkoutExerciseEntity {
    /// Create a new WorkoutExerciseEntity from a WorkoutExercise domain model
    static func make(from workoutExercise: WorkoutExercise, using exerciseEntity: ExerciseEntity) -> WorkoutExerciseEntity {
        let entity = WorkoutExerciseEntity(
            exercise: exerciseEntity,
            sets: []
        )
        
        // Add sets
        for set in workoutExercise.sets {
            let setEntity = ExerciseSetEntity(
                reps: set.reps,
                weight: set.weight,
                restTime: set.restTime,
                completed: set.completed
            )
            entity.sets.append(setEntity)
        }
        
        return entity
    }
}

// Note: Additional convenience mapping methods between SwiftData entities and value types 
// are defined in Workout+SwiftDataMapping.swift to keep this file focused on 
// entity definitions and safe access patterns.

