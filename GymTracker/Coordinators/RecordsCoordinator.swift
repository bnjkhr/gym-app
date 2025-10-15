import Foundation
import SwiftData
import SwiftUI

/// RecordsCoordinator manages personal records (PRs) and 1RM calculations
///
/// **Responsibilities:**
/// - Personal record tracking (max weight, max reps, max volume)
/// - 1RM (One Rep Max) estimation and calculations
/// - Training weight recommendations
/// - Record statistics and leaderboards
/// - New record detection
///
/// **Dependencies:**
/// - ExerciseRecordService (record persistence)
/// - ExerciseCoordinator (exercise access)
///
/// **Used by:**
/// - StatisticsView
/// - ExerciseDetailView
/// - RecordsView
/// - WorkoutDetailView (for PR celebrations)
@MainActor
final class RecordsCoordinator: ObservableObject {
    // MARK: - Published State

    /// All personal records
    @Published var records: [ExerciseRecord] = []

    /// Top records for leaderboard display
    @Published var topRecords: [ExerciseRecord] = []

    /// New records achieved in current session (for celebration UI)
    @Published var newRecordsThisSession: [RecordType] = []

    // MARK: - Dependencies

    private let recordService: ExerciseRecordService
    private weak var exerciseCoordinator: ExerciseCoordinator?
    private var modelContext: ModelContext?

    // MARK: - Initialization

    init(recordService: ExerciseRecordService = ExerciseRecordService()) {
        self.recordService = recordService
    }

    // MARK: - Context Management

