import Combine
import Foundation
import SwiftData
import SwiftUI

/// WorkoutStoreCoordinator - Backward Compatibility Facade
///
/// **Purpose:**
/// This coordinator serves as a backward compatibility layer that aggregates all
/// other coordinators and provides a unified interface matching the old WorkoutStore.
///
/// **Responsibilities:**
/// - Holds references to all sub-coordinators
/// - Delegates method calls to appropriate coordinators
/// - Manages coordinator dependencies and initialization
/// - Provides context management for all coordinators
/// - Enables gradual view migration from WorkoutStore to specific coordinators
///
/// **Migration Strategy:**
/// 1. Views currently using WorkoutStore can switch to WorkoutStoreCoordinator (1:1 replacement)
/// 2. Gradually migrate views to use specific coordinators directly
/// 3. Once all views migrated, WorkoutStoreCoordinator can be removed
///
/// **Dependencies:**
/// All 8 feature coordinators:
/// - ProfileCoordinator (user profile)
/// - ExerciseCoordinator (exercise library)
/// - WorkoutCoordinator (workout templates)
/// - SessionCoordinator (active sessions)
/// - RecordsCoordinator (personal records)
/// - AnalyticsCoordinator (statistics)
/// - HealthKitCoordinator (HealthKit sync)
/// - RestTimerCoordinator (rest timer)
///
/// **Used by:**
/// - ContentView (during migration period)
/// - Any views not yet migrated to specific coordinators
@MainActor
final class WorkoutStoreCoordinator: ObservableObject {
    // MARK: - Sub-Coordinators

    let profileCoordinator: ProfileCoordinator
    let exerciseCoordinator: ExerciseCoordinator
    let workoutCoordinator: WorkoutCoordinator
    let sessionCoordinator: SessionCoordinator
    let recordsCoordinator: RecordsCoordinator
    let analyticsCoordinator: AnalyticsCoordinator
    let healthKitCoordinator: HealthKitCoordinator
    let restTimerCoordinator: RestTimerCoordinator

    // MARK: - Published State (aggregated from coordinators)

    /// Profile update trigger (from ProfileCoordinator)
    @Published var profileUpdateTrigger: UUID = UUID()

    /// Active session ID (from SessionCoordinator)
    @Published var activeSessionID: UUID?

    /// Rest timer state (from RestTimerCoordinator)
    @Published var currentRestTimerState: RestTimerState?

    // MARK: - Context Management

    private var cancellables = Set<AnyCancellable>()

    var modelContext: ModelContext? {
        didSet {
            // Propagate context to all coordinators
            profileCoordinator.setContext(modelContext)
            exerciseCoordinator.setContext(modelContext)
            workoutCoordinator.setContext(modelContext)
            sessionCoordinator.setContext(modelContext)
            recordsCoordinator.setContext(modelContext)
            analyticsCoordinator.setContext(modelContext)
            healthKitCoordinator.setContext(modelContext)
        }
    }

    // MARK: - Initialization

    init(
        profileCoordinator: ProfileCoordinator = ProfileCoordinator(),
        exerciseCoordinator: ExerciseCoordinator = ExerciseCoordinator(),
        workoutCoordinator: WorkoutCoordinator = WorkoutCoordinator(),
        sessionCoordinator: SessionCoordinator = SessionCoordinator(),
        recordsCoordinator: RecordsCoordinator = RecordsCoordinator(),
        analyticsCoordinator: AnalyticsCoordinator = AnalyticsCoordinator(),
        healthKitCoordinator: HealthKitCoordinator = HealthKitCoordinator(),
        restTimerCoordinator: RestTimerCoordinator = RestTimerCoordinator()
    ) {

        self.profileCoordinator = profileCoordinator
        self.exerciseCoordinator = exerciseCoordinator
        self.workoutCoordinator = workoutCoordinator
        self.sessionCoordinator = sessionCoordinator
        self.recordsCoordinator = recordsCoordinator
        self.analyticsCoordinator = analyticsCoordinator
        self.healthKitCoordinator = healthKitCoordinator
        self.restTimerCoordinator = restTimerCoordinator

        // Setup coordinator dependencies
        setupCoordinatorDependencies()

        // Observe state changes from sub-coordinators
        observeCoordinatorStates()
    }

    // MARK: - Coordinator Dependencies Setup

