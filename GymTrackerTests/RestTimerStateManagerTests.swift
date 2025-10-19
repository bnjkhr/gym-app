//
//  RestTimerStateManagerTests.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-13.
//  Unit tests for RestTimerStateManager
//

import XCTest

@testable import GymBo

@MainActor
final class RestTimerStateManagerTests: XCTestCase {

    var manager: RestTimerStateManager!
    var mockStorage: UserDefaults!
    var timerEngine: TimerEngine!

    let testWorkout = Workout(
        id: UUID(),
        name: "Test Workout",
        date: Date(),
        exercises: []
    )

    override func setUp() async throws {
        // Use a unique suite name for isolated testing
        let suiteName = "TestSuite_\(UUID().uuidString)"
        mockStorage = UserDefaults(suiteName: suiteName)!
        timerEngine = TimerEngine()
        manager = RestTimerStateManager(storage: mockStorage, timerEngine: timerEngine)
    }

    override func tearDown() async throws {
        manager.cancelRest()
        mockStorage.removePersistentDomain(
            forName: mockStorage.dictionaryRepresentation().keys.first ?? "")
        manager = nil
        mockStorage = nil
        timerEngine = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        // Then
        XCTAssertNil(manager.currentState)
    }

    // MARK: - Start Rest Tests

    func testStartRest_CreatesState() {
        // When
        manager.startRest(
            for: testWorkout,
            exercise: 0,
            set: 1,
            duration: 60,
            currentExerciseName: "Bankdrücken",
            nextExerciseName: "Kniebeugen"
        )

        // Then
        XCTAssertNotNil(manager.currentState)
        XCTAssertEqual(manager.currentState?.workoutId, testWorkout.id)
        XCTAssertEqual(manager.currentState?.workoutName, testWorkout.name)
        XCTAssertEqual(manager.currentState?.exerciseIndex, 0)
        XCTAssertEqual(manager.currentState?.setIndex, 1)
        XCTAssertEqual(manager.currentState?.totalSeconds, 60)
        XCTAssertEqual(manager.currentState?.phase, .running)
        XCTAssertEqual(manager.currentState?.currentExerciseName, "Bankdrücken")
        XCTAssertEqual(manager.currentState?.nextExerciseName, "Kniebeugen")
    }

    func testStartRest_StartsTimerEngine() {
        // When
        manager.startRest(
            for: testWorkout,
            exercise: 0,
            set: 0,
            duration: 60
        )

        // Then
        XCTAssertTrue(timerEngine.isRunning)
        XCTAssertEqual(timerEngine.remainingSeconds, 60, accuracy: 2)
    }

    func testStartRest_PersistsState() {
        // When
        manager.startRest(
            for: testWorkout,
            exercise: 0,
            set: 0,
            duration: 90
        )

        // Then
        let data = mockStorage.data(forKey: "restTimerState_v2")
        XCTAssertNotNil(data)
        XCTAssertFalse(data!.isEmpty)
    }

    func testStartRest_ReplacesExistingTimer() {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)
        let firstStateId = manager.currentState?.id

        // When
        manager.startRest(for: testWorkout, exercise: 1, set: 1, duration: 90)
        let secondStateId = manager.currentState?.id

