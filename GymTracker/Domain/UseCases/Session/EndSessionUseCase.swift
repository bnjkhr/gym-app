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
    func execute(sessionId: UUID) async throws -> WorkoutSession
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

    func execute(sessionId: UUID) async throws -> WorkoutSession {
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

#if DEBUG
    import XCTest

    /// Unit tests for EndSessionUseCase
    final class EndSessionUseCaseTests: XCTestCase {

        var repository: MockSessionRepository!
        var useCase: DefaultEndSessionUseCase!

        override func setUp() {
            super.setUp()
            repository = MockSessionRepository()
            useCase = DefaultEndSessionUseCase(sessionRepository: repository)
        }

        override func tearDown() {
            repository = nil
            useCase = nil
            super.tearDown()
        }

        func testExecute_EndsActiveSession() async throws {
            // Given
            var session = WorkoutSession(workoutId: UUID(), state: .active)
            try await repository.save(session)

            // When
            let completedSession = try await useCase.execute(sessionId: session.id)

            // Then
            XCTAssertEqual(completedSession.state, .completed)
            XCTAssertNotNil(completedSession.endDate)

            // Verify persistence
            session = try await repository.fetch(id: session.id)!
            XCTAssertEqual(session.state, .completed)
        }

        func testExecute_EndsPausedSession() async throws {
            // Given
            var session = WorkoutSession(workoutId: UUID(), state: .paused)
            try await repository.save(session)

            // When
            let completedSession = try await useCase.execute(sessionId: session.id)

            // Then
            XCTAssertEqual(completedSession.state, .completed)
            XCTAssertNotNil(completedSession.endDate)
        }

        func testExecute_ThrowsErrorWhenSessionNotFound() async throws {
            // Given
            let sessionId = UUID()

            // When/Then
            do {
                _ = try await useCase.execute(sessionId: sessionId)
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.sessionNotFound(let id) {
                XCTAssertEqual(id, sessionId)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testExecute_ThrowsErrorWhenSessionAlreadyCompleted() async throws {
            // Given
            var session = WorkoutSession(workoutId: UUID(), state: .completed)
            session.endDate = Date()
            try await repository.save(session)

            // When/Then
            do {
                _ = try await useCase.execute(sessionId: session.id)
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.invalidOperation {
                // Success - expected error
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testExecute_CalculatesDuration() async throws {
            // Given
            let startDate = Date().addingTimeInterval(-3600)  // 1 hour ago
            var session = WorkoutSession(
                workoutId: UUID(),
                startDate: startDate,
                state: .active
            )
            try await repository.save(session)

            // When
            let completedSession = try await useCase.execute(sessionId: session.id)

            // Then
            XCTAssertGreaterThan(completedSession.duration, 3590)  // ~1 hour
            XCTAssertLessThan(completedSession.duration, 3610)  // ~1 hour
        }
    }

    /// Unit tests for PauseSessionUseCase
    final class PauseSessionUseCaseTests: XCTestCase {

        var repository: MockSessionRepository!
        var useCase: DefaultPauseSessionUseCase!

        override func setUp() {
            super.setUp()
            repository = MockSessionRepository()
            useCase = DefaultPauseSessionUseCase(sessionRepository: repository)
        }

        func testExecute_PausesActiveSession() async throws {
            // Given
            var session = WorkoutSession(workoutId: UUID(), state: .active)
            try await repository.save(session)

            // When
            try await useCase.execute(sessionId: session.id)

            // Then
            session = try await repository.fetch(id: session.id)!
            XCTAssertEqual(session.state, .paused)
        }

        func testExecute_ThrowsErrorWhenSessionNotActive() async throws {
            // Given
            let session = WorkoutSession(workoutId: UUID(), state: .completed)
            try await repository.save(session)

            // When/Then
            do {
                try await useCase.execute(sessionId: session.id)
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.invalidOperation {
                // Success
            }
        }
    }

    /// Unit tests for ResumeSessionUseCase
    final class ResumeSessionUseCaseTests: XCTestCase {

        var repository: MockSessionRepository!
        var useCase: DefaultResumeSessionUseCase!

        override func setUp() {
            super.setUp()
            repository = MockSessionRepository()
            useCase = DefaultResumeSessionUseCase(sessionRepository: repository)
        }

        func testExecute_ResumespausedSession() async throws {
            // Given
            var session = WorkoutSession(workoutId: UUID(), state: .paused)
            try await repository.save(session)

            // When
            try await useCase.execute(sessionId: session.id)

            // Then
            session = try await repository.fetch(id: session.id)!
            XCTAssertEqual(session.state, .active)
        }

        func testExecute_ThrowsErrorWhenSessionNotPaused() async throws {
            // Given
            let session = WorkoutSession(workoutId: UUID(), state: .active)
            try await repository.save(session)

            // When/Then
            do {
                try await useCase.execute(sessionId: session.id)
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.invalidOperation {
                // Success
            }
        }
    }
#endif
