//
//  SessionExerciseEntity.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Data Layer
//

import Foundation
import SwiftData

/// SwiftData persistence entity for SessionExercise
///
/// **Design Decisions:**
/// - `@Model` class for SwiftData persistence
/// - Relationship to parent WorkoutSessionEntity
/// - Relationship to child SessionSetEntity
/// - Optional notes and restTimeToNext
@Model
final class SessionExerciseEntity {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Reference to exercise template
    var exerciseId: UUID

    /// Optional user notes
    var notes: String?

    /// Optional rest time in seconds before next exercise
    var restTimeToNext: TimeInterval?

    /// Sets for this exercise
    @Relationship(deleteRule: .cascade, inverse: \SessionSetEntity.exercise)
    var sets: [SessionSetEntity]

    /// Parent session (inverse relationship)
    var session: WorkoutSessionEntity?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        notes: String? = nil,
        restTimeToNext: TimeInterval? = nil,
        sets: [SessionSetEntity] = []
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.notes = notes
        self.restTimeToNext = restTimeToNext
        self.sets = sets
    }
}
