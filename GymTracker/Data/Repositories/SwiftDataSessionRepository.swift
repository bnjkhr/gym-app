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
/// - Persist DomainWorkoutSession to SwiftData
/// - Fetch DomainWorkoutSession from SwiftData
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

    func save(_ session: DomainWorkoutSession) async throws {
        do {
            let entity = mapper.toEntity(session)
            modelContext.insert(entity)
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(error)
        }
    }

    func update(_ session: DomainWorkoutSession) async throws {
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

    func fetch(id: UUID) async throws -> DomainWorkoutSession? {
        do {
            guard let entity = try await fetchEntity(id: id) else {
                return nil
            }
            return mapper.toDomain(entity)
        } catch {
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchActiveSession() async throws -> DomainWorkoutSession? {
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

    func fetchSessions(for workoutId: UUID) async throws -> [DomainWorkoutSession] {
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

    func fetchRecentSessions(limit: Int) async throws -> [DomainWorkoutSession] {
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

// MARK: - Tests
// TODO: Move inline tests to separate Test target file
// Tests were removed from production code to avoid XCTest import issues
// See: GymTrackerTests/Data/SwiftDataSessionRepositoryTests.swift (to be created)
