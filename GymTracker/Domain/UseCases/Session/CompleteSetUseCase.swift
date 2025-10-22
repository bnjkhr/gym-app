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
// TODO: Move inline tests to separate Test target file
// Tests were removed from production code to avoid XCTest import issues