    private func setupCoordinatorDependencies() {
        // Workout → Exercise
        workoutCoordinator.setExerciseCoordinator(exerciseCoordinator)

        // Session → Workout
        sessionCoordinator.setWorkoutCoordinator(workoutCoordinator)

        // Records → Exercise
        recordsCoordinator.setExerciseCoordinator(exerciseCoordinator)

        // Analytics → Workout + Exercise
        analyticsCoordinator.setWorkoutCoordinator(workoutCoordinator)
        analyticsCoordinator.setExerciseCoordinator(exerciseCoordinator)

        // HealthKit → Profile
        healthKitCoordinator.setProfileCoordinator(profileCoordinator)
    }

    private func observeCoordinatorStates() {
        // Observe profile updates
        profileCoordinator.$profileUpdateTrigger
            .assign(to: &$profileUpdateTrigger)

        // Observe session changes
        sessionCoordinator.$activeSessionID
            .assign(to: &$activeSessionID)

        // Observe rest timer state
        restTimerCoordinator.$currentState
            .assign(to: &$currentRestTimerState)
    }

    // MARK: - Profile Methods (delegate to ProfileCoordinator)

    var userProfile: UserProfile {
        profileCoordinator.profile
    }

    func updateProfile(
        name: String,
        birthDate: Date?,
        weight: Double?,
        height: Double?,
        biologicalSex: HKBiologicalSex?,
        goal: FitnessGoal,
        experience: ExperienceLevel,
        equipment: EquipmentPreference,
        preferredDuration: WorkoutDuration,
        healthKitSyncEnabled: Bool
    ) {
        profileCoordinator.updateProfile(
            name: name,
            birthDate: birthDate,
            weight: weight,
            height: height,
            biologicalSex: biologicalSex,
            goal: goal,
            experience: experience,
            equipment: equipment,
            preferredDuration: preferredDuration,
            healthKitSyncEnabled: healthKitSyncEnabled
        )
    }

    func updateProfileImage(_ image: UIImage?) {
        profileCoordinator.updateProfileImage(image)
    }

    func updateLockerNumber(_ lockerNumber: String?) {
        profileCoordinator.updateLockerNumber(lockerNumber)
    }

    func markOnboardingStep(
        hasExploredWorkouts: Bool? = nil,
        hasCreatedFirstWorkout: Bool? = nil,
        hasSetupProfile: Bool? = nil
    ) {
        profileCoordinator.markOnboardingStep(
            hasExploredWorkouts: hasExploredWorkouts,
            hasCreatedFirstWorkout: hasCreatedFirstWorkout,
            hasSetupProfile: hasSetupProfile
        )
    }

    // MARK: - Exercise Methods (delegate to ExerciseCoordinator)

    var exercises: [Exercise] {
        exerciseCoordinator.exercises
    }

    func addExercise(_ exercise: Exercise) {
        try? exerciseCoordinator.addExercise(
            name: exercise.name,
            germanName: exercise.germanName,
            primaryMuscle: exercise.primaryMuscle,
            secondaryMuscles: exercise.secondaryMuscles,
            equipment: exercise.equipment,
            difficulty: exercise.difficulty,
            instructions: exercise.instructions,
            tips: exercise.tips
        )
    }

    func updateExercise(_ exercise: Exercise) {
        try? exerciseCoordinator.updateExercise(exercise)
    }

    func deleteExercise(at indexSet: IndexSet) {
        for index in indexSet {
            if let exercise = exerciseCoordinator.filteredExercises[safe: index] {
                try? exerciseCoordinator.deleteExercise(exercise)
            }
        }
    }

    func exercise(named name: String) -> Exercise? {
        return exerciseCoordinator.exercise(named: name)
    }

