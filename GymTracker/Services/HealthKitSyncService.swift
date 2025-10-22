import Foundation
import HealthKit
import SwiftData

/// Service für HealthKit Synchronisation
/// Verantwortlich für:
/// - HealthKit Authorization
/// - Profile Import von HealthKit
/// - Workout Export zu HealthKit
/// - Gesundheitsdaten-Abfragen (Herzfrequenz, Gewicht, Körperfett)
@MainActor
final class HealthKitSyncService {

    // MARK: - Properties

    private let healthKitManager: HealthKitManager
    private let profileService: ProfileService
    private var modelContext: ModelContext?

    // MARK: - Initialization

    init(
        healthKitManager: HealthKitManager = .shared,
        profileService: ProfileService
    ) {
        self.healthKitManager = healthKitManager
        self.profileService = profileService
    }

    // MARK: - Context Management

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        // Note: ProfileService doesn't store context, uses it as parameter
    }

    // MARK: - Authorization

    /// Fordert HealthKit-Berechtigung an
    /// - Throws: HealthKitError bei Fehlern
    func requestAuthorization() async throws {
        try await healthKitManager.requestAuthorization()

        // Automatically import profile data after successful authorization
        if healthKitManager.isAuthorized {
            print("🔄 HealthKit authorized - importing profile data automatically...")
            try await importProfile()
        }
    }

    /// Gibt an ob HealthKit autorisiert ist
    var isAuthorized: Bool {
        healthKitManager.isAuthorized
    }

    // MARK: - Profile Import

    /// Importiert Profildaten von HealthKit
    /// - Throws: HealthKitError bei Fehlern
    func importProfile() async throws {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        print("🏥 Starte HealthKit-Import...")

        do {
            let data = try await healthKitManager.readProfileData()

            guard let context = modelContext else {
                print("❌ ModelContext nicht verfügbar")
                throw HealthKitError.saveFailed
            }

            let descriptor = FetchDescriptor<UserProfileEntity>()

            let entity: UserProfileEntity
            if let existing = try? context.fetch(descriptor).first {
                entity = existing
            } else {
                entity = UserProfileEntity()
                context.insert(entity)
            }

            // Update only if we got valid data from HealthKit
            var updatedFields: [String] = []

            if let birthDate = data.birthDate {
                entity.birthDate = birthDate
                updatedFields.append("Geburtsdatum")
            }
            if let weight = data.weight {
                entity.weight = weight
                updatedFields.append("Gewicht")
            }
            if let height = data.height {
                entity.height = height
                updatedFields.append("Größe")
            }
            if let sex = data.biologicalSex {
                entity.biologicalSexRaw = Int16(sex.rawValue)
                updatedFields.append("Geschlecht")
            }

            entity.healthKitSyncEnabled = true
            entity.updatedAt = Date()

            try context.save()

            // Post notification for immediate UI updates
            NotificationCenter.default.post(name: .profileUpdatedFromHealthKit, object: nil)

            print("✅ HealthKit-Import erfolgreich abgeschlossen")
            print("   • Aktualisierte Felder: \(updatedFields.joined(separator: ", "))")

        } catch let error as HealthKitError {
            print("❌ HealthKit-Fehler: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Unbekannter Fehler beim HealthKit-Import: \(error)")
            throw HealthKitError.saveFailed
        }
    }

    // MARK: - Workout Export

    /// Exportiert eine Workout-Session zu HealthKit
    /// - Parameter session: Die WorkoutSession zum Exportieren
    /// - Throws: HealthKitError bei Fehlern
    func saveWorkout(_ session: WorkoutSessionV1) async throws {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        // Check if user has enabled HealthKit sync
        let profile = profileService.loadProfile(context: modelContext)
        guard profile.healthKitSyncEnabled else {
            print("ℹ️ HealthKit Sync ist deaktiviert")
            return
        }

        try await healthKitManager.saveWorkout(session)
        print("✅ Workout zu HealthKit exportiert: \(session.name)")
    }

    /// Exportiert mehrere Sessions zu HealthKit
    /// - Parameter sessions: Array von WorkoutSessions
    /// - Returns: Anzahl erfolgreich exportierter Sessions
    func saveWorkouts(_ sessions: [WorkoutSession]) async -> Int {
        guard healthKitManager.isAuthorized else {
            print("❌ HealthKit nicht autorisiert")
            return 0
        }

        let profile = profileService.loadProfile(context: modelContext)
        guard profile.healthKitSyncEnabled else {
            print("ℹ️ HealthKit Sync ist deaktiviert")
            return 0
        }

        var successCount = 0

        for session in sessions {
            do {
                try await healthKitManager.saveWorkout(session)
                successCount += 1
            } catch {
                print("⚠️ Fehler beim Export von '\(session.name)': \(error.localizedDescription)")
            }
        }

        print("✅ \(successCount)/\(sessions.count) Workouts zu HealthKit exportiert")
        return successCount
    }

    // MARK: - Health Data Queries

    /// Liest Herzfrequenz-Daten aus HealthKit
    /// - Parameters:
    ///   - startDate: Startdatum
    ///   - endDate: Enddatum
    /// - Returns: Array von HeartRateReading
    /// - Throws: HealthKitError bei Fehlern
    func readHeartRateData(from startDate: Date, to endDate: Date) async throws
        -> [HeartRateReading]
    {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        return try await healthKitManager.readHeartRate(from: startDate, to: endDate)
    }

    /// Liest Gewichtsdaten aus HealthKit
    /// - Parameters:
    ///   - startDate: Startdatum
    ///   - endDate: Enddatum
    /// - Returns: Array von BodyWeightReading
    /// - Throws: HealthKitError bei Fehlern
    func readWeightData(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading]
    {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        return try await healthKitManager.readWeight(from: startDate, to: endDate)
    }

    /// Liest Körperfettdaten aus HealthKit
    /// - Parameters:
    ///   - startDate: Startdatum
    ///   - endDate: Enddatum
    /// - Returns: Array von BodyFatReading
    /// - Throws: HealthKitError bei Fehlern
    func readBodyFatData(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading] {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        return try await healthKitManager.readBodyFat(from: startDate, to: endDate)
    }

    // MARK: - Batch Operations

    /// Liest alle verfügbaren Gesundheitsdaten für einen Zeitraum
    /// - Parameters:
    ///   - startDate: Startdatum
    ///   - endDate: Enddatum
    /// - Returns: HealthDataBundle mit allen verfügbaren Daten
    func readAllHealthData(from startDate: Date, to endDate: Date) async throws -> HealthDataBundle
    {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        async let heartRate = try await readHeartRateData(from: startDate, to: endDate)
        async let weight = try await readWeightData(from: startDate, to: endDate)
        async let bodyFat = try await readBodyFatData(from: startDate, to: endDate)

        return try await HealthDataBundle(
            heartRateReadings: heartRate,
            weightReadings: weight,
            bodyFatReadings: bodyFat,
            startDate: startDate,
            endDate: endDate
        )
    }

    // MARK: - Sync Status

    /// Prüft den Sync-Status
    /// - Returns: HealthKitSyncStatus
    func getSyncStatus() -> HealthKitSyncStatus {
        let isAuthorized = healthKitManager.isAuthorized
        let profile = profileService.loadProfile(context: modelContext)
        let isSyncEnabled = profile.healthKitSyncEnabled

        return HealthKitSyncStatus(
            isAuthorized: isAuthorized,
            isSyncEnabled: isSyncEnabled,
            canSync: isAuthorized && isSyncEnabled
        )
    }

    /// Aktiviert HealthKit Sync für das User-Profil
    func enableSync() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<UserProfileEntity>()
        guard let entity = try? context.fetch(descriptor).first else { return }

        entity.healthKitSyncEnabled = true
        entity.updatedAt = Date()

        try? context.save()

        print("✅ HealthKit Sync aktiviert")
    }

    /// Deaktiviert HealthKit Sync für das User-Profil
    func disableSync() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<UserProfileEntity>()
        guard let entity = try? context.fetch(descriptor).first else { return }

        entity.healthKitSyncEnabled = false
        entity.updatedAt = Date()

        try? context.save()

        print("✅ HealthKit Sync deaktiviert")
    }
}

// MARK: - Supporting Types

struct HealthDataBundle {
    let heartRateReadings: [HeartRateReading]
    let weightReadings: [BodyWeightReading]
    let bodyFatReadings: [BodyFatReading]
    let startDate: Date
    let endDate: Date

    var hasData: Bool {
        !heartRateReadings.isEmpty || !weightReadings.isEmpty || !bodyFatReadings.isEmpty
    }
}

struct HealthKitSyncStatus {
    let isAuthorized: Bool
    let isSyncEnabled: Bool
    let canSync: Bool

    var statusMessage: String {
        if !isAuthorized {
            return "HealthKit nicht autorisiert"
        }
        if !isSyncEnabled {
            return "Sync deaktiviert"
        }
        return "Sync aktiv"
    }
}
