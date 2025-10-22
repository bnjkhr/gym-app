//
//  StartSessionUseCase.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Domain Layer
//

import Foundation

/// Use Case for starting a new workout session
///
/// **Responsibility:**
/// - Create a new WorkoutSession from a workout template
/// - Load exercises from workout template
/// - Ensure no other active sessions exist
/// - Save session to repository
///
/// **Business Rules:**
/// - Only ONE active session allowed at a time
/// - Session starts with all sets marked as incomplete
/// - Session state is `.active` by default
/// - Start date is set to current time
///
/// **Usage:**
/// ```swift
/// let useCase = DefaultStartSessionUseCase(repository: repository)
/// let session = try await useCase.execute(workoutId: workoutId)
/// ```
protocol StartSessionUseCase {
    /// Start a new workout session
    /// - Parameter workoutId: ID of the workout template to use
    /// - Returns: The newly created session
    /// - Throws: UseCaseError if session cannot be started
    func execute(workoutId: UUID) async throws -> WorkoutSession
}

// MARK: - Implementation

/// Default implementation of StartSessionUseCase
final class DefaultStartSessionUseCase: StartSessionUseCase {

    // MARK: - Properties

    private let sessionRepository: SessionRepositoryProtocol

    // TODO: Sprint 1.3 - Add WorkoutRepository to load workout template
    // private let workoutRepository: WorkoutRepositoryProtocol

    // MARK: - Initialization

    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }

    // MARK: - Execute

    func execute(workoutId: UUID) async throws -> WorkoutSession {
        // BUSINESS RULE: Only one active session allowed
        if let existingSession = try await sessionRepository.fetchActiveSession() {
            throw UseCaseError.activeSessionExists(existingSession.id)
        }

        // TODO: Sprint 1.3 - Load workout template from WorkoutRepository
        // let workout = try await workoutRepository.fetch(id: workoutId)
        // guard let workout = workout else {
        //     throw UseCaseError.workoutNotFound(workoutId)
        // }

        // TEMPORARY: Create session with empty exercises
        // Will be replaced when WorkoutRepository is implemented
        let session = WorkoutSession(
            workoutId: workoutId,
            startDate: Date(),
            exercises: [],  // TODO: Load from workout template
            state: .active
        )

        // Save session to repository
        do {
            try await sessionRepository.save(session)
        } catch {
            throw UseCaseError.saveFailed(error)
        }

        return session
    }
}

// MARK: - Use Case Errors

/// Errors that can occur during Use Case execution
enum UseCaseError: Error, LocalizedError {
    /// Another session is already active
    case activeSessionExists(UUID)

    /// Workout template not found
    case workoutNotFound(UUID)

    /// Session not found
    case sessionNotFound(UUID)

    /// Set not found in session
    case setNotFound(UUID)

    /// Exercise not found in session
    case exerciseNotFound(UUID)

    /// Failed to save to repository
    case saveFailed(Error)

    /// Failed to update in repository
    case updateFailed(Error)

    /// Invalid operation (e.g., completing already completed set)
    case invalidOperation(String)

    var errorDescription: String? {
        switch self {
        case .activeSessionExists(let id):
            return
                "Cannot start a new session. Another session (\(id.uuidString)) is already active. Please complete or pause the active session first."
        case .workoutNotFound(let id):
            return "Workout with ID \(id.uuidString) not found"
        case .sessionNotFound(let id):
            return "Session with ID \(id.uuidString) not found"
        case .setNotFound(let id):
            return "Set with ID \(id.uuidString) not found in session"
        case .exerciseNotFound(let id):
            return "Exercise with ID \(id.uuidString) not found in session"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update: \(error.localizedDescription)"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        }
    }
}

// MARK: - Tests

#if DEBUG
    import XCTest

    /// Unit tests for StartSessionUseCase
    final class StartSessionUseCaseTests: XCTestCase {

        var repository: MockSessionRepository!
        var useCase: DefaultStartSessionUseCase!

        override func setUp() {
            super.setUp()
            repository = MockSessionRepository()
            useCase = DefaultStartSessionUseCase(sessionRepository: repository)
        }

        override func tearDown() {
            repository = nil
            useCase = nil
            super.tearDown()
        }

        func testExecute_CreatesNewSession() async throws {
            // Given
            let workoutId = UUID()

            // When
            let session = try await useCase.execute(workoutId: workoutId)

            // Then
            XCTAssertEqual(session.workoutId, workoutId)
            XCTAssertEqual(session.state, .active)
            XCTAssertNil(session.endDate)

            // Verify session was saved to repository
            let savedSession = try await repository.fetch(id: session.id)
            XCTAssertEqual(savedSession?.id, session.id)
        }

        func testExecute_ThrowsErrorWhenActiveSessionExists() async throws {
            // Given
            let existingSession = WorkoutSession(workoutId: UUID())
            try await repository.save(existingSession)

            // When/Then
            do {
                _ = try await useCase.execute(workoutId: UUID())
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.activeSessionExists(let id) {
                XCTAssertEqual(id, existingSession.id)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testExecute_ThrowsErrorWhenSaveFails() async throws {
            // Given
            repository.shouldThrowError = true
            repository.errorToThrow = .saveFailed(NSError(domain: "Test", code: -1))

            // When/Then
            do {
                _ = try await useCase.execute(workoutId: UUID())
                XCTFail("Expected error to be thrown")
            } catch UseCaseError.saveFailed {
                // Success - expected error
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
#endif
