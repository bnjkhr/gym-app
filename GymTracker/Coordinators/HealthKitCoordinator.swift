import Foundation
import HealthKit
import SwiftData
import SwiftUI

/// HealthKitCoordinator manages HealthKit integration and data synchronization
///
/// **Responsibilities:**
/// - HealthKit authorization management
/// - Profile data import from HealthKit
/// - Workout data export to HealthKit
/// - Health metric queries (heart rate, weight, body fat)
/// - Sync status tracking
///
/// **Dependencies:**
/// - HealthKitSyncService (sync operations)
/// - HealthKitManager (HealthKit framework wrapper)
/// - ProfileCoordinator (profile updates)
///
/// **Used by:**
/// - ProfileView
/// - SettingsView
/// - HealthKitSyncView
/// - StatisticsView
@MainActor
final class HealthKitCoordinator: ObservableObject {
    // MARK: - Published State

    /// Whether HealthKit is authorized
    @Published var isAuthorized: Bool = false

    /// Whether HealthKit is available on this device
    @Published var isAvailable: Bool = false

    /// Whether sync is currently in progress
    @Published var isSyncing: Bool = false

    /// Last sync timestamp
    @Published var lastSyncDate: Date?

    /// Sync error message (if any)
    @Published var syncError: String?

    /// Number of workouts synced to HealthKit
    @Published var syncedWorkoutCount: Int = 0

    // MARK: - Dependencies

    private let syncService: HealthKitSyncService
    private let healthKitManager = HealthKitManager.shared
    private weak var profileCoordinator: ProfileCoordinator?
    private var modelContext: ModelContext?

    // MARK: - Initialization

    init(syncService: HealthKitSyncService = HealthKitSyncService()) {
        self.syncService = syncService
        self.isAvailable = HKHealthStore.isHealthDataAvailable()
        self.isAuthorized = healthKitManager.isAuthorized
    }

    // MARK: - Context Management

