//
//  SessionSetEntity.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Data Layer
//

import Foundation
import SwiftData

/// SwiftData persistence entity for DomainSessionSet
///
/// **Design Decisions:**
/// - `@Model` class for SwiftData persistence
/// - Stores weight, reps, completion status
/// - Relationship to parent SessionExerciseEntity
@Model
final class SessionSetEntity {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Weight in kilograms
    var weight: Double

    /// Number of repetitions
    var reps: Int

    /// Whether this set has been completed
    var completed: Bool

    /// Timestamp when set was completed
    var completedAt: Date?

    /// Parent exercise (inverse relationship)
    var exercise: SessionExerciseEntity?

    // MARK: - Initialization

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
}
