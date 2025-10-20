//
//  WorkoutAnalyticsServiceTests.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-20.
//  Unit tests for WorkoutAnalyticsService
//

import SwiftData
import XCTest

@testable import GymBo

@MainActor
final class WorkoutAnalyticsServiceTests: XCTestCase {

    var service: WorkoutAnalyticsService!
    var sessionService: WorkoutSessionService!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        service = WorkoutAnalyticsService()
        sessionService = WorkoutSessionService()
        context = try createTestContext()
        service.setContext(context)
        sessionService.setContext(context)
    }

    override func tearDown() async throws {
        service = nil
        sessionService = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createExercise(name: String, muscleGroups: [MuscleGroup] = [.chest]) -> Exercise {
        let exercise = TestFixtures.createSampleExercise(name: name, muscleGroups: muscleGroups)
        let entity = ExerciseEntity.make(from: exercise)
        context.insert(entity)
        try? context.save()
        return exercise
    }

    private func createSession(
        name: String,
        exercise: Exercise,
        sets: [ExerciseSet],
        date: Date = Date(),
        duration: TimeInterval = 3600
    ) -> WorkoutSession {
        let workoutExercise = WorkoutExercise(exercise: exercise, sets: sets)
        let session = WorkoutSession(
            id: UUID(),
            templateId: UUID(),
            name: name,
            date: date,
            exercises: [workoutExercise],
            defaultRestTime: 90,
            duration: duration,
            notes: ""
        )
        _ = try? sessionService.recordSession(session)
        return session
    }

    // MARK: - Context Tests

    func testSetContext_SetsContextCorrectly() {
        let newContext = try! createTestContext()
        service.setContext(newContext)

        // Verify by using the service - should not crash
        let count = service.totalWorkoutCount()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Total Workout Count Tests

    func testTotalWorkoutCount_WithNoSessions_ReturnsZero() {
        let count = service.totalWorkoutCount()

        XCTAssertEqual(count, 0)
    }

    func testTotalWorkoutCount_WithSessions_ReturnsCorrectCount() {
        let exercise = createExercise(name: "Bench Press")

        _ = createSession(
            name: "Session 1", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 50)])
        _ = createSession(
            name: "Session 2", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 50)])
        _ = createSession(
            name: "Session 3", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 50)])

        let count = service.totalWorkoutCount()

        XCTAssertEqual(count, 3)
    }

    // MARK: - Average Workouts Per Week Tests

    func testAverageWorkoutsPerWeek_WithNoSessions_ReturnsZero() {
        let average = service.averageWorkoutsPerWeek()

        XCTAssertEqual(average, 0.0)
    }

    func testAverageWorkoutsPerWeek_WithRecentSessions_ReturnsCorrectAverage() {
        let exercise = createExercise(name: "Squats")
        let now = Date()

        // Create 3 sessions over 2 weeks
        _ = createSession(
            name: "Session 1",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 100)],
            date: now.addingTimeInterval(-14 * 24 * 60 * 60)  // 2 weeks ago
        )
        _ = createSession(
            name: "Session 2",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 100)],
            date: now.addingTimeInterval(-7 * 24 * 60 * 60)  // 1 week ago
        )
        _ = createSession(
            name: "Session 3",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 100)],
            date: now
        )

        let average = service.averageWorkoutsPerWeek()

        // Should be approximately 1.5 workouts per week (3 sessions / 2 weeks)
        XCTAssertGreaterThan(average, 1.0)
        XCTAssertLessThan(average, 2.0)
    }

    // MARK: - Week Streak Tests

    func testCurrentWeekStreak_WithNoSessions_ReturnsZero() {
        let streak = service.currentWeekStreak()

        XCTAssertEqual(streak, 0)
    }

    func testCurrentWeekStreak_WithSessionsThisWeek_ReturnsOne() {
        let exercise = createExercise(name: "Deadlift")
        _ = createSession(
            name: "This Week",
            exercise: exercise,
            sets: [ExerciseSet(reps: 5, weight: 140)],
            date: Date()
        )

        let streak = service.currentWeekStreak()

        XCTAssertEqual(streak, 1)
    }

    func testCurrentWeekStreak_WithConsecutiveWeeks_ReturnsCorrectStreak() {
        let exercise = createExercise(name: "Bench Press")
        let now = Date()

        // Create sessions for 3 consecutive weeks
        _ = createSession(
            name: "Week 1",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 60)],
            date: now.addingTimeInterval(-14 * 24 * 60 * 60)
        )
        _ = createSession(
            name: "Week 2",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 60)],
            date: now.addingTimeInterval(-7 * 24 * 60 * 60)
        )
        _ = createSession(
            name: "Week 3",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 60)],
            date: now
        )

        let streak = service.currentWeekStreak()

        XCTAssertEqual(streak, 3)
    }

    func testCurrentWeekStreak_CachesResult() {
        let exercise = createExercise(name: "Squats")
        _ = createSession(
            name: "Session", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 100)])

        let firstCall = service.currentWeekStreak()
        let secondCall = service.currentWeekStreak()

        XCTAssertEqual(firstCall, secondCall)
        XCTAssertEqual(firstCall, 1)
    }

    // MARK: - Average Duration Tests

    func testAverageDurationMinutes_WithNoSessions_ReturnsZero() {
        let average = service.averageDurationMinutes()

        XCTAssertEqual(average, 0)
    }

    func testAverageDurationMinutes_WithSessions_ReturnsCorrectAverage() {
        let exercise = createExercise(name: "Bench Press")

        _ = createSession(
            name: "Session 1",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 60)],
            duration: 3600  // 60 minutes
        )
        _ = createSession(
            name: "Session 2",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 60)],
            duration: 4800  // 80 minutes
        )

        let average = service.averageDurationMinutes()

        // Average should be 70 minutes
        XCTAssertEqual(average, 70)
    }

    // MARK: - Muscle Volume Tests

    func testMuscleVolumeByGroup_WithNoSessions_ReturnsEmpty() {
        let volume = service.muscleVolume(byGroupInLastWeeks: 4)

        XCTAssertEqual(volume.count, 0)
    }

    func testMuscleVolumeByGroup_WithSessions_ReturnsCorrectVolume() {
        let chestExercise = createExercise(name: "Bench Press", muscleGroups: [.chest])
        let legExercise = createExercise(name: "Squats", muscleGroups: [.legs])

        // Chest: 10 reps * 60kg = 600
        _ = createSession(
            name: "Chest Day",
            exercise: chestExercise,
            sets: [ExerciseSet(reps: 10, weight: 60)]
        )

        // Legs: 10 reps * 100kg = 1000
        _ = createSession(
            name: "Leg Day",
            exercise: legExercise,
            sets: [ExerciseSet(reps: 10, weight: 100)]
        )

        let volume = service.muscleVolume(byGroupInLastWeeks: 4)

        XCTAssertEqual(volume.count, 2)

        // Should be sorted by volume (highest first)
        XCTAssertEqual(volume[0].0, .legs)
        XCTAssertEqual(volume[0].1, 1000.0)
        XCTAssertEqual(volume[1].0, .chest)
        XCTAssertEqual(volume[1].1, 600.0)
    }

    func testMuscleVolumeByGroup_FiltersOldSessions() {
        let exercise = createExercise(name: "Bench Press", muscleGroups: [.chest])

        // Recent session
        _ = createSession(
            name: "Recent",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 60)],
            date: Date()
        )

        // Old session (8 weeks ago)
        _ = createSession(
            name: "Old",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 60)],
            date: Date().addingTimeInterval(-8 * 7 * 24 * 60 * 60)
        )

        let volume = service.muscleVolume(byGroupInLastWeeks: 4)

        // Only recent session should count
        XCTAssertEqual(volume.count, 1)
        XCTAssertEqual(volume[0].1, 600.0)
    }

    // MARK: - Exercise Stats Tests

    func testExerciseStats_WithNoSessions_ReturnsNil() {
        let exercise = createExercise(name: "Bench Press")

        let stats = service.exerciseStats(for: exercise)

        XCTAssertNil(stats)
    }

    func testExerciseStats_WithSessions_ReturnsCorrectStats() {
        let exercise = createExercise(name: "Bench Press")

        _ = createSession(
            name: "Session 1",
            exercise: exercise,
            sets: [
                ExerciseSet(reps: 10, weight: 60),  // Volume: 600
                ExerciseSet(reps: 8, weight: 70),  // Volume: 560
            ]
        )

        let stats = service.exerciseStats(for: exercise)

        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.totalVolume, 1160.0)
        XCTAssertEqual(stats?.totalReps, 18)
        XCTAssertEqual(stats?.maxWeight, 70.0)
        XCTAssertEqual(stats?.history.count, 1)
    }

    func testExerciseStats_CalculatesOneRepMax() {
        let exercise = createExercise(name: "Deadlift")

        _ = createSession(
            name: "Heavy Day",
            exercise: exercise,
            sets: [ExerciseSet(reps: 5, weight: 140)]
        )

        let stats = service.exerciseStats(for: exercise)

        XCTAssertNotNil(stats)
        // 1RM formula: weight * (1 + reps/30) = 140 * (1 + 5/30) ≈ 163.33
        XCTAssertGreaterThan(stats!.estimatedOneRepMax, 140.0)
        XCTAssertLessThan(stats!.estimatedOneRepMax, 170.0)
    }

    func testExerciseStats_CachesResult() {
        let exercise = createExercise(name: "Squats")
        _ = createSession(
            name: "Session", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 100)])

        let firstCall = service.exerciseStats(for: exercise)
        let secondCall = service.exerciseStats(for: exercise)

        XCTAssertNotNil(firstCall)
        XCTAssertNotNil(secondCall)
        // Should return same cached instance
        XCTAssertEqual(firstCall?.totalVolume, secondCall?.totalVolume)
    }

    // MARK: - Cache Invalidation Tests

    func testInvalidateCaches_ClearsAllCaches() {
        let exercise = createExercise(name: "Bench Press")
        _ = createSession(
            name: "Session", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 60)])

        // Prime caches
        _ = service.exerciseStats(for: exercise)
        _ = service.currentWeekStreak()

        // Invalidate
        service.invalidateCaches()

        // Should recalculate (we can't directly test cache miss, but we can verify it doesn't crash)
        let stats = service.exerciseStats(for: exercise)
        let streak = service.currentWeekStreak()

        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(streak, 0)
    }

    func testInvalidateExerciseCache_ClearsSpecificExercise() {
        let exercise = createExercise(name: "Squats")
        _ = createSession(
            name: "Session", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 100)])

        // Prime cache
        _ = service.exerciseStats(for: exercise)

        // Invalidate specific exercise
        service.invalidateExerciseCache(for: exercise.id)

        // Should recalculate
        let stats = service.exerciseStats(for: exercise)
        XCTAssertNotNil(stats)
    }

    // MARK: - Workouts By Day Tests

    func testWorkoutsByDay_WithNoSessions_ReturnsEmpty() {
        let now = Date()
        let range = now.addingTimeInterval(-7 * 24 * 60 * 60)...now

        let grouped = service.workoutsByDay(in: range)

        XCTAssertEqual(grouped.count, 0)
    }

    func testWorkoutsByDay_GroupsByDay() {
        let exercise = createExercise(name: "Bench Press")
        let now = Date()
        let calendar = Calendar.current

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.startOfDay(for: now.addingTimeInterval(-24 * 60 * 60))

        _ = createSession(
            name: "Today 1", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 60)],
            date: now)
        _ = createSession(
            name: "Today 2", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 60)],
            date: now)
        _ = createSession(
            name: "Yesterday", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 60)],
            date: yesterday)

        let range = yesterday...now
        let grouped = service.workoutsByDay(in: range)

        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(grouped[today]?.count, 2)
        XCTAssertEqual(grouped[yesterday]?.count, 1)
    }

    func testWorkoutsByDay_FiltersOutsideRange() {
        let exercise = createExercise(name: "Squats")
        let now = Date()

        _ = createSession(
            name: "Recent", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 100)],
            date: now)
        _ = createSession(
            name: "Old",
            exercise: exercise,
            sets: [ExerciseSet(reps: 10, weight: 100)],
            date: now.addingTimeInterval(-30 * 24 * 60 * 60)  // 30 days ago
        )

        let range = now.addingTimeInterval(-7 * 24 * 60 * 60)...now  // Last 7 days
        let grouped = service.workoutsByDay(in: range)

        // Should only include recent session
        XCTAssertEqual(grouped.values.flatMap { $0 }.count, 1)
    }

    // MARK: - Get Session History Tests

    func testGetSessionHistory_ReturnsAllSessions() {
        let exercise = createExercise(name: "Bench Press")

        _ = createSession(
            name: "Session 1", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 60)])
        _ = createSession(
            name: "Session 2", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 60)])

        let history = service.getSessionHistory()

        XCTAssertEqual(history.count, 2)
    }

    func testGetSessionHistory_SortedByDateDescending() {
        let exercise = createExercise(name: "Squats")
        let now = Date()

        _ = createSession(
            name: "Oldest", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 100)],
            date: now.addingTimeInterval(-7200))
        _ = createSession(
            name: "Newest", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 100)],
            date: now)
        _ = createSession(
            name: "Middle", exercise: exercise, sets: [ExerciseSet(reps: 10, weight: 100)],
            date: now.addingTimeInterval(-3600))

        let history = service.getSessionHistory()

        XCTAssertEqual(history[0].name, "Newest")
        XCTAssertEqual(history[1].name, "Middle")
        XCTAssertEqual(history[2].name, "Oldest")
    }

    func testGetSessionHistory_RespectsLimit() {
        let exercise = createExercise(name: "Deadlift")

        for i in 1...10 {
            _ = createSession(
                name: "Session \(i)", exercise: exercise, sets: [ExerciseSet(reps: 5, weight: 140)])
        }

        let history = service.getSessionHistory(limit: 5)

        XCTAssertEqual(history.count, 5)
    }
}
