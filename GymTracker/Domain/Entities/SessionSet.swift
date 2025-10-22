//
//  DomainSessionSet.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Domain Layer
//

import Foundation

/// Domain Entity representing a single set within an exercise
///
/// **Design Decisions:**
/// - `struct` for value semantics
/// - `weight` in kg (Double for precision, e.g., 62.5kg)
/// - `reps` as Int (whole numbers only)
/// - `completed` flag for tracking progress
/// - `completedAt` timestamp for analytics
///
/// **Usage:**
/// ```swift
/// let set = DomainSessionSet(
///     weight: 100.0,
///     reps: 8,
///     completed: false
/// )
/// ```
struct DomainSessionSet: Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for this set
    let id: UUID

    /// Weight in kilograms (use Double for precision, e.g., 62.5kg)
    var weight: Double

    /// Number of repetitions
    var reps: Int

    /// Whether this set has been completed
    var completed: Bool

    /// Timestamp when the set was completed (nil if not completed)
    var completedAt: Date?

    // MARK: - Computed Properties

    /// Volume for this set (weight × reps)
    var volume: Double {
        weight * Double(reps)
    }

    /// Formatted weight string with unit
    /// Example: "100.0 kg", "62.5 kg"
    var formattedWeight: String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) kg"
        } else {
            return String(format: "%.1f kg", weight)
        }
    }

    /// Formatted reps string
    /// Example: "8 reps", "1 rep"
    var formattedReps: String {
        reps == 1 ? "1 rep" : "\(reps) reps"
    }

    /// Formatted volume string
    /// Example: "800 kg"
    var formattedVolume: String {
        "\(Int(volume)) kg"
    }

    /// Check if this set has been completed recently (within last 5 seconds)
    /// Useful for triggering animations or haptic feedback
    var wasJustCompleted: Bool {
        guard let completedAt = completedAt else { return false }
        return Date().timeIntervalSince(completedAt) < 5.0
    }

    // MARK: - Initialization

    /// Create a new set
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - weight: Weight in kg
    ///   - reps: Number of repetitions
    ///   - completed: Completion status (defaults to false)
    ///   - completedAt: Completion timestamp (defaults to nil)
    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        completed: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.completed = completed
        self.completedAt = completedAt
    }

    // MARK: - Mutating Methods

    /// Mark this set as completed
    /// Sets `completed` to true and `completedAt` to current time
    mutating func markCompleted() {
        completed = true
        completedAt = Date()
    }

    /// Mark this set as incomplete
    /// Sets `completed` to false and clears `completedAt`
    mutating func markIncomplete() {
        completed = false
        completedAt = nil
    }

    /// Toggle completion status
    mutating func toggleCompletion() {
        if completed {
            markIncomplete()
        } else {
            markCompleted()
        }
    }

    // MARK: - Equatable

    /// Equality based on ID only
    static func == (lhs: DomainSessionSet, rhs: DomainSessionSet) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Validation

extension DomainSessionSet {
    /// Check if this set has valid values
    /// - Returns: True if weight > 0 and reps > 0
    var isValid: Bool {
        weight > 0 && reps > 0
    }

    /// Validation errors for this set
    enum ValidationError: Error, LocalizedError {
        case invalidWeight(Double)
        case invalidReps(Int)

        var errorDescription: String? {
            switch self {
            case .invalidWeight(let weight):
                return "Invalid weight: \(weight) kg. Weight must be greater than 0."
            case .invalidReps(let reps):
                return "Invalid reps: \(reps). Reps must be greater than 0."
            }
        }
    }

    /// Validate this set
    /// - Throws: ValidationError if validation fails
    func validate() throws {
        if weight <= 0 {
            throw ValidationError.invalidWeight(weight)
        }
        if reps <= 0 {
            throw ValidationError.invalidReps(reps)
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
    extension DomainSessionSet {
        /// Sample set for previews/testing
        static var preview: DomainSessionSet {
            DomainSessionSet(
                weight: 100.0,
                reps: 8,
                completed: false
            )
        }

        /// Sample completed set for previews/testing
        static var previewCompleted: DomainSessionSet {
            DomainSessionSet(
                weight: 100.0,
                reps: 8,
                completed: true,
                completedAt: Date().addingTimeInterval(-120)  // 2 minutes ago
            )
        }

        /// Sample set with decimal weight for previews/testing
        static var previewDecimal: DomainSessionSet {
            DomainSessionSet(
                weight: 62.5,
                reps: 10,
                completed: false
            )
        }

        /// Sample just completed set for previews/testing
        static var previewJustCompleted: DomainSessionSet {
            DomainSessionSet(
                weight: 120.0,
                reps: 5,
                completed: true,
                completedAt: Date().addingTimeInterval(-2)  // 2 seconds ago
            )
        }
    }
#endif
