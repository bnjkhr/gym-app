//
//  RestTimerStateManager.swift
//  GymTracker
//
//  Created by Claude on 2025-10-13.
//  Part of Robust Notification System
//

import Foundation
import UIKit

#if canImport(ActivityKit)
    import ActivityKit
#endif

/// Single Source of Truth for all rest timer state and lifecycle management
///
/// This manager is responsible for:
/// - Managing timer state (running, paused, expired, completed)
/// - Automatic state persistence for force quit recovery
/// - Coordinating all notification subsystems (Timer, Live Activity, Push, Overlay)
/// - State validation and recovery
///
/// ## Architecture:
/// ```
/// RestTimerStateManager (SSOT)
///         ↓
///    ┌────┴────┬──────────┬───────────┐
///    ↓         ↓          ↓           ↓
/// TimerEngine  LiveAct  Notifications Overlay
/// ```
///
/// ## Usage:
/// ```swift
/// let manager = RestTimerStateManager()
///
/// // Start rest timer
/// manager.startRest(
///     for: workout,
///     exercise: 0,
///     set: 0,
///     duration: 90,
///     currentExerciseName: "Bankdrücken",
///     nextExerciseName: "Kniebeugen"
/// )
///
/// // Update heart rate (from HealthKit)
/// manager.updateHeartRate(145)
///
/// // Pause/Resume
/// manager.pauseRest()
/// manager.resumeRest()
///
/// // Acknowledge expiration
/// manager.acknowledgeExpired()
/// ```
@MainActor
final class RestTimerStateManager: ObservableObject {

    // MARK: - Published State

    /// Current rest timer state (nil if no active timer)
    ///
    /// Observers can watch this to react to state changes.
    @Published private(set) var currentState: RestTimerState?

    // MARK: - Configuration

    /// UserDefaults key for state persistence
    private let persistenceKey = "restTimerState_v2"

    /// Maximum age of persisted state before discarding (24 hours)
    private let maxStateAge: TimeInterval = 24 * 3600

    /// Minimum interval between heart rate updates (throttling)
    private let heartRateUpdateThrottle: TimeInterval = 5.0

    /// Last time heart rate was updated
    private var lastHeartRateUpdate: Date?

    // MARK: - User Preferences (Phase 6)

    /// Whether to show in-app overlay (user preference, default: true)
    private var showInAppOverlay: Bool {
        // Check if key exists, if not return default value (true)
        if UserDefaults.standard.object(forKey: "showInAppOverlay") == nil {
            return true  // Default: enabled
        }
        return UserDefaults.standard.bool(forKey: "showInAppOverlay")
    }

    /// Whether to enable push notifications (user preference, default: true)
    private var enablePushNotifications: Bool {
        // Check if key exists, if not return default value (true)
        if UserDefaults.standard.object(forKey: "enablePushNotifications") == nil {
            return true  // Default: enabled
        }
        return UserDefaults.standard.bool(forKey: "enablePushNotifications")
    }

    /// Whether to enable Live Activity (user preference, default: true)
    private var enableLiveActivity: Bool {
        // Check if key exists, if not return default value (true)
        if UserDefaults.standard.object(forKey: "enableLiveActivity") == nil {
            return true  // Default: enabled
        }
        return UserDefaults.standard.bool(forKey: "enableLiveActivity")
    }

    // MARK: - Dependencies

    /// Persistent storage
    private let storage: UserDefaults

    /// Timer engine for precise countdown
    private let timerEngine: TimerEngine

    /// In-app overlay manager (injected, optional for Phase 2)
    weak var overlayManager: RestTimerOverlayProtocol?

    /// Live Activity controller (Phase 3)
    #if canImport(ActivityKit)
        private let liveActivityController: WorkoutLiveActivityController?
    #endif

    /// Notification manager (Phase 4)
    private let notificationManager: NotificationManager

    // MARK: - Initialization

    /// Creates a new RestTimerStateManager
    ///
    /// - Parameters:
    ///   - storage: UserDefaults instance for persistence (default: .standard)
    ///   - timerEngine: Timer engine instance (default: new instance)
    ///   - notificationManager: Notification manager instance (default: shared)
    init(
        storage: UserDefaults = .standard,
        timerEngine: TimerEngine? = nil,
        notificationManager: NotificationManager? = nil
    ) {
        self.storage = storage
        self.timerEngine = timerEngine ?? TimerEngine()
        self.notificationManager = notificationManager ?? .shared

        #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                self.liveActivityController = WorkoutLiveActivityController.shared
            } else {
                self.liveActivityController = nil
            }
        #endif

