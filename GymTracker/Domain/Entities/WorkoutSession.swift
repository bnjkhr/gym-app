//
//  WorkoutSession.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Domain Layer
//

import Foundation

/// Domain Entity representing an active or completed workout session
///
/// This is a pure Swift struct with no framework dependencies. It represents
/// the core business logic of a workout session in the Domain layer.
///
/// **Design Decisions:**
/// - `struct` instead of `class` - Value semantics, immutability by default
/// - All properties have explicit types - No optionals unless truly optional
/// - Computed properties for derived data - No stored state duplication
/// - Equatable & Identifiable for SwiftUI/Testing - But no SwiftData dependencies
///
/// **Usage:**
/// ```swift
/// let session = WorkoutSession(
///     id: UUID(),
///     workoutId: workout.id,
///     startDate: Date(),
///     exercises: []
/// )
/// ```
struct WorkoutSession: Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for this session
    let id: UUID

    /// Reference to the workout template this session is based on
    let workoutId: UUID

    /// When the session was started
    let startDate: Date

    /// When the session was ended (nil if still active)
    var endDate: Date?

    /// List of exercises in this session
    var exercises: [SessionExercise]

    /// Current state of the session
    var state: SessionState

    // MARK: - Nested Types

    /// Possible states of a workout session
    enum SessionState: String, Equatable, Codable {
        /// Session is currently active
        case active

        /// Session has been paused by user
        case paused

        /// Session has been completed
        case completed
    }

    // MARK: - Computed Properties

    /// Total duration of the session in seconds
    /// - Returns: TimeInterval from start to end (or current time if active)
    var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }

    /// Formatted duration string (MM:SS or HH:MM:SS)
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Total number of sets in the session
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    /// Number of completed sets
    var completedSets: Int {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter { $0.completed }.count
        }
    }

    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard totalSets > 0 else { return 0.0 }
        return Double(completedSets) / Double(totalSets)
    }

    /// Total volume in kg (weight × reps for all completed sets)
    var totalVolume: Double {
        exercises.reduce(0.0) { total, exercise in
            total
                + exercise.sets
                .filter { $0.completed }
                .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        }
    }

    /// Check if session is currently active
    var isActive: Bool {
        state == .active
    }

    /// Check if all exercises are completed
    var allExercisesCompleted: Bool {
        !exercises.isEmpty && exercises.allSatisfy { $0.isCompleted }
    }

    // MARK: - Initialization

    /// Create a new workout session
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - workoutId: ID of the workout template
    ///   - startDate: When the session started (defaults to now)
    ///   - endDate: When the session ended (nil for active sessions)
    ///   - exercises: List of exercises (defaults to empty)
    ///   - state: Current state (defaults to active)
    init(
        id: UUID = UUID(),
        workoutId: UUID,
        startDate: Date = Date(),
        endDate: Date? = nil,
        exercises: [SessionExercise] = [],
        state: SessionState = .active
    ) {
        self.id = id
        self.workoutId = workoutId
        self.startDate = startDate
        self.endDate = endDate
        self.exercises = exercises
        self.state = state
    }

    // MARK: - Equatable

    /// Equality based on ID only (value semantics for other properties)
    static func == (lhs: WorkoutSession, rhs: WorkoutSession) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview Helpers

#if DEBUG
    extension WorkoutSession {
        /// Sample active session for previews/testing
        static var preview: WorkoutSession {
            WorkoutSession(
                workoutId: UUID(),
                exercises: [
                    .preview,
                    .previewWithNotes,
                ],
                state: .active
            )
        }

        /// Sample completed session for previews/testing
        static var previewCompleted: WorkoutSession {
            var session = WorkoutSession.preview
            session.endDate = Date().addingTimeInterval(3600)  // 1 hour later
            session.state = .completed
            return session
        }
    }
#endif
