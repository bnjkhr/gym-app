import Foundation
import OSLog

/// Centralized logging system for GymBo app
/// Replaces print() statements with structured, performance-efficient logging
///
/// Usage:
/// ```swift
/// AppLogger.workouts.info("Workout saved: \(workout.name)")
/// AppLogger.data.error("Failed to save: \(error.localizedDescription)")
/// ```
enum AppLogger {

    // MARK: - Category Loggers

    /// Workout-related operations (create, edit, delete, start sessions)
    static let workouts = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "Workouts")

    /// Database and data persistence operations
    static let data = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "Data")

    /// HealthKit integration and syncing
    static let health = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "HealthKit")

    /// Exercise management and migrations
    static let exercises = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "Exercises")

    /// App lifecycle, migrations, and startup
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "App")

    /// UI and navigation events
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "UI")

    /// Audio, notifications, and media
    static let media = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "Media")

    /// Backup and restore operations
    static let backup = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "Backup")

    /// Live Activities and widgets
    static let liveActivity = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gymbo", category: "LiveActivity")

    // MARK: - Helper Methods

    /// Log performance metrics
    static func logPerformance(_ message: String, duration: TimeInterval, category: Logger = AppLogger.app) {
        category.debug("⏱️ \(message): \(String(format: "%.2f", duration * 1000))ms")
    }

    /// Log memory usage (for debugging memory issues)
    static func logMemoryUsage(category: Logger = AppLogger.app) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            category.debug("💾 Memory usage: \(String(format: "%.2f", usedMB)) MB")
        }
    }
}

// MARK: - OSLog Extension for Privacy

extension Logger {
    /// Log sensitive data (will be redacted in release builds)
    func sensitive(_ message: String) {
        self.debug("\(message, privacy: .private)")
    }
}
