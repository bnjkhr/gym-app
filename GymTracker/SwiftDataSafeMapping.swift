import Foundation
import SwiftData

// Centralized safe mapping utilities for SwiftData entities
// These helpers refetch entities by ID before accessing properties to avoid
// crashes from reading invalidated instances.

func fetchExercise(by id: UUID, in context: ModelContext) -> ExerciseEntity? {
    let descriptor = FetchDescriptor<ExerciseEntity>(
        predicate: #Predicate { $0.id == id }
    )
    return try? context.fetch(descriptor).first
}

/// Safely maps an array of ExerciseEntity snapshot references to value type Exercises by
/// refetching each entity by id from the current ModelContext before accessing properties.
/// Any entities that can’t be refetched are skipped.
func safeMapExercises(_ entities: [ExerciseEntity], in context: ModelContext) -> [Exercise] {
    var results: [Exercise] = []
    results.reserveCapacity(entities.count)
    for entity in entities {
        let id = entity.id
        if let fresh = fetchExercise(by: id, in: context) {
            let groups: [MuscleGroup] = fresh.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
            results.append(
                Exercise(
                    id: fresh.id,
                    name: fresh.name,
                    muscleGroups: groups,
                    description: fresh.descriptionText,
                    instructions: fresh.instructions,
                    createdAt: fresh.createdAt
                )
            )
        }
    }
    return results
}

