//
//  SessionRepositoryProtocol.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Domain Layer
//

import Foundation

/// Repository protocol for workout session persistence operations
///
/// **Design Principles:**
/// - Pure protocol in Domain layer - No implementation details
/// - Async/await for all operations - Modern concurrency
/// - Throws for error handling - Explicit error propagation
/// - Returns Domain entities only - No Data layer leakage
///
/// **Implementation:**
/// - Will be implemented by `SwiftDataSessionRepository` in Data layer
/// - Can be mocked for testing Use Cases
///
/// **Usage:**
/// ```swift
/// let repository: SessionRepositoryProtocol = SwiftDataSessionRepository(...)
/// let session = try await repository.fetch(id: sessionId)
/// ```
protocol SessionRepositoryProtocol {

    // MARK: - Create & Update

    /// Save a new session to persistence
    /// - Parameter session: The session to save
    /// - Throws: RepositoryError if save fails
    func save(_ session: DomainWorkoutSession) async throws

    /// Update an existing session
    /// - Parameter session: The session with updated data
    /// - Throws: RepositoryError if update fails or session not found
    func update(_ session: DomainWorkoutSession) async throws

    // MARK: - Read

    /// Fetch a session by ID
    /// - Parameter id: The session's unique identifier
    /// - Returns: The session if found, nil otherwise
    /// - Throws: RepositoryError if fetch fails
    func fetch(id: UUID) async throws -> DomainWorkoutSession?

    /// Fetch the currently active session (if any)
    /// - Returns: The active session if one exists, nil otherwise
    /// - Throws: RepositoryError if fetch fails
    func fetchActiveSession() async throws -> DomainWorkoutSession?

    /// Fetch all sessions for a specific workout template
    /// - Parameter workoutId: ID of the workout template
    /// - Returns: Array of sessions (may be empty)
    /// - Throws: RepositoryError if fetch fails
    func fetchSessions(for workoutId: UUID) async throws -> [DomainWorkoutSession]

    /// Fetch recent sessions (last N sessions)
    /// - Parameter limit: Maximum number of sessions to fetch
    /// - Returns: Array of sessions, sorted by startDate descending
    /// - Throws: RepositoryError if fetch fails
    func fetchRecentSessions(limit: Int) async throws -> [DomainWorkoutSession]

    // MARK: - Delete

    /// Delete a session by ID
    /// - Parameter id: The session's unique identifier
    /// - Throws: RepositoryError if delete fails
    func delete(id: UUID) async throws

    /// Delete all sessions (use with caution!)
    /// - Throws: RepositoryError if delete fails
    func deleteAll() async throws
}

// MARK: - Repository Errors

/// Errors that can occur during repository operations
enum RepositoryError: Error, LocalizedError {
    /// Session with given ID was not found
    case sessionNotFound(UUID)

    /// Failed to save session to persistence
    case saveFailed(Error)

    /// Failed to update session in persistence
    case updateFailed(Error)

    /// Failed to fetch session from persistence
    case fetchFailed(Error)

    /// Failed to delete session from persistence
    case deleteFailed(Error)

    /// Multiple active sessions found (should only be one)
    case multipleActiveSessions

    /// Invalid session data (e.g., missing required fields)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Session with ID \(id.uuidString) not found"
        case .saveFailed(let error):
            return "Failed to save session: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update session: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch session: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete session: \(error.localizedDescription)"
        case .multipleActiveSessions:
            return "Multiple active sessions found. Only one session can be active at a time."
        case .invalidData(let message):
            return "Invalid session data: \(message)"
        }
    }
}

// MARK: - Mock Implementation (for Testing)

#if DEBUG
    /// Mock implementation of SessionRepositoryProtocol for testing
    ///
    /// Stores sessions in memory, useful for unit testing Use Cases without database
    final class MockSessionRepository: SessionRepositoryProtocol {

        /// In-memory storage
        private var sessions: [UUID: DomainWorkoutSession] = [:]

        /// Flag to simulate errors (for testing error handling)
        var shouldThrowError: Bool = false

        /// Error to throw when shouldThrowError is true
        var errorToThrow: RepositoryError = .fetchFailed(NSError(domain: "Mock", code: -1))

        func save(_ session: DomainWorkoutSession) async throws {
            if shouldThrowError { throw errorToThrow }
            sessions[session.id] = session
        }

        func update(_ session: DomainWorkoutSession) async throws {
            if shouldThrowError { throw errorToThrow }
            guard sessions[session.id] != nil else {
                throw RepositoryError.sessionNotFound(session.id)
            }
            sessions[session.id] = session
        }

        func fetch(id: UUID) async throws -> DomainWorkoutSession? {
            if shouldThrowError { throw errorToThrow }
            return sessions[id]
        }

        func fetchActiveSession() async throws -> DomainWorkoutSession? {
            if shouldThrowError { throw errorToThrow }
            let activeSessions = sessions.values.filter { $0.state == .active }

            if activeSessions.count > 1 {
                throw RepositoryError.multipleActiveSessions
            }

            return activeSessions.first
        }

        func fetchSessions(for workoutId: UUID) async throws -> [DomainWorkoutSession] {
            if shouldThrowError { throw errorToThrow }
            return sessions.values
                .filter { $0.workoutId == workoutId }
                .sorted { $0.startDate > $1.startDate }
        }

        func fetchRecentSessions(limit: Int) async throws -> [DomainWorkoutSession] {
            if shouldThrowError { throw errorToThrow }
            return sessions.values
                .sorted { $0.startDate > $1.startDate }
                .prefix(limit)
                .map { $0 }
        }

        func delete(id: UUID) async throws {
            if shouldThrowError { throw errorToThrow }
            sessions.removeValue(forKey: id)
        }

        func deleteAll() async throws {
            if shouldThrowError { throw errorToThrow }
            sessions.removeAll()
        }

        /// Reset the mock repository (useful between tests)
        func reset() {
            sessions.removeAll()
            shouldThrowError = false
        }
    }
#endif
