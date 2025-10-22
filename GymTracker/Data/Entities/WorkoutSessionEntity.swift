//
//  WorkoutSessionEntity.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Data Layer
//

import Foundation
import SwiftData

/// SwiftData persistence entity for DomainWorkoutSession
///
/// **Design Decisions:**
/// - `@Model` class for SwiftData persistence
/// - Mirrors Domain/Entities/DomainWorkoutSession structure
/// - Uses primitive types compatible with SwiftData
/// - Relationships to SessionExerciseEntity
///
/// **Mapping:**
/// - Maps to/from Domain's `DomainWorkoutSession` via `SessionMapper`
/// - No business logic here - pure data storage
///
/// **Usage:**
/// ```swift
/// let entity = WorkoutSessionEntity()
/// entity.id = session.id
/// modelContext.insert(entity)
/// ```
@Model
final class WorkoutSessionEntity {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Reference to workout template
    var workoutId: UUID

    /// When the session started
    var startDate: Date

    /// When the session ended (nil if active)
    var endDate: Date?

    /// Current state of the session
    var state: String  // SessionState.rawValue

    /// Exercises in this session
    @Relationship(deleteRule: .cascade, inverse: \SessionExerciseEntity.session)
    var exercises: [SessionExerciseEntity]

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        startDate: Date,
        endDate: Date? = nil,
        state: String = "active",
        exercises: [SessionExerciseEntity] = []
    ) {
        self.id = id
        self.workoutId = workoutId
        self.startDate = startDate
        self.endDate = endDate
        self.state = state
        self.exercises = exercises
    }
}

// MARK: - SwiftData Schema

extension WorkoutSessionEntity {
    /// Schema migration version
    static let schemaVersion = 1
}
