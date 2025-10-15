import Combine
import Foundation
import SwiftData
import SwiftUI

/// SessionCoordinator manages active workout session state and lifecycle
///
/// **Responsibilities:**
/// - Active session state management
/// - Session start/end lifecycle
/// - Live Activity integration
/// - Heart rate tracking integration
/// - Session restoration after force quit
///
/// **Dependencies:**
/// - SessionManagementService (session lifecycle)
/// - WorkoutSessionService (session persistence)
/// - WorkoutLiveActivityController (Live Activities)
/// - HealthKitWorkoutTracker (heart rate tracking)
/// - WorkoutCoordinator (workout access)
///
/// **Used by:**
/// - WorkoutDetailView
/// - WorkoutsHomeView
/// - ContentView
@MainActor
final class SessionCoordinator: ObservableObject {
    // MARK: - Published State

    /// ID of the currently active workout session
    @Published var activeSessionID: UUID?

    /// Whether the workout detail view should be shown
    @Published var isShowingWorkoutDetail: Bool = false

    /// Current heart rate during active workout (BPM)
    @Published var currentHeartRate: Int?

    /// Average heart rate for current session
    @Published var averageHeartRate: Int?

    /// Session start time
    @Published var sessionStartTime: Date?

    // MARK: - Dependencies

    private let sessionManagementService: SessionManagementService
    private let sessionService: WorkoutSessionService
    private weak var workoutCoordinator: WorkoutCoordinator?
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()

    // Heart rate tracking
    private var heartRateTracker: HealthKitWorkoutTracker?
    private var heartRateReadings: [Int] = []

    // MARK: - Initialization

    init(
        sessionManagementService: SessionManagementService = SessionManagementService(),
        sessionService: WorkoutSessionService = WorkoutSessionService()
    ) {
        self.sessionManagementService = sessionManagementService
        self.sessionService = sessionService

        // Observe session state changes from service
        sessionManagementService.$activeSessionID
            .assign(to: &$activeSessionID)

        // Restore active session on init
        restoreActiveSession()
    }

    // MARK: - Context Management

