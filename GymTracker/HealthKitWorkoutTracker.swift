import Foundation
import HealthKit
import OSLog

/// Verwaltet Live-Herzfrequenz-Tracking während eines aktiven Workouts
@MainActor
class HealthKitWorkoutTracker: ObservableObject {
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?
    private var lastUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 1.0 // Maximal alle 1 Sekunde updaten

    @Published var currentHeartRate: Int?
    @Published var isTracking = false

    var onHeartRateUpdate: ((Int) -> Void)?

    init() {}

    // MARK: - Public Methods

    /// Startet das Live-Herzfrequenz-Tracking
    func startTracking() {
        guard HKHealthStore.isHealthDataAvailable() else {
            AppLogger.health.warning("[HR Tracker] HealthKit nicht verfügbar")
            return
        }

        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            AppLogger.health.error("[HR Tracker] Herzfrequenz-Typ nicht verfügbar")
            return
        }

        // Prüfe Berechtigung
        let status = healthStore.authorizationStatus(for: heartRateType)
        guard status == .sharingAuthorized else {
            AppLogger.health.warning("[HR Tracker] Keine Berechtigung für Herzfrequenz (Status: \(status.rawValue))")
            return
        }

        // Stoppe vorherige Query falls vorhanden
        stopTracking()

        AppLogger.health.info("[HR Tracker] Starte Live-Herzfrequenz-Tracking")

        // Erstelle Query für kontinuierliche Updates
        let query = createHeartRateStreamingQuery()
        heartRateQuery = query
        healthStore.execute(query)

        isTracking = true
    }

    /// Stoppt das Live-Herzfrequenz-Tracking
    func stopTracking() {
        guard let query = heartRateQuery else { return }

        AppLogger.health.info("[HR Tracker] Stoppe Live-Herzfrequenz-Tracking")

        healthStore.stop(query)
        heartRateQuery = nil
        isTracking = false
        currentHeartRate = nil
    }

    // MARK: - Private Methods

    private func createHeartRateStreamingQuery() -> HKQuery {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            fatalError("Herzfrequenz-Typ sollte verfügbar sein")
        }

        // Nur Samples der letzten 10 Sekunden berücksichtigen
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-10),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor [weak self] in
                self?.handleHeartRateSamples(samples: samples, error: error)
            }
        }

        // Update-Handler für kontinuierliche Updates
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor [weak self] in
                self?.handleHeartRateSamples(samples: samples, error: error)
            }
        }

        return query
    }

    private func handleHeartRateSamples(samples: [HKSample]?, error: Error?) {
        if let error = error {
            AppLogger.health.error("[HR Tracker] Fehler beim Lesen der Herzfrequenz: \(error.localizedDescription)")
            return
        }

        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
            return
        }

        // Nutze den neuesten Sample
        guard let latestSample = samples.max(by: { $0.startDate < $1.startDate }) else {
            return
        }

        // Throttle Updates
        let now = Date()
        if let lastUpdate = lastUpdateTime, now.timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            return
        }
        lastUpdateTime = now

        let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        let bpm = Int(heartRate.rounded())

        // Validierung: Nur realistische Werte (30-220 BPM)
        guard (30...220).contains(bpm) else {
            AppLogger.health.warning("[HR Tracker] Unrealistischer Herzfrequenz-Wert: \(bpm) BPM")
            return
        }

        Task { @MainActor in
            self.currentHeartRate = bpm
            self.onHeartRateUpdate?(bpm)
            AppLogger.health.debug("[HR Tracker] Herzfrequenz aktualisiert: \(bpm) BPM")
        }
    }

    deinit {
        // Cleanup in deinit muss synchron sein
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
    }
}