        AppLogger.workouts.info("RestTimerStateManager initialized")
    }

    // MARK: - Public API

    /// Starts a new rest timer
    ///
    /// Any previously active timer will be cancelled.
    ///
    /// - Parameters:
    ///   - workout: The workout this rest timer belongs to
    ///   - exercise: Index of the current exercise
    ///   - set: Index of the current set
    ///   - duration: Duration in seconds
    ///   - currentExerciseName: Name of current exercise (for Live Activity)
    ///   - nextExerciseName: Name of next exercise (for Live Activity)
    func startRest(
        for workout: Workout,
        exercise: Int,
        set: Int,
        duration: Int,
        currentExerciseName: String? = nil,
        nextExerciseName: String? = nil
    ) {
        AppLogger.workouts.info("Starting rest timer: \(duration)s for \(workout.name)")

        let state = RestTimerState.create(
            workoutId: workout.id,
            workoutName: workout.name,
            exerciseIndex: exercise,
            setIndex: set,
            duration: duration,
            currentExerciseName: currentExerciseName,
            nextExerciseName: nextExerciseName
        )

        applyStateChange(state)
    }

    /// Updates the heart rate in the current state
    ///
    /// Updates are throttled to max 1 per 5 seconds to avoid excessive Live Activity updates.
    ///
    /// - Parameter heartRate: Heart rate in BPM (30-250 valid range)
    func updateHeartRate(_ heartRate: Int) {
        guard var state = currentState else {
            AppLogger.workouts.warning("Attempted to update heart rate with no active timer")
            return
        }

        // Throttle updates
        if let lastUpdate = lastHeartRateUpdate,
            Date().timeIntervalSince(lastUpdate) < heartRateUpdateThrottle
        {
            return
        }

        // Validate heart rate
        guard heartRate >= 30 && heartRate <= 250 else {
            AppLogger.workouts.warning("Invalid heart rate: \(heartRate) BPM")
            return
        }

        state.currentHeartRate = heartRate
        state.lastUpdateDate = Date()
        lastHeartRateUpdate = Date()

        applyStateChange(state)

        AppLogger.workouts.debug("Heart rate updated: \(heartRate) BPM")
    }

    /// Pauses the currently running timer
    ///
    /// Only works if timer is in .running phase.
    func pauseRest() {
        guard var state = currentState, state.phase == .running else {
            AppLogger.workouts.warning("Cannot pause: timer not running")
            return
        }

        AppLogger.workouts.info("Pausing rest timer")

        state.phase = .paused
        state.lastUpdateDate = Date()

        applyStateChange(state)
    }

    /// Resumes a paused timer
    ///
    /// Only works if timer is in .paused phase.
    /// Recalculates endDate based on remaining time.
    func resumeRest() {
        guard var state = currentState, state.phase == .paused else {
            AppLogger.workouts.warning("Cannot resume: timer not paused")
            return
        }

        AppLogger.workouts.info("Resuming rest timer")

        // Recalculate end date based on remaining time
        let remaining = state.remainingSeconds
        let now = Date()
        state.endDate = now.addingTimeInterval(TimeInterval(remaining))
        state.phase = .running
        state.lastUpdateDate = now

        applyStateChange(state)
    }

    /// Acknowledges that timer has expired and user has seen notification
    ///
    /// Transitions state to .completed and cleans up after a short delay.
    func acknowledgeExpired() {
        guard var state = currentState, state.hasExpired else {
            AppLogger.workouts.warning("Cannot acknowledge: timer not expired")
            return
        }

        AppLogger.workouts.info("Rest timer acknowledged")

        state.phase = .completed
        state.lastUpdateDate = Date()

        applyStateChange(state)

        // Clean up after short delay to allow UI animations
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
            self.clearState()
        }
    }

    /// Cancels the current rest timer
    ///
    /// Immediately stops timer and clears all state.
    func cancelRest() {
        AppLogger.workouts.info("Rest timer cancelled")
        clearState()
    }

    /// Adds time to the current rest timer
    ///
    /// - Parameter seconds: Number of seconds to add (can be negative to subtract)
    func addRest(seconds: Int) {
        guard var state = currentState else {
            AppLogger.workouts.warning("Cannot add rest: no active timer")
            return
        }

        // Calculate new remaining time
        let newRemaining = max(0, state.remainingSeconds + seconds)
        let newTotal = max(state.totalSeconds, newRemaining)

        // Update state with new times
        var updatedState = RestTimerState(
            id: state.id,
            workoutId: state.workoutId,
            workoutName: state.workoutName,
            exerciseIndex: state.exerciseIndex,
            setIndex: state.setIndex,
            startDate: state.startDate,
            endDate: Date().addingTimeInterval(TimeInterval(newRemaining)),
            totalSeconds: newTotal,
            phase: newRemaining > 0 ? state.phase : .expired,
            lastUpdateDate: Date(),
            currentExerciseName: state.currentExerciseName,
            nextExerciseName: state.nextExerciseName,
            currentHeartRate: state.currentHeartRate
        )

        applyStateChange(updatedState)
        AppLogger.workouts.info("Added \(seconds)s to rest timer. New remaining: \(newRemaining)s")
    }

    /// Sets the remaining time for the current rest timer
    ///
    /// - Parameters:
    ///   - remaining: New remaining seconds
    ///   - total: Optional new total duration (defaults to remaining if not specified)
    func setRest(remaining: Int, total: Int? = nil) {
        guard var state = currentState else {
            AppLogger.workouts.warning("Cannot set rest: no active timer")
            return
        }

        let newRemaining = max(0, remaining)
        let newTotal = total ?? max(state.totalSeconds, newRemaining)

        // Update state with new times
        var updatedState = RestTimerState(
            id: state.id,
            workoutId: state.workoutId,
            workoutName: state.workoutName,
            exerciseIndex: state.exerciseIndex,
            setIndex: state.setIndex,
            startDate: state.startDate,
            endDate: Date().addingTimeInterval(TimeInterval(newRemaining)),
            totalSeconds: newTotal,
            phase: newRemaining > 0 ? state.phase : .expired,
            lastUpdateDate: Date(),
            currentExerciseName: state.currentExerciseName,
            nextExerciseName: state.nextExerciseName,
            currentHeartRate: state.currentHeartRate
        )

        applyStateChange(updatedState)
        AppLogger.workouts.info("Set rest timer to \(newRemaining)s (total: \(newTotal)s)")
    }

    // MARK: - State Management

    /// Applies a state change transactionally
    ///
    /// This is the only method that should modify currentState.
    /// Ensures state is persisted and all subsystems are notified atomically.
    ///
    /// - Parameter newState: The new state (nil to clear)
    private func applyStateChange(_ newState: RestTimerState?) {
        let oldState = currentState

        // Update state
        currentState = newState

        // Persist immediately (transactional)
        persistState(newState)

        // Notify all subsystems
        notifySubsystems(oldState: oldState, newState: newState)

        // Logging
        let oldPhase = oldState?.phase.rawValue ?? "nil"
        let newPhase = newState?.phase.rawValue ?? "nil"
        AppLogger.workouts.info("State transition: \(oldPhase) → \(newPhase)")
    }

    /// Notifies all subsystems of state change
    ///
    /// Coordinates Timer Engine, Live Activity, Notifications, and Overlay.
    ///
    /// **Critical:** Live Activity updates are async but fire-and-forget.
    /// This is intentional to avoid blocking state updates. Errors are logged
    /// but don't prevent other subsystems from working.
    ///
    /// - Parameters:
    ///   - oldState: Previous state
    ///   - newState: New state
    private func notifySubsystems(oldState: RestTimerState?, newState: RestTimerState?) {
        // 1. Timer Engine (synchronous, fast)
        updateTimerEngine(for: newState)

        // 2. Live Activity (async, fire-and-forget with error handling)
        #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                // Check user preference before updating
                if enableLiveActivity {
                    // Capture state for async context
                    let stateCopy = newState
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        do {
                            self.liveActivityController?.updateForState(stateCopy)
                            if stateCopy != nil {
                                AppLogger.workouts.debug("✅ Live Activity update dispatched")
                            }
                        } catch {
                            AppLogger.workouts.error("❌ Live Activity update failed: \(error)")
                        }
                    }
                } else {
                    AppLogger.workouts.debug("⏭️ Live Activity disabled by user")
                }
            }
        #endif

        // 3. Notifications (async, fire-and-forget with error handling)
        // Check user preference before scheduling
        if enablePushNotifications {
            let stateCopy = newState
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    if let state = stateCopy {
                        self.notificationManager.scheduleNotification(for: state)
                    } else {
                        self.notificationManager.cancelNotifications()
                    }
                } catch {
                    AppLogger.workouts.error("❌ Notification scheduling failed: \(error)")
                }
            }
        } else {
            AppLogger.workouts.debug("⏭️ Push notifications disabled by user")
        }
    }

    /// Updates the timer engine based on state
    private func updateTimerEngine(for state: RestTimerState?) {
        if let state = state, state.phase == .running {
            // Start timer
            timerEngine.startTimer(until: state.endDate) { [weak self] in
                Task { @MainActor in
                    self?.handleTimerExpired()
                }
            }
        } else {
            // Stop timer (paused, expired, completed, or nil)
            timerEngine.stopTimer()
        }
    }

    /// Handles timer expiration
    ///
    /// Transitions state to .expired and triggers all notifications.
    private func handleTimerExpired() {
        guard var state = currentState else {
            AppLogger.workouts.warning("Timer expired but no current state")
            return
        }

        AppLogger.workouts.info("⏰ Rest timer expired!")

        // Transition to expired phase
        state.phase = .expired
        state.lastUpdateDate = Date()

        applyStateChange(state)

        // Trigger all notification channels
        triggerExpirationNotifications(for: state)
    }

    /// Triggers all notification channels when timer expires
    ///
    /// - In-App Overlay (if app is active)
    /// - Live Activity Alert (Dynamic Island)
    /// - Push Notification (if app is background/inactive)
    /// - Haptic Feedback
    /// - Sound
    ///
    /// - Parameter state: The expired state
    private func triggerExpirationNotifications(for state: RestTimerState) {
        AppLogger.workouts.info("Triggering expiration notifications")

        // 1. Live Activity Alert (Phase 3)
        #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                liveActivityController?.showExpirationAlert(for: state)
                AppLogger.workouts.info("✅ Live Activity expiration alert triggered")
            }
        #endif

        // 2. In-App Overlay (Phase 2) - only if app is active AND user enabled it
        if UIApplication.shared.applicationState == .active {
            if showInAppOverlay {
                overlayManager?.showExpiredOverlay(for: state)
                AppLogger.workouts.info("✅ In-app overlay shown (app active)")
            } else {
                AppLogger.workouts.debug("⏭️ In-app overlay disabled by user")
            }
        }

        // 3. Push Notification (Phase 4) - already scheduled, will fire automatically

        // 4. Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        AppLogger.workouts.debug("✅ Haptic feedback triggered")

        // 5. Sound (Phase 2)
        // TODO: AudioManager.shared.playBoxBell()

        AppLogger.workouts.info("✅ Expiration notifications triggered")
    }

    // MARK: - Persistence

    /// Persists state to UserDefaults
    ///
    /// Uses JSON encoding for forward compatibility.
    ///
    /// - Parameter state: State to persist (nil to clear)
    private func persistState(_ state: RestTimerState?) {
        do {
            if let state = state {
                let data = try JSONEncoder().encode(state)
                storage.set(data, forKey: persistenceKey)
                AppLogger.data.debug("✅ State persisted (\(data.count) bytes)")
            } else {
                storage.removeObject(forKey: persistenceKey)
                AppLogger.data.debug("✅ State cleared")
            }
        } catch {
            AppLogger.data.error("❌ Failed to persist state: \(error)")
        }
    }

    /// Restores state from UserDefaults
    ///
    /// Called on app launch to recover timer after force quit.
    /// Validates state age and adjusts for expired timers.
    func restoreState() {
        guard let data = storage.data(forKey: persistenceKey) else {
            AppLogger.data.info("No persisted state found")
            return
        }

        do {
            var state = try JSONDecoder().decode(RestTimerState.self, from: data)

            // Validate state age
            let age = state.age
            guard age < maxStateAge else {
                AppLogger.data.warning("⚠️ State too old (\(Int(age/3600))h), discarding")
                clearState()
                return
            }

            // Validate state consistency
            guard state.isValid() else {
                AppLogger.data.warning("⚠️ Invalid state, discarding")
                clearState()
                return
            }

            // Check if timer expired while app was closed
            if state.hasExpired && state.phase == .running {
                AppLogger.data.info("⏱️ Timer expired during app absence")
                state.phase = .expired
            }

            // Apply restored state
            applyStateChange(state)

            // Trigger notifications if just expired
            if state.phase == .expired {
                triggerExpirationNotifications(for: state)
            }

            AppLogger.data.info(
                "✅ State restored: \(state.remainingSeconds)s remaining, phase: \(state.phase.rawValue)"
            )

        } catch {
            AppLogger.data.error("❌ Failed to restore state: \(error)")
            clearState()
        }
    }

    /// Clears current state and all persistent storage
    private func clearState() {
        applyStateChange(nil)
    }
}

// MARK: - Debug Support

extension RestTimerStateManager {
    /// Debug description of current state
    var debugDescription: String {
        guard let state = currentState else {
            return "RestTimerStateManager(no active timer)"
        }

        return """
            RestTimerStateManager:
              \(state.description)
              TimerEngine: \(timerEngine.isRunning ? "running" : "stopped")
            """
    }
}
