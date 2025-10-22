//
//  SwiftDataSessionRepository.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Data Layer
//

import Foundation
import SwiftData

/// SwiftData implementation of SessionRepositoryProtocol
///
/// **Responsibility:**
/// - Persist WorkoutSession to SwiftData
/// - Fetch WorkoutSession from SwiftData
/// - Convert between Domain and Data entities using SessionMapper
///
/// **Design Decisions:**
/// - Uses SessionMapper for all conversions
/// - Async/await for all operations
/// - Proper error handling with RepositoryError
/// - No business logic - pure data access
///
/// **Usage:**
/// ```swift
/// let repository = SwiftDataSessionRepository(modelContext: context)
/// try await repository.save(session)
/// let session = try await repository.fetch(id: sessionId)
/// ```
final class SwiftDataSessionRepository: SessionRepositoryProtocol {

    // MARK: - Properties

    private let modelContext: ModelContext
    private let mapper: SessionMapper

    // MARK: - Initialization

    init(modelContext: ModelContext, mapper: SessionMapper = SessionMapper()) {
        self.modelContext = modelContext
        self.mapper = mapper
    }

    // MARK: - Create & Update

    func save(_ session: WorkoutSession) async throws {
        do {
            let entity = mapper.toEntity(session)
            modelContext.insert(entity)
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(error)
        }
    }

    func update(_ session: WorkoutSession) async throws {
        do {
            // Fetch existing entity
            guard let entity = try await fetchEntity(id: session.id) else {
                throw RepositoryError.sessionNotFound(session.id)
            }

            // Update entity with new data
            mapper.updateEntity(entity, from: session)

            // Save changes
            try modelContext.save()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.updateFailed(error)
        }
    }

    // MARK: - Read

