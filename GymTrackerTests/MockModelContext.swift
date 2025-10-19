//
//  MockModelContext.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-19.
//  Mock ModelContext for testing SwiftData operations
//

import XCTest
import Foundation
import SwiftData
@testable import GymBo

/// Helper to create an in-memory ModelContext for testing
@MainActor
class ModelContextFactory {

    /// Creates an in-memory ModelContext for testing
    /// - Returns: A ModelContext that won't persist data to disk
    static func createInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            ExerciseEntity.self,
            WorkoutEntity.self,
            WorkoutSessionEntity.self,
            UserProfileEntity.self,
            ExerciseSetEntity.self,
            WorkoutExerciseEntity.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        return ModelContext(container)
    }
}

/// Extension to make test setup easier
extension XCTestCase {

    /// Create a fresh in-memory ModelContext for each test
    @MainActor
    func createTestContext() throws -> ModelContext {
        try ModelContextFactory.createInMemoryContext()
    }
}
