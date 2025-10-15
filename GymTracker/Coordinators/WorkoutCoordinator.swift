import Foundation
import SwiftData
import SwiftUI

/// WorkoutCoordinator manages all workout-related operations
///
/// **Responsibilities:**
/// - Workout CRUD operations
/// - Favorites management (standard & home favorites)
/// - Workout generation from preferences
/// - Session recording and history
/// - Workout templates management
///
/// **Dependencies:**
/// - WorkoutDataService (workout persistence)
/// - WorkoutGenerationService (workout wizard)
/// - WorkoutSessionService (session management)
/// - WorkoutAnalyticsService (session history)
/// - ExerciseCoordinator (exercise access)
///
/// **Used by:**
/// - WorkoutsView
/// - WorkoutsHomeView
/// - WorkoutDetailView
/// - EditWorkoutView
/// - AddWorkoutView
/// - WorkoutWizardView
@MainActor
final class WorkoutCoordinator: ObservableObject {
    // MARK: - Published State

    /// All available workouts (templates)
    @Published var workouts: [Workout] = []

    /// Home favorite workouts (max 4)
    @Published var homeWorkouts: [Workout] = []

    /// Currently selected workout (for detail view)
    @Published var selectedWorkout: Workout?

    /// Session history
    @Published var sessionHistory: [WorkoutSession] = []

    // MARK: - Constants

    /// Maximum number of workouts that can be favorited on home screen
    private let maxHomeFavorites = 4

    // MARK: - Dependencies

    private let dataService: WorkoutDataService
    private let generationService: WorkoutGenerationService
    private let sessionService: WorkoutSessionService
    private let analyticsService: WorkoutAnalyticsService
    private weak var exerciseCoordinator: ExerciseCoordinator?
    private var modelContext: ModelContext?

    // MARK: - Initialization

    init(
        dataService: WorkoutDataService = WorkoutDataService(),
        generationService: WorkoutGenerationService = WorkoutGenerationService(),
        sessionService: WorkoutSessionService = WorkoutSessionService(),
        analyticsService: WorkoutAnalyticsService = WorkoutAnalyticsService()
    ) {
        self.dataService = dataService
        self.generationService = generationService
        self.sessionService = sessionService
        self.analyticsService = analyticsService
    }

    // MARK: - Context Management

