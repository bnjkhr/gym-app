import Foundation
import SwiftData

@MainActor
final class WorkoutDataService {
    private var modelContext: ModelContext?

    func setContext(_ context: ModelContext?) {
        modelContext = context
    }

    // MARK: - Fetching

    func activeWorkout(with id: UUID?) -> Workout? {
        guard let id, let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { workout in workout.id == id }
        )
        guard let entity = try? context.fetch(descriptor).first else { return nil }
        return mapWorkoutEntity(entity)
    }

    func allWorkouts(limit: Int = 200) -> [Workout] {
        guard let context = modelContext else { return [] }
        var descriptor = FetchDescriptor<WorkoutEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if limit > 0 {
            descriptor.fetchLimit = limit
        }
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map(mapWorkoutEntity(_:))
    }

    func homeWorkouts(limit: Int = 50) -> [Workout] {
        guard let context = modelContext else { return [] }
        var descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { entity in entity.isFavorite == true },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = limit
        descriptor.includePendingChanges = false
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map(mapWorkoutEntity(_:))
    }

    func exercises() -> [Exercise] {
        guard let context = modelContext else { return [] }
        var descriptor = FetchDescriptor<ExerciseEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.includePendingChanges = false
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map(mapExerciseEntity(_:))
    }

    // MARK: - Exercise Operations

    func exercise(named name: String) -> Exercise {
        guard let context = modelContext else {
            return Exercise(name: name, muscleGroups: [], equipmentType: .mixed, description: "")
        }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { entity in
                entity.name.localizedLowercase == name.localizedLowercase
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            return mapExerciseEntity(existing)
        }

        let newExercise = Exercise(
            name: name, muscleGroups: [], equipmentType: .mixed, description: "")
        let entity = ExerciseEntity.make(from: newExercise)
        context.insert(entity)
        try? context.save()
        return newExercise
    }

    func similarExercises(
        to exercise: Exercise,
        count: Int = 10,
        userLevel: ExperienceLevel? = nil
    ) -> [Exercise] {
        let allExercises = exercises()

        let candidates = allExercises.filter { candidate in
            candidate.id != exercise.id && exercise.hasSimilarMuscleGroups(to: candidate)
        }

        let scoredExercises = candidates.compactMap {
            candidate -> (exercise: Exercise, score: Int, matchesLevel: Bool, sharesPrimary: Bool)?
            in
            let score = exercise.similarityScore(to: candidate)
            guard score > 0 else { return nil }

            let matchesLevel =
                userLevel != nil ? matchesDifficultyLevel(candidate, for: userLevel!) : true
            let sharesPrimary = exercise.sharesPrimaryMuscleGroup(with: candidate)
            return (candidate, score, matchesLevel, sharesPrimary)
        }

        let sorted = scoredExercises.sorted { first, second in
            if first.sharesPrimary && !second.sharesPrimary {
                return true
            }
            if !first.sharesPrimary && second.sharesPrimary {
                return false
            }

            if userLevel != nil {
                if first.matchesLevel && !second.matchesLevel {
                    return true
                }
                if !first.matchesLevel && second.matchesLevel {
                    return false
                }
            }

            return first.score > second.score
        }

        return Array(sorted.prefix(count).map { $0.exercise })
    }

    func addExercise(_ exercise: Exercise) {
        guard let context = modelContext else { return }

        let idDescriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { entity in entity.id == exercise.id }
        )
        if (try? context.fetch(idDescriptor).first) != nil {
            return
        }

        let nameDescriptor = FetchDescriptor<ExerciseEntity>()
        if let existing = try? context.fetch(nameDescriptor),
            existing.contains(where: {
                $0.name.localizedCaseInsensitiveCompare(exercise.name) == .orderedSame
            })
        {
            return
        }

        let entity = ExerciseEntity.make(from: exercise)
        context.insert(entity)
        try? context.save()
    }

    func updateExercise(_ exercise: Exercise) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { entity in entity.id == exercise.id }
        )

        guard let entity = try? context.fetch(descriptor).first else { return }

        entity.name = exercise.name
        entity.muscleGroupsRaw = exercise.muscleGroups.map { $0.rawValue }
        entity.equipmentTypeRaw = exercise.equipmentType.rawValue
        entity.difficultyLevelRaw = exercise.difficultyLevel.rawValue
        entity.descriptionText = exercise.description
        entity.instructions = exercise.instructions

        try? context.save()
    }

    @discardableResult
    func deleteExercises(at indexSet: IndexSet) -> [UUID] {
        guard let context = modelContext else { return [] }
        let currentExercises = exercises()
        let removed = indexSet.compactMap { index -> Exercise? in
            guard index < currentExercises.count else { return nil }
            return currentExercises[index]
        }

        for exercise in removed {
            let descriptor = FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { entity in entity.id == exercise.id }
            )
            if let entity = try? context.fetch(descriptor).first {
                context.delete(entity)
            }
        }

        try? context.save()
        return removed.map(\.id)
    }

    // MARK: - Workout Operations

    func addWorkout(_ workout: Workout) {
        guard let context = modelContext else { return }
        do {
            try DataManager.shared.saveWorkout(workout, to: context)
        } catch {
            print("❌ Fehler beim Speichern des Workouts: \(error)")
        }
    }

    func updateWorkout(_ workout: Workout) {
        guard let context = modelContext else { return }
        do {
            try DataManager.shared.saveWorkout(workout, to: context)
        } catch {
            print("❌ Fehler beim Aktualisieren des Workouts: \(error)")
        }
    }

    func deleteWorkouts(at indexSet: IndexSet) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WorkoutEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []

        for index in indexSet {
            guard index < entities.count else { continue }
            context.delete(entities[index])
        }

        try? context.save()
    }

    func toggleFavorite(for workoutID: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { entity in entity.id == workoutID }
        )
        guard let entity = try? context.fetch(descriptor).first else { return }
        entity.isFavorite.toggle()
        try? context.save()
        let action = entity.isFavorite ? "hinzugefügt" : "entfernt"
        print("✅ Workout '\(entity.name)' Favorit \(action)")
    }

    func toggleHomeFavorite(workoutID: UUID, limit: Int = 4) -> Bool {
        guard let context = modelContext else { return false }

        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { entity in entity.id == workoutID }
        )

        guard let entity = try? context.fetch(descriptor).first else { return false }

        if !entity.isFavorite {
            let currentCount = homeFavoritesCount()
            if currentCount >= limit {
                print("⚠️ Home-Favoriten Limit erreicht: \(currentCount)/\(limit)")
                return false
            }
        }

        entity.isFavorite.toggle()

        do {
            try context.save()
            context.processPendingChanges()
            let action = entity.isFavorite ? "hinzugefügt" : "entfernt"
            print("✅ Home-Favorit für Workout '\(entity.name)' \(action)")
            return true
        } catch {
            print("❌ Fehler beim Speichern der Favoriten: \(error)")
            return false
        }
    }

    // MARK: - Helpers

    private func mapExerciseEntity(_ entity: ExerciseEntity) -> Exercise {
        let groups = entity.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
        let equipmentType = EquipmentType(rawValue: entity.equipmentTypeRaw) ?? .mixed
        let difficultyLevel = DifficultyLevel(rawValue: entity.difficultyLevelRaw) ?? .anfänger

        return Exercise(
            id: entity.id,
            name: entity.name,
            muscleGroups: groups,
            equipmentType: equipmentType,
            difficultyLevel: difficultyLevel,
            description: entity.descriptionText,
            instructions: entity.instructions,
            createdAt: entity.createdAt
        )
    }

    private func mapWorkoutEntity(_ entity: WorkoutEntity) -> Workout {
        let sortedExercises = entity.exercises.sorted { $0.order < $1.order }
        let exercises: [WorkoutExercise] = sortedExercises.compactMap { workoutExercise in
            guard let exerciseEntity = workoutExercise.exercise else { return nil }
            let exercise = mapExerciseEntity(exerciseEntity)
            let sets = workoutExercise.sets.map { set in
                ExerciseSet(
                    reps: set.reps,
                    weight: set.weight,
                    restTime: set.restTime,
                    completed: set.completed
                )
            }
            return WorkoutExercise(exercise: exercise, sets: sets)
        }

        return Workout(
            id: entity.id,
            name: entity.name,
            date: entity.date,
            exercises: exercises,
            defaultRestTime: entity.defaultRestTime,
            duration: entity.duration,
            notes: entity.notes,
            isFavorite: entity.isFavorite
        )
    }

    private func homeFavoritesCount() -> Int {
        guard let context = modelContext else { return 0 }

        do {
            let descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate<WorkoutEntity> { entity in entity.isFavorite == true }
            )
            return try context.fetch(descriptor).count
        } catch {
            print("❌ Fehler beim Zählen der Home-Favoriten: \(error)")
            return 0
        }
    }

    private func matchesDifficultyLevel(_ exercise: Exercise, for level: ExperienceLevel) -> Bool {
        switch level {
        case .beginner:
            return exercise.difficultyLevel == .anfänger
        case .intermediate:
            return exercise.difficultyLevel == .fortgeschritten
                || exercise.difficultyLevel == .anfänger
        case .advanced:
            return exercise.difficultyLevel == .profi
                || exercise.difficultyLevel == .fortgeschritten
                || exercise.difficultyLevel == .anfänger
        }
    }
}
