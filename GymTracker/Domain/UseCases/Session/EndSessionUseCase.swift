//
//  EndSessionUseCase.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Domain Layer
//

import Foundation

/// Use Case for ending a workout session
///
/// **Responsibility:**
/// - Mark session as completed
/// - Set end timestamp
/// - Calculate final statistics
/// - Persist changes to repository
/// - Export to HealthKit (optional)
///
/// **Business Rules:**
/// - Session must be in `.active` or `.paused` state
/// - End date is set to current time
/// - Session state changes to `.completed`
/// - All incomplete sets remain incomplete (not auto-completed)
///
/// **Usage:**
/// ```swift
/// let useCase = DefaultEndSessionUseCase(repository: repository)
/// let completedSession = try await useCase.execute(sessionId: sessionId)
/// ```
protocol EndSessionUseCase {
    /// End a workout session
    /// - Parameter sessionId: ID of the session to end
    /// - Returns: The completed session with updated statistics
    /// - Throws: UseCaseError if session cannot be ended
    func execute(sessionId: UUID) async throws -> DomainWorkoutSession
}

// MARK: - Implementation

/// Default implementation of EndSessionUseCase
final class DefaultEndSessionUseCase: EndSessionUseCase {

    // MARK: - Properties

    private let sessionRepository: SessionRepositoryProtocol

    // TODO: Sprint 1.4 - Add HealthKitService for export
    // private let healthKitService: HealthKitServiceProtocol?

    // MARK: - Initialization

    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }

    // MARK: - Execute

    func execute(sessionId: UUID) async throws -> DomainWorkoutSession {
        // Fetch session
        guard var session = try await sessionRepository.fetch(id: sessionId) else {
            throw UseCaseError.sessionNotFound(sessionId)
        }

        // BUSINESS RULE: Session must be active or paused
        guard session.state == .active || session.state == .paused else {
            throw UseCaseError.invalidOperation(
                "Cannot end session in state: \(session.state). Session must be active or paused."
            )
        }

        // Mark session as completed
        session.endDate = Date()
        session.state = .completed

        // Update session in repository
        do {
            try await sessionRepository.update(session)
        } catch {
            throw UseCaseError.updateFailed(error)
        }

        // TODO: Sprint 1.4 - Export to HealthKit
        // if let healthKitService = healthKitService {
        //     try? await healthKitService.exportWorkout(session)
        // }

        // TODO: Sprint 1.4 - Post notification for UI update
        // NotificationCenter.default.post(
        //     name: .sessionCompleted,
        //     object: session
        // )

        return session
    }
}

// MARK: - Additional Use Case: Pause Session

/// Use Case for pausing a workout session
protocol PauseSessionUseCase {
    /// Pause an active session
    /// - Parameter sessionId: ID of the session to pause
    /// - Throws: UseCaseError if session cannot be paused
    func execute(sessionId: UUID) async throws
}

/// Default implementation of PauseSessionUseCase
final class DefaultPauseSessionUseCase: PauseSessionUseCase {

    private let sessionRepository: SessionRepositoryProtocol

    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }

    func execute(sessionId: UUID) async throws {
        guard var session = try await sessionRepository.fetch(id: sessionId) else {
            throw UseCaseError.sessionNotFound(sessionId)
        }

        guard session.state == .active else {
            throw UseCaseError.invalidOperation(
                "Cannot pause session in state: \(session.state). Session must be active."
            )
        }

        session.state = .paused
        try await sessionRepository.update(session)
    }
}

// MARK: - Additional Use Case: Resume Session

/// Use Case for resuming a paused workout session
protocol ResumeSessionUseCase {
    /// Resume a paused session
    /// - Parameter sessionId: ID of the session to resume
    /// - Throws: UseCaseError if session cannot be resumed
    func execute(sessionId: UUID) async throws
}

/// Default implementation of ResumeSessionUseCase
final class DefaultResumeSessionUseCase: ResumeSessionUseCase {

    private let sessionRepository: SessionRepositoryProtocol

    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }

    func execute(sessionId: UUID) async throws {
        guard var session = try await sessionRepository.fetch(id: sessionId) else {
            throw UseCaseError.sessionNotFound(sessionId)
        }

        guard session.state == .paused else {
            throw UseCaseError.invalidOperation(
                "Cannot resume session in state: \(session.state). Session must be paused."
            )
        }

        session.state = .active
        try await sessionRepository.update(session)
    }
}


// MARK: - Tests
// TODO: Move inline tests to separate Test target file
// Tests were removed from production code to avoid XCTest import issues