    /// Sets the SwiftData context for workout operations
    /// - Parameter context: The ModelContext to use for persistence
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        dataService.setContext(context)
        sessionService.setContext(context)
        analyticsService.setContext(context)
        refreshWorkouts()
        refreshSessionHistory()
    }

    /// Sets the exercise coordinator for exercise access
    /// - Parameter coordinator: The ExerciseCoordinator instance
    func setExerciseCoordinator(_ coordinator: ExerciseCoordinator) {
        self.exerciseCoordinator = coordinator
    }

    /// Refreshes the workout lists from persistence
    func refreshWorkouts() {
        self.workouts = dataService.allWorkouts()
        self.homeWorkouts = dataService.homeWorkouts()
        AppLogger.workouts.debug(
            "✅ Refreshed \(self.workouts.count) workouts (\(self.homeWorkouts.count) home)")
    }

    /// Refreshes the session history from persistence
    func refreshSessionHistory(limit: Int = 100) {
        self.sessionHistory = analyticsService.getSessionHistory(limit: limit)
        AppLogger.workouts.debug("✅ Refreshed \(self.sessionHistory.count) sessions")
    }

    // MARK: - Workout CRUD

    /// Adds a new workout template
    ///
    /// - Parameter workout: The workout to add
    func addWorkout(_ workout: Workout) {
        dataService.addWorkout(workout)
        refreshWorkouts()
        AppLogger.workouts.info("✅ Workout added: \(workout.name)")
    }

    /// Updates an existing workout template
    ///
    /// - Parameter workout: The workout with updated values
    func updateWorkout(_ workout: Workout) {
        dataService.updateWorkout(workout)
        refreshWorkouts()
        AppLogger.workouts.info("✅ Workout updated: \(workout.name)")
    }

    /// Deletes workouts at the specified indices
    ///
    /// - Parameter indexSet: The indices of workouts to delete
    func deleteWorkout(at indexSet: IndexSet) {
        dataService.deleteWorkouts(at: indexSet)
        refreshWorkouts()
        AppLogger.workouts.info("✅ Deleted \(indexSet.count) workout(s)")
    }

    /// Finds a workout by ID
    ///
    /// - Parameter id: The workout ID
    /// - Returns: The matching workout, or nil if not found
    func workout(withId id: UUID) -> Workout? {
        return workouts.first { $0.id == id }
    }

    // MARK: - Favorites Management

    /// Toggles the favorite status of a workout
    ///
    /// - Parameter workoutID: The workout ID
    func toggleFavorite(for workoutID: UUID) {
        dataService.toggleFavorite(for: workoutID)
        refreshWorkouts()
        AppLogger.workouts.info("✅ Toggled favorite for workout: \(workoutID)")
    }

    /// Toggles the home favorite status of a workout
    ///
    /// **Business Rules:**
    /// - Maximum 4 workouts can be home favorites
    /// - If adding a 5th favorite, user must remove one first
    /// - Returns false if operation failed (max limit reached)
    ///
    /// - Parameter workoutID: The workout ID
    /// - Returns: true if operation succeeded, false if max favorites reached
    func toggleHomeFavorite(workoutID: UUID) -> Bool {
        let currentHomeFavorites = homeWorkouts
        let isCurrentlyHomeFavorite = currentHomeFavorites.contains { $0.id == workoutID }

        // If adding a new home favorite and already at max, prevent it
        if !isCurrentlyHomeFavorite && currentHomeFavorites.count >= maxHomeFavorites {
            AppLogger.workouts.warning("⚠️ Max home favorites reached (\(maxHomeFavorites))")
            return false
        }

        let success = dataService.toggleHomeFavorite(workoutID: workoutID)
        refreshWorkouts()

        if success {
            AppLogger.workouts.info("✅ Toggled home favorite for workout: \(workoutID)")
        }

        return success
    }

    /// Gets the current number of home favorites
    var homeFavoriteCount: Int {
        homeWorkouts.count
    }

    /// Checks if max home favorites limit is reached
    var isMaxHomeFavoritesReached: Bool {
        homeWorkouts.count >= maxHomeFavorites
    }

    // MARK: - Workout Generation

    /// Generates a workout from user preferences (Workout Wizard)
    ///
    /// - Parameter preferences: User's workout preferences
    /// - Returns: Generated workout template
    /// - Throws: GenerationError if generation fails
    func generateWorkout(from preferences: WorkoutPreferences) throws -> Workout {
        guard let exercises = exerciseCoordinator?.exercises else {
            throw WorkoutCoordinatorError.exerciseCoordinatorNotSet
        }

        do {
            let workout = try generationService.generateWorkout(from: preferences, using: exercises)
            AppLogger.workouts.info(
                "✅ Generated workout: \(workout.name) with \(workout.exercises.count) exercises")
            return workout
        } catch {
            AppLogger.workouts.error("❌ Workout generation failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Session Management

    /// Records a completed workout session to history
    ///
    /// **Side Effects:**
    /// - Saves session to database
    /// - Updates exercise records (PRs)
    /// - Updates last-used metrics
    /// - Syncs to HealthKit if enabled
    ///
    /// - Parameter workout: The completed workout
    func recordSession(from workout: Workout) {
        guard let context = modelContext else {
            AppLogger.workouts.error("❌ ModelContext not set - cannot record session")
            return
        }

        let session = WorkoutSession(
            templateId: workout.id,
            name: workout.name,
            date: workout.date,
            exercises: workout.exercises,
            defaultRestTime: workout.defaultRestTime,
            duration: workout.duration,
            notes: workout.notes,
            minHeartRate: workout.minHeartRate,
            maxHeartRate: workout.maxHeartRate,
            avgHeartRate: workout.avgHeartRate
        )

        do {
            let savedEntity = try sessionService.recordSession(session)

            // Update exercise records asynchronously
            Task {
                await ExerciseRecordMigration.updateRecords(from: savedEntity, context: context)
            }

            refreshSessionHistory()
            AppLogger.workouts.info("✅ Session recorded: \(workout.name)")

        } catch {
            AppLogger.workouts.error("❌ Failed to record session: \(error.localizedDescription)")
        }
    }

    /// Removes a session from history
    ///
    /// - Parameter id: The session ID
    func removeSession(with id: UUID) {
        do {
            try sessionService.removeSession(with: id)
            refreshSessionHistory()
            AppLogger.workouts.info("✅ Session removed: \(id)")
        } catch {
            AppLogger.workouts.error("❌ Failed to remove session: \(error.localizedDescription)")
        }
    }

    /// Gets session history with optional limit
    ///
    /// - Parameter limit: Maximum number of sessions to return (default: 100)
    /// - Returns: Array of workout sessions, sorted by date (newest first)
    func getSessionHistory(limit: Int = 100) -> [WorkoutSession] {
        return analyticsService.getSessionHistory(limit: limit)
    }

    /// Gets sessions for a specific workout template
    ///
    /// - Parameters:
    ///   - templateId: The workout template ID
    ///   - limit: Maximum number of sessions to return
    /// - Returns: Array of sessions for this template
    func getSessions(for templateId: UUID, limit: Int = 10) -> [WorkoutSession] {
        guard let context = modelContext else { return [] }

        do {
            let sessions = try sessionService.getSessions(for: templateId, limit: limit)
            return sessions
        } catch {
            AppLogger.workouts.error("❌ Failed to get sessions: \(error.localizedDescription)")
            return []
        }
    }

    /// Gets the most recent session for a workout template
    ///
    /// - Parameter workout: The workout template
    /// - Returns: The previous workout with actual values, or nil if no history
    func previousWorkout(before workout: Workout) -> Workout? {
        let sessions = getSessions(for: workout.id, limit: 1)
        return sessions.first.map { Workout(session: $0) }
    }

    // MARK: - Statistics

    /// Total number of completed workout sessions
    var totalWorkoutSessions: Int {
        sessionHistory.count
    }

    /// Total workout duration across all sessions
    var totalDuration: TimeInterval {
        sessionHistory.reduce(0) { $0 + $1.duration }
    }

    /// Average workout duration in minutes
    var averageDurationMinutes: Int {
        guard !sessionHistory.isEmpty else { return 0 }
        let avgSeconds = totalDuration / Double(sessionHistory.count)
        return Int(avgSeconds / 60)
    }

    /// Gets sessions completed in the last N days
    ///
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of recent sessions
    func recentSessions(days: Int) -> [WorkoutSession] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sessionHistory.filter { $0.date >= startDate }
    }

    /// Checks if a workout was completed today
    ///
    /// - Parameter workoutId: The workout template ID
    /// - Returns: true if completed today
    func wasCompletedToday(workoutId: UUID) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return sessionHistory.contains { session in
            session.templateId == workoutId && calendar.startOfDay(for: session.date) == today
        }
    }

    /// Gets workout completion count in last N days
    ///
    /// - Parameter days: Number of days to analyze
    /// - Returns: Dictionary mapping dates to workout counts
    func workoutsByDay(days: Int) -> [Date: Int] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        let relevantSessions = sessionHistory.filter { $0.date >= startDate }

        var workoutsByDay: [Date: Int] = [:]
        for session in relevantSessions {
            let day = calendar.startOfDay(for: session.date)
            workoutsByDay[day, default: 0] += 1
        }

        return workoutsByDay
    }
}

// MARK: - Error Types

enum WorkoutCoordinatorError: LocalizedError {
    case exerciseCoordinatorNotSet
    case maxHomeFavoritesReached

    var errorDescription: String? {
        switch self {
        case .exerciseCoordinatorNotSet:
            return "Exercise coordinator must be set before generating workouts"
        case .maxHomeFavoritesReached:
            return "Maximum number of home favorites (\(4)) has been reached"
        }
    }
}
