import Foundation
import SwiftData
import SwiftUI

/// ExerciseCoordinator manages all exercise-related operations
///
/// **Responsibilities:**
/// - Exercise CRUD operations
/// - Exercise search and filtering
/// - Similar exercise recommendations
/// - Last-used metrics tracking
/// - Exercise library management
///
/// **Dependencies:**
/// - WorkoutDataService (exercise persistence)
/// - LastUsedMetricsService (metrics tracking)
///
/// **Used by:**
/// - ExercisesView
/// - AddExerciseView
/// - EditExerciseView
/// - ExerciseSelectionView
/// - WorkoutDetailView
/// - ExerciseDetailView
@MainActor
final class ExerciseCoordinator: ObservableObject {
    // MARK: - Published State

    /// All available exercises
    @Published var exercises: [Exercise] = []

    /// Currently selected exercise (for detail view)
    @Published var selectedExercise: Exercise?

    /// Search query for filtering exercises
    @Published var searchQuery: String = ""

    /// Selected muscle group filter
    @Published var selectedMuscleGroup: MuscleGroup?

    /// Selected equipment filter
    @Published var selectedEquipment: EquipmentType?

    /// Selected difficulty filter
    @Published var selectedDifficulty: DifficultyLevel?

    // MARK: - Dependencies

    private let dataService: WorkoutDataService
    private let metricsService: LastUsedMetricsService
    private var modelContext: ModelContext?

    // MARK: - Initialization

    init(
        dataService: WorkoutDataService = WorkoutDataService(),
        metricsService: LastUsedMetricsService = LastUsedMetricsService()
    ) {
        self.dataService = dataService
        self.metricsService = metricsService
    }

    // MARK: - Context Management

