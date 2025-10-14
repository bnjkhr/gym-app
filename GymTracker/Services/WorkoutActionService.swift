import Foundation
import SwiftData

@MainActor
final class WorkoutActionService {
    enum ActionError: Error {
        case workoutNotFound
        case exportFailed(Error)
    }

    struct DeletionResult {
        let removed: Bool
        let clearedActiveSession: Bool
    }

    private let modelContext: ModelContext
    private let workoutStore: WorkoutStoreCoordinator

    init(modelContext: ModelContext, workoutStore: WorkoutStoreCoordinator) {
        self.modelContext = modelContext
        self.workoutStore = workoutStore
    }

    func deleteWorkout(id: UUID, in workouts: [WorkoutEntity]) throws -> DeletionResult {
        var removed = false

        if let entity = workouts.first(where: { $0.id == id }) {
            modelContext.delete(entity)
            try modelContext.save()
            removed = true
        }

        let clearedSession = clearActiveSessionIfNeeded(for: id, stopRest: false)
        return DeletionResult(removed: removed, clearedActiveSession: clearedSession)
    }

    func duplicateWorkout(id: UUID, in workouts: [WorkoutEntity]) throws {
        guard let originalEntity = workouts.first(where: { $0.id == id }) else {
            throw ActionError.workoutNotFound
        }

        let duplicatedEntity = WorkoutEntity(
            name: "\(originalEntity.name) (Kopie)",
            date: Date(),
            exercises: [],
            defaultRestTime: originalEntity.defaultRestTime,
            duration: nil,
            notes: originalEntity.notes,
            isFavorite: false,
            isSampleWorkout: false
        )

        let sortedExercises = originalEntity.exercises.sorted { $0.order < $1.order }
        for (index, originalWorkoutExercise) in sortedExercises.enumerated() {
            let copiedWorkoutExercise = WorkoutExerciseEntity(
                exercise: originalWorkoutExercise.exercise,
                order: index
            )

            for originalSet in originalWorkoutExercise.sets {
                let copiedSet = ExerciseSetEntity(
                    reps: originalSet.reps,
                    weight: originalSet.weight,
                    restTime: originalSet.restTime,
                    completed: false
                )
                copiedWorkoutExercise.sets.append(copiedSet)
                modelContext.insert(copiedSet)
            }

            duplicatedEntity.exercises.append(copiedWorkoutExercise)
            modelContext.insert(copiedWorkoutExercise)
        }

        modelContext.insert(duplicatedEntity)
        try modelContext.save()
    }

    func shareWorkout(id: UUID, in workouts: [WorkoutEntity]) throws -> URL {
        guard let entity = workouts.first(where: { $0.id == id }) else {
            throw ActionError.workoutNotFound
        }

        do {
            let shareable = ShareableWorkout.from(entity: entity)
            return try shareable.exportToFile()
        } catch {
            throw ActionError.exportFailed(error)
        }
    }

    func endActiveSession() {
        _ = clearActiveSessionIfNeeded(for: workoutStore.activeSessionID, stopRest: true)
    }

    @discardableResult
    private func clearActiveSessionIfNeeded(for id: UUID?, stopRest: Bool) -> Bool {
        guard let sessionId = id, workoutStore.activeSessionID == sessionId else {
            return false
        }

        if stopRest {
            workoutStore.stopRest()
        }

        workoutStore.activeSessionID = nil
        WorkoutLiveActivityController.shared.end()
        return true
    }
}
