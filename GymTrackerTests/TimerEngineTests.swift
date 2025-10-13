//
//  TimerEngineTests.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-13.
//  Unit tests for TimerEngine
//

import XCTest

@testable import GymBo

@MainActor
final class TimerEngineTests: XCTestCase {

    var engine: TimerEngine!

    override func setUp() async throws {
        engine = TimerEngine()
    }

    override func tearDown() async throws {
        engine.stopTimer()
        engine = nil
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // Then
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.remainingSeconds, 0)
    }

    // MARK: - Start Timer Tests

    func testStartTimer() {
        // Given
        let expectation = expectation(description: "Timer starts")
        let endDate = Date().addingTimeInterval(60)

        // When
        engine.startTimer(until: endDate) {
            // Timer started
        }

        // Then
        XCTAssertTrue(engine.isRunning)
        XCTAssertEqual(engine.remainingSeconds, 60, accuracy: 1)
        expectation.fulfill()

        wait(for: [expectation], timeout: 0.1)
    }

    func testStartTimer_ReplacesPreviousTimer() {
        // Given
        let firstEndDate = Date().addingTimeInterval(60)
        let secondEndDate = Date().addingTimeInterval(30)

        var firstTimerExpired = false
        var secondTimerExpired = false

        // When
        engine.startTimer(until: firstEndDate) {
            firstTimerExpired = true
        }

        engine.startTimer(until: secondEndDate) {
            secondTimerExpired = true
        }

        // Then
        XCTAssertTrue(engine.isRunning)
        XCTAssertEqual(engine.remainingSeconds, 30, accuracy: 1)
        XCTAssertFalse(firstTimerExpired)
        XCTAssertFalse(secondTimerExpired)
    }

    // MARK: - Stop Timer Tests

    func testStopTimer() {
        // Given
        let endDate = Date().addingTimeInterval(60)
        engine.startTimer(until: endDate) {}

        // When
        engine.stopTimer()

        // Then
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.remainingSeconds, 0)
    }

    func testStopTimer_SafeWhenNotRunning() {
        // When/Then - Should not crash
        engine.stopTimer()
        engine.stopTimer()

        XCTAssertFalse(engine.isRunning)
    }

    func testStopTimer_DoesNotTriggerCallback() {
        // Given
        let expectation = expectation(description: "Callback should not be called")
        expectation.isInverted = true

        let endDate = Date().addingTimeInterval(60)
        engine.startTimer(until: endDate) {
            expectation.fulfill()
        }

        // When
        engine.stopTimer()

        // Then
        wait(for: [expectation], timeout: 0.5)
    }

    // MARK: - Expiration Tests

    func testTimerExpiration_Short() async {
        // Given
        let expectation = expectation(description: "Timer expires")
        let endDate = Date().addingTimeInterval(2)  // 2 seconds

        var callbackCalled = false

        // When
        engine.startTimer(until: endDate) {
            callbackCalled = true
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertTrue(callbackCalled)
        XCTAssertFalse(engine.isRunning)
    }

    func testTimerExpiration_AlreadyExpired() {
        // Given
        let expectation = expectation(description: "Timer expires immediately")
        let pastDate = Date().addingTimeInterval(-1)  // Already expired

        var callbackCalled = false

        // When
        engine.startTimer(until: pastDate) {
            callbackCalled = true
            expectation.fulfill()
        }

        // Then - Should trigger immediately
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(callbackCalled)
        XCTAssertFalse(engine.isRunning)
    }

    func testTimerExpiration_StopsAfterCallback() async {
        // Given
        let expectation = expectation(description: "Timer expires")
        let endDate = Date().addingTimeInterval(1.5)

        // When
        engine.startTimer(until: endDate) {
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 2.5)

        // Wait a bit more to ensure timer stopped
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.remainingSeconds, 0)
    }

    // MARK: - Remaining Time Tests

    func testRemainingSeconds_Countdown() async {
        // Given
        let endDate = Date().addingTimeInterval(5)
        engine.startTimer(until: endDate) {}

        // When - Check immediately
        let initialRemaining = engine.remainingSeconds

        // Wait 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let afterRemaining = engine.remainingSeconds

        // Then
        XCTAssertEqual(initialRemaining, 5, accuracy: 1)
        XCTAssertEqual(afterRemaining, 3, accuracy: 1)
        XCTAssertLessThan(afterRemaining, initialRemaining)
    }

    func testRemainingSeconds_WhenNotRunning() {
        // When/Then
        XCTAssertEqual(engine.remainingSeconds, 0)
    }

    func testRemainingTimeInterval() {
        // Given
        let endDate = Date().addingTimeInterval(45.5)
        engine.startTimer(until: endDate) {}

        // When
        let remaining = engine.remainingTimeInterval

        // Then
        XCTAssertEqual(remaining, 45.5, accuracy: 0.5)
    }

    // MARK: - Background Support Tests

    func testWillExpireBefore_True() {
        // Given
        let endDate = Date().addingTimeInterval(30)
        engine.startTimer(until: endDate) {}

        let futureDate = Date().addingTimeInterval(60)

        // When/Then
        XCTAssertTrue(engine.willExpireBefore(futureDate))
    }

    func testWillExpireBefore_False() {
        // Given
        let endDate = Date().addingTimeInterval(60)
        engine.startTimer(until: endDate) {}

        let nearFutureDate = Date().addingTimeInterval(30)

        // When/Then
        XCTAssertFalse(engine.willExpireBefore(nearFutureDate))
    }

    func testWillExpireBefore_NotRunning() {
        // Given
        let futureDate = Date().addingTimeInterval(60)

        // When/Then
        XCTAssertFalse(engine.willExpireBefore(futureDate))
    }

    // MARK: - Memory Management Tests

    func testMemoryLeak_StartStopCycles() {
        // Given/When - Perform many start/stop cycles
        for _ in 0..<100 {
            let endDate = Date().addingTimeInterval(60)
            engine.startTimer(until: endDate) {}
            engine.stopTimer()
        }

        // Then - Should not leak memory (verified by Instruments)
        XCTAssertFalse(engine.isRunning)
    }

    func testDeinit_StopsTimer() async {
        // Given
        var engine: TimerEngine? = TimerEngine()
        let expectation = expectation(description: "Callback should not be called after deinit")
        expectation.isInverted = true

        let endDate = Date().addingTimeInterval(2)
        await engine?.startTimer(until: endDate) {
            expectation.fulfill()
        }

        // When - Deinitialize engine
        engine = nil

        // Then - Wait to ensure callback doesn't fire
        await fulfillment(of: [expectation], timeout: 3.0)
    }

    // MARK: - Edge Cases

    func testZeroDurationTimer() {
        // Given
        let expectation = expectation(description: "Zero duration timer expires immediately")
        let now = Date()

        // When
        engine.startTimer(until: now) {
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 0.5)
    }

    func testVeryShortTimer() async {
        // Given
        let expectation = expectation(description: "Very short timer expires")
        let endDate = Date().addingTimeInterval(0.1)  // 100ms

        // When
        engine.startTimer(until: endDate) {
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testVeryLongTimer() {
        // Given
        let endDate = Date().addingTimeInterval(3600)  // 1 hour

        // When
        engine.startTimer(until: endDate) {}

        // Then
        XCTAssertTrue(engine.isRunning)
        XCTAssertEqual(engine.remainingSeconds, 3600, accuracy: 2)
    }

    // MARK: - Debug Description Tests

    func testDebugDescription_NotRunning() {
        // When
        let description = engine.debugDescription

        // Then
        XCTAssertTrue(description.contains("not running"))
    }

    func testDebugDescription_Running() {
        // Given
        let endDate = Date().addingTimeInterval(60)
        engine.startTimer(until: endDate) {}

        // When
        let description = engine.debugDescription

        // Then
        XCTAssertTrue(description.contains("isRunning: true"))
        XCTAssertTrue(description.contains("remaining"))
    }

    // MARK: - Multiple Callback Tests

    func testCallback_CalledOnlyOnce() async {
        // Given
        let expectation = expectation(description: "Callback called once")
        let endDate = Date().addingTimeInterval(1.5)

        var callCount = 0

        // When
        engine.startTimer(until: endDate) {
            callCount += 1
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 2.5)

        // Wait extra to ensure no additional calls
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertEqual(callCount, 1)
    }
}
