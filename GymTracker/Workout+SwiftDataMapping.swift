#if canImport(SwiftData)
import Foundation
import SwiftData

// MARK: - Mapping from Entities to Value Types
extension Workout {
    init(entity: WorkoutEntity) {
        self.init(
            id: entity.id,
            name: entity.name,
            date: entity.date,
            exercises: [], // Avoid traversing relationships on potentially invalid snapshots
            defaultRestTime: entity.defaultRestTime,
            duration: entity.duration,
            notes: entity.notes,
            isFavorite: entity.isFavorite
        )
    }
    
    init(entity: WorkoutEntity, in context: ModelContext) {
        // Refetch workout by id from the provided context to ensure a valid instance
        let workoutId = entity.id
        let wDesc = FetchDescriptor<WorkoutEntity>(predicate: #Predicate { entity in
            entity.id == workoutId
        })
        let fresh = (try? context.fetch(wDesc).first) ?? entity

        // Sort exercises by order to maintain correct sequence
        let sortedExercises = fresh.exercises.sorted { $0.order < $1.order }

        // Debug logging
        print("📖 [Workout+Mapping] Lade Workout: \(fresh.name)")
        print("📋 [Workout+Mapping] Übungen aus DB (sortiert nach order):")
        for (i, we) in sortedExercises.enumerated() {
            print("  [\(i)] order=\(we.order) \(we.exercise?.name ?? "Unknown")")
        }

        let mappedExercises: [WorkoutExercise] = sortedExercises.compactMap { we in
            return WorkoutExercise(entity: we, in: context)
        }

        self.init(
            id: fresh.id,
            name: fresh.name,
            date: fresh.date,
            exercises: mappedExercises,
            defaultRestTime: fresh.defaultRestTime,
            duration: fresh.duration,
            notes: fresh.notes,
            isFavorite: fresh.isFavorite
        )
    }
}

extension WorkoutExercise {
    init(entity: WorkoutExerciseEntity) {
        // Minimal, defensive initializer that avoids traversing invalidated relationships
        let placeholder = Exercise(
            id: UUID(),
            name: "Übung nicht verfügbar",
            muscleGroups: [],
            description: "",
            instructions: [],
            createdAt: Date()
        )
        let sets = entity.sets.map { ExerciseSet(entity: $0) }
        self.init(id: entity.id, exercise: placeholder, sets: sets)
    }
}

extension WorkoutExercise {
    init(entity: WorkoutExerciseEntity, in context: ModelContext) {
        let sets = entity.sets.map { ExerciseSet(entity: $0) }
        
        if let exEntity = entity.exerciseEntity {
            let exercise = Exercise(entity: exEntity, in: context)
            self.init(id: entity.id, exercise: exercise, sets: sets)
        } else {
            let placeholder = Exercise(
                id: UUID(),
                name: "Übung nicht verfügbar",
                muscleGroups: [],
                description: "",
                instructions: [],
                createdAt: Date()
            )
            self.init(id: entity.id, exercise: placeholder, sets: sets)
        }
    }
}

extension ExerciseSet {
    init(entity: ExerciseSetEntity) {
        self.init(
            id: entity.id,
            reps: entity.reps,
            weight: entity.weight,
            restTime: entity.restTime,
            completed: entity.completed
        )
    }
}

extension Exercise {
    init(entity: ExerciseEntity) {
        // Avoid direct access to snapshot properties that may be invalidated
        self.init(
            id: entity.id,
            name: entity.name,
            muscleGroups: [],
            equipmentType: EquipmentType(rawValue: entity.equipmentTypeRaw) ?? .mixed,
            difficultyLevel: DifficultyLevel(rawValue: entity.difficultyLevelRaw) ?? .anfänger,
            description: entity.descriptionText,
            instructions: entity.instructions,
            createdAt: entity.createdAt
        )
    }
}

extension Exercise {
    init(entity: ExerciseEntity, in context: ModelContext) {
        // Simple approach: try to refetch, but if that fails, use placeholder data
        let exId = entity.id
        let eDesc = FetchDescriptor<ExerciseEntity>(predicate: #Predicate { entity in
            entity.id == exId
        })
        
        let fresh = (try? context.fetch(eDesc).first) ?? entity
        
        // Direct access to muscleGroupsRaw - let it crash if entity is truly invalid
        let groups: [MuscleGroup] = fresh.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
        let equipmentType = EquipmentType(rawValue: fresh.equipmentTypeRaw) ?? .mixed
        let difficultyLevel = DifficultyLevel(rawValue: fresh.difficultyLevelRaw) ?? .anfänger
        
        self.init(
            id: fresh.id,
            name: fresh.name,
            muscleGroups: groups,
            equipmentType: equipmentType,
            difficultyLevel: difficultyLevel,
            description: fresh.descriptionText,
            instructions: fresh.instructions,
            createdAt: fresh.createdAt
        )
    }
}

