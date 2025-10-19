//
//  TestHelpers.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-19.
//  Common test utilities and helper functions
//

import XCTest
import Foundation
import SwiftData
@testable import GymBo

// MARK: - Test Fixtures

enum TestFixtures {

    // MARK: - Exercise Fixtures

    static func createSampleExercise(
        id: UUID = UUID(),
        name: String = "Test Exercise",
        muscleGroups: [MuscleGroup] = [.chest],
        equipmentType: EquipmentType = .freeWeights,
        difficultyLevel: DifficultyLevel = .fortgeschritten
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroups: muscleGroups,
            equipmentType: equipmentType,
            difficultyLevel: difficultyLevel,
            description: "Test description for \(name)",
            instructions: ["Step 1", "Step 2", "Step 3"],
            createdAt: Date()
        )
    }

    static func createSampleExercises(count: Int = 5) -> [Exercise] {
        (0..<count).map { index in
            createSampleExercise(
                name: "Test Exercise \(index + 1)",
                muscleGroups: [MuscleGroup.allCases[index % MuscleGroup.allCases.count]],
                equipmentType: EquipmentType.allCases[index % EquipmentType.allCases.count]
            )
        }
    }

    // MARK: - Workout Fixtures

    static func createSampleWorkout(
        id: UUID = UUID(),
        name: String = "Test Workout",
        exercises: [WorkoutExercise]? = nil
    ) -> Workout {
        let workoutExercises = exercises ?? [
            WorkoutExercise(
                exercise: createSampleExercise(name: "Bench Press", muscleGroups: [.chest]),
                sets: [
                    ExerciseSet(reps: 10, weight: 60),
                    ExerciseSet(reps: 8, weight: 70),
                    ExerciseSet(reps: 6, weight: 80)
                ]
            ),
            WorkoutExercise(
                exercise: createSampleExercise(name: "Squats", muscleGroups: [.legs]),
                sets: [
                    ExerciseSet(reps: 12, weight: 100),
                    ExerciseSet(reps: 10, weight: 110)
                ]
            )
        ]

        return Workout(
            id: id,
            name: name,
            exercises: workoutExercises,
            defaultRestTime: 90,
            notes: "Test workout notes"
        )
    }
}

// MARK: - Assertion Helpers

extension XCTestCase {

    /// Assert that two doubles are approximately equal (within 0.01)
    func XCTAssertApproximatelyEqual(
        _ value1: Double,
        _ value2: Double,
        accuracy: Double = 0.01,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(value1, value2, accuracy: accuracy, message, file: file, line: line)
    }

    /// Assert that an optional is not nil and return unwrapped value
    func XCTAssertNotNilAndUnwrap<T>(
        _ expression: @autoclosure () throws -> T?,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> T {
        let value = try expression()
        XCTAssertNotNil(value, message, file: file, line: line)
        return try XCTUnwrap(value, message, file: file, line: line)
    }
}