    func getSimilarExercises(to exercise: Exercise, count: Int = 10) -> [Exercise] {
        return exerciseCoordinator.getSimilarExercises(to: exercise, limit: count)
    }

    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        return exerciseCoordinator.lastMetrics(for: exercise)
    }

    // MARK: - Workout Methods (delegate to WorkoutCoordinator)

    var workouts: [Workout] {
        workoutCoordinator.workouts
    }

    var homeWorkouts: [Workout] {
        workoutCoordinator.homeWorkouts
    }

    func addWorkout(_ workout: Workout) {
        workoutCoordinator.addWorkout(workout)
    }

    func updateWorkout(_ workout: Workout) {
        workoutCoordinator.updateWorkout(workout)
    }

    func deleteWorkout(at indexSet: IndexSet) {
        workoutCoordinator.deleteWorkout(at: indexSet)
    }

    func toggleFavorite(for workoutID: UUID) {
        workoutCoordinator.toggleFavorite(for: workoutID)
    }

    func toggleHomeFavorite(workoutID: UUID) -> Bool {
        return workoutCoordinator.toggleHomeFavorite(workoutID: workoutID)
    }

    func generateWorkout(from preferences: WorkoutPreferences) throws -> Workout {
        return try workoutCoordinator.generateWorkout(from: preferences)
    }

    func recordSession(from workout: Workout) {
        workoutCoordinator.recordSession(from: workout)
    }

    func removeSession(with id: UUID) {
        workoutCoordinator.removeSession(with: id)
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        return workoutCoordinator.previousWorkout(before: workout)
    }

    func getSessionHistory(limit: Int = 100) -> [WorkoutSessionV1] {
        return workoutCoordinator.getSessionHistory(limit: limit)
    }

    // MARK: - Session Methods (delegate to SessionCoordinator)

    var activeWorkout: Workout? {
        sessionCoordinator.activeWorkout()
    }

    func startSession(for workoutId: UUID) {
        sessionCoordinator.startSession(for: workoutId)
    }

    func endCurrentSession() {
        sessionCoordinator.endCurrentSession()
    }

    // MARK: - Records Methods (delegate to RecordsCoordinator)

    func getExerciseRecord(for exercise: Exercise) -> ExerciseRecord? {
        return recordsCoordinator.getRecord(for: exercise)
    }

    func getAllExerciseRecords() -> [ExerciseRecord] {
        return recordsCoordinator.getAllRecords()
    }

    func checkForNewRecord(exercise: Exercise, weight: Double, reps: Int) -> RecordType? {
        return recordsCoordinator.checkForNewRecord(exercise: exercise, weight: weight, reps: reps)
    }

    func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        return recordsCoordinator.estimateOneRepMax(weight: weight, reps: reps)
    }

    // MARK: - Analytics Methods (delegate to AnalyticsCoordinator)

    var totalWorkouts: Int {
        analyticsCoordinator.totalWorkouts
    }

    var totalDuration: TimeInterval {
        analyticsCoordinator.totalDuration
    }

    var currentStreak: Int {
        analyticsCoordinator.currentStreak
    }

    var averageDurationMinutes: Int {
        analyticsCoordinator.averageDurationMinutes
    }

    func muscleVolume(for muscleGroup: MuscleGroup, days: Int = 30) -> Double {
        return analyticsCoordinator.muscleVolume(for: muscleGroup, days: days)
    }

    func exerciseStats(for exerciseId: UUID) -> ExerciseStats? {
        return analyticsCoordinator.exerciseStats(for: exerciseId)
    }

    func workoutsByDay(days: Int) -> [Date: Int] {
        return analyticsCoordinator.workoutsByDay(days: days)
    }

    // MARK: - HealthKit Methods (delegate to HealthKitCoordinator)

    func requestHealthKitAuthorization() async throws {
        try await healthKitCoordinator.requestAuthorization()
    }

    func importFromHealthKit() async throws {
        try await healthKitCoordinator.importProfile()
    }

    func saveWorkoutToHealthKit(_ session: WorkoutSessionV1) async throws {
        try await healthKitCoordinator.saveWorkout(session)
    }

    func readHeartRateData(from startDate: Date, to endDate: Date) async throws
        -> [HeartRateReading]
    {
        return try await healthKitCoordinator.readHeartRateData(from: startDate, to: endDate)
    }

    func readWeightData(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading]
    {
        return try await healthKitCoordinator.readWeightData(from: startDate, to: endDate)
    }

    func readBodyFatData(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading] {
        return try await healthKitCoordinator.readBodyFatData(from: startDate, to: endDate)
    }

    // MARK: - Rest Timer Methods (delegate to RestTimerCoordinator)

    func startRest(
        for workout: Workout,
        exerciseIndex: Int,
        setIndex: Int,
        totalSeconds: Int
    ) {
        let currentExerciseName = workout.exercises[safe: exerciseIndex]?.exercise.name
        let nextExerciseName = workout.exercises[safe: exerciseIndex + 1]?.exercise.name

        restTimerCoordinator.startRest(
            for: workout,
            exercise: exerciseIndex,
            set: setIndex,
            duration: totalSeconds,
            currentExerciseName: currentExerciseName,
            nextExerciseName: nextExerciseName
        )
    }

    func pauseRest() {
        restTimerCoordinator.pauseRest()
    }

    func resumeRest() {
        restTimerCoordinator.resumeRest()
    }

    func cancelRest() {
        restTimerCoordinator.cancelRest()
    }

    func stopRest() {
        restTimerCoordinator.cancelRest()
    }

    // MARK: - Cache Invalidation

    func invalidateCaches() {
        analyticsCoordinator.invalidateCaches()
    }

    // MARK: - Cleanup

    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Collection Safety Extension

extension Collection {
    fileprivate subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
