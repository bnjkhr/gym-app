//
//  RestTimerStateTests.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-13.
//  Unit tests for RestTimerState model
//

import XCTest

@testable import GymBo

final class RestTimerStateTests: XCTestCase {

    // MARK: - Test Properties

    let testWorkoutId = UUID()
    let testWorkoutName = "Test Workout"

    // MARK: - Initialization Tests

    func testInitialization() {
        // Given
        let now = Date()
        let endDate = now.addingTimeInterval(60)

        // When
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 1,
            startDate: now,
            endDate: endDate,
            totalSeconds: 60,
            currentExerciseName: "Bankdrücken",
            nextExerciseName: "Kniebeugen"
        )

        // Then
        XCTAssertEqual(state.workoutId, testWorkoutId)
        XCTAssertEqual(state.workoutName, testWorkoutName)
        XCTAssertEqual(state.exerciseIndex, 0)
        XCTAssertEqual(state.setIndex, 1)
        XCTAssertEqual(state.totalSeconds, 60)
        XCTAssertEqual(state.phase, .running)
        XCTAssertEqual(state.currentExerciseName, "Bankdrücken")
        XCTAssertEqual(state.nextExerciseName, "Kniebeugen")
        XCTAssertNil(state.currentHeartRate)
    }

    func testFactoryMethod() {
        // When
        let state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 2,
            setIndex: 3,
            duration: 90,
            currentExerciseName: "Kreuzheben",
            nextExerciseName: "Klimmzüge"
        )

        // Then
        XCTAssertEqual(state.workoutId, testWorkoutId)
        XCTAssertEqual(state.totalSeconds, 90)
        XCTAssertEqual(state.phase, .running)
        XCTAssertEqual(state.currentExerciseName, "Kreuzheben")
        XCTAssertEqual(state.nextExerciseName, "Klimmzüge")

        // Verify timing
        let timeDiff = state.endDate.timeIntervalSince(state.startDate)
        XCTAssertEqual(timeDiff, 90, accuracy: 0.1)
    }

    // MARK: - Computed Properties Tests

    func testRemainingSeconds_ActiveTimer() {
        // Given - Timer with 60 seconds remaining
        let now = Date()
        let endDate = now.addingTimeInterval(60)
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: endDate,
            totalSeconds: 60
        )

        // Then
        XCTAssertEqual(state.remainingSeconds, 60, accuracy: 1)
    }

    func testRemainingSeconds_ExpiredTimer() {
        // Given - Timer that expired 10 seconds ago
        let now = Date()
        let endDate = now.addingTimeInterval(-10)
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: endDate.addingTimeInterval(-60),
            endDate: endDate,
            totalSeconds: 60
        )

        // Then - Should return 0, not negative
        XCTAssertEqual(state.remainingSeconds, 0)
    }

    func testIsActive_RunningPhase() {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )

        // When
        state.phase = .running

        // Then
        XCTAssertTrue(state.isActive)
    }

    func testIsActive_PausedPhase() {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )

        // When
        state.phase = .paused

        // Then
        XCTAssertTrue(state.isActive)
    }

    func testIsActive_ExpiredPhase() {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )

        // When
        state.phase = .expired

        // Then
        XCTAssertFalse(state.isActive)
    }

    func testIsActive_CompletedPhase() {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )

        // When
        state.phase = .completed

        // Then
        XCTAssertFalse(state.isActive)
    }

    func testHasExpired_NotExpired() {
        // Given - Timer with 30 seconds remaining
        let now = Date()
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: now.addingTimeInterval(30),
            totalSeconds: 60
        )

        // Then
        XCTAssertFalse(state.hasExpired)
    }

    func testHasExpired_JustExpired() {
        // Given - Timer that just expired
        let now = Date()
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(-1),
            totalSeconds: 60,
            phase: .running
        )

        // Then
        XCTAssertTrue(state.hasExpired)
    }

    func testHasExpired_CompletedPhase() {
        // Given - Expired timer but marked as completed
        let now = Date()
        var state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(-1),
            totalSeconds: 60
        )
        state.phase = .completed

        // Then - Should return false because acknowledged
        XCTAssertFalse(state.hasExpired)
    }

    func testProgress_Start() {
        // Given - Timer just started
        let now = Date()
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: now.addingTimeInterval(60),
            totalSeconds: 60
        )

        // Then
        XCTAssertEqual(state.progress, 0.0, accuracy: 0.05)
    }

    func testProgress_Halfway() {
        // Given - Timer halfway through
        let now = Date()
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now.addingTimeInterval(-30),
            endDate: now.addingTimeInterval(30),
            totalSeconds: 60
        )

        // Then
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.05)
    }

    func testProgress_Complete() {
        // Given - Timer expired
        let now = Date()
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(-5),
            totalSeconds: 60
        )

        // Then
        XCTAssertEqual(state.progress, 1.0, accuracy: 0.01)
    }

    // MARK: - Validation Tests

    func testIsValid_ValidState() {
        // Given
        let state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )

        // Then
        XCTAssertTrue(state.isValid())
    }

    func testIsValid_NegativeTotalSeconds() {
        // Given
        let now = Date()
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: now.addingTimeInterval(60),
            totalSeconds: -10
        )

        // Then
        XCTAssertFalse(state.isValid())
    }

    func testIsValid_EndDateBeforeStartDate() {
        // Given
        let now = Date()
        let state = RestTimerState(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: now.addingTimeInterval(-60),  // End before start!
            totalSeconds: 60
        )

        // Then
        XCTAssertFalse(state.isValid())
    }

    func testIsValid_NegativeExerciseIndex() {
        // Given
        let state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: -1,
            setIndex: 0,
            duration: 60
        )

        // Then
        XCTAssertFalse(state.isValid())
    }

    func testIsValid_ValidHeartRate() {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )
        state.currentHeartRate = 120

        // Then
        XCTAssertTrue(state.isValid())
    }

    func testIsValid_InvalidHeartRate_TooLow() {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )
        state.currentHeartRate = 20  // Too low

        // Then
        XCTAssertFalse(state.isValid())
    }

    func testIsValid_InvalidHeartRate_TooHigh() {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )
        state.currentHeartRate = 300  // Too high

        // Then
        XCTAssertFalse(state.isValid())
    }

    // MARK: - Codable Tests

    func testCodable_Encoding() throws {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 1,
            setIndex: 2,
            duration: 90,
            currentExerciseName: "Bankdrücken",
            nextExerciseName: "Kniebeugen"
        )
        state.currentHeartRate = 145

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)

        // Then
        XCTAssertFalse(data.isEmpty)
    }

    func testCodable_RoundTrip() throws {
        // Given
        var originalState = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 3,
            setIndex: 4,
            duration: 120,
            currentExerciseName: "Kreuzheben",
            nextExerciseName: "Schulterdrücken"
        )
        originalState.currentHeartRate = 160
        originalState.phase = .paused

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)

        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(RestTimerState.self, from: data)

        // Then
        XCTAssertEqual(decodedState.id, originalState.id)
        XCTAssertEqual(decodedState.workoutId, originalState.workoutId)
        XCTAssertEqual(decodedState.workoutName, originalState.workoutName)
        XCTAssertEqual(decodedState.exerciseIndex, originalState.exerciseIndex)
        XCTAssertEqual(decodedState.setIndex, originalState.setIndex)
        XCTAssertEqual(decodedState.totalSeconds, originalState.totalSeconds)
        XCTAssertEqual(decodedState.phase, originalState.phase)
        XCTAssertEqual(decodedState.currentExerciseName, originalState.currentExerciseName)
        XCTAssertEqual(decodedState.nextExerciseName, originalState.nextExerciseName)
        XCTAssertEqual(decodedState.currentHeartRate, originalState.currentHeartRate)
    }

    func testCodable_WithOptionalNilValues() throws {
        // Given
        let state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )
        // All optionals are nil

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(RestTimerState.self, from: data)

        // Then
        XCTAssertNil(decodedState.currentExerciseName)
        XCTAssertNil(decodedState.nextExerciseName)
        XCTAssertNil(decodedState.currentHeartRate)
    }

    // MARK: - Equatable Tests

    func testEquatable_Equal() {
        // Given
        let id = UUID()
        let now = Date()
        let endDate = now.addingTimeInterval(60)

        let state1 = RestTimerState(
            id: id,
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: endDate,
            totalSeconds: 60
        )

        let state2 = RestTimerState(
            id: id,
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: endDate,
            totalSeconds: 60
        )

        // Then
        XCTAssertEqual(state1, state2)
    }

    func testEquatable_DifferentId() {
        // Given
        let state1 = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )

        let state2 = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )

        // Then - Different IDs
        XCTAssertNotEqual(state1, state2)
    }

    func testEquatable_DifferentPhase() {
        // Given
        let id = UUID()
        let now = Date()
        let endDate = now.addingTimeInterval(60)

        var state1 = RestTimerState(
            id: id,
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: endDate,
            totalSeconds: 60,
            phase: .running
        )

        var state2 = RestTimerState(
            id: id,
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            startDate: now,
            endDate: endDate,
            totalSeconds: 60,
            phase: .running
        )

        state2.phase = .paused

        // Then
        XCTAssertNotEqual(state1, state2)
    }

    // MARK: - Age Tests

    func testAge() {
        // Given
        let pastDate = Date().addingTimeInterval(-10)
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: testWorkoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: 60
        )
        state.lastUpdateDate = pastDate

        // Then
        XCTAssertEqual(state.age, 10, accuracy: 0.5)
    }

    // MARK: - Description Tests

    func testDescription() {
        // Given
        var state = RestTimerState.create(
            workoutId: testWorkoutId,
            workoutName: "Push Day",
            exerciseIndex: 2,
            setIndex: 3,
            duration: 90,
            currentExerciseName: "Bankdrücken",
            nextExerciseName: "Schrägbankdrücken"
        )
        state.currentHeartRate = 145

        // When
        let description = state.description

        // Then
        XCTAssertTrue(description.contains("Push Day"))
        XCTAssertTrue(description.contains("running"))
        XCTAssertTrue(description.contains("Bankdrücken"))
        XCTAssertTrue(description.contains("Schrägbankdrücken"))
        XCTAssertTrue(description.contains("145 BPM"))
    }
}