    func fetch(id: UUID) async throws -> WorkoutSession? {
        do {
            guard let entity = try await fetchEntity(id: id) else {
                return nil
            }
            return mapper.toDomain(entity)
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchActiveSession() async throws -> WorkoutSession? {
        do {
            let descriptor = FetchDescriptor<WorkoutSessionEntity>(
                predicate: #Predicate { $0.state == "active" }
            )

            let entities = try modelContext.fetch(descriptor)

            // Business rule: Only one active session allowed
            if entities.count > 1 {
                throw RepositoryError.multipleActiveSessions
            }

            guard let entity = entities.first else {
                return nil
            }

            return mapper.toDomain(entity)
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchSessions(for workoutId: UUID) async throws -> [WorkoutSession] {
        do {
            let descriptor = FetchDescriptor<WorkoutSessionEntity>(
                predicate: #Predicate { $0.workoutId == workoutId },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )

            let entities = try modelContext.fetch(descriptor)
            return mapper.toDomain(entities)
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchRecentSessions(limit: Int) async throws -> [WorkoutSession] {
        do {
            var descriptor = FetchDescriptor<WorkoutSessionEntity>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            descriptor.fetchLimit = limit

            let entities = try modelContext.fetch(descriptor)
            return mapper.toDomain(entities)
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        do {
            guard let entity = try await fetchEntity(id: id) else {
                throw RepositoryError.sessionNotFound(id)
            }

            modelContext.delete(entity)
            try modelContext.save()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.deleteFailed(error)
        }
    }

    func deleteAll() async throws {
        do {
            let descriptor = FetchDescriptor<WorkoutSessionEntity>()
            let entities = try modelContext.fetch(descriptor)

            for entity in entities {
                modelContext.delete(entity)
            }

            try modelContext.save()
        } catch {
            throw RepositoryError.deleteFailed(error)
        }
    }

    // MARK: - Private Helpers

    private func fetchEntity(id: UUID) async throws -> WorkoutSessionEntity? {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}

// MARK: - Integration Tests

#if DEBUG
    import XCTest

    /// Integration tests for SwiftDataSessionRepository
    ///
    /// Note: These tests use an in-memory ModelContext
    final class SwiftDataSessionRepositoryTests: XCTestCase {

        var modelContext: ModelContext!
        var repository: SwiftDataSessionRepository!

        override func setUp() {
            super.setUp()

            // Create in-memory ModelContext for testing
            let schema = Schema([
                WorkoutSessionEntity.self,
                SessionExerciseEntity.self,
                SessionSetEntity.self,
            ])
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: configuration)

            modelContext = ModelContext(container)
            repository = SwiftDataSessionRepository(modelContext: modelContext)
        }

        override func tearDown() {
            modelContext = nil
            repository = nil
            super.tearDown()
        }

        func testSave_CreatesEntity() async throws {
            // Given
            let session = WorkoutSession(workoutId: UUID())

            // When
            try await repository.save(session)

            // Then
            let fetchedSession = try await repository.fetch(id: session.id)
            XCTAssertNotNil(fetchedSession)
            XCTAssertEqual(fetchedSession?.id, session.id)
        }

        func testFetch_ReturnsNilWhenNotFound() async throws {
            // Given
            let nonExistentId = UUID()

            // When
            let session = try await repository.fetch(id: nonExistentId)

            // Then
            XCTAssertNil(session)
        }

        func testUpdate_UpdatesExistingEntity() async throws {
            // Given
            var session = WorkoutSession(workoutId: UUID(), state: .active)
            try await repository.save(session)

            // When - Update session
            session.endDate = Date()
            session.state = .completed
            try await repository.update(session)

            // Then
            let updatedSession = try await repository.fetch(id: session.id)
            XCTAssertEqual(updatedSession?.state, .completed)
            XCTAssertNotNil(updatedSession?.endDate)
        }

        func testFetchActiveSession_ReturnsActiveSession() async throws {
            // Given
            let activeSession = WorkoutSession(workoutId: UUID(), state: .active)
            let completedSession = WorkoutSession(workoutId: UUID(), state: .completed)
            try await repository.save(activeSession)
            try await repository.save(completedSession)

            // When
            let fetchedActive = try await repository.fetchActiveSession()

            // Then
            XCTAssertNotNil(fetchedActive)
            XCTAssertEqual(fetchedActive?.id, activeSession.id)
        }

        func testFetchActiveSession_ThrowsWhenMultipleActive() async throws {
            // Given
            let session1 = WorkoutSession(workoutId: UUID(), state: .active)
            let session2 = WorkoutSession(workoutId: UUID(), state: .active)
            try await repository.save(session1)
            try await repository.save(session2)

            // When/Then
            do {
                _ = try await repository.fetchActiveSession()
                XCTFail("Expected error to be thrown")
            } catch RepositoryError.multipleActiveSessions {
                // Success - expected error
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testDelete_RemovesEntity() async throws {
            // Given
            let session = WorkoutSession(workoutId: UUID())
            try await repository.save(session)

            // When
            try await repository.delete(id: session.id)

            // Then
            let fetchedSession = try await repository.fetch(id: session.id)
            XCTAssertNil(fetchedSession)
        }

        func testFetchRecentSessions_ReturnsLimitedResults() async throws {
            // Given - Create 5 sessions
            for _ in 0..<5 {
                let session = WorkoutSession(workoutId: UUID())
                try await repository.save(session)
            }

            // When - Fetch only 3
            let sessions = try await repository.fetchRecentSessions(limit: 3)

            // Then
            XCTAssertEqual(sessions.count, 3)
        }

        func testSaveAndFetch_PreservesExercises() async throws {
            // Given - Session with exercises and sets
            let set = SessionSet(weight: 100, reps: 8)
            let exercise = SessionExercise(exerciseId: UUID(), sets: [set])
            let session = WorkoutSession(workoutId: UUID(), exercises: [exercise])

            // When
            try await repository.save(session)
            let fetchedSession = try await repository.fetch(id: session.id)

            // Then
            XCTAssertNotNil(fetchedSession)
            XCTAssertEqual(fetchedSession?.exercises.count, 1)
            XCTAssertEqual(fetchedSession?.exercises[0].sets.count, 1)
            XCTAssertEqual(fetchedSession?.exercises[0].sets[0].weight, 100)
        }
    }
#endif
