//
//  WorkoutSessionServiceTests.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-20.
//  Unit tests for WorkoutSessionService
//

import SwiftData
import XCTest

@testable import GymBo

@MainActor
final class WorkoutSessionServiceTests: XCTestCase {

    var service: WorkoutSessionService!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        service = WorkoutSessionService()
        context = try createTestContext()
        service.setContext(context)
    }

    override func tearDown() async throws {
        service = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createSampleExercise(name: String) -> Exercise {
        let exercise = TestFixtures.createSampleExercise(name: name)
        let entity = ExerciseEntity.make(from: exercise)
        context.insert(entity)
        try? context.save()
        return exercise
    }

    private func createSampleWorkout(name: String, exercises: [Exercise]) -> WorkoutEntity {
        let workoutExercises = exercises.map { exercise -> WorkoutExerciseEntity in
            let exerciseEntity = try! context.fetch(
                FetchDescriptor<ExerciseEntity>(
                    predicate: #Predicate { $0.id == exercise.id }
                )
            ).first!

            let workoutExercise = WorkoutExerciseEntity(exercise: exerciseEntity, order: 0)
            workoutExercise.sets.append(ExerciseSetEntity(reps: 10, weight: 50))
            return workoutExercise
        }

        let workout = WorkoutEntity(
            name: name,
            exercises: workoutExercises,
            defaultRestTime: 90
        )
        context.insert(workout)
        try? context.save()
        return workout
    }

    private func createSampleSession(name: String, exercise: Exercise) -> WorkoutSession {
        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: [
                ExerciseSet(reps: 10, weight: 50, restTime: 90, completed: true),
                ExerciseSet(reps: 8, weight: 60, restTime: 90, completed: true),
            ]
        )

        return WorkoutSession(
            id: UUID(),
            templateId: UUID(),
            name: name,
            date: Date(),
            exercises: [workoutExercise],
            defaultRestTime: 90,
            duration: 1800,
            notes: "Test session"
        )
    }

    // MARK: - Context Tests

    func testSetContext_SetsContextCorrectly() {
        let newContext = try! createTestContext()
        service.setContext(newContext)

        // Verify by trying to use the service - should not crash
        let sessions = service.getAllSessions()
        XCTAssertNotNil(sessions)
    }

    func testOperationsWithNilContext_ThrowsError() {
        service.setContext(nil)

        XCTAssertThrowsError(try service.prepareSessionStart(for: UUID())) { error in
            guard case WorkoutSessionService.SessionError.missingModelContext = error else {
                XCTFail("Expected missingModelContext error")
                return
            }
        }
    }

    // MARK: - Prepare Session Tests

    func testPrepareSessionStart_WithValidWorkout_ReturnsWorkout() throws {
        let exercise = createSampleExercise(name: "Bench Press")
        let workout = createSampleWorkout(name: "Test Workout", exercises: [exercise])

        let result = try service.prepareSessionStart(for: workout.id)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, workout.id)
        XCTAssertEqual(result?.name, "Test Workout")
    }

    func testPrepareSessionStart_WithInvalidWorkoutId_ReturnsNil() throws {
        let result = try service.prepareSessionStart(for: UUID())

        XCTAssertNil(result)
    }

    func testPrepareSessionStart_WithNilContext_ThrowsError() {
        service.setContext(nil)

        XCTAssertThrowsError(try service.prepareSessionStart(for: UUID())) { error in
            guard case WorkoutSessionService.SessionError.missingModelContext = error else {
                XCTFail("Expected missingModelContext error")
                return
            }
        }
    }

    // MARK: - Record Session Tests

    func testRecordSession_CreatesSessionInDatabase() throws {
        let exercise = createSampleExercise(name: "Squats")
        let session = createSampleSession(name: "Morning Workout", exercise: exercise)

        let entity = try service.recordSession(session)

        XCTAssertEqual(entity.id, session.id)
        XCTAssertEqual(entity.name, "Morning Workout")
        XCTAssertEqual(entity.exercises.count, 1)
        XCTAssertEqual(entity.exercises.first?.sets.count, 2)
    }

    func testRecordSession_WithMultipleExercises() throws {
        let exercise1 = createSampleExercise(name: "Bench Press")
        let exercise2 = createSampleExercise(name: "Squats")

        let workoutExercises = [
            WorkoutExercise(
                exercise: exercise1,
                sets: [ExerciseSet(reps: 10, weight: 60)]
            ),
            WorkoutExercise(
                exercise: exercise2,
                sets: [ExerciseSet(reps: 12, weight: 100)]
            ),
        ]

        let session = WorkoutSession(
            id: UUID(),
            templateId: UUID(),
            name: "Full Body",
            date: Date(),
            exercises: workoutExercises,
            defaultRestTime: 90,
            duration: 0,
            notes: ""
        )

        let entity = try service.recordSession(session)

        XCTAssertEqual(entity.exercises.count, 2)
        XCTAssertEqual(entity.exercises[0].sets.count, 1)
        XCTAssertEqual(entity.exercises[1].sets.count, 1)
    }

    func testRecordSession_PreservesAllData() throws {
        let exercise = createSampleExercise(name: "Deadlift")

        let session = WorkoutSession(
            id: UUID(),
            templateId: UUID(),
            name: "Strength Training",
            date: Date(),
            exercises: [
                WorkoutExercise(
                    exercise: exercise,
                    sets: [ExerciseSet(reps: 5, weight: 140, restTime: 180, completed: true)]
                )
            ],
            defaultRestTime: 120,
            duration: 3600,
            notes: "Heavy day",
            minHeartRate: 80,
            maxHeartRate: 160,
            avgHeartRate: 120
        )

        let entity = try service.recordSession(session)

        XCTAssertEqual(entity.name, "Strength Training")
        XCTAssertEqual(entity.defaultRestTime, 120)
        XCTAssertEqual(entity.duration, 3600)
        XCTAssertEqual(entity.notes, "Heavy day")
        XCTAssertEqual(entity.minHeartRate, 80)
        XCTAssertEqual(entity.maxHeartRate, 160)
        XCTAssertEqual(entity.avgHeartRate, 120)
    }

    func testRecordSession_WithNilContext_ThrowsError() {
        service.setContext(nil)
        let exercise = TestFixtures.createSampleExercise(name: "Test")
        let session = createSampleSession(name: "Test", exercise: exercise)

        XCTAssertThrowsError(try service.recordSession(session)) { error in
            guard case WorkoutSessionService.SessionError.missingModelContext = error else {
                XCTFail("Expected missingModelContext error")
                return
            }
        }
    }

    // MARK: - Get Session Tests

    func testGetSession_WithValidId_ReturnsSession() throws {
        let exercise = createSampleExercise(name: "Pull-ups")
        let session = createSampleSession(name: "Back Day", exercise: exercise)

        _ = try service.recordSession(session)

        let retrieved = service.getSession(with: session.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, session.id)
        XCTAssertEqual(retrieved?.name, "Back Day")
    }

    func testGetSession_WithInvalidId_ReturnsNil() {
        let retrieved = service.getSession(with: UUID())

        XCTAssertNil(retrieved)
    }

    func testGetSession_WithNilContext_ReturnsNil() {
        service.setContext(nil)

        let retrieved = service.getSession(with: UUID())

        XCTAssertNil(retrieved)
    }

    // MARK: - Get All Sessions Tests

    func testGetAllSessions_ReturnsAllSessions() throws {
        let exercise = createSampleExercise(name: "Bench Press")

        let session1 = createSampleSession(name: "Session 1", exercise: exercise)
        let session2 = createSampleSession(name: "Session 2", exercise: exercise)
        let session3 = createSampleSession(name: "Session 3", exercise: exercise)

        _ = try service.recordSession(session1)
        _ = try service.recordSession(session2)
        _ = try service.recordSession(session3)

        let sessions = service.getAllSessions()

        XCTAssertEqual(sessions.count, 3)
    }

    func testGetAllSessions_SortedByDateDescending() throws {
        let exercise = createSampleExercise(name: "Squats")
        let now = Date()

        var session1 = createSampleSession(name: "Oldest", exercise: exercise)
        session1 = WorkoutSession(
            id: session1.id,
            templateId: session1.templateId,
            name: session1.name,
            date: now.addingTimeInterval(-7200),  // 2 hours ago
            exercises: session1.exercises,
            defaultRestTime: session1.defaultRestTime,
            duration: session1.duration,
            notes: session1.notes
        )

        var session2 = createSampleSession(name: "Newest", exercise: exercise)
        session2 = WorkoutSession(
            id: session2.id,
            templateId: session2.templateId,
            name: session2.name,
            date: now,
            exercises: session2.exercises,
            defaultRestTime: session2.defaultRestTime,
            duration: session2.duration,
            notes: session2.notes
        )

        var session3 = createSampleSession(name: "Middle", exercise: exercise)
        session3 = WorkoutSession(
            id: session3.id,
            templateId: session3.templateId,
            name: session3.name,
            date: now.addingTimeInterval(-3600),  // 1 hour ago
            exercises: session3.exercises,
            defaultRestTime: session3.defaultRestTime,
            duration: session3.duration,
            notes: session3.notes
        )

        _ = try service.recordSession(session1)
        _ = try service.recordSession(session2)
        _ = try service.recordSession(session3)

        let sessions = service.getAllSessions()

        XCTAssertEqual(sessions[0].name, "Newest")
        XCTAssertEqual(sessions[1].name, "Middle")
        XCTAssertEqual(sessions[2].name, "Oldest")
    }

    func testGetAllSessions_RespectsLimit() throws {
        let exercise = createSampleExercise(name: "Deadlift")

        // Create 10 sessions
        for i in 1...10 {
            let session = createSampleSession(name: "Session \(i)", exercise: exercise)
            _ = try service.recordSession(session)
        }

        let sessions = service.getAllSessions(limit: 5)

        XCTAssertEqual(sessions.count, 5)
    }

    func testGetAllSessions_WithEmptyDatabase_ReturnsEmptyArray() {
        let sessions = service.getAllSessions()

        XCTAssertEqual(sessions.count, 0)
    }

    func testGetAllSessions_WithNilContext_ReturnsEmptyArray() {
        service.setContext(nil)

        let sessions = service.getAllSessions()

        XCTAssertEqual(sessions.count, 0)
    }

    // MARK: - Get Sessions for Template Tests

    func testGetSessionsForTemplate_ReturnsMatchingSessions() throws {
        let exercise = createSampleExercise(name: "Bench Press")
        let templateId = UUID()

        var session1 = createSampleSession(name: "Session 1", exercise: exercise)
        session1 = WorkoutSession(
            id: session1.id,
            templateId: templateId,
            name: session1.name,
            date: session1.date,
            exercises: session1.exercises,
            defaultRestTime: session1.defaultRestTime,
            duration: session1.duration,
            notes: session1.notes
        )

        var session2 = createSampleSession(name: "Session 2", exercise: exercise)
        session2 = WorkoutSession(
            id: session2.id,
            templateId: templateId,
            name: session2.name,
            date: session2.date,
            exercises: session2.exercises,
            defaultRestTime: session2.defaultRestTime,
            duration: session2.duration,
            notes: session2.notes
        )

        // Different template
        let session3 = createSampleSession(name: "Session 3", exercise: exercise)

        _ = try service.recordSession(session1)
        _ = try service.recordSession(session2)
        _ = try service.recordSession(session3)

        let sessions = service.getSessions(for: templateId)

        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.allSatisfy { $0.templateId == templateId })
    }

    func testGetSessionsForTemplate_RespectsLimit() throws {
        let exercise = createSampleExercise(name: "Squats")
        let templateId = UUID()

        // Create 10 sessions for same template
        for i in 1...10 {
            var session = createSampleSession(name: "Session \(i)", exercise: exercise)
            session = WorkoutSession(
                id: session.id,
                templateId: templateId,
                name: session.name,
                date: session.date,
                exercises: session.exercises,
                defaultRestTime: session.defaultRestTime,
                duration: session.duration,
                notes: session.notes
            )
            _ = try service.recordSession(session)
        }

        let sessions = service.getSessions(for: templateId, limit: 3)

        XCTAssertEqual(sessions.count, 3)
    }

    func testGetSessionsForTemplate_WithNoMatchingSessions_ReturnsEmptyArray() {
        let sessions = service.getSessions(for: UUID())

        XCTAssertEqual(sessions.count, 0)
    }

    // MARK: - Remove Session Tests

    func testRemoveSession_DeletesSession() throws {
        let exercise = createSampleExercise(name: "Deadlift")
        let session = createSampleSession(name: "Test Session", exercise: exercise)

        _ = try service.recordSession(session)

        XCTAssertEqual(service.getAllSessions().count, 1)

        try service.removeSession(with: session.id)

        XCTAssertEqual(service.getAllSessions().count, 0)
    }

    func testRemoveSession_WithInvalidId_ThrowsError() {
        XCTAssertThrowsError(try service.removeSession(with: UUID())) { error in
            guard case WorkoutSessionService.SessionError.sessionNotFound = error else {
                XCTFail("Expected sessionNotFound error")
                return
            }
        }
    }

    func testRemoveSession_WithNilContext_ThrowsError() {
        service.setContext(nil)

        XCTAssertThrowsError(try service.removeSession(with: UUID())) { error in
            guard case WorkoutSessionService.SessionError.missingModelContext = error else {
                XCTFail("Expected missingModelContext error")
                return
            }
        }
    }

    // MARK: - Integration Tests

    func testFullSessionLifecycle() throws {
        // Create exercise
        let exercise = createSampleExercise(name: "Bench Press")

        // Create session
        let session = createSampleSession(name: "Chest Day", exercise: exercise)
        let sessionId = session.id

        // Record session
        _ = try service.recordSession(session)

        // Retrieve session
        let retrieved = service.getSession(with: sessionId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Chest Day")

        // Verify in all sessions
        let allSessions = service.getAllSessions()
        XCTAssertEqual(allSessions.count, 1)
        XCTAssertEqual(allSessions.first?.id, sessionId)

        // Delete session
        try service.removeSession(with: sessionId)

        // Verify deleted
        XCTAssertNil(service.getSession(with: sessionId))
        XCTAssertEqual(service.getAllSessions().count, 0)
    }
}