    /// Sets the SwiftData context for exercise operations
    /// - Parameter context: The ModelContext to use for persistence
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        dataService.setContext(context)
        metricsService.setContext(context)
        refreshExercises()
    }

    /// Refreshes the exercise list from persistence
    func refreshExercises() {
        self.exercises = dataService.exercises()
        AppLogger.exercises.debug("✅ Refreshed \(self.exercises.count) exercises")
    }

    // MARK: - Exercise CRUD

    /// Adds a new custom exercise
    ///
    /// - Parameters:
    ///   - name: Exercise name
    ///   - germanName: German translation (optional)
    ///   - primaryMuscle: Primary muscle group
    ///   - secondaryMuscles: Secondary muscle groups
    ///   - equipment: Required equipment
    ///   - difficulty: Difficulty level
    ///   - instructions: Exercise instructions
    ///   - tips: Exercise tips
    /// - Returns: The created exercise
    /// - Throws: DataServiceError if creation fails
    @discardableResult
    func addExercise(
        name: String,
        germanName: String?,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup],
        equipment: EquipmentType,
        difficulty: DifficultyLevel,
        instructions: String?,
        tips: String?
    ) throws -> Exercise {
        guard let context = modelContext else {
            throw DataServiceError.contextNotSet
        }

        let exercise = Exercise(
            id: UUID(),
            name: name,
            germanName: germanName,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            difficulty: difficulty,
            instructions: instructions,
            tips: tips,
            isCustom: true
        )

        // Create entity
        let entity = ExerciseEntity(
            id: exercise.id,
            name: exercise.name,
            germanName: exercise.germanName,
            primaryMuscleRaw: exercise.primaryMuscle.rawValue,
            secondaryMusclesRaw: exercise.secondaryMuscles.map { $0.rawValue },
            equipmentRaw: exercise.equipment.rawValue,
            difficultyRaw: exercise.difficulty.rawValue,
            instructions: exercise.instructions,
            tips: exercise.tips,
            isCustom: exercise.isCustom
        )

        context.insert(entity)
        try context.save()

        refreshExercises()

        AppLogger.exercises.info("✅ Exercise created: \(name)")
        return exercise
    }

    /// Updates an existing exercise
    ///
    /// - Parameter exercise: The exercise with updated values
    /// - Throws: DataServiceError if update fails
    func updateExercise(_ exercise: Exercise) throws {
        guard let context = modelContext else {
            throw DataServiceError.contextNotSet
        }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.id == exercise.id }
        )

        guard let entity = try context.fetch(descriptor).first else {
            throw DataServiceError.entityNotFound
        }

        // Update properties
        entity.name = exercise.name
        entity.germanName = exercise.germanName
        entity.primaryMuscleRaw = exercise.primaryMuscle.rawValue
        entity.secondaryMusclesRaw = exercise.secondaryMuscles.map { $0.rawValue }
        entity.equipmentRaw = exercise.equipment.rawValue
        entity.difficultyRaw = exercise.difficulty.rawValue
        entity.instructions = exercise.instructions
        entity.tips = exercise.tips

        try context.save()

        refreshExercises()

        AppLogger.exercises.info("✅ Exercise updated: \(exercise.name)")
    }

    /// Deletes an exercise
    ///
    /// - Parameter exercise: The exercise to delete
    /// - Throws: DataServiceError if deletion fails
    func deleteExercise(_ exercise: Exercise) throws {
        guard let context = modelContext else {
            throw DataServiceError.contextNotSet
        }

        // Only allow deleting custom exercises
        guard exercise.isCustom else {
            throw DataServiceError.cannotDeletePredefinedExercise
        }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.id == exercise.id }
        )

        guard let entity = try context.fetch(descriptor).first else {
            throw DataServiceError.entityNotFound
        }

        context.delete(entity)
        try context.save()

        refreshExercises()

        AppLogger.exercises.info("✅ Exercise deleted: \(exercise.name)")
    }

    // MARK: - Exercise Search & Filtering

    /// Finds an exercise by name (case-insensitive)
    ///
    /// - Parameter name: The exercise name to search for
    /// - Returns: The matching exercise, or nil if not found
    func exercise(named name: String) -> Exercise? {
        return exercises.first {
            $0.name.localizedCaseInsensitiveContains(name)
                || ($0.germanName?.localizedCaseInsensitiveContains(name) ?? false)
        }
    }

    /// Finds an exercise by ID
    ///
    /// - Parameter id: The exercise ID
    /// - Returns: The matching exercise, or nil if not found
    func exercise(withId id: UUID) -> Exercise? {
        return exercises.first { $0.id == id }
    }

    /// Gets exercises filtered by current filters
    var filteredExercises: [Exercise] {
        var filtered = exercises

        // Search query
        if !searchQuery.isEmpty {
            filtered = filtered.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchQuery)
                    || (exercise.germanName?.localizedCaseInsensitiveContains(searchQuery) ?? false)
                    || exercise.primaryMuscle.rawValue.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        // Muscle group filter
        if let muscleGroup = selectedMuscleGroup {
            filtered = filtered.filter { exercise in
                exercise.primaryMuscle == muscleGroup
                    || exercise.secondaryMuscles.contains(muscleGroup)
            }
        }

        // Equipment filter
        if let equipment = selectedEquipment {
            filtered = filtered.filter { $0.equipment == equipment }
        }

        // Difficulty filter
        if let difficulty = selectedDifficulty {
            filtered = filtered.filter { $0.difficulty == difficulty }
        }

        return filtered
    }

    /// Clears all filters
    func clearFilters() {
        searchQuery = ""
        selectedMuscleGroup = nil
        selectedEquipment = nil
        selectedDifficulty = nil
    }

    // MARK: - Similar Exercises

    /// Gets similar exercises based on muscle groups and equipment
    ///
    /// - Parameters:
    ///   - exercise: The reference exercise
    ///   - limit: Maximum number of similar exercises to return
    /// - Returns: Array of similar exercises, sorted by similarity score
    func getSimilarExercises(to exercise: Exercise, limit: Int = 5) -> [Exercise] {
        return exercise.similarExercises(from: exercises, limit: limit)
    }

    /// Gets exercises that target the same primary muscle
    ///
    /// - Parameters:
    ///   - muscleGroup: The target muscle group
    ///   - equipment: Optional equipment filter
    ///   - excludeExerciseId: Optional exercise ID to exclude from results
    /// - Returns: Array of exercises targeting the muscle group
    func exercisesForMuscleGroup(
        _ muscleGroup: MuscleGroup,
        equipment: EquipmentType? = nil,
        excludeExerciseId: UUID? = nil
    ) -> [Exercise] {
        var filtered = exercises.filter { $0.primaryMuscle == muscleGroup }

        if let equipment = equipment {
            filtered = filtered.filter { $0.equipment == equipment }
        }

        if let excludeId = excludeExerciseId {
            filtered = filtered.filter { $0.id != excludeId }
        }

        return filtered
    }

    // MARK: - Last-Used Metrics

    /// Gets the last-used weight and set count for an exercise
    ///
    /// - Parameter exercise: The exercise
    /// - Returns: Tuple of (weight, setCount) or nil if no history
    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        return metricsService.lastMetrics(for: exercise)
    }

    /// Gets complete last-used metrics for an exercise
    ///
    /// - Parameter exercise: The exercise
    /// - Returns: ExerciseLastUsedMetrics or nil if no history
    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics? {
        return metricsService.completeLastMetrics(for: exercise)
    }

    /// Checks if an exercise has last-used metrics
    ///
    /// - Parameter exercise: The exercise
    /// - Returns: true if metrics exist
    func hasLastUsedMetrics(for exercise: Exercise) -> Bool {
        return metricsService.hasLastUsedMetrics(for: exercise)
    }

    /// Clears last-used metrics for an exercise
    ///
    /// - Parameter exercise: The exercise
    func clearLastUsedMetrics(for exercise: Exercise) {
        metricsService.clearLastUsedMetrics(for: exercise)
        AppLogger.exercises.info("✅ Cleared last-used metrics for: \(exercise.name)")
    }

    // MARK: - Exercise Statistics

    /// Gets exercise statistics grouped by muscle group
    var exercisesByMuscleGroup: [MuscleGroup: [Exercise]] {
        Dictionary(grouping: exercises, by: { $0.primaryMuscle })
    }

    /// Gets exercise statistics grouped by equipment
    var exercisesByEquipment: [EquipmentType: [Exercise]] {
        Dictionary(grouping: exercises, by: { $0.equipment })
    }

    /// Gets exercise statistics grouped by difficulty
    var exercisesByDifficulty: [DifficultyLevel: [Exercise]] {
        Dictionary(grouping: exercises, by: { $0.difficulty })
    }

    /// Total number of exercises
    var totalExerciseCount: Int {
        exercises.count
    }

    /// Number of custom exercises
    var customExerciseCount: Int {
        exercises.filter { $0.isCustom }.count
    }

    /// Number of predefined exercises
    var predefinedExerciseCount: Int {
        exercises.filter { !$0.isCustom }.count
    }
}

// MARK: - Error Types

enum DataServiceError: LocalizedError {
    case contextNotSet
    case entityNotFound
    case cannotDeletePredefinedExercise

    var errorDescription: String? {
        switch self {
        case .contextNotSet:
            return "Database context is not set"
        case .entityNotFound:
            return "Exercise not found in database"
        case .cannotDeletePredefinedExercise:
            return "Cannot delete predefined exercises"
        }
    }
}