    /// Sets the SwiftData context for HealthKit operations
    /// - Parameter context: The ModelContext to use for persistence
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        syncService.setContext(context)
    }

    /// Sets the profile coordinator for profile updates
    /// - Parameter coordinator: The ProfileCoordinator instance
    func setProfileCoordinator(_ coordinator: ProfileCoordinator) {
        self.profileCoordinator = coordinator
    }

    // MARK: - Authorization

    /// Requests HealthKit authorization for required data types
    ///
    /// **Permissions requested:**
    /// - Read: Birth date, biological sex, height, body mass, heart rate
    /// - Write: Workout data, active energy burned
    ///
    /// - Throws: HealthKitError if authorization fails
    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        AppLogger.app.info("🏥 Requesting HealthKit authorization...")
        isSyncing = true
        syncError = nil

        do {
            try await syncService.requestAuthorization()

            await MainActor.run {
                self.isAuthorized = true
                AppLogger.app.info("✅ HealthKit authorization granted")
            }
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                AppLogger.app.error(
                    "❌ HealthKit authorization failed: \(error.localizedDescription)")
            }
            throw error
        }

        isSyncing = false
    }

    /// Checks current authorization status
    func checkAuthorizationStatus() {
        self.isAuthorized = healthKitManager.isAuthorized
    }

    // MARK: - Profile Import

    /// Imports user profile data from HealthKit
    ///
    /// **Imports:**
    /// - Birth date
    /// - Biological sex
    /// - Height (most recent)
    /// - Body mass/weight (most recent)
    ///
    /// Updates the user profile via ProfileCoordinator.
    ///
    /// - Throws: HealthKitError if import fails
    func importProfile() async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        AppLogger.app.info("🏥 Importing profile from HealthKit...")
        isSyncing = true
        syncError = nil

        do {
            try await syncService.importProfile()

            await MainActor.run {
                self.lastSyncDate = Date()

                // Refresh profile in ProfileCoordinator
                self.profileCoordinator?.refreshProfile()

                AppLogger.app.info("✅ Profile imported from HealthKit")
            }
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                AppLogger.app.error("❌ Profile import failed: \(error.localizedDescription)")
            }
            throw error
        }

        isSyncing = false
    }

    // MARK: - Workout Export

    /// Exports a workout session to HealthKit
    ///
    /// **Exports:**
    /// - Workout type (strength training)
    /// - Duration
    /// - Start/end date
    /// - Active energy burned (estimated)
    /// - Heart rate samples (if available)
    ///
    /// - Parameter session: The workout session to export
    /// - Throws: HealthKitError if export fails
    func saveWorkout(_ session: WorkoutSession) async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        do {
            try await syncService.saveWorkout(session)

            await MainActor.run {
                self.syncedWorkoutCount += 1
                self.lastSyncDate = Date()
                AppLogger.app.info("✅ Workout saved to HealthKit: \(session.name)")
            }
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                AppLogger.app.error("❌ Workout save failed: \(error.localizedDescription)")
            }
            throw error
        }
    }

    /// Exports multiple workouts to HealthKit in batch
    ///
    /// - Parameter sessions: Array of workout sessions
    /// - Returns: Number of successfully synced workouts
    func saveWorkouts(_ sessions: [WorkoutSession]) async -> Int {
        guard isAuthorized else {
            AppLogger.app.warning("⚠️ HealthKit not authorized - skipping batch sync")
            return 0
        }

        isSyncing = true

        let syncedCount = await syncService.saveWorkouts(sessions)

        await MainActor.run {
            self.syncedWorkoutCount += syncedCount
            self.lastSyncDate = Date()
            self.isSyncing = false
            AppLogger.app.info(
                "✅ Batch sync complete: \(syncedCount)/\(sessions.count) workouts synced")
        }

        return syncedCount
    }

    // MARK: - Health Data Queries

    /// Reads heart rate data for a time period
    ///
    /// - Parameters:
    ///   - startDate: Start of time period
    ///   - endDate: End of time period
    /// - Returns: Array of heart rate readings
    /// - Throws: HealthKitError if query fails
    func readHeartRateData(from startDate: Date, to endDate: Date) async throws
        -> [HeartRateReading]
    {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        do {
            let readings = try await syncService.readHeartRateData(from: startDate, to: endDate)
            AppLogger.app.debug("✅ Read \(readings.count) heart rate readings")
            return readings
        } catch {
            AppLogger.app.error("❌ Heart rate query failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Reads weight/body mass data for a time period
    ///
    /// - Parameters:
    ///   - startDate: Start of time period
    ///   - endDate: End of time period
    /// - Returns: Array of weight readings
    /// - Throws: HealthKitError if query fails
    func readWeightData(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading]
    {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        do {
            let readings = try await syncService.readWeightData(from: startDate, to: endDate)
            AppLogger.app.debug("✅ Read \(readings.count) weight readings")
            return readings
        } catch {
            AppLogger.app.error("❌ Weight query failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Reads body fat percentage data for a time period
    ///
    /// - Parameters:
    ///   - startDate: Start of time period
    ///   - endDate: End of time period
    /// - Returns: Array of body fat readings
    /// - Throws: HealthKitError if query fails
    func readBodyFatData(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading] {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        do {
            let readings = try await syncService.readBodyFatData(from: startDate, to: endDate)
            AppLogger.app.debug("✅ Read \(readings.count) body fat readings")
            return readings
        } catch {
            AppLogger.app.error("❌ Body fat query failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Reads all health data for a time period (combined query)
    ///
    /// - Parameters:
    ///   - startDate: Start of time period
    ///   - endDate: End of time period
    /// - Returns: Bundle of all health data
    /// - Throws: HealthKitError if query fails
    func readAllHealthData(from startDate: Date, to endDate: Date) async throws -> HealthDataBundle
    {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let bundle = try await syncService.readAllHealthData(from: startDate, to: endDate)
            AppLogger.app.info(
                "✅ Read all health data: \(bundle.heartRateReadings.count) HR, \(bundle.weightReadings.count) weight, \(bundle.bodyFatReadings.count) body fat"
            )
            return bundle
        } catch {
            AppLogger.app.error("❌ Health data query failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sync Status

    /// Gets current sync status
    ///
    /// - Returns: HealthKitSyncStatus with authorization and sync info
    func getSyncStatus() -> HealthKitSyncStatus {
        return syncService.getSyncStatus()
    }

    /// Enables HealthKit sync
    func enableSync() {
        syncService.enableSync()
        AppLogger.app.info("✅ HealthKit sync enabled")
    }

    /// Disables HealthKit sync
    func disableSync() {
        syncService.disableSync()
        AppLogger.app.info("✅ HealthKit sync disabled")
    }

    /// Checks if sync is enabled
    var isSyncEnabled: Bool {
        let status = getSyncStatus()
        return status.syncEnabled
    }

    // MARK: - Convenience Methods

    /// Gets the most recent weight reading
    ///
    /// - Returns: Most recent weight in kg, or nil if no data
    func getLatestWeight() async -> Double? {
        guard isAuthorized else { return nil }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate

        do {
            let readings = try await readWeightData(from: startDate, to: endDate)
            return readings.last?.weight
        } catch {
            return nil
        }
    }

    /// Gets weight trend over last N days
    ///
    /// - Parameter days: Number of days to analyze
    /// - Returns: Array of (date, weight) tuples
    func getWeightTrend(days: Int) async -> [(Date, Double)] {
        guard isAuthorized else { return [] }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        do {
            let readings = try await readWeightData(from: startDate, to: endDate)
            return readings.map { ($0.date, $0.weight) }
        } catch {
            return []
        }
    }

    /// Gets average heart rate during workouts
    ///
    /// - Parameter days: Number of days to analyze
    /// - Returns: Average heart rate in BPM
    func getAverageWorkoutHeartRate(days: Int) async -> Int? {
        guard isAuthorized else { return nil }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        do {
            let readings = try await readHeartRateData(from: startDate, to: endDate)

            guard !readings.isEmpty else { return nil }

            let sum = readings.reduce(0) { $0 + $1.heartRate }
            return sum / readings.count
        } catch {
            return nil
        }
    }

    // MARK: - Error Handling

    /// Clears the current sync error
    func clearError() {
        self.syncError = nil
    }

    /// Gets user-friendly error message
    ///
    /// - Parameter error: The error
    /// - Returns: Localized error message
    func errorMessage(for error: Error) -> String {
        if let healthKitError = error as? HealthKitError {
            return healthKitError.localizedDescription
        }
        return error.localizedDescription
    }
}

// MARK: - Supporting Types

/// Bundle of health data from multiple queries
struct HealthDataBundle {
    let heartRateReadings: [HeartRateReading]
    let weightReadings: [BodyWeightReading]
    let bodyFatReadings: [BodyFatReading]
}

/// Heart rate reading
struct HeartRateReading {
    let date: Date
    let heartRate: Int  // BPM
}

/// Body weight reading
struct BodyWeightReading {
    let date: Date
    let weight: Double  // kg
}

/// Body fat percentage reading
struct BodyFatReading {
    let date: Date
    let percentage: Double  // 0-100
}

/// HealthKit sync status
struct HealthKitSyncStatus {
    let isAuthorized: Bool
    let syncEnabled: Bool
    let lastSyncDate: Date?
    let syncedWorkoutCount: Int
}

/// HealthKit error types
enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case authorizationFailed
    case saveFailed
    case queryFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit ist auf diesem Gerät nicht verfügbar"
        case .notAuthorized:
            return "HealthKit-Berechtigung wurde nicht erteilt"
        case .authorizationFailed:
            return "HealthKit-Autorisierung fehlgeschlagen"
        case .saveFailed:
            return "Fehler beim Speichern in HealthKit"
        case .queryFailed:
            return "Fehler beim Abrufen von HealthKit-Daten"
        }
    }
}
