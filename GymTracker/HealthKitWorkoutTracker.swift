import Foundation
import HealthKit
import OSLog

/// Verwaltet Live-Herzfrequenz-Tracking während eines aktiven Workouts
@MainActor
class HealthKitWorkoutTracker: ObservableObject {
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?
    private var pollingTimer: Timer?
    private var lastUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 1.0 // Maximal alle 1 Sekunde updaten
    private let pollingInterval: TimeInterval = 3.0 // Alle 3 Sekunden aktiv abfragen

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

        // Erstelle Observer Query für Updates bei neuen Samples
        let query = createHeartRateStreamingQuery()
        heartRateQuery = query
        healthStore.execute(query)

        isTracking = true

        // Hole sofort den aktuellen Wert beim Start
        Task {
            await fetchLatestHeartRate()
        }

        // Starte zusätzlichen Polling-Timer für regelmäßige Updates
        // Dies stellt sicher, dass wir auch dann Updates bekommen, wenn der Observer nicht triggert
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchLatestHeartRate()
            }
        }
    }

    /// Stoppt das Live-Herzfrequenz-Tracking
    func stopTracking() {
        AppLogger.health.info("[HR Tracker] Stoppe Live-Herzfrequenz-Tracking")

        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }

        pollingTimer?.invalidate()
        pollingTimer = nil

        isTracking = false
        currentHeartRate = nil
    }

    // MARK: - Private Methods

    private func createHeartRateStreamingQuery() -> HKQuery {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            fatalError("Herzfrequenz-Typ sollte verfügbar sein")
        }

        // Observer Query für kontinuierliche Updates - wird bei jedem neuen Sample getriggert
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                AppLogger.health.error("[HR Tracker] Observer Query Fehler: \(error.localizedDescription)")
                completionHandler()
                return
            }

            // Hole die neuesten Herzfrequenz-Samples
            Task { @MainActor [weak self] in
                await self?.fetchLatestHeartRate()
                completionHandler()
            }
        }

        return query
    }

    private func fetchLatestHeartRate() async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        // Hole nur die neuesten Samples der letzten 30 Sekunden
        let now = Date()
        let startDate = now.addingTimeInterval(-30)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictEndDate)

        // Sortiere nach Datum, neueste zuerst
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1, // Nur den neuesten Wert
                sortDescriptors: [sortDescriptor]
            ) { [weak self] query, samples, error in
                Task { @MainActor [weak self] in
                    self?.handleHeartRateSamples(samples: samples, error: error)
                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
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
        pollingTimer?.invalidate()
    }
}
