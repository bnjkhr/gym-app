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
    var difficultyLevelRaw: String  // NEU: Schwierigkeitsgrad als String gespeichert
    var descriptionText: String
    var instructions: [String]
    var createdAt: Date

    // 🆕 NEU: Letzte verwendete Werte für bessere UX
    var lastUsedWeight: Double?
    var lastUsedReps: Int?
    var lastUsedSetCount: Int?
    var lastUsedDate: Date?
    var lastUsedRestTime: TimeInterval?

    @Relationship(inverse: \WorkoutExerciseEntity.exercise) var usages: [WorkoutExerciseEntity] = []

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroupsRaw: [String] = [],
        equipmentTypeRaw: String = "mixed",
        difficultyLevelRaw: String = "Anfänger",  // Default-Schwierigkeitsgrad
        descriptionText: String = "",
        instructions: [String] = [],
        createdAt: Date = Date(),
        lastUsedWeight: Double? = nil,
        lastUsedReps: Int? = nil,
        lastUsedSetCount: Int? = nil,
        lastUsedDate: Date? = nil,
        lastUsedRestTime: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.muscleGroupsRaw = muscleGroupsRaw
        self.equipmentTypeRaw = equipmentTypeRaw
        self.difficultyLevelRaw = difficultyLevelRaw
        self.descriptionText = descriptionText
        self.instructions = instructions
        self.createdAt = createdAt
        self.lastUsedWeight = lastUsedWeight
        self.lastUsedReps = lastUsedReps
        self.lastUsedSetCount = lastUsedSetCount
        self.lastUsedDate = lastUsedDate
        self.lastUsedRestTime = lastUsedRestTime
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
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSetEntity.owner) var sets:
        [ExerciseSetEntity]
    var workout: WorkoutEntity?
    var session: WorkoutSessionEntity?
    var order: Int = 0  // Maintains the order of exercises in the workout (default 0 for existing data)

    // ✅ NEU: Notizen zur Übung
    var notes: String? = nil

    // ✅ NEU: Pause bis zur nächsten Übung (in Sekunden)
    var restTimeToNext: TimeInterval? = nil

    init(
        id: UUID = UUID(),
        exercise: ExerciseEntity? = nil,
        sets: [ExerciseSetEntity] = [],
        workout: WorkoutEntity? = nil,
        session: WorkoutSessionEntity? = nil,
        order: Int = 0,
        notes: String? = nil,  // ✅ NEU
        restTimeToNext: TimeInterval? = nil  // ✅ NEU
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.workout = workout
        self.session = session
        self.order = order
        self.notes = notes  // ✅ NEU
        self.restTimeToNext = restTimeToNext  // ✅ NEU
    }
}

// MARK: - WorkoutFolderEntity
@Model
final class WorkoutFolderEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String  // Hex color string
    var order: Int
    var createdDate: Date
    @Relationship(deleteRule: .nullify, inverse: \WorkoutEntity.folder) var workouts:
        [WorkoutEntity] = []

    init(
        id: UUID = UUID(),
        name: String,
        color: String = "#8B5CF6",  // Default purple
        order: Int = 0,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.order = order
        self.createdDate = createdDate
        self.workouts = []
    }
}

// MARK: - WorkoutEntity (Template)
@Model
final class WorkoutEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseEntity.workout) var exercises:
        [WorkoutExerciseEntity]
    var defaultRestTime: TimeInterval
    var duration: TimeInterval?
    var startDate: Date? = nil  // ✅ NEU: Wann wurde die aktive Session gestartet?
    var notes: String
    var isFavorite: Bool
    var isSampleWorkout: Bool?  // Markiert Beispiel-Workouts für versioniertes Update (nil = alte Workouts)

    // Performance: Cached exercise count to avoid loading relationship
    var exerciseCount: Int = 0

    // Folder organization (default values for migration compatibility)
    @Relationship(deleteRule: .nullify) var folder: WorkoutFolderEntity? = nil
    var orderInFolder: Int = 0

    init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        exercises: [WorkoutExerciseEntity] = [],
        defaultRestTime: TimeInterval = 90,
        duration: TimeInterval? = nil,
        startDate: Date? = nil,  // ✅ NEU
        notes: String = "",
        isFavorite: Bool = false,
        isSampleWorkout: Bool? = nil,
        folder: WorkoutFolderEntity? = nil,
        orderInFolder: Int = 0
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
        self.isSampleWorkout = isSampleWorkout
        self.exerciseCount = exercises.count
        self.folder = folder
        self.orderInFolder = orderInFolder
    }

    /// Performance: Update cached exercise count
    func updateExerciseCount() {
        exerciseCount = exercises.count
    }

    /// Clean up any workout exercises that reference invalid exercise entities
    func cleanupInvalidExercises(modelContext: ModelContext) {
        let invalidExercises = exercises.filter { $0.exercise == nil }
        for invalidExercise in invalidExercises {
            modelContext.delete(invalidExercise)
        }
        if !invalidExercises.isEmpty {
            print(
                "🧹 Cleaned up \(invalidExercises.count) invalid exercise references from workout: \(name)"
            )
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
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseEntity.session) var exercises:
        [WorkoutExerciseEntity]
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
        exercises: [WorkoutExerciseEntity],
        defaultRestTime: TimeInterval,
        duration: TimeInterval? = nil,
        notes: String = "",
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
    var biologicalSexRaw: Int16  // HKBiologicalSex.rawValue
    var healthKitSyncEnabled: Bool
    // Persist profile goal and preferences as raw values
    var goalRaw: String
    var experienceRaw: String
    var equipmentRaw: String
    var preferredDurationRaw: Int

    var profileImageData: Data?
    var lockerNumber: String?  // Spintnummer
    var hasExploredWorkouts: Bool  // Onboarding: Beispielworkouts entdeckt
    var hasCreatedFirstWorkout: Bool  // Onboarding: Erstes Workout erstellt
    var hasSetupProfile: Bool  // Onboarding: Profil eingerichtet
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        birthDate: Date? = nil,
        weight: Double? = nil,
        height: Double? = nil,
        biologicalSexRaw: Int16 = 0,  // HKBiologicalSex.notSet
        healthKitSyncEnabled: Bool = false,
        goalRaw: String = "general",
        experienceRaw: String = "intermediate",
        equipmentRaw: String = "mixed",
        preferredDurationRaw: Int = 45,
        profileImageData: Data? = nil,
        lockerNumber: String? = nil,
        hasExploredWorkouts: Bool = false,
        hasCreatedFirstWorkout: Bool = false,
        hasSetupProfile: Bool = false,
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
        self.lockerNumber = lockerNumber
        self.hasExploredWorkouts = hasExploredWorkouts
        self.hasCreatedFirstWorkout = hasCreatedFirstWorkout
        self.hasSetupProfile = hasSetupProfile
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Convenience mapping helpers (non-persisted)
extension ExerciseEntity {
    /// Deprecated: Accessing via this property can crash if the entity instance is invalidated.
    /// Use direct access to muscleGroupsRaw or refetch the entity from context.
    @available(
        *, deprecated,
        message: "Use direct access to muscleGroupsRaw or refetch the entity from context."
    )
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
    static func make(from workoutExercise: WorkoutExercise, using exerciseEntity: ExerciseEntity)
        -> WorkoutExerciseEntity
    {
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
