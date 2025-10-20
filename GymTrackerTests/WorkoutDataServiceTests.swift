//
//  WorkoutDataServiceTests.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-19.
//  Unit tests for WorkoutDataService
//

import SwiftData
import XCTest

@testable import GymBo

@MainActor
final class WorkoutDataServiceTests: XCTestCase {

    var service: WorkoutDataService!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        service = WorkoutDataService()
        context = try createTestContext()
        service.setContext(context)
    }

    override func tearDown() async throws {
        service = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    /// Helper to create a workout and ensure its exercises exist in the database
    private func createWorkoutWithExercises(name: String, exercises: [WorkoutExercise]? = nil)
        -> Workout
    {
        let workout: Workout
        if let exercises = exercises {
            // Use provided exercises
            workout = TestFixtures.createSampleWorkout(name: name, exercises: exercises)
            // Ensure all exercises exist in the database
            for workoutExercise in workout.exercises {
                service.addExercise(workoutExercise.exercise)
            }
        } else {
            // Create a simple workout with just one exercise to speed up tests
            let exercise = TestFixtures.createSampleExercise(name: "\(name) Exercise")
            service.addExercise(exercise)

            let workoutExercise = WorkoutExercise(
                exercise: exercise,
                sets: [ExerciseSet(reps: 10, weight: 50)]
            )
            workout = Workout(
                id: UUID(),
                name: name,
                exercises: [workoutExercise]
            )
        }
        return workout
    }

    // MARK: - Context Tests

    func testSetContext_SetsContextCorrectly() {
        let newContext = try! createTestContext()
        service.setContext(newContext)

        // Verify by trying to fetch - should not crash
        let workouts = service.allWorkouts()
        XCTAssertNotNil(workouts)
    }

    func testOperationsWithNilContext_ReturnsEmptyOrNil() {
        service.setContext(nil)

        XCTAssertNil(service.activeWorkout(with: UUID()))
        XCTAssertEqual(service.allWorkouts().count, 0)
        XCTAssertEqual(service.homeWorkouts().count, 0)
        XCTAssertEqual(service.exercises().count, 0)
    }

    // MARK: - Exercise Tests

    func testExercise_Named_CreatesNewExercise() {
        let exerciseName = "New Exercise"
        let exercise = service.exercise(named: exerciseName)

        XCTAssertEqual(exercise.name, exerciseName)

        // Verify it was saved
        let allExercises = service.exercises()
        XCTAssertTrue(allExercises.contains(where: { $0.name == exerciseName }))
    }

    func testExercise_Named_ReturnsExistingExercise() {
        // Create exercise first
        let exerciseName = "Bench Press"
        let firstCall = service.exercise(named: exerciseName)
        let firstID = firstCall.id

        // Call again with same name
        let secondCall = service.exercise(named: exerciseName)

        // Should return the same exercise
        XCTAssertEqual(firstID, secondCall.id)

        // Should not create duplicate
        let allExercises = service.exercises()
        let matchingExercises = allExercises.filter {
            $0.name.lowercased() == exerciseName.lowercased()
        }
        XCTAssertEqual(matchingExercises.count, 1)
    }

    func testExercise_Named_CaseInsensitive() {
        _ = service.exercise(named: "BENCH PRESS")
        _ = service.exercise(named: "bench press")

        // Should return the same exercise
        let allExercises = service.exercises()
        let matching = allExercises.filter { $0.name.lowercased() == "bench press" }
        XCTAssertEqual(matching.count, 1)
    }

    func testExercises_ReturnsAllExercises() {
        // Create multiple exercises
        _ = service.exercise(named: "Exercise 1")
        _ = service.exercise(named: "Exercise 2")
        _ = service.exercise(named: "Exercise 3")

        let exercises = service.exercises()
        XCTAssertEqual(exercises.count, 3)
    }

    func testExercises_ReturnsSortedByName() {
        // Create in random order
        _ = service.exercise(named: "Zebra Exercise")
        _ = service.exercise(named: "Alpha Exercise")
        _ = service.exercise(named: "Beta Exercise")

        let exercises = service.exercises()
        XCTAssertEqual(exercises[0].name, "Alpha Exercise")
        XCTAssertEqual(exercises[1].name, "Beta Exercise")
        XCTAssertEqual(exercises[2].name, "Zebra Exercise")
    }

    func testAddExercise_AddsNewExercise() {
        let exercise = TestFixtures.createSampleExercise(name: "New Exercise")
        service.addExercise(exercise)

        let exercises = service.exercises()
        XCTAssertTrue(exercises.contains(where: { $0.id == exercise.id }))
    }

    func testAddExercise_PreventsDuplicateByID() {
        let exercise = TestFixtures.createSampleExercise(name: "Test Exercise")
        service.addExercise(exercise)
        service.addExercise(exercise)  // Try to add again

        let exercises = service.exercises()
        let matching = exercises.filter { $0.id == exercise.id }
        XCTAssertEqual(matching.count, 1, "Should not create duplicate exercise")
    }

    func testAddExercise_PreventsDuplicateByName() {
        let exercise1 = TestFixtures.createSampleExercise(name: "Bench Press")
        let exercise2 = TestFixtures.createSampleExercise(name: "Bench Press")  // Different ID, same name

        service.addExercise(exercise1)
        service.addExercise(exercise2)

        let exercises = service.exercises()
        let matching = exercises.filter { $0.name.lowercased() == "bench press" }
        XCTAssertEqual(matching.count, 1, "Should not create duplicate by name")
    }

    func testUpdateExercise_UpdatesExistingExercise() {
        // Create exercise
        var exercise = TestFixtures.createSampleExercise(name: "Original Name")
        service.addExercise(exercise)

        // Update it
        exercise = Exercise(
            id: exercise.id,
            name: "Updated Name",
            muscleGroups: [.back, .biceps],
            equipmentType: .machine,
            difficultyLevel: .profi,
            description: "Updated description",
            instructions: ["New step 1", "New step 2"],
            createdAt: exercise.createdAt
        )
        service.updateExercise(exercise)

        // Verify update
        let exercises = service.exercises()
        let updated = exercises.first(where: { $0.id == exercise.id })

        XCTAssertEqual(updated?.name, "Updated Name")
        XCTAssertEqual(updated?.muscleGroups, [.back, .biceps])
        XCTAssertEqual(updated?.equipmentType, .machine)
        XCTAssertEqual(updated?.difficultyLevel, .profi)
    }

    func testDeleteExercises_RemovesExercises() {
        // Create exercises
        _ = service.exercise(named: "Exercise 1")
        _ = service.exercise(named: "Exercise 2")
        _ = service.exercise(named: "Exercise 3")

        XCTAssertEqual(service.exercises().count, 3)

        // Delete second exercise (index 1)
        let deletedIDs = service.deleteExercises(at: IndexSet(integer: 1))

        XCTAssertEqual(deletedIDs.count, 1)
        XCTAssertEqual(service.exercises().count, 2)
    }

    func testDeleteExercises_MultipleIndices() {
        // Create exercises
        _ = service.exercise(named: "Exercise 1")
        _ = service.exercise(named: "Exercise 2")
        _ = service.exercise(named: "Exercise 3")
        _ = service.exercise(named: "Exercise 4")

        // Delete indices 1 and 2
        let deletedIDs = service.deleteExercises(at: IndexSet([1, 2]))

        XCTAssertEqual(deletedIDs.count, 2)
        XCTAssertEqual(service.exercises().count, 2)
    }

    // MARK: - Workout Tests

    func testAddWorkout_CreatesNewWorkout() {
        // First, ensure the exercises exist in the database
        let workout = createWorkoutWithExercises(name: "Test Workout")
        for workoutExercise in workout.exercises {
            service.addExercise(workoutExercise.exercise)
        }

        service.addWorkout(workout)

        let workouts = service.allWorkouts()
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.name, "Test Workout")
    }

    func testAllWorkouts_ReturnsAllWorkouts() {
        // Create multiple workouts
        service.addWorkout(createWorkoutWithExercises(name: "Workout 1"))
        service.addWorkout(createWorkoutWithExercises(name: "Workout 2"))
        service.addWorkout(createWorkoutWithExercises(name: "Workout 3"))

        let workouts = service.allWorkouts()
        XCTAssertEqual(workouts.count, 3)
    }

    func testAllWorkouts_SortedByDateDescending() {
        // Create workouts with different dates
        let now = Date()
        var workout1 = createWorkoutWithExercises(name: "Oldest")
        workout1 = Workout(
            id: workout1.id,
            name: workout1.name,
            date: now.addingTimeInterval(-7200),  // 2 hours ago
            exercises: workout1.exercises
        )

        var workout2 = createWorkoutWithExercises(name: "Newest")
        workout2 = Workout(
            id: workout2.id,
            name: workout2.name,
            date: now,
            exercises: workout2.exercises
        )

        var workout3 = createWorkoutWithExercises(name: "Middle")
        workout3 = Workout(
            id: workout3.id,
            name: workout3.name,
            date: now.addingTimeInterval(-3600),  // 1 hour ago
            exercises: workout3.exercises
        )

        service.addWorkout(workout1)
        service.addWorkout(workout2)
        service.addWorkout(workout3)

        let workouts = service.allWorkouts()

        // Should be sorted newest first
        XCTAssertEqual(workouts[0].name, "Newest")
        XCTAssertEqual(workouts[1].name, "Middle")
        XCTAssertEqual(workouts[2].name, "Oldest")
    }

    func testAllWorkouts_RespectsLimit() {
        // Create 10 workouts
        for i in 1...10 {
            service.addWorkout(createWorkoutWithExercises(name: "Workout \(i)"))
        }

        let limitedWorkouts = service.allWorkouts(limit: 5)
        XCTAssertEqual(limitedWorkouts.count, 5)
    }

    func testActiveWorkout_ReturnsCorrectWorkout() {
        let workout = createWorkoutWithExercises(name: "Active Workout")
        service.addWorkout(workout)

        let retrieved = service.activeWorkout(with: workout.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, workout.id)
        XCTAssertEqual(retrieved?.name, "Active Workout")
    }

    func testActiveWorkout_ReturnsNilForInvalidID() {
        let retrieved = service.activeWorkout(with: UUID())
        XCTAssertNil(retrieved)
    }

    func testActiveWorkout_ReturnsNilForNilID() {
        let retrieved = service.activeWorkout(with: nil)
        XCTAssertNil(retrieved)
    }

    func testUpdateWorkout_UpdatesExistingWorkout() {
        var workout = createWorkoutWithExercises(name: "Original Workout")
        service.addWorkout(workout)

        // Update workout
        workout = Workout(
            id: workout.id,
            name: "Updated Workout",
            date: workout.date,
            exercises: workout.exercises,
            defaultRestTime: 120,
            notes: "Updated notes"
        )
        service.updateWorkout(workout)

        // Verify update
        let retrieved = service.activeWorkout(with: workout.id)
        XCTAssertEqual(retrieved?.name, "Updated Workout")
        XCTAssertEqual(retrieved?.defaultRestTime, 120)
        XCTAssertEqual(retrieved?.notes, "Updated notes")
    }

    func testDeleteWorkouts_RemovesWorkout() {
        service.addWorkout(createWorkoutWithExercises(name: "Workout 1"))
        service.addWorkout(createWorkoutWithExercises(name: "Workout 2"))
        service.addWorkout(createWorkoutWithExercises(name: "Workout 3"))

        XCTAssertEqual(service.allWorkouts().count, 3)

        // Delete middle workout
        service.deleteWorkouts(at: IndexSet(integer: 1))

        XCTAssertEqual(service.allWorkouts().count, 2)
    }

    // MARK: - Favorite Tests

    func testToggleFavorite_MarksWorkoutAsFavorite() {
        let workout = createWorkoutWithExercises(name: "Test Workout")
        service.addWorkout(workout)

        // Toggle favorite on
        service.toggleFavorite(for: workout.id)

        let retrieved = service.activeWorkout(with: workout.id)
        XCTAssertTrue(retrieved?.isFavorite ?? false)
    }

    func testToggleFavorite_UnmarksWorkoutAsFavorite() {
        var workout = createWorkoutWithExercises(name: "Test Workout")
        workout = Workout(
            id: workout.id,
            name: workout.name,
            date: workout.date,
            exercises: workout.exercises,
            defaultRestTime: workout.defaultRestTime,
            duration: workout.duration,
            notes: workout.notes,
            isFavorite: true
        )
        service.addWorkout(workout)

        // Toggle favorite off
        service.toggleFavorite(for: workout.id)

        let retrieved = service.activeWorkout(with: workout.id)
        XCTAssertFalse(retrieved?.isFavorite ?? true)
    }

    func testHomeWorkouts_ReturnsOnlyFavorites() {
        var workout1 = createWorkoutWithExercises(name: "Favorite 1")
        workout1 = Workout(
            id: workout1.id,
            name: workout1.name,
            date: workout1.date,
            exercises: workout1.exercises,
            isFavorite: true
        )

        let workout2 = createWorkoutWithExercises(name: "Not Favorite")

        var workout3 = createWorkoutWithExercises(name: "Favorite 2")
        workout3 = Workout(
            id: workout3.id,
            name: workout3.name,
            date: workout3.date,
            exercises: workout3.exercises,
            isFavorite: true
        )

        service.addWorkout(workout1)
        service.addWorkout(workout2)
        service.addWorkout(workout3)

        let homeWorkouts = service.homeWorkouts()

        XCTAssertEqual(homeWorkouts.count, 2)
        XCTAssertTrue(homeWorkouts.allSatisfy { $0.isFavorite })
    }

    func testHomeWorkouts_SortedByName() {
        var workoutZ = createWorkoutWithExercises(name: "Zebra Workout")
        workoutZ = Workout(
            id: workoutZ.id,
            name: workoutZ.name,
            date: workoutZ.date,
            exercises: workoutZ.exercises,
            isFavorite: true
        )

        var workoutA = createWorkoutWithExercises(name: "Alpha Workout")
        workoutA = Workout(
            id: workoutA.id,
            name: workoutA.name,
            date: workoutA.date,
            exercises: workoutA.exercises,
            isFavorite: true
        )

        service.addWorkout(workoutZ)
        service.addWorkout(workoutA)

        let homeWorkouts = service.homeWorkouts()

        XCTAssertEqual(homeWorkouts[0].name, "Alpha Workout")
        XCTAssertEqual(homeWorkouts[1].name, "Zebra Workout")
    }

    func testHomeWorkouts_RespectsLimit() {
        // Create 10 favorite workouts
        for i in 1...10 {
            var workout = createWorkoutWithExercises(name: "Workout \(i)")
            workout = Workout(
                id: workout.id,
                name: workout.name,
                date: workout.date,
                exercises: workout.exercises,
                isFavorite: true
            )
            service.addWorkout(workout)
        }

        let limitedHomeWorkouts = service.homeWorkouts(limit: 5)
        XCTAssertEqual(limitedHomeWorkouts.count, 5)
    }

    func testToggleHomeFavorite_AddsToHomeFavorites() {
        let workout = createWorkoutWithExercises(name: "Test Workout")
        service.addWorkout(workout)

        let success = service.toggleHomeFavorite(workoutID: workout.id, limit: 4)

        XCTAssertTrue(success)

        let homeWorkouts = service.homeWorkouts()
        XCTAssertEqual(homeWorkouts.count, 1)
        XCTAssertTrue(homeWorkouts.first?.isFavorite ?? false)
    }

    func testToggleHomeFavorite_RemovesFromHomeFavorites() {
        var workout = createWorkoutWithExercises(name: "Test Workout")
        workout = Workout(
            id: workout.id,
            name: workout.name,
            date: workout.date,
            exercises: workout.exercises,
            isFavorite: true
        )
        service.addWorkout(workout)

        let success = service.toggleHomeFavorite(workoutID: workout.id, limit: 4)

        XCTAssertTrue(success)

        let homeWorkouts = service.homeWorkouts()
        XCTAssertEqual(homeWorkouts.count, 0)
    }

    func testToggleHomeFavorite_RespectsLimit() {
        // Create 4 favorite workouts (at limit)
        for i in 1...4 {
            var workout = createWorkoutWithExercises(name: "Workout \(i)")
            workout = Workout(
                id: workout.id,
                name: workout.name,
                date: workout.date,
                exercises: workout.exercises,
                isFavorite: true
            )
            service.addWorkout(workout)
        }

        // Try to add a 5th favorite
        let newWorkout = createWorkoutWithExercises(name: "Workout 5")
        service.addWorkout(newWorkout)

        let success = service.toggleHomeFavorite(workoutID: newWorkout.id, limit: 4)

        XCTAssertFalse(success, "Should not allow exceeding limit")

        let homeWorkouts = service.homeWorkouts()
        XCTAssertEqual(homeWorkouts.count, 4, "Should still have 4 favorites")
    }

    // MARK: - Edge Cases

    func testEmptyDatabase_ReturnsEmptyCollections() {
        XCTAssertEqual(service.allWorkouts().count, 0)
        XCTAssertEqual(service.homeWorkouts().count, 0)
        XCTAssertEqual(service.exercises().count, 0)
    }

    func testWorkoutWithExercises_PreservesExerciseData() {
        let exercise1 = TestFixtures.createSampleExercise(
            name: "Bench Press", muscleGroups: [.chest])
        let exercise2 = TestFixtures.createSampleExercise(name: "Squats", muscleGroups: [.legs])

        let workoutExercises = [
            WorkoutExercise(
                exercise: exercise1,
                sets: [
                    ExerciseSet(reps: 10, weight: 60),
                    ExerciseSet(reps: 8, weight: 70),
                ]
            ),
            WorkoutExercise(
                exercise: exercise2,
                sets: [
                    ExerciseSet(reps: 12, weight: 100)
                ]
            ),
        ]

        let workout = createWorkoutWithExercises(
            name: "Complex Workout", exercises: workoutExercises)
        service.addWorkout(workout)

        let retrieved = service.activeWorkout(with: workout.id)

        XCTAssertEqual(retrieved?.exercises.count, 2)
        XCTAssertEqual(retrieved?.exercises[0].exercise.name, "Bench Press")
        XCTAssertEqual(retrieved?.exercises[0].sets.count, 2)
        XCTAssertEqual(retrieved?.exercises[1].exercise.name, "Squats")
        XCTAssertEqual(retrieved?.exercises[1].sets.count, 1)
    }
}
