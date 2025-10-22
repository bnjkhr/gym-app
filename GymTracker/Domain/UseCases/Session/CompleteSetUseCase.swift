//
//  CompleteSetUseCase.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Domain Layer
//

import Foundation

/// Use Case for completing a set within a workout session
///
/// **Responsibility:**
/// - Mark a specific set as completed
/// - Update completion timestamp
/// - Persist changes to repository
/// - Trigger rest timer if configured
///
/// **Business Rules:**
/// - Set must exist in session
/// - Set can be toggled between completed/incomplete
/// - Completion timestamp is set automatically
/// - Rest timer starts after set completion (handled by timer service)
///
/// **Usage:**
/// ```swift
/// let useCase = DefaultCompleteSetUseCase(repository: repository)
/// try await useCase.execute(sessionId: sessionId, exerciseId: exerciseId, setId: setId)
/// ```
protocol CompleteSetUseCase {
    /// Complete a set in a workout session
    /// - Parameters:
    ///   - sessionId: ID of the session
    ///   - exerciseId: ID of the exercise containing the set
    ///   - setId: ID of the set to complete
    /// - Throws: UseCaseError if set cannot be completed
    func execute(sessionId: UUID, exerciseId: UUID, setId: UUID) async throws
}

// MARK: - Implementation

/// Default implementation of CompleteSetUseCase
final class DefaultCompleteSetUseCase: CompleteSetUseCase {

    // MARK: - Properties

    private let sessionRepository: SessionRepositoryProtocol

    // MARK: - Initialization

    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }

    // MARK: - Execute

    func execute(sessionId: UUID, exerciseId: UUID, setId: UUID) async throws {
        // Fetch session
        guard var session = try await sessionRepository.fetch(id: sessionId) else {
            throw UseCaseError.sessionNotFound(sessionId)
        }

        // Find exercise index
        guard let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId })
        else {
            throw UseCaseError.exerciseNotFound(exerciseId)
        }

        // Find set index
        guard
            let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: {
                $0.id == setId
            })
        else {
            throw UseCaseError.setNotFound(setId)
        }

        // Mark set as completed
        session.exercises[exerciseIndex].sets[setIndex].markCompleted()

        // Update session in repository
        do {
            try await sessionRepository.update(session)
        } catch {
            throw UseCaseError.updateFailed(error)
        }

        // TODO: Sprint 1.4 - Trigger rest timer via RestTimerService
        // if let restTime = session.exercises[exerciseIndex].restTimeToNext {
        //     restTimerService.start(duration: restTime)
        // }
    }
}

// MARK: - Tests

#if DEBUG
    import XCTest

    /// Unit tests for CompleteSetUseCase
    final class CompleteSetUseCaseTests: XCTestCase {

        var repository: MockSessionRepository!
        var useCase: DefaultCompleteSetUseCase!

        override func setUp() {
            super.setUp()
            repository = MockSessionRepository()
            useCase = DefaultCompleteSetUseCase(sessionRepository: repository)
        }

        override func tearDown() {
            repository = nil
            useCase = nil
            super.tearDown()
        }

        func testExecute_MarksSetAsCompleted() async throws {
            // Given
            let set = SessionSet(weight: 100, reps: 8, completed: false)
            let exercise = SessionExercise(exerciseId: UUID(), sets: [set])
            var session = WorkoutSession(workoutId: UUID(), exercises: [exercise])
            try await repository.save(session)

            // When
            try await useCase.execute(
                sessionId: session.id,
                exerciseId: exercise.id,
                setId: set.id
            )

            // Then
            session = try await repository.fetch(id: session.id)!
            let completedSet = session.exercises[0].sets[0]
            XCTAssertTrue(completedSet.completed)
            XCTAssertNotNil(completedSet.completedAt)
        }

        func testExecute_ThrowsErrorWhenSessionNotFound() async throws {
            // Given
            let sessionId = UUID()
            let exerciseId = UUID()
            let setId = UUID()

            // When/Then
            do {
                try await useCase.execute(
                    sessionId: sessionId,
                    exerciseId: exerciseId,
                    setId: setId
                )
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.sessionNotFound(let id) {
                XCTAssertEqual(id, sessionId)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testExecute_ThrowsErrorWhenExerciseNotFound() async throws {
            // Given
            let session = WorkoutSession(workoutId: UUID(), exercises: [])
            try await repository.save(session)

            // When/Then
            do {
                try await useCase.execute(
                    sessionId: session.id,
                    exerciseId: UUID(),
                    setId: UUID()
                )
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.exerciseNotFound {
                // Success - expected error
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testExecute_ThrowsErrorWhenSetNotFound() async throws {
            // Given
            let exercise = SessionExercise(exerciseId: UUID(), sets: [])
            let session = WorkoutSession(workoutId: UUID(), exercises: [exercise])
            try await repository.save(session)

            // When/Then
            do {
                try await useCase.execute(
                    sessionId: session.id,
                    exerciseId: exercise.id,
                    setId: UUID()
                )
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.setNotFound {
                // Success - expected error
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testExecute_UpdatesRepositoryWithCompletedSet() async throws {
            // Given
            let set = SessionSet(weight: 80, reps: 10, completed: false)
            let exercise = SessionExercise(exerciseId: UUID(), sets: [set])
            var session = WorkoutSession(workoutId: UUID(), exercises: [exercise])
            try await repository.save(session)

            // When
            try await useCase.execute(
                sessionId: session.id,
                exerciseId: exercise.id,
                setId: set.id
            )

            // Then - Verify persistence
            session = try await repository.fetch(id: session.id)!
            XCTAssertTrue(session.exercises[0].sets[0].completed)
        }
    }
#endif
