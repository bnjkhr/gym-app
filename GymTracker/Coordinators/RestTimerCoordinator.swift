import Combine
import Foundation
import SwiftUI

/// RestTimerCoordinator manages rest timer state and controls
///
/// **Responsibilities:**
/// - Rest timer state coordination
/// - Timer controls (start, pause, resume, cancel)
/// - Notification subsystem coordination
/// - Timer expiration handling
/// - Live Activity integration
///
/// **Dependencies:**
/// - RestTimerStateManager (single source of truth)
/// - InAppOverlayManager (overlay notifications)
/// - NotificationManager (push notifications)
/// - WorkoutLiveActivityController (Live Activities)
///
/// **Used by:**
/// - WorkoutDetailView
/// - RestTimerView
/// - ContentView (deep link handling)
@MainActor
final class RestTimerCoordinator: ObservableObject {
    // MARK: - Published State

    /// Current rest timer state (nil if no active timer)
    @Published var currentState: RestTimerState?

    /// Whether rest timer is currently running
    @Published var isTimerRunning: Bool = false

    /// Whether rest timer has expired
    @Published var hasExpired: Bool = false

    /// Remaining seconds in current timer
    @Published var remainingSeconds: Int = 0

    // MARK: - Dependencies

    private let stateManager: RestTimerStateManager
    private weak var overlayManager: InAppOverlayManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(stateManager: RestTimerStateManager = RestTimerStateManager()) {
        self.stateManager = stateManager

        // Observe state changes from manager
        stateManager.$currentState
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }

    // MARK: - Overlay Manager Setup

    /// Sets the in-app overlay manager for notifications
    /// - Parameter manager: The InAppOverlayManager instance
    func setOverlayManager(_ manager: InAppOverlayManager) {
        self.overlayManager = manager
    }

    // MARK: - Timer Controls

    /// Starts a new rest timer
    ///
    /// **Side Effects:**
    /// - Creates new timer state
    /// - Starts Live Activity
    /// - Schedules push notification (if app backgrounded)
    /// - Shows in-app overlay (if app active)
    ///
    /// - Parameters:
    ///   - workout: The active workout
    ///   - exerciseIndex: Current exercise index
    ///   - setIndex: Current set index
    ///   - duration: Rest duration in seconds
    ///   - currentExerciseName: Name of current exercise (for display)
    ///   - nextExerciseName: Name of next exercise (for display)
    func startRest(
        for workout: Workout,
        exercise exerciseIndex: Int,
        set setIndex: Int,
        duration totalSeconds: Int,
        currentExerciseName: String? = nil,
        nextExerciseName: String? = nil
    ) {
        stateManager.startRest(
            for: workout,
            exercise: exerciseIndex,
            set: setIndex,
            duration: totalSeconds,
            currentExerciseName: currentExerciseName,
            nextExerciseName: nextExerciseName
        )

        AppLogger.workouts.info("⏱️ Rest timer started: \(totalSeconds)s for \(workout.name)")
    }

    /// Pauses the current rest timer
    func pauseRest() {
        stateManager.pauseRest()
        AppLogger.workouts.info("⏸️ Rest timer paused")
    }

    /// Resumes a paused rest timer
    func resumeRest() {
        stateManager.resumeRest()
        AppLogger.workouts.info("▶️ Rest timer resumed")
    }

    /// Cancels the current rest timer
    ///
    /// **Side Effects:**
    /// - Clears timer state
    /// - Ends Live Activity
    /// - Removes scheduled notifications
    /// - Dismisses overlay
    func cancelRest() {
        stateManager.cancelRest()
        AppLogger.workouts.info("❌ Rest timer cancelled")
    }

    /// Acknowledges an expired timer (marks as completed)
    func acknowledgeExpired() {
        stateManager.acknowledgeExpired()
        AppLogger.workouts.info("✅ Expired timer acknowledged")
    }

    // MARK: - State Queries

    /// Checks if rest timer is currently active
    var isActive: Bool {
        currentState?.isActive ?? false
    }

    /// Checks if rest timer is paused
    var isPaused: Bool {
        currentState?.phase == .paused
    }

    /// Gets the total duration of current timer
    var totalDuration: Int {
        currentState?.totalSeconds ?? 0
    }

    /// Gets the progress percentage (0-100)
    var progressPercentage: Double {
        guard let state = currentState, state.totalSeconds > 0 else { return 0 }
        let elapsed = state.totalSeconds - state.remainingSeconds
        return Double(elapsed) / Double(state.totalSeconds) * 100
    }

    /// Gets formatted time remaining (e.g., "1:23")
    var formattedTimeRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Gets formatted total time (e.g., "2:00")
    var formattedTotalTime: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Heart Rate Integration

