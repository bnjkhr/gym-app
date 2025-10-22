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

    // MARK: - WorkoutSession Mapping

    /// Convert Domain WorkoutSession to SwiftData Entity
    /// - Parameter domain: Domain entity
    /// - Returns: SwiftData entity ready for persistence
    func toEntity(_ domain: WorkoutSession) -> WorkoutSessionEntity {
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

    /// Convert SwiftData Entity to Domain WorkoutSession
    /// - Parameter entity: SwiftData entity
    /// - Returns: Domain entity for business logic
    func toDomain(_ entity: WorkoutSessionEntity) -> WorkoutSession {
        WorkoutSession(
            id: entity.id,
            workoutId: entity.workoutId,
            startDate: entity.startDate,
            endDate: entity.endDate,
            exercises: entity.exercises.map { toDomain($0) },
            state: WorkoutSession.SessionState(rawValue: entity.state) ?? .active
        )
    }

    /// Update existing entity with domain data
    /// - Parameters:
    ///   - entity: Existing SwiftData entity to update
    ///   - domain: Domain entity with new data
    func updateEntity(_ entity: WorkoutSessionEntity, from domain: WorkoutSession) {
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

    // MARK: - SessionExercise Mapping

    /// Convert Domain SessionExercise to SwiftData Entity
    func toEntity(_ domain: SessionExercise) -> SessionExerciseEntity {
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

    /// Convert SwiftData Entity to Domain SessionExercise
    func toDomain(_ entity: SessionExerciseEntity) -> SessionExercise {
        SessionExercise(
            id: entity.id,
            exerciseId: entity.exerciseId,
            sets: entity.sets.map { toDomain($0) },
            notes: entity.notes,
            restTimeToNext: entity.restTimeToNext
        )
    }

    // MARK: - SessionSet Mapping

    /// Convert Domain SessionSet to SwiftData Entity
    func toEntity(_ domain: SessionSet) -> SessionSetEntity {
        SessionSetEntity(
            id: domain.id,
            weight: domain.weight,
            reps: domain.reps,
            completed: domain.completed,
            completedAt: domain.completedAt
        )
    }

    /// Convert SwiftData Entity to Domain SessionSet
    func toDomain(_ entity: SessionSetEntity) -> SessionSet {
        SessionSet(
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
    func toDomain(_ entities: [WorkoutSessionEntity]) -> [WorkoutSession] {
        entities.map { toDomain($0) }
    }

    /// Batch convert multiple domain objects to entities
    func toEntity(_ domains: [WorkoutSession]) -> [WorkoutSessionEntity] {
        domains.map { toEntity($0) }
    }
}

// MARK: - Tests

#if DEBUG
    import XCTest

    /// Unit tests for SessionMapper
    final class SessionMapperTests: XCTestCase {

        var mapper: SessionMapper!

        override func setUp() {
            super.setUp()
            mapper = SessionMapper()
        }

        override func tearDown() {
            mapper = nil
            super.tearDown()
        }

        func testToDomain_WorkoutSession() {
            // Given
            let entity = WorkoutSessionEntity(
                id: UUID(),
                workoutId: UUID(),
                startDate: Date(),
                state: "active"
            )

            // When
            let domain = mapper.toDomain(entity)

            // Then
            XCTAssertEqual(domain.id, entity.id)
            XCTAssertEqual(domain.workoutId, entity.workoutId)
            XCTAssertEqual(domain.state, .active)
        }

        func testToEntity_WorkoutSession() {
            // Given
            let domain = WorkoutSession(
                workoutId: UUID(),
                state: .active
            )

            // When
            let entity = mapper.toEntity(domain)

            // Then
            XCTAssertEqual(entity.id, domain.id)
            XCTAssertEqual(entity.workoutId, domain.workoutId)
            XCTAssertEqual(entity.state, "active")
        }

        func testRoundTrip_WorkoutSession() {
            // Given
            let originalDomain = WorkoutSession(
                workoutId: UUID(),
                startDate: Date(),
                state: .active
            )

            // When - Convert to entity and back
            let entity = mapper.toEntity(originalDomain)
            let roundTrippedDomain = mapper.toDomain(entity)

            // Then - Should be identical
            XCTAssertEqual(originalDomain.id, roundTrippedDomain.id)
            XCTAssertEqual(originalDomain.workoutId, roundTrippedDomain.workoutId)
            XCTAssertEqual(originalDomain.state, roundTrippedDomain.state)
        }

        func testToDomain_WithExercises() {
            // Given
            let setEntity = SessionSetEntity(weight: 100, reps: 8, completed: true)
            let exerciseEntity = SessionExerciseEntity(
                exerciseId: UUID(),
                sets: [setEntity]
            )
            let sessionEntity = WorkoutSessionEntity(
                workoutId: UUID(),
                startDate: Date(),
                exercises: [exerciseEntity]
            )

            // When
            let domain = mapper.toDomain(sessionEntity)

            // Then
            XCTAssertEqual(domain.exercises.count, 1)
            XCTAssertEqual(domain.exercises[0].sets.count, 1)
            XCTAssertEqual(domain.exercises[0].sets[0].weight, 100)
            XCTAssertEqual(domain.exercises[0].sets[0].reps, 8)
            XCTAssertTrue(domain.exercises[0].sets[0].completed)
        }

        func testToEntity_WithExercises() {
            // Given
            let set = SessionSet(weight: 80, reps: 10, completed: false)
            let exercise = SessionExercise(exerciseId: UUID(), sets: [set])
            let session = WorkoutSession(workoutId: UUID(), exercises: [exercise])

            // When
            let entity = mapper.toEntity(session)

            // Then
            XCTAssertEqual(entity.exercises.count, 1)
            XCTAssertEqual(entity.exercises[0].sets.count, 1)
            XCTAssertEqual(entity.exercises[0].sets[0].weight, 80)
            XCTAssertEqual(entity.exercises[0].sets[0].reps, 10)
            XCTAssertFalse(entity.exercises[0].sets[0].completed)
        }

        func testUpdateEntity() {
            // Given
            let originalEntity = WorkoutSessionEntity(
                workoutId: UUID(),
                startDate: Date(),
                state: "active"
            )

            let updatedDomain = WorkoutSession(
                id: originalEntity.id,
                workoutId: originalEntity.workoutId,
                startDate: originalEntity.startDate,
                endDate: Date(),
                state: .completed
            )

            // When
            mapper.updateEntity(originalEntity, from: updatedDomain)

            // Then
            XCTAssertEqual(originalEntity.state, "completed")
            XCTAssertNotNil(originalEntity.endDate)
        }
    }
#endif
