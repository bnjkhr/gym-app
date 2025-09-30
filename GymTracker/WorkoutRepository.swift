#if canImport(SwiftData)
import Foundation
import SwiftData

// MARK: - Protocol
protocol WorkoutRepository {
    func fetchAll() throws -> [Workout]
    func upsert(_ workout: Workout) throws
    func delete(id: UUID) throws
}

// MARK: - SwiftData Implementation (not used yet)
final class SwiftDataWorkoutRepository: WorkoutRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Workout] {
        let descriptor = FetchDescriptor<WorkoutEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entities = try context.fetch(descriptor)
        return entities.map(Workout.init(entity:))
    }

    func upsert(_ workout: Workout) throws {
        // Try to find existing entity by id
        let predicate = #Predicate<WorkoutEntity> { $0.id == workout.id }
        let descriptor = FetchDescriptor<WorkoutEntity>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            // Update existing
            existing.name = workout.name
            existing.date = workout.date
            existing.defaultRestTime = workout.defaultRestTime
            existing.duration = workout.duration
            existing.notes = workout.notes
            existing.isFavorite = workout.isFavorite
            // Replace exercises wholesale for simplicity in Phase 1
            existing.exercises = workout.exercises.map { WorkoutExerciseEntity.make(from: $0, in: context) }
        } else {
            // Insert new
            let entity = WorkoutEntity(
                id: workout.id,
                name: workout.name,
                date: workout.date,
                exercises: workout.exercises.map { WorkoutExerciseEntity.make(from: $0, in: context) },
                defaultRestTime: workout.defaultRestTime,
                duration: workout.duration,
                notes: workout.notes,
                isFavorite: workout.isFavorite
            )
            context.insert(entity)
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        let predicate = #Predicate<WorkoutEntity> { $0.id == id }
        let descriptor = FetchDescriptor<WorkoutEntity>(predicate: predicate)
        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
}

extension ExerciseEntity {
    static func findOrCreate(from model: Exercise, in context: ModelContext) -> ExerciseEntity {
        let predicate = #Predicate<ExerciseEntity> { $0.id == model.id }
        let descriptor = FetchDescriptor<ExerciseEntity>(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first {
            // Update fields
            existing.name = model.name
            existing.muscleGroupsRaw = model.muscleGroups.map { $0.rawValue }
            existing.descriptionText = model.description
            existing.instructions = model.instructions
            existing.createdAt = model.createdAt
            return existing
        } else {
            let created = ExerciseEntity(
                id: model.id,
                name: model.name,
                muscleGroupsRaw: model.muscleGroups.map { $0.rawValue },
                descriptionText: model.description,
                instructions: model.instructions,
                createdAt: model.createdAt
            )
            context.insert(created)
            return created
        }
    }
}

extension WorkoutExerciseEntity {
    static func make(from model: WorkoutExercise, in context: ModelContext) -> WorkoutExerciseEntity {
        let exEntity = ExerciseEntity.findOrCreate(from: model.exercise, in: context)
        let setEntities = model.sets.map { set in
            ExerciseSetEntity(id: set.id, reps: set.reps, weight: set.weight, restTime: set.restTime, completed: set.completed)
        }
        return WorkoutExerciseEntity(id: model.id, exercise: exEntity, sets: setEntities)
    }
}
#endif