extension WorkoutSession {
    init(entity: WorkoutSessionEntityV1) {
        self.init(
            id: entity.id,
            templateId: entity.templateId,
            name: entity.name,
            date: entity.date,
            exercises: [],
            defaultRestTime: entity.defaultRestTime,
            duration: entity.duration,
            notes: entity.notes,
            minHeartRate: entity.minHeartRate,
            maxHeartRate: entity.maxHeartRate,
            avgHeartRate: entity.avgHeartRate
        )
    }
}

extension WorkoutSession {
    init(entity: WorkoutSessionEntityV1, in context: ModelContext) {
        let sId = entity.id
        let sDesc = FetchDescriptor<WorkoutSessionEntityV1>(predicate: #Predicate { entity in
            entity.id == sId
        })
        let fresh = (try? context.fetch(sDesc).first) ?? entity

        // Sort exercises by order to maintain correct sequence
        let sortedExercises = fresh.exercises.sorted { $0.order < $1.order }
        let mapped = sortedExercises.compactMap { we in
            return WorkoutExercise(entity: we, in: context)
        }

        self.init(
            id: fresh.id,
            templateId: fresh.templateId,
            name: fresh.name,
            date: fresh.date,
            exercises: mapped,
            defaultRestTime: fresh.defaultRestTime,
            duration: fresh.duration,
            notes: fresh.notes,
            minHeartRate: fresh.minHeartRate,
            maxHeartRate: fresh.maxHeartRate,
            avgHeartRate: fresh.avgHeartRate
        )
    }
}

// MARK: - Mapping from Value Types to Entities
extension WorkoutEntity {
    static func make(from workout: Workout) -> WorkoutEntity {
        let exerciseEntities: [WorkoutExerciseEntity] = workout.exercises.enumerated().map { (index, exercise) in
            WorkoutExerciseEntity.make(from: exercise, order: index)
        }
        return WorkoutEntity(
            id: workout.id,
            name: workout.name,
            date: workout.date,
            exercises: exerciseEntities,
            defaultRestTime: workout.defaultRestTime,
            duration: workout.duration,
            notes: workout.notes,
            isFavorite: workout.isFavorite
        )
    }
}

extension WorkoutExerciseEntity {
    static func make(from we: WorkoutExercise, order: Int = 0) -> WorkoutExerciseEntity {
        let exerciseEntity = ExerciseEntity.make(from: we.exercise)
        let setEntities = we.sets.map { ExerciseSetEntity.make(from: $0) }
        return WorkoutExerciseEntity(id: we.id, exercise: exerciseEntity, sets: setEntities, order: order)
    }

    static func make(from we: WorkoutExercise, withExistingExercise exerciseEntity: ExerciseEntity, order: Int = 0) -> WorkoutExerciseEntity {
        let setEntities = we.sets.map { ExerciseSetEntity.make(from: $0) }
        return WorkoutExerciseEntity(id: we.id, exercise: exerciseEntity, sets: setEntities, order: order)
    }
}

extension ExerciseSetEntity {
    static func make(from set: ExerciseSet) -> ExerciseSetEntity {
        ExerciseSetEntity(id: set.id, reps: set.reps, weight: set.weight, restTime: set.restTime, completed: set.completed)
    }
}

extension ExerciseEntity {
    static func make(from exercise: Exercise) -> ExerciseEntity {
        ExerciseEntity(
            id: exercise.id,
            name: exercise.name,
            muscleGroupsRaw: exercise.muscleGroups.map { $0.rawValue },
            equipmentTypeRaw: exercise.equipmentType.rawValue,
            difficultyLevelRaw: exercise.difficultyLevel.rawValue,
            descriptionText: exercise.description,
            instructions: exercise.instructions,
            createdAt: exercise.createdAt
        )
    }
}

extension WorkoutSessionEntityV1 {
    static func make(from session: WorkoutSession) -> WorkoutSessionEntityV1 {
        let exerciseEntities = session.exercises.enumerated().map { (index, exercise) in
            WorkoutExerciseEntity.make(from: exercise, order: index)
        }
        return WorkoutSessionEntity(
            id: session.id,
            templateId: session.templateId,
            name: session.name,
            date: session.date,
            exercises: exerciseEntities,
            defaultRestTime: session.defaultRestTime,
            duration: session.duration,
            notes: session.notes,
            minHeartRate: session.minHeartRate,
            maxHeartRate: session.maxHeartRate,
            avgHeartRate: session.avgHeartRate
        )
    }
}

// Note: These helpers intentionally duplicate ExerciseEntity creation rather than resolving an existing catalog entry.
// In a later phase, we can switch to a lookup by id/name within a shared catalog to avoid duplicates.

#endif