    /// Sets the SwiftData context for session operations
    /// - Parameter context: The ModelContext to use for persistence
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        sessionService.setContext(context)
    }

    /// Sets the workout coordinator for workout access
    /// - Parameter coordinator: The WorkoutCoordinator instance
    func setWorkoutCoordinator(_ coordinator: WorkoutCoordinator) {
        self.workoutCoordinator = coordinator
    }

    // MARK: - Session Lifecycle

    /// Starts a new workout session
    ///
    /// **Side Effects:**
    /// - Sets activeSessionID
    /// - Starts Live Activity
    /// - Starts heart rate tracking (if authorized)
    /// - Persists session ID to UserDefaults
    ///
    /// - Parameter workoutId: The workout template ID
    func startSession(for workoutId: UUID) {
        do {
            guard let workoutEntity = try sessionService.prepareSessionStart(for: workoutId) else {
                AppLogger.workouts.error("❌ Workout with ID \(workoutId) not found")
                return
            }

            activeSessionID = workoutId
            sessionStartTime = Date()

            // Persist session ID for recovery after force quit
            UserDefaults.standard.set(workoutId.uuidString, forKey: "activeWorkoutID")

            // Start heart rate tracking
            startHeartRateTracking(workoutId: workoutId, workoutName: workoutEntity.name)

            AppLogger.workouts.info("✅ Session started: \(workoutEntity.name)")

        } catch {
            AppLogger.workouts.error("❌ Failed to start session: \(error.localizedDescription)")
        }
    }

    /// Ends the current active session
    ///
    /// **Side Effects:**
    /// - Clears activeSessionID
    /// - Ends Live Activity
    /// - Stops heart rate tracking
    /// - Removes persisted session ID
    func endCurrentSession() {
        guard let sessionID = activeSessionID else {
            AppLogger.workouts.warning("⚠️ No active session to end")
            return
        }

        // Stop heart rate tracking
        stopHeartRateTracking()

        // Clear session state
        activeSessionID = nil
        sessionStartTime = nil
        currentHeartRate = nil
        averageHeartRate = nil
        heartRateReadings.removeAll()

        // Remove persisted session ID
        UserDefaults.standard.removeObject(forKey: "activeWorkoutID")

        // End Live Activity
        WorkoutLiveActivityController.shared.end()

        AppLogger.workouts.info("🔚 Session ended: \(sessionID)")
    }

    /// Pauses the current session (placeholder for future feature)
    func pauseSession() {
        // TODO: Implement session pause logic
        AppLogger.workouts.info("⏸️ Session paused")
    }

    /// Resumes a paused session (placeholder for future feature)
    func resumeSession() {
        // TODO: Implement session resume logic
        AppLogger.workouts.info("▶️ Session resumed")
    }

    /// Restores active session after app restart or force quit
    ///
    /// **Logic:**
    /// 1. Check for persisted session ID in UserDefaults
    /// 2. Validate session still exists in database
    /// 3. Restore session state if valid
    /// 4. Clean up if session is stale
    private func restoreActiveSession() {
        guard let sessionIDString = UserDefaults.standard.string(forKey: "activeWorkoutID"),
            let sessionID = UUID(uuidString: sessionIDString)
        else {
            return
        }

        // Validate session exists
        guard let context = modelContext,
            (try? sessionService.prepareSessionStart(for: sessionID)) != nil
        else {
            // Session no longer exists, clean up
            UserDefaults.standard.removeObject(forKey: "activeWorkoutID")
            AppLogger.workouts.warning("⚠️ Stale session ID cleaned up: \(sessionID)")
            return
        }

        // Restore session
        activeSessionID = sessionID
        AppLogger.workouts.info("✅ Active session restored: \(sessionID)")

        // Sync with Live Activity if it exists
        syncWithLiveActivity()
    }

    /// Syncs session state with existing Live Activity
    private func syncWithLiveActivity() {
        // Live Activity cleanup is handled by WorkoutLiveActivityController
        // This is a placeholder for future sync logic
    }

    // MARK: - Active Workout Access

    /// Gets the currently active workout
    ///
    /// **Note:** Returns workout template with current state
    ///
    /// - Returns: Active workout or nil if no active session
    func activeWorkout() -> Workout? {
        guard let sessionID = activeSessionID else { return nil }
        return workoutCoordinator?.workout(withId: sessionID)
    }

    /// Checks if a specific workout is currently active
    ///
    /// - Parameter workoutId: The workout ID to check
    /// - Returns: true if this workout is the active session
    func isActive(workoutId: UUID) -> Bool {
        return activeSessionID == workoutId
    }

    /// Checks if any workout session is currently active
    var hasActiveSession: Bool {
        return activeSessionID != nil
    }

    // MARK: - Heart Rate Tracking

    /// Starts heart rate tracking for the active workout
    ///
    /// **Requirements:**
    /// - HealthKit authorization granted
    /// - Physical iOS device (not simulator)
    ///
    /// - Parameters:
    ///   - workoutId: The workout ID
    ///   - workoutName: The workout name for Live Activity
    private func startHeartRateTracking(workoutId: UUID, workoutName: String) {
        let healthKitManager = HealthKitManager.shared

        guard healthKitManager.isAuthorized else {
            AppLogger.workouts.info("⚠️ HealthKit not authorized - skipping heart rate tracking")
            return
        }

        let tracker = HealthKitWorkoutTracker()
        self.heartRateTracker = tracker

        // Start workout tracking
        tracker.startWorkout(
            activityType: .traditionalStrengthTraining,
            locationType: .indoor
        )

        // Start heart rate query
        tracker.startHeartRateQuery { [weak self] heartRate in
            guard let self = self else { return }

            Task { @MainActor in
                self.currentHeartRate = Int(heartRate)
                self.heartRateReadings.append(Int(heartRate))

                // Update average
                if !self.heartRateReadings.isEmpty {
                    let sum = self.heartRateReadings.reduce(0, +)
                    self.averageHeartRate = sum / self.heartRateReadings.count
                }

                // Update Live Activity with heart rate
                if let workout = self.activeWorkout() {
                    WorkoutLiveActivityController.shared.update(
                        workout: workout,
                        heartRate: Int(heartRate)
                    )
                }
            }
        }

        AppLogger.workouts.info("✅ Heart rate tracking started for: \(workoutName)")
    }

    /// Stops heart rate tracking and ends HealthKit workout
    private func stopHeartRateTracking() {
        guard let tracker = heartRateTracker else { return }

        tracker.stopHeartRateQuery()
        tracker.endWorkout()

        self.heartRateTracker = nil

        AppLogger.workouts.info("✅ Heart rate tracking stopped")
    }

    // MARK: - Session Statistics

    /// Gets the current session duration
    ///
    /// - Returns: Duration in seconds, or 0 if no active session
    var currentSessionDuration: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    /// Gets min/max/avg heart rate for current session
    var heartRateStatistics: (min: Int, max: Int, avg: Int)? {
        guard !heartRateReadings.isEmpty else { return nil }

        let min = heartRateReadings.min() ?? 0
        let max = heartRateReadings.max() ?? 0
        let sum = heartRateReadings.reduce(0, +)
        let avg = sum / heartRateReadings.count

        return (min: min, max: max, avg: avg)
    }

    /// Applies heart rate statistics to a workout before saving
    ///
    /// - Parameter workout: The workout to update
    /// - Returns: Workout with heart rate data
    func applyHeartRateStatistics(to workout: Workout) -> Workout {
        guard let stats = heartRateStatistics else { return workout }

        var updatedWorkout = workout
        updatedWorkout.minHeartRate = stats.min
        updatedWorkout.maxHeartRate = stats.max
        updatedWorkout.avgHeartRate = stats.avg

        return updatedWorkout
    }

    // MARK: - Memory Management

    /// Performs memory cleanup (called when memory warning received)
    func performMemoryCleanup() {
        // Clear old heart rate readings if too many
        if heartRateReadings.count > 1000 {
            // Keep only last 500 readings
            heartRateReadings = Array(heartRateReadings.suffix(500))
            AppLogger.workouts.info("✅ Heart rate readings cleaned up")
        }
    }

    deinit {
        // Clean up resources
        stopHeartRateTracking()
        cancellables.removeAll()
    }
}
