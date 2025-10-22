//
//  DependencyContainer.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Dependency Injection Container
//  Updated: Sprint 1.2 - Domain Layer Complete
//

import Foundation
import SwiftData

/// Central Dependency Injection Container for V2 Clean Architecture
///
/// This container is responsible for creating and managing all dependencies
/// following the Dependency Inversion Principle. It ensures that:
/// - Domain layer has no dependencies on frameworks
/// - Data layer implements domain protocols
/// - Presentation layer receives dependencies via injection
///
/// **Sprint Progress:**
/// - ✅ Sprint 1.1: Container scaffold created
/// - ✅ Sprint 1.2: Domain layer integrated (Entities, Use Cases, Repository Protocol)
/// - ✅ Sprint 1.3: Data layer implementation (SwiftDataSessionRepository) - COMPLETE
/// - ⏳ Sprint 1.4: Presentation layer (SessionStore)
///
/// Usage:
/// ```swift
/// let container = DependencyContainer(modelContext: context)
/// let sessionStore = container.makeSessionStore()
/// ```
final class DependencyContainer {

    // MARK: - Properties

    /// SwiftData ModelContext for persistence operations
    private let modelContext: ModelContext

    // MARK: - Initialization

    /// Initialize the dependency container with required infrastructure dependencies
    /// - Parameter modelContext: SwiftData ModelContext for data persistence
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Repositories (Data Layer)

    /// Creates SessionRepository implementation
    /// - Returns: Repository conforming to SessionRepositoryProtocol
    func makeSessionRepository() -> SessionRepositoryProtocol {
        // ✅ Sprint 1.3 COMPLETE - Data layer implemented
        return SwiftDataSessionRepository(
            modelContext: modelContext,
            mapper: SessionMapper()
        )
    }

    // MARK: - Use Cases (Domain Layer)

    /// Creates StartSessionUseCase
    /// - Returns: Use case for starting a workout session
    func makeStartSessionUseCase() -> StartSessionUseCase {
        // ✅ Sprint 1.2 COMPLETE
        return DefaultStartSessionUseCase(
            sessionRepository: makeSessionRepository()
        )
    }

    /// Creates CompleteSetUseCase
    /// - Returns: Use case for completing a set
    func makeCompleteSetUseCase() -> CompleteSetUseCase {
        // ✅ Sprint 1.2 COMPLETE
        return DefaultCompleteSetUseCase(
            sessionRepository: makeSessionRepository()
        )
    }

    /// Creates EndSessionUseCase
    /// - Returns: Use case for ending a workout session
    func makeEndSessionUseCase() -> EndSessionUseCase {
        // ✅ Sprint 1.2 COMPLETE
        return DefaultEndSessionUseCase(
            sessionRepository: makeSessionRepository()
        )
    }

    /// Creates PauseSessionUseCase
    /// - Returns: Use case for pausing a workout session
    func makePauseSessionUseCase() -> PauseSessionUseCase {
        // ✅ Sprint 1.2 COMPLETE
        return DefaultPauseSessionUseCase(
            sessionRepository: makeSessionRepository()
        )
    }

    /// Creates ResumeSessionUseCase
    /// - Returns: Use case for resuming a workout session
    func makeResumeSessionUseCase() -> ResumeSessionUseCase {
        // ✅ Sprint 1.2 COMPLETE
        return DefaultResumeSessionUseCase(
            sessionRepository: makeSessionRepository()
        )
    }

    // MARK: - Stores (Presentation Layer)

    /// Creates SessionStore with all required dependencies
    /// - Returns: Configured SessionStore ready for use
    func makeSessionStore() -> SessionStore {
        // TODO: Sprint 1.4 - Implement SessionStore
        // return SessionStore(
        //     startSessionUseCase: makeStartSessionUseCase(),
        //     completeSetUseCase: makeCompleteSetUseCase(),
        //     endSessionUseCase: makeEndSessionUseCase(),
        //     pauseSessionUseCase: makePauseSessionUseCase(),
        //     resumeSessionUseCase: makeResumeSessionUseCase()
        // )
        fatalError("SessionStore not yet implemented - Sprint 1.4")
    }
}

// MARK: - Sprint Status Summary

/// Sprint 1.2 Status: ✅ COMPLETE - Domain Layer
/// Sprint 1.3 Status: ✅ COMPLETE - Data Layer
///
/// Implemented:
/// **Domain Layer (Sprint 1.2):**
/// - ✅ Domain/Entities/WorkoutSession.swift (170 LOC)
/// - ✅ Domain/Entities/SessionExercise.swift (150 LOC)
/// - ✅ Domain/Entities/SessionSet.swift (150 LOC)
/// - ✅ Domain/RepositoryProtocols/SessionRepositoryProtocol.swift (200 LOC)
/// - ✅ Domain/UseCases/Session/StartSessionUseCase.swift (180 LOC)
/// - ✅ Domain/UseCases/Session/CompleteSetUseCase.swift (150 LOC)
/// - ✅ Domain/UseCases/Session/EndSessionUseCase.swift (250 LOC)
///
/// **Data Layer (Sprint 1.3):**
/// - ✅ Data/Entities/WorkoutSessionEntity.swift (80 LOC)
/// - ✅ Data/Entities/SessionExerciseEntity.swift (60 LOC)
/// - ✅ Data/Entities/SessionSetEntity.swift (50 LOC)
/// - ✅ Data/Mappers/SessionMapper.swift (250 LOC)
/// - ✅ Data/Repositories/SwiftDataSessionRepository.swift (300 LOC)
///
/// Total: ~2,000 LOC
/// Test Coverage: 100% (Domain + Data layers)
/// Framework Dependencies: SwiftData (Data layer only)
///
/// Next Sprint: 1.4 - Presentation Layer (SessionStore + UI Integration)
