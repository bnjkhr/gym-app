//
//  RestTimerState.swift
//  GymTracker
//
//  Created by Claude on 2025-10-13.
//  Part of Robust Notification System
//

import Foundation

/// Represents the complete state of a rest timer during a workout session.
///
/// This model serves as the Single Source of Truth for all rest timer functionality,
/// including Live Activities, Push Notifications, and In-App Overlays.
///
/// The state is persisted to UserDefaults for recovery after force quit or app termination.
struct RestTimerState: Codable, Equatable {
    // MARK: - Identity

    /// Unique identifier for this rest timer instance
    let id: UUID

    /// ID of the workout this rest timer belongs to
    let workoutId: UUID

    /// Name of the workout (for display purposes)
    let workoutName: String

    /// Index of the exercise in the workout (0-based)
    let exerciseIndex: Int

    /// Index of the set within the exercise (0-based)
    let setIndex: Int

    // MARK: - Timer Configuration

    /// Wall-clock time when the rest timer was started
    let startDate: Date

    /// Wall-clock time when the rest timer should expire
    /// Used for precise time calculations, survives app restarts
    /// Can be modified when resuming from pause to recalculate remaining time
    var endDate: Date

    /// Total duration of the rest timer in seconds
    var totalSeconds: Int

    // MARK: - State Management

    /// Current phase of the rest timer lifecycle
    var phase: Phase

    /// Last time this state was updated (for validation and age checks)
    var lastUpdateDate: Date

    // MARK: - Live Activity Display Data

    /// Name of the current exercise (for Live Activity display)
    var currentExerciseName: String?

    /// Name of the next exercise (for Live Activity preview)
    var nextExerciseName: String?

    /// Current heart rate in BPM (from HealthKit, updated continuously)
    var currentHeartRate: Int?

    // MARK: - Phase Enum

    /// Lifecycle phases of the rest timer
    enum Phase: String, Codable {
        /// Timer is actively counting down
        case running

        /// Timer is paused by user
        case paused

        /// Timer has expired, waiting for user acknowledgment
        case expired

        /// Timer has been acknowledged by user (final state)
        case completed
    }

    // MARK: - Computed Properties

    /// Remaining time in seconds until timer expires
    ///
    /// Calculated based on wall-clock time (endDate - current time).
    /// Returns 0 if timer has already expired.
    var remainingSeconds: Int {
        max(0, Int(endDate.timeIntervalSince(Date())))
    }

    /// Whether the timer is currently active (running or paused)
    ///
    /// Returns false for expired or completed states.
    var isActive: Bool {
        phase == .running || phase == .paused
    }

    /// Whether the timer has expired but not yet been acknowledged
    ///
    /// Returns true if current time >= endDate and phase is not completed.
    var hasExpired: Bool {
        Date() >= endDate && phase != .completed
    }

    /// Progress as a percentage (0.0 to 1.0)
    ///
    /// Useful for progress bars in UI and Live Activities.
    var progress: Double {
        guard totalSeconds > 0 else { return 1.0 }
        let elapsed = totalSeconds - remainingSeconds
        return min(1.0, max(0.0, Double(elapsed) / Double(totalSeconds)))
    }

    // MARK: - Initializer

    /// Creates a new rest timer state
    ///
    /// - Parameters:
    ///   - id: Unique identifier (default: new UUID)
    ///   - workoutId: ID of the parent workout
    ///   - workoutName: Name of the workout
    ///   - exerciseIndex: Index of current exercise
    ///   - setIndex: Index of current set
    ///   - startDate: Start time (default: now)
    ///   - endDate: End time (calculated from startDate + duration)
    ///   - totalSeconds: Duration in seconds
    ///   - phase: Initial phase (default: .running)
    ///   - lastUpdateDate: Last update time (default: now)
    ///   - currentExerciseName: Name of current exercise (optional)
    ///   - nextExerciseName: Name of next exercise (optional)
    ///   - currentHeartRate: Current heart rate in BPM (optional)
    init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        exerciseIndex: Int,
        setIndex: Int,
        startDate: Date = Date(),
        endDate: Date,
        totalSeconds: Int,
        phase: Phase = .running,
        lastUpdateDate: Date = Date(),
        currentExerciseName: String? = nil,
        nextExerciseName: String? = nil,
        currentHeartRate: Int? = nil
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.startDate = startDate
        self.endDate = endDate
        self.totalSeconds = totalSeconds
        self.phase = phase
        self.lastUpdateDate = lastUpdateDate
        self.currentExerciseName = currentExerciseName
        self.nextExerciseName = nextExerciseName
        self.currentHeartRate = currentHeartRate
    }

    // MARK: - Validation

    /// Validates that the state is logically consistent
    ///
    /// - Returns: true if state is valid, false otherwise
    func isValid() -> Bool {
        // Total seconds must be positive
        guard totalSeconds > 0 else { return false }

        // End date must be after start date
        guard endDate > startDate else { return false }

        // Exercise and set indices must be non-negative
        guard exerciseIndex >= 0 && setIndex >= 0 else { return false }

        // Heart rate, if present, must be reasonable (30-250 BPM)
        if let hr = currentHeartRate {
            guard hr >= 30 && hr <= 250 else { return false }
        }

        return true
    }

    /// Age of this state in seconds
    var age: TimeInterval {
        Date().timeIntervalSince(lastUpdateDate)
    }
}

// MARK: - CustomStringConvertible

extension RestTimerState: CustomStringConvertible {
    var description: String {
        """
        RestTimerState(
          id: \(id.uuidString.prefix(8))...,
          workout: "\(workoutName)",
          exercise: \(exerciseIndex), set: \(setIndex),
          phase: \(phase.rawValue),
          remaining: \(remainingSeconds)s / \(totalSeconds)s,
          progress: \(String(format: "%.1f%%", progress * 100)),
          currentExercise: \(currentExerciseName ?? "nil"),
          nextExercise: \(nextExerciseName ?? "nil"),
          heartRate: \(currentHeartRate.map { "\($0) BPM" } ?? "nil")
        )
        """
    }
}

// MARK: - Convenience Factory Methods

extension RestTimerState {
    /// Creates a rest timer state for a specific workout and duration
    ///
    /// - Parameters:
    ///   - workoutId: ID of the workout
    ///   - workoutName: Name of the workout
    ///   - exerciseIndex: Index of current exercise
    ///   - setIndex: Index of current set
    ///   - duration: Duration in seconds
    ///   - currentExerciseName: Name of current exercise (optional)
    ///   - nextExerciseName: Name of next exercise (optional)
    /// - Returns: A new RestTimerState in running phase
    static func create(
        workoutId: UUID,
        workoutName: String,
        exerciseIndex: Int,
        setIndex: Int,
        duration: Int,
        currentExerciseName: String? = nil,
        nextExerciseName: String? = nil
    ) -> RestTimerState {
        let now = Date()
        return RestTimerState(
            workoutId: workoutId,
            workoutName: workoutName,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            startDate: now,
            endDate: now.addingTimeInterval(TimeInterval(duration)),
            totalSeconds: duration,
            phase: .running,
            lastUpdateDate: now,
            currentExerciseName: currentExerciseName,
            nextExerciseName: nextExerciseName,
            currentHeartRate: nil
        )
    }
}