        // Then
        XCTAssertNotEqual(firstStateId, secondStateId)
        XCTAssertEqual(manager.currentState?.totalSeconds, 90)
        XCTAssertEqual(manager.currentState?.exerciseIndex, 1)
    }

    // MARK: - Update Heart Rate Tests

    func testUpdateHeartRate_ValidValue() {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)

        // When
        manager.updateHeartRate(145)

        // Then
        XCTAssertEqual(manager.currentState?.currentHeartRate, 145)
    }

    func testUpdateHeartRate_InvalidTooLow() {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)

        // When
        manager.updateHeartRate(20)  // Too low

        // Then
        XCTAssertNil(manager.currentState?.currentHeartRate)
    }

    func testUpdateHeartRate_InvalidTooHigh() {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)

        // When
        manager.updateHeartRate(300)  // Too high

        // Then
        XCTAssertNil(manager.currentState?.currentHeartRate)
    }

    func testUpdateHeartRate_WithoutActiveTimer() {
        // When
        manager.updateHeartRate(145)

        // Then - Should not crash
        XCTAssertNil(manager.currentState)
    }

    func testUpdateHeartRate_Throttling() async {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)

        // When - Rapid updates
        manager.updateHeartRate(140)
        manager.updateHeartRate(145)  // Should be ignored (throttled)
        manager.updateHeartRate(150)  // Should be ignored (throttled)

        // Then - Only first update should apply
        XCTAssertEqual(manager.currentState?.currentHeartRate, 140)

        // Wait for throttle period
        try? await Task.sleep(nanoseconds: 5_100_000_000)  // 5.1s

        // When - Update after throttle
        manager.updateHeartRate(155)

        // Then - Should apply
        XCTAssertEqual(manager.currentState?.currentHeartRate, 155)
    }

    // MARK: - Pause/Resume Tests

    func testPauseRest() {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)

        // When
        manager.pauseRest()

        // Then
        XCTAssertEqual(manager.currentState?.phase, .paused)
        XCTAssertFalse(timerEngine.isRunning)
    }

    func testPauseRest_WhenNotRunning() {
        // When - Pause without starting
        manager.pauseRest()

        // Then - Should not crash
        XCTAssertNil(manager.currentState)
    }

    func testPauseRest_WhenAlreadyPaused() {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)
        manager.pauseRest()

        // When - Pause again
        manager.pauseRest()

        // Then - Should remain paused
        XCTAssertEqual(manager.currentState?.phase, .paused)
    }

    func testResumeRest() async {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)

        // Wait a bit
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2s

        manager.pauseRest()
        let remainingWhenPaused = manager.currentState?.remainingSeconds ?? 0

        // When
        manager.resumeRest()

        // Then
        XCTAssertEqual(manager.currentState?.phase, .running)
        XCTAssertTrue(timerEngine.isRunning)
        XCTAssertEqual(manager.currentState?.remainingSeconds, remainingWhenPaused, accuracy: 2)
    }

    func testResumeRest_WhenNotPaused() {
        // When - Resume without pausing
        manager.resumeRest()

        // Then - Should not crash
        XCTAssertNil(manager.currentState)
    }

    func testPauseResumeMultipleTimes() async {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)

        // When - Multiple pause/resume cycles
        manager.pauseRest()
        XCTAssertEqual(manager.currentState?.phase, .paused)

        manager.resumeRest()
        XCTAssertEqual(manager.currentState?.phase, .running)

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        manager.pauseRest()
        XCTAssertEqual(manager.currentState?.phase, .paused)

        manager.resumeRest()
        XCTAssertEqual(manager.currentState?.phase, .running)

        // Then
        XCTAssertTrue(timerEngine.isRunning)
    }

    // MARK: - Acknowledge Expired Tests

    func testAcknowledgeExpired() async {
        // Given - Timer that will expire quickly
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 1)

        // Wait for expiration
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        XCTAssertEqual(manager.currentState?.phase, .expired)

        // When
        manager.acknowledgeExpired()

        // Then
        XCTAssertEqual(manager.currentState?.phase, .completed)

        // Wait for cleanup
        try? await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertNil(manager.currentState)
    }

    func testAcknowledgeExpired_WhenNotExpired() {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)

        // When - Try to acknowledge non-expired timer
        manager.acknowledgeExpired()

        // Then - Should remain running
        XCTAssertEqual(manager.currentState?.phase, .running)
    }

    // MARK: - Cancel Rest Tests

    func testCancelRest() {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)
        XCTAssertNotNil(manager.currentState)

        // When
        manager.cancelRest()

        // Then
        XCTAssertNil(manager.currentState)
        XCTAssertFalse(timerEngine.isRunning)

        // Verify persistence cleared
        let data = mockStorage.data(forKey: "restTimerState_v2")
        XCTAssertNil(data)
    }

    func testCancelRest_WhenNoTimer() {
        // When - Cancel without active timer
        manager.cancelRest()

        // Then - Should not crash
        XCTAssertNil(manager.currentState)
    }

    // MARK: - Timer Expiration Tests

    func testTimerExpiration_TransitionsToExpired() async {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 2)

        // Wait for expiration
        try? await Task.sleep(nanoseconds: 2_500_000_000)  // 2.5s

        // Then
        XCTAssertEqual(manager.currentState?.phase, .expired)
        XCTAssertFalse(timerEngine.isRunning)
    }

    func testTimerExpiration_StopsTimerEngine() async {
        // Given
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 1)
        XCTAssertTrue(timerEngine.isRunning)

        // Wait for expiration
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Then
        XCTAssertFalse(timerEngine.isRunning)
    }

    // MARK: - Persistence Tests

    func testPersistence_SaveAndRestore() {
        // Given
        manager.startRest(
            for: testWorkout,
            exercise: 2,
            set: 3,
            duration: 90,
            currentExerciseName: "Kreuzheben",
            nextExerciseName: "Schulterdrücken"
        )
        let originalId = manager.currentState?.id

        // When - Create new manager with same storage
        let newManager = RestTimerStateManager(storage: mockStorage, timerEngine: TimerEngine())
        newManager.restoreState()

        // Then
        XCTAssertNotNil(newManager.currentState)
        XCTAssertEqual(newManager.currentState?.id, originalId)
        XCTAssertEqual(newManager.currentState?.workoutId, testWorkout.id)
        XCTAssertEqual(newManager.currentState?.exerciseIndex, 2)
        XCTAssertEqual(newManager.currentState?.setIndex, 3)
        XCTAssertEqual(newManager.currentState?.currentExerciseName, "Kreuzheben")
        XCTAssertEqual(newManager.currentState?.nextExerciseName, "Schulterdrücken")
    }

    func testPersistence_RestoreExpiredTimer() async {
        // Given - Start timer that will expire
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 1)

        // Wait for expiration
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Save current data
        let data = mockStorage.data(forKey: "restTimerState_v2")!

        // Create state that expired in the past
        var state = try! JSONDecoder().decode(RestTimerState.self, from: data)
        state.phase = .running  // Pretend it was running when app closed
        let expiredData = try! JSONEncoder().encode(state)
        mockStorage.set(expiredData, forKey: "restTimerState_v2")

        // When - Restore with new manager
        let newManager = RestTimerStateManager(storage: mockStorage, timerEngine: TimerEngine())
        newManager.restoreState()

        // Then - Should detect expiration
        XCTAssertEqual(newManager.currentState?.phase, .expired)
    }

    func testPersistence_DiscardOldState() {
        // Given - Create very old state
        var state = RestTimerState.create(
            workoutId: testWorkout.id,
            workoutName: testWorkout.name,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )
        state.lastUpdateDate = Date().addingTimeInterval(-25 * 3600)  // 25 hours ago

        let data = try! JSONEncoder().encode(state)
        mockStorage.set(data, forKey: "restTimerState_v2")

        // When - Restore
        manager.restoreState()

        // Then - Should discard old state
        XCTAssertNil(manager.currentState)

        // Verify cleared from storage
        let storedData = mockStorage.data(forKey: "restTimerState_v2")
        XCTAssertNil(storedData)
    }

    func testPersistence_DiscardInvalidState() {
        // Given - Create invalid state
        var state = RestTimerState.create(
            workoutId: testWorkout.id,
            workoutName: testWorkout.name,
            exerciseIndex: -1,  // Invalid!
            setIndex: 0,
            duration: 60
        )

        let data = try! JSONEncoder().encode(state)
        mockStorage.set(data, forKey: "restTimerState_v2")

        // When - Restore
        manager.restoreState()

        // Then - Should discard invalid state
        XCTAssertNil(manager.currentState)
    }

    func testPersistence_HandleCorruptData() {
        // Given - Store corrupt data
        let corruptData = "not valid json".data(using: .utf8)!
        mockStorage.set(corruptData, forKey: "restTimerState_v2")

        // When - Restore
        manager.restoreState()

        // Then - Should handle gracefully
        XCTAssertNil(manager.currentState)

        // Verify cleared from storage
        let storedData = mockStorage.data(forKey: "restTimerState_v2")
        XCTAssertNil(storedData)
    }

    func testPersistence_NoStoredState() {
        // When - Restore with no stored state
        manager.restoreState()

        // Then
        XCTAssertNil(manager.currentState)
    }

    // MARK: - State Transition Tests

    func testStateTransitions_FullLifecycle() async {
        // 1. Start
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 10)
        XCTAssertEqual(manager.currentState?.phase, .running)

        // 2. Pause
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        manager.pauseRest()
        XCTAssertEqual(manager.currentState?.phase, .paused)

        // 3. Resume
        manager.resumeRest()
        XCTAssertEqual(manager.currentState?.phase, .running)

        // 4. Wait for expiration
        try? await Task.sleep(nanoseconds: 10_000_000_000)
        XCTAssertEqual(manager.currentState?.phase, .expired)

        // 5. Acknowledge
        manager.acknowledgeExpired()
        XCTAssertEqual(manager.currentState?.phase, .completed)

        // 6. Wait for cleanup
        try? await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertNil(manager.currentState)
    }

    // MARK: - Concurrent Operations Tests

    func testConcurrentOperations_RapidStateChanges() {
        // When - Rapid operations
        manager.startRest(for: testWorkout, exercise: 0, set: 0, duration: 60)
        manager.pauseRest()
        manager.resumeRest()
        manager.pauseRest()
        manager.resumeRest()
        manager.updateHeartRate(145)

        // Then - Should remain consistent
        XCTAssertNotNil(manager.currentState)
        XCTAssertEqual(manager.currentState?.phase, .running)
    }

    // MARK: - Debug Description Tests

    func testDebugDescription_NoState() {
        // When
        let description = manager.debugDescription

        // Then
        XCTAssertTrue(description.contains("no active timer"))
    }

    func testDebugDescription_WithState() {
        // Given
        manager.startRest(
            for: testWorkout,
            exercise: 0,
            set: 0,
            duration: 60,
            currentExerciseName: "Bankdrücken"
        )

        // When
        let description = manager.debugDescription

        // Then
        XCTAssertTrue(description.contains("RestTimerStateManager"))
        XCTAssertTrue(description.contains("Bankdrücken"))
    }
}
