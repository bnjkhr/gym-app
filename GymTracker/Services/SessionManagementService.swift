import Combine
import Foundation
import HealthKit
import SwiftData

/// Service für Active Session Lifecycle Management
/// Verantwortlich für:
/// - Starten und Beenden von Workout-Sessions
/// - Herzfrequenz-Tracking während Sessions
/// - Live Activity Integration
/// - Session State Persistence
@MainActor
final class SessionManagementService: ObservableObject {

    // MARK: - Published State

    /// Die ID der aktuell aktiven Session
    @Published var activeSessionID: UUID?

    // MARK: - Private Properties

    /// HealthKit Workout Tracker für Herzfrequenz-Messung
    private var heartRateTracker: HealthKitWorkoutTracker?

    /// Abhängigkeiten
    private let sessionService: WorkoutSessionService
    private let liveActivityController: WorkoutLiveActivityController

    // MARK: - Initialization

    init(
        sessionService: WorkoutSessionService,
        liveActivityController: WorkoutLiveActivityController = .shared
    ) {
        self.sessionService = sessionService
        self.liveActivityController = liveActivityController

        // Restore active session from UserDefaults
        restoreActiveSession()
    }

    // MARK: - Session Lifecycle

    /// Startet eine neue Workout-Session
    /// - Parameter workoutId: Die ID des zu startenden Workouts
    func startSession(for workoutId: UUID) {
        do {
            guard let workoutEntity = try sessionService.prepareSessionStart(for: workoutId) else {
                print("❌ Workout mit ID \(workoutId) nicht gefunden")
                return
            }

            // Set active session
            activeSessionID = workoutId

            // Persist for recovery after force quit
            UserDefaults.standard.set(workoutId.uuidString, forKey: "activeWorkoutID")

            print("✅ Session gestartet für Workout: \(workoutEntity.name)")

            // Start heart rate tracking
            startHeartRateTracking(workoutId: workoutId, workoutName: workoutEntity.name)

        } catch WorkoutSessionService.SessionError.missingModelContext {
            print("❌ SessionManagementService: ModelContext ist nil beim Starten einer Session")
        } catch {
            print("❌ Fehler beim Starten der Session: \(error)")
        }
    }

    /// Beendet die aktuell aktive Session
    func endSession() {
        guard let sessionID = activeSessionID else {
            print("⚠️ Keine aktive Session zum Beenden")
            return
        }

        print("🔚 Session beendet für Workout-ID: \(sessionID)")

        // Clear active session
        activeSessionID = nil

        // Remove persisted state
        UserDefaults.standard.removeObject(forKey: "activeWorkoutID")

        // Stop heart rate tracking
        stopHeartRateTracking()

        // End Live Activity
        liveActivityController.end()
    }

    /// Pausiert die aktuelle Session (optional für zukünftige Features)
    func pauseSession() {
        guard activeSessionID != nil else {
            print("⚠️ Keine aktive Session zum Pausieren")
            return
        }

        // Stop heart rate tracking during pause
        stopHeartRateTracking()

        print("⏸️ Session pausiert")
    }

    /// Setzt eine pausierte Session fort
    func resumeSession() {
        guard let sessionID = activeSessionID else {
            print("⚠️ Keine Session zum Fortsetzen")
            return
        }

        // Get workout details for heart rate tracking
        if let session = sessionService.getSession(with: sessionID) {
            startHeartRateTracking(workoutId: sessionID, workoutName: session.name)
        }

        print("▶️ Session fortgesetzt")
    }

    // MARK: - Heart Rate Tracking

    /// Startet das Herzfrequenz-Tracking für die aktive Session
    /// - Parameters:
    ///   - workoutId: Die Workout-ID
    ///   - workoutName: Der Workout-Name
    private func startHeartRateTracking(workoutId: UUID, workoutName: String) {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            AppLogger.health.info(
                "[SessionManagement] HealthKit nicht verfügbar - kein Herzfrequenz-Tracking")
            return
        }

        let healthStore = HKHealthStore()
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        // Check authorization
        let status = healthStore.authorizationStatus(for: heartRateType)
        guard status == .sharingAuthorized else {
            AppLogger.health.info(
                "[SessionManagement] Keine HealthKit-Berechtigung für Herzfrequenz")
            return
        }

        // Create and configure tracker
        let tracker = HealthKitWorkoutTracker()
        tracker.onHeartRateUpdate = { [weak self] heartRate in
            guard let self = self else { return }

            // Update Live Activity with new heart rate
            // Use weak self in nested Task to prevent retain cycle
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.liveActivityController.updateHeartRate(
                    workoutId: workoutId,
                    workoutName: workoutName,
                    heartRate: heartRate
                )
            }
        }

        // Store and start tracker
        self.heartRateTracker = tracker
        tracker.startTracking()

        AppLogger.health.info(
            "[SessionManagement] Herzfrequenz-Tracking gestartet für '\(workoutName)'")
    }

    /// Stoppt das Herzfrequenz-Tracking
    private func stopHeartRateTracking() {
        guard let tracker = heartRateTracker else { return }

        tracker.stopTracking()
        heartRateTracker = nil

        AppLogger.health.info("[SessionManagement] Herzfrequenz-Tracking gestoppt")
    }

    // MARK: - State Restoration

    /// Stellt eine aktive Session nach App-Neustart wieder her
    private func restoreActiveSession() {
        guard let workoutIdString = UserDefaults.standard.string(forKey: "activeWorkoutID"),
            let workoutId = UUID(uuidString: workoutIdString)
        else {
            return
        }

        // Validate session still exists
        if sessionService.getSession(with: workoutId) != nil {
            activeSessionID = workoutId
            print("✅ Aktive Session wiederhergestellt: \(workoutId.uuidString.prefix(8))")
        } else {
            // Clean up invalid session
            UserDefaults.standard.removeObject(forKey: "activeWorkoutID")
            print("⚠️ Gespeicherte Session nicht mehr gültig")
        }
    }

    // MARK: - Public Getters

    /// Gibt an, ob aktuell eine Session aktiv ist
    var isSessionActive: Bool {
        activeSessionID != nil
    }

    /// Gibt die aktive Session zurück (falls vorhanden)
    var activeSession: WorkoutSession? {
        guard let sessionID = activeSessionID else { return nil }
        return sessionService.getSession(with: sessionID)
    }

    // MARK: - Memory Management

    /// Cleanup bei Memory Warnings
    func performMemoryCleanup() {
        // Stop heart rate tracking if no active session
        if activeSessionID == nil {
            stopHeartRateTracking()
        }

        print("[SessionManagement] Memory cleanup performed")
    }
}
