//
//  SessionMapper.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Data Layer
//

import Foundation
import SwiftData

/// Mapper for converting between Domain entities and SwiftData entities
///
/// **Responsibility:**
/// - Map Domain/Entities → Data/Entities (for persistence)
/// - Map Data/Entities → Domain/Entities (for business logic)
/// - Handle all type conversions
/// - Maintain relationship integrity
///
/// **Design Decisions:**
/// - Stateless struct - No stored state
/// - Pure functions - No side effects
/// - Bidirectional mapping - toDomain() and toEntity()
///
/// **Usage:**
/// ```swift
/// let mapper = SessionMapper()
/// let entity = mapper.toEntity(domainSession)
/// let domain = mapper.toDomain(entity)
/// ```
struct SessionMapper {

    // MARK: - DomainWorkoutSession Mapping

    /// Convert Domain DomainWorkoutSession to SwiftData Entity
    /// - Parameter domain: Domain entity
    /// - Returns: SwiftData entity ready for persistence
    func toEntity(_ domain: DomainWorkoutSession) -> WorkoutSessionEntity {
        let entity = WorkoutSessionEntity(
            id: domain.id,
            workoutId: domain.workoutId,
            startDate: domain.startDate,
            endDate: domain.endDate,
            state: domain.state.rawValue,
            exercises: []  // Will be set below
        )

        // Map exercises
        entity.exercises = domain.exercises.map { exercise in
            let exerciseEntity = toEntity(exercise)
            exerciseEntity.session = entity
            return exerciseEntity
        }

        return entity
    }

    /// Convert SwiftData Entity to Domain DomainWorkoutSession
    /// - Parameter entity: SwiftData entity
    /// - Returns: Domain entity for business logic
    func toDomain(_ entity: WorkoutSessionEntity) -> DomainWorkoutSession {
        DomainWorkoutSession(
            id: entity.id,
            workoutId: entity.workoutId,
            startDate: entity.startDate,
            endDate: entity.endDate,
            exercises: entity.exercises.map { toDomain($0) },
            state: DomainWorkoutSession.SessionState(rawValue: entity.state) ?? .active
        )
    }

    /// Update existing entity with domain data
    /// - Parameters:
    ///   - entity: Existing SwiftData entity to update
    ///   - domain: Domain entity with new data
    func updateEntity(_ entity: WorkoutSessionEntity, from domain: DomainWorkoutSession) {
        entity.workoutId = domain.workoutId
        entity.startDate = domain.startDate
        entity.endDate = domain.endDate
        entity.state = domain.state.rawValue

        // Update exercises
        // Note: This is a simplified version. In production, you'd want to:
        // - Match existing exercises by ID
        // - Only update changed exercises
        // - Handle additions/deletions properly

        // For now: Clear and recreate (simpler but less efficient)
        entity.exercises.removeAll()
        entity.exercises = domain.exercises.map { exercise in
            let exerciseEntity = toEntity(exercise)
            exerciseEntity.session = entity
            return exerciseEntity
        }
    }

    // MARK: - DomainSessionExercise Mapping

    /// Convert Domain DomainSessionExercise to SwiftData Entity
    func toEntity(_ domain: DomainSessionExercise) -> SessionExerciseEntity {
        let entity = SessionExerciseEntity(
            id: domain.id,
            exerciseId: domain.exerciseId,
            notes: domain.notes,
            restTimeToNext: domain.restTimeToNext,
            sets: []  // Will be set below
        )

        // Map sets
        entity.sets = domain.sets.map { set in
            let setEntity = toEntity(set)
            setEntity.exercise = entity
            return setEntity
        }

        return entity
    }

    /// Convert SwiftData Entity to Domain DomainSessionExercise
    func toDomain(_ entity: SessionExerciseEntity) -> DomainSessionExercise {
        DomainSessionExercise(
            id: entity.id,
            exerciseId: entity.exerciseId,
            sets: entity.sets.map { toDomain($0) },
            notes: entity.notes,
            restTimeToNext: entity.restTimeToNext
        )
    }

    // MARK: - DomainSessionSet Mapping

    /// Convert Domain DomainSessionSet to SwiftData Entity
    func toEntity(_ domain: DomainSessionSet) -> SessionSetEntity {
        SessionSetEntity(
            id: domain.id,
            weight: domain.weight,
            reps: domain.reps,
            completed: domain.completed,
            completedAt: domain.completedAt
        )
    }

    /// Convert SwiftData Entity to Domain DomainSessionSet
    func toDomain(_ entity: SessionSetEntity) -> DomainSessionSet {
        DomainSessionSet(
            id: entity.id,
            weight: entity.weight,
            reps: entity.reps,
            completed: entity.completed,
            completedAt: entity.completedAt
        )
    }
}

// MARK: - Mapping Extensions

extension SessionMapper {
    /// Batch convert multiple entities to domain
    func toDomain(_ entities: [WorkoutSessionEntity]) -> [DomainWorkoutSession] {
        entities.map { toDomain($0) }
    }

    /// Batch convert multiple domain objects to entities
    func toEntity(_ domains: [DomainWorkoutSession]) -> [WorkoutSessionEntity] {
        domains.map { toEntity($0) }
    }
}


// MARK: - Tests
// TODO: Move inline tests to separate Test target file
// Tests were removed from production code to avoid XCTest import issues
