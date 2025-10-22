//
//  SessionExercise.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Domain Layer
//

import Foundation

/// Domain Entity representing an exercise within a workout session
///
/// **Design Decisions:**
/// - `struct` for value semantics
/// - Reference to exercise template via `exerciseId`
/// - Mutable `sets` array for runtime modifications
/// - Optional `notes` for user annotations
/// - Optional `restTimeToNext` for timer between exercises
///
/// **Usage:**
/// ```swift
/// let exercise = SessionExercise(
///     exerciseId: benchPress.id,
///     sets: [
///         SessionSet(weight: 100, reps: 8),
///         SessionSet(weight: 100, reps: 8)
///     ]
/// )
/// ```
struct SessionExercise: Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for this exercise instance in the session
    let id: UUID

    /// Reference to the exercise template/definition
    let exerciseId: UUID

    /// List of sets for this exercise
    var sets: [SessionSet]

    /// Optional user notes for this exercise during the session
    /// Example: "Felt heavy today", "Form was good"
    var notes: String?

    /// Optional rest time in seconds before the next exercise
    /// Used for timer between exercises
    var restTimeToNext: TimeInterval?

    // MARK: - Computed Properties

    /// Total number of sets
    var totalSets: Int {
        sets.count
    }

    /// Number of completed sets
    var completedSets: Int {
        sets.filter { $0.completed }.count
    }

    /// Check if all sets are completed
    var isCompleted: Bool {
        !sets.isEmpty && sets.allSatisfy { $0.completed }
    }

    /// Progress percentage for this exercise (0.0 to 1.0)
    var progress: Double {
        guard !sets.isEmpty else { return 0.0 }
        return Double(completedSets) / Double(totalSets)
    }

    /// Total volume for this exercise in kg (sum of weight × reps for completed sets)
    var totalVolume: Double {
        sets
            .filter { $0.completed }
            .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
    }

    /// Formatted rest time to next exercise (MM:SS)
    var formattedRestTimeToNext: String? {
        guard let restTime = restTimeToNext else { return nil }
        let minutes = Int(restTime) / 60
        let seconds = Int(restTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Check if exercise has any notes
    var hasNotes: Bool {
        notes != nil && !(notes?.isEmpty ?? true)
    }

    // MARK: - Initialization

    /// Create a new session exercise
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - exerciseId: ID of the exercise template
    ///   - sets: List of sets (defaults to empty)
    ///   - notes: Optional user notes
    ///   - restTimeToNext: Optional rest time in seconds
    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        sets: [SessionSet] = [],
        notes: String? = nil,
        restTimeToNext: TimeInterval? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.sets = sets
        self.notes = notes
        self.restTimeToNext = restTimeToNext
    }

    // MARK: - Mutating Methods

    /// Add a new set to this exercise
    /// - Parameter set: The set to add
    mutating func addSet(_ set: SessionSet) {
        sets.append(set)
    }

    /// Remove a set at the specified index
    /// - Parameter index: Index of the set to remove
    mutating func removeSet(at index: Int) {
        guard sets.indices.contains(index) else { return }
        sets.remove(at: index)
    }

    /// Mark a specific set as completed
    /// - Parameter setId: ID of the set to mark complete
    mutating func completeSet(id setId: UUID) {
        if let index = sets.firstIndex(where: { $0.id == setId }) {
            sets[index].completed = true
            sets[index].completedAt = Date()
        }
    }

    /// Mark all sets as completed
    mutating func completeAllSets() {
        let now = Date()
        for index in sets.indices {
            sets[index].completed = true
            sets[index].completedAt = now
        }
    }

    // MARK: - Equatable

    /// Equality based on ID only
    static func == (lhs: SessionExercise, rhs: SessionExercise) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview Helpers

#if DEBUG
    extension SessionExercise {
        /// Sample exercise for previews/testing
        static var preview: SessionExercise {
            SessionExercise(
                exerciseId: UUID(),
                sets: [
                    SessionSet(weight: 100, reps: 8, completed: true),
                    SessionSet(weight: 100, reps: 8, completed: true),
                    SessionSet(weight: 100, reps: 7, completed: false),
                ],
                restTimeToNext: 180  // 3 minutes
            )
        }

        /// Sample exercise with notes for previews/testing
        static var previewWithNotes: SessionExercise {
            SessionExercise(
                exerciseId: UUID(),
                sets: [
                    SessionSet(weight: 80, reps: 10, completed: true),
                    SessionSet(weight: 80, reps: 9, completed: false),
                ],
                notes: "Felt heavy today, might need to deload next week",
                restTimeToNext: 120  // 2 minutes
            )
        }

        /// Sample completed exercise for previews/testing
        static var previewCompleted: SessionExercise {
            SessionExercise(
                exerciseId: UUID(),
                sets: [
                    SessionSet(weight: 120, reps: 6, completed: true),
                    SessionSet(weight: 120, reps: 6, completed: true),
                    SessionSet(weight: 120, reps: 5, completed: true),
                ]
            )
        }
    }
#endif
