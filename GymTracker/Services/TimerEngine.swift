//
//  TimerEngine.swift
//  GymTracker
//
//  Created by Claude on 2025-10-13.
//  Part of Robust Notification System
//

import Foundation

/// A precise timer engine based on wall-clock time that survives app restarts
///
/// This timer uses Date-based calculations instead of relative time intervals,
/// ensuring accuracy even after force quit or background/foreground transitions.
///
/// ## Key Features:
/// - Wall-clock synchronization (survives app restart)
/// - Automatic expiration detection
/// - Memory-safe (no retain cycles)
/// - Background-capable (within iOS limitations)
///
/// ## Usage:
/// ```swift
/// let engine = TimerEngine()
/// let endDate = Date().addingTimeInterval(60)
/// engine.startTimer(until: endDate) {
///     print("Timer expired!")
/// }
/// ```
@MainActor
final class TimerEngine: ObservableObject {

    // MARK: - Properties

    /// The active timer instance (nil when not running)
    private var timer: Timer?

    /// Target end date for the timer (wall-clock time)
    private var endDate: Date?

    /// Callback to execute when timer expires
    private var expirationHandler: (() -> Void)?

    /// Whether the timer is currently active
    @Published private(set) var isRunning: Bool = false

    /// Timer tick interval (how often to check for expiration)
    private let tickInterval: TimeInterval = 1.0

    // MARK: - Public API

    /// Starts the timer until a specific end date
    ///
    /// Any previously running timer will be stopped first.
    ///
    /// - Parameters:
    ///   - endDate: The wall-clock time when timer should expire
    ///   - onExpire: Callback to execute when timer expires
    func startTimer(until endDate: Date, onExpire: @escaping () -> Void) {
        // Stop any existing timer first
        stopTimer()

        self.endDate = endDate
        self.expirationHandler = onExpire
        self.isRunning = true

        // Create and schedule timer
        timer = Timer.scheduledTimer(
            withTimeInterval: tickInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkExpiration()
            }
        }

        // Ensure timer runs in common run loop modes (works during scrolling, etc.)
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }

        // Immediate check in case timer already expired
        checkExpiration()

        AppLogger.workouts.info("⏱️ TimerEngine: Started timer until \(endDate)")
    }

    /// Stops the timer without triggering the expiration callback
    ///
    /// Safe to call multiple times or when no timer is running.
    func stopTimer() {
        guard isRunning else { return }

        timer?.invalidate()
        timer = nil
        endDate = nil
        expirationHandler = nil
        isRunning = false

        AppLogger.workouts.info("⏹️ TimerEngine: Timer stopped")
    }

    /// Remaining time until expiration in seconds
    ///
    /// Returns 0 if timer is not running or has already expired.
    var remainingSeconds: Int {
        guard let endDate = endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(Date())))
    }

    // MARK: - Private Methods

    /// Checks if timer has expired and triggers callback if so
    private func checkExpiration() {
        guard let endDate = endDate else {
            stopTimer()
            return
        }

        // Check if we've reached or passed the end date
        if Date() >= endDate {
            AppLogger.workouts.info("⏰ TimerEngine: Timer expired!")

            // Store handler before stopping (stopTimer clears it)
            let handler = expirationHandler

            // Stop timer first
            stopTimer()

            // Call expiration handler last
            handler?()
        }
    }

    // MARK: - Deinit

    deinit {
        // Manually clean up timer (can't call @MainActor method from deinit)
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Background Execution Support

extension TimerEngine {
    /// Calculates if timer will expire before a given date
    ///
    /// Useful for scheduling background tasks or notifications.
    ///
    /// - Parameter date: The date to check against
    /// - Returns: true if timer will expire before the given date
    func willExpireBefore(_ date: Date) -> Bool {
        guard let endDate = endDate else { return false }
        return endDate < date
    }

    /// Time until expiration as TimeInterval
    ///
    /// Returns 0 if timer is not running or has already expired.
    var remainingTimeInterval: TimeInterval {
        guard let endDate = endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(Date()))
    }
}

// MARK: - Debug Support

extension TimerEngine {
    /// Debug description of current timer state
    var debugDescription: String {
        guard isRunning, let endDate = endDate else {
            return "TimerEngine(not running)"
        }

        return """
            TimerEngine(
              isRunning: true,
              endDate: \(endDate),
              remaining: \(remainingSeconds)s
            )
            """
    }
}