    /// Sets the SwiftData context for record operations
    /// - Parameter context: The ModelContext to use for persistence
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        recordService.setContext(context)
        refreshRecords()
    }

    /// Sets the exercise coordinator for exercise access
    /// - Parameter coordinator: The ExerciseCoordinator instance
    func setExerciseCoordinator(_ coordinator: ExerciseCoordinator) {
        self.exerciseCoordinator = coordinator
    }

    /// Refreshes all records from persistence
    func refreshRecords() {
        self.records = recordService.getAllRecords()
        self.topRecords = recordService.getTopRecords(limit: 10, sortBy: .weight)
        AppLogger.exercises.debug("✅ Refreshed \(self.records.count) records")
    }

    // MARK: - Record Access

    /// Gets the personal record for an exercise
    ///
    /// - Parameter exercise: The exercise
    /// - Returns: ExerciseRecord or nil if no records exist
    func getRecord(for exercise: Exercise) -> ExerciseRecord? {
        return recordService.getRecord(for: exercise)
    }

    /// Gets the personal record for an exercise by ID
    ///
    /// - Parameter exerciseId: The exercise ID
    /// - Returns: ExerciseRecord or nil if no records exist
    func getRecord(forExerciseId exerciseId: UUID) -> ExerciseRecord? {
        return records.first { $0.exerciseId == exerciseId }
    }

    /// Gets all personal records
    ///
    /// - Returns: Array of all records
    func getAllRecords() -> [ExerciseRecord] {
        return recordService.getAllRecords()
    }

    /// Gets top records sorted by criteria
    ///
    /// - Parameters:
    ///   - limit: Maximum number of records to return
    ///   - sortBy: Sorting criteria (weight, reps, volume, oneRepMax)
    /// - Returns: Top records array
    func getTopRecords(limit: Int = 10, sortBy: RecordSortCriteria = .weight) -> [ExerciseRecord] {
        return recordService.getTopRecords(limit: limit, sortBy: sortBy)
    }

    // MARK: - Record Updates

    /// Checks if a new record was achieved and updates if so
    ///
    /// **Record Types:**
    /// - Max Weight: Heaviest weight lifted
    /// - Max Reps: Most reps performed
    /// - Max Volume: Highest total volume (weight × reps)
    /// - Max 1RM: Best estimated one-rep max
    ///
    /// - Parameters:
    ///   - exercise: The exercise
    ///   - weight: Weight lifted
    ///   - reps: Reps performed
    ///   - date: Date of achievement
    /// - Returns: RecordType if a new record was set, nil otherwise
    @discardableResult
    func checkForNewRecord(
        exercise: Exercise,
        weight: Double,
        reps: Int,
        date: Date = Date()
    ) -> RecordType? {
        let recordType = recordService.checkForNewRecord(
            exercise: exercise,
            weight: weight,
            reps: reps,
            date: date
        )

        if let type = recordType {
            // Update record
            recordService.updateRecord(
                for: exercise,
                weight: weight,
                reps: reps,
                date: date
            )

            // Add to session records for celebration
            newRecordsThisSession.append(type)

            refreshRecords()

            AppLogger.exercises.info(
                "🎉 New \(type.rawValue) record for \(exercise.name): \(weight)kg × \(reps) reps")
        }

        return recordType
    }

    /// Updates a personal record manually
    ///
    /// - Parameters:
    ///   - exercise: The exercise
    ///   - weight: Weight lifted
    ///   - reps: Reps performed
    ///   - date: Date of achievement
    func updateRecord(
        for exercise: Exercise,
        weight: Double,
        reps: Int,
        date: Date = Date()
    ) {
        recordService.updateRecord(
            for: exercise,
            weight: weight,
            reps: reps,
            date: date
        )

        refreshRecords()
        AppLogger.exercises.info("✅ Record updated for \(exercise.name)")
    }

    /// Deletes a personal record
    ///
    /// - Parameter exercise: The exercise
    func deleteRecord(for exercise: Exercise) {
        recordService.deleteRecord(for: exercise)
        refreshRecords()
        AppLogger.exercises.info("✅ Record deleted for \(exercise.name)")
    }

    /// Clears new records from current session
    func clearSessionRecords() {
        newRecordsThisSession.removeAll()
    }

    // MARK: - 1RM Calculations

    /// Estimates the one-rep max using Epley formula
    ///
    /// **Formula:** 1RM = weight × (1 + reps/30)
    ///
    /// **Accuracy:**
    /// - Most accurate for 1-10 reps
    /// - Less accurate for 15+ reps
    ///
    /// - Parameters:
    ///   - weight: Weight lifted
    ///   - reps: Reps performed
    /// - Returns: Estimated 1RM in kg
    func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        return recordService.estimateOneRepMax(weight: weight, reps: reps)
    }

    /// Calculates training weights based on 1RM percentage
    ///
    /// **Returns a dictionary with:**
    /// - 50%: Warm-up weight
    /// - 60%: Light training
    /// - 70%: Moderate training
    /// - 80%: Heavy training
    /// - 85%: Very heavy
    /// - 90%: Near max
    /// - 95%: Max effort
    ///
    /// - Parameter oneRepMax: The estimated or actual 1RM
    /// - Returns: Dictionary mapping percentages to weights
    func calculateTrainingWeights(oneRepMax: Double) -> [Int: Double] {
        return recordService.calculateTrainingWeights(oneRepMax: oneRepMax)
    }

    /// Gets the estimated 1RM for an exercise based on current record
    ///
    /// - Parameter exercise: The exercise
    /// - Returns: Estimated 1RM or nil if no record exists
    func getCurrentOneRepMax(for exercise: Exercise) -> Double? {
        guard let record = getRecord(for: exercise) else { return nil }
        return record.estimatedOneRepMax
    }

    /// Gets training weight recommendations for an exercise
    ///
    /// - Parameter exercise: The exercise
    /// - Returns: Dictionary of training weights, or nil if no record exists
    func getTrainingWeights(for exercise: Exercise) -> [Int: Double]? {
        guard let oneRepMax = getCurrentOneRepMax(for: exercise) else { return nil }
        return calculateTrainingWeights(oneRepMax: oneRepMax)
    }

    // MARK: - Record Statistics

    /// Gets comprehensive record statistics
    ///
    /// - Returns: RecordStatistics with counts and totals
    func getStatistics() -> RecordStatistics {
        return recordService.getRecordStatistics()
    }

    /// Total number of personal records
    var totalRecordCount: Int {
        records.count
    }

    /// Total volume across all records (sum of weight × reps)
    var totalVolume: Double {
        records.reduce(0) { $0 + ($1.maxWeight * Double($1.maxWeightReps)) }
    }

    /// Average max weight across all records
    var averageMaxWeight: Double {
        guard !records.isEmpty else { return 0 }
        let sum = records.reduce(0) { $0 + $1.maxWeight }
        return sum / Double(records.count)
    }

    /// Gets records achieved in the last N days
    ///
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of recent records
    func recentRecords(days: Int) -> [ExerciseRecord] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return records.filter { $0.achievedDate >= startDate }
    }

    /// Gets records for a specific muscle group
    ///
    /// - Parameter muscleGroup: The target muscle group
    /// - Returns: Array of records for that muscle group
    func records(for muscleGroup: MuscleGroup) -> [ExerciseRecord] {
        guard let coordinator = exerciseCoordinator else { return [] }

        return records.filter { record in
            guard let exercise = coordinator.exercise(withId: record.exerciseId) else {
                return false
            }
            return exercise.primaryMuscle == muscleGroup
                || exercise.secondaryMuscles.contains(muscleGroup)
        }
    }

    /// Checks if exercise has any personal records
    ///
    /// - Parameter exercise: The exercise
    /// - Returns: true if records exist
    func hasRecord(for exercise: Exercise) -> Bool {
        return getRecord(for: exercise) != nil
    }

    // MARK: - Leaderboard

    /// Gets top exercises by max weight
    ///
    /// - Parameter limit: Number of top exercises to return
    /// - Returns: Array of records sorted by max weight
    func topByWeight(limit: Int = 5) -> [ExerciseRecord] {
        return getTopRecords(limit: limit, sortBy: .weight)
    }

    /// Gets top exercises by max reps
    ///
    /// - Parameter limit: Number of top exercises to return
    /// - Returns: Array of records sorted by max reps
    func topByReps(limit: Int = 5) -> [ExerciseRecord] {
        return getTopRecords(limit: limit, sortBy: .reps)
    }

    /// Gets top exercises by total volume
    ///
    /// - Parameter limit: Number of top exercises to return
    /// - Returns: Array of records sorted by volume
    func topByVolume(limit: Int = 5) -> [ExerciseRecord] {
        return getTopRecords(limit: limit, sortBy: .volume)
    }

    /// Gets top exercises by estimated 1RM
    ///
    /// - Parameter limit: Number of top exercises to return
    /// - Returns: Array of records sorted by 1RM
    func topByOneRepMax(limit: Int = 5) -> [ExerciseRecord] {
        return getTopRecords(limit: limit, sortBy: .oneRepMax)
    }
}

// MARK: - Supporting Types

/// Record sorting criteria
enum RecordSortCriteria {
    case weight
    case reps
    case volume
    case oneRepMax
}

/// Type of personal record
enum RecordType: String {
    case maxWeight = "Max Weight"
    case maxReps = "Max Reps"
    case maxVolume = "Max Volume"
    case maxOneRepMax = "Max 1RM"
}