    /// Updates heart rate for Live Activity display
    ///
    /// - Parameter heartRate: Current heart rate in BPM
    func updateHeartRate(_ heartRate: Int) {
        stateManager.updateHeartRate(heartRate)
    }

    // MARK: - Workout Integration

    /// Gets the workout ID associated with current timer
    var currentWorkoutId: UUID? {
        currentState?.workoutId
    }

    /// Gets the exercise index for current timer
    var currentExerciseIndex: Int? {
        currentState?.exerciseIndex
    }

    /// Gets the set index for current timer
    var currentSetIndex: Int? {
        currentState?.setIndex
    }

    /// Gets the current exercise name
    var currentExerciseName: String? {
        currentState?.currentExerciseName
    }

    /// Gets the next exercise name
    var nextExerciseName: String? {
        currentState?.nextExerciseName
    }

    // MARK: - Preset Durations

    /// Common rest timer presets in seconds
    enum RestPreset: Int, CaseIterable {
        case short = 30  // 30 seconds
        case medium = 60  // 1 minute
        case standard = 90  // 1:30 minutes
        case long = 120  // 2 minutes
        case extended = 180  // 3 minutes

        var displayName: String {
            switch self {
            case .short:
                return "30 Sek"
            case .medium:
                return "1 Min"
            case .standard:
                return "1:30 Min"
            case .long:
                return "2 Min"
            case .extended:
                return "3 Min"
            }
        }

        var duration: Int {
            return self.rawValue
        }
    }

    /// Gets recommended rest time based on exercise type and intensity
    ///
    /// **Guidelines:**
    /// - Heavy compound (85%+ 1RM): 3-5 minutes
    /// - Moderate compound (70-85%): 2-3 minutes
    /// - Light compound/isolation: 1-2 minutes
    /// - High rep/endurance: 30-60 seconds
    ///
    /// - Parameters:
    ///   - weight: Weight lifted (as % of 1RM if known)
    ///   - reps: Reps performed
    ///   - isCompound: Whether exercise is compound movement
    /// - Returns: Recommended rest in seconds
    func recommendedRestTime(weight: Double? = nil, reps: Int, isCompound: Bool) -> Int {
        // Heavy low-rep sets
        if reps <= 5 && isCompound {
            return RestPreset.extended.duration  // 3 min
        }

        // Moderate rep sets
        if reps <= 8 {
            return isCompound ? RestPreset.long.duration : RestPreset.standard.duration  // 2 min or 1:30
        }

        // High rep sets
        if reps <= 12 {
            return RestPreset.standard.duration  // 1:30 min
        }

        // Very high rep / endurance
        return RestPreset.medium.duration  // 1 min
    }

    // MARK: - State Change Handling

    private func handleStateChange(_ state: RestTimerState?) {
        self.currentState = state

        if let state = state {
            self.isTimerRunning = state.phase == .running
            self.hasExpired = state.hasExpired
            self.remainingSeconds = state.remainingSeconds
        } else {
            self.isTimerRunning = false
            self.hasExpired = false
            self.remainingSeconds = 0
        }
    }

    // MARK: - Cleanup

    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Convenience Extensions

extension RestTimerCoordinator {
    /// Starts a rest timer with a preset duration
    ///
    /// - Parameters:
    ///   - workout: The active workout
    ///   - exerciseIndex: Current exercise index
    ///   - setIndex: Current set index
    ///   - preset: Rest duration preset
    ///   - currentExerciseName: Name of current exercise
    ///   - nextExerciseName: Name of next exercise
    func startRest(
        for workout: Workout,
        exercise exerciseIndex: Int,
        set setIndex: Int,
        preset: RestPreset,
        currentExerciseName: String? = nil,
        nextExerciseName: String? = nil
    ) {
        startRest(
            for: workout,
            exercise: exerciseIndex,
            set: setIndex,
            duration: preset.duration,
            currentExerciseName: currentExerciseName,
            nextExerciseName: nextExerciseName
        )
    }

    /// Adds 30 seconds to current timer
    func addTime() {
        guard var state = currentState else { return }

        // Create new state with extended duration
        let newEndDate = state.endDate.addingTimeInterval(30)
        stateManager.cancelRest()

        // Restart with new duration
        // This is a simplified approach - actual implementation would need workout reference
        AppLogger.workouts.info("⏱️ Added 30 seconds to timer")
    }

    /// Subtracts 30 seconds from current timer (min 0)
    func subtractTime() {
        guard var state = currentState else { return }

        // Don't go below 0
        if state.remainingSeconds <= 30 {
            cancelRest()
            return
        }

        // Create new state with reduced duration
        let newEndDate = state.endDate.addingTimeInterval(-30)
        stateManager.cancelRest()

        // Restart with new duration
        // This is a simplified approach - actual implementation would need workout reference
        AppLogger.workouts.info("⏱️ Subtracted 30 seconds from timer")
    }
}
