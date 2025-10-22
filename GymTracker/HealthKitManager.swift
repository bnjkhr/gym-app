import Foundation
import HealthKit
import SwiftUI

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    // HealthKit Datentypen die wir verwenden wollen
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
        HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
        HKObjectType.workoutType()
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
    ]
    
    private init() {
        checkAuthorizationStatus()
    }
    
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            print("❌ HealthKit ist auf diesem Gerät nicht verfügbar")
            throw HealthKitError.notAvailable
        }
        
        print("📱 Fordere HealthKit-Berechtigung an...")
        print("   Read types: \(readTypes.count)")
        print("   Write types: \(writeTypes.count)")
        
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        
        // Force update authorization status on main thread
        await MainActor.run {
            updateAuthorizationStatus()
        }
        
        print("✅ HealthKit-Autorisierung abgeschlossen")
        print("   Status: \(authorizationStatus)")
        print("   Autorisiert: \(isAuthorized)")
    }
    
    private func checkAuthorizationStatus() {
        guard isHealthDataAvailable else { 
            print("❌ HealthKit nicht verfügbar - kann Status nicht prüfen")
            let wasAuthorized = isAuthorized
            let prevStatus = authorizationStatus
            
            if wasAuthorized || prevStatus != .notDetermined {
                isAuthorized = false
                authorizationStatus = .notDetermined
            }
            return 
        }
        
        // Prüfe verschiedene Datentypen für eine genauere Diagnose
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let workoutType = HKObjectType.workoutType()
        
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)
        let bodyMassStatus = healthStore.authorizationStatus(for: bodyMassType)
        let workoutShareStatus = healthStore.authorizationStatus(for: workoutType)
        
        print("📊 HealthKit Authorization Status:")
        print("   Herzfrequenz: \(heartRateStatus.debugDescription)")
        print("   Körpergewicht: \(bodyMassStatus.debugDescription)")
        print("   Workout (Schreiben): \(workoutShareStatus.debugDescription)")
        
        // Einfachere und stabilere Autorisierungslogik
        let newIsAuthorized = heartRateStatus == .sharingAuthorized || 
                             bodyMassStatus == .sharingAuthorized ||
                             workoutShareStatus == .sharingAuthorized
        
        let newAuthorizationStatus: HKAuthorizationStatus
        if newIsAuthorized {
            newAuthorizationStatus = .sharingAuthorized
        } else if heartRateStatus == .sharingDenied && bodyMassStatus == .sharingDenied {
            newAuthorizationStatus = .sharingDenied
        } else {
            newAuthorizationStatus = .notDetermined
        }
        
        // Nur aktualisieren wenn sich der Status wirklich geändert hat
        if isAuthorized != newIsAuthorized {
            isAuthorized = newIsAuthorized
        }
        
        if authorizationStatus != newAuthorizationStatus {
            authorizationStatus = newAuthorizationStatus
        }
        
        print("   Gesamt-Status: \(isAuthorized ? "✅ Autorisiert" : "❌ Nicht autorisiert")")
    }
    
    func updateAuthorizationStatus() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Profile Data Reading
    
    func readProfileData() async throws -> HealthKitProfileData {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        print("📊 Starte HealthKit-Datenimport...")
        
        // Mit Timeout für den gesamten Import
        let profileData = try await withTimeout(seconds: 30) {
            async let birthDate = self.readBirthDate()
            async let weight = self.readWeight()
            async let height = self.readHeight()
            async let biologicalSex = self.readBiologicalSex()
            
            print("   • Lese Profildaten parallel...")
            
            let results = try await (
                birthDate: birthDate,
                weight: weight,
                height: height,
                biologicalSex: biologicalSex
            )
            
            print("✅ HealthKit-Datenimport abgeschlossen")
            print("   • Geburtsdatum: \(results.birthDate != nil ? "✓" : "✗")")
            print("   • Gewicht: \(results.weight != nil ? "✓" : "✗")")
            print("   • Größe: \(results.height != nil ? "✓" : "✗")")
            
            return HealthKitProfileData(
                birthDate: results.birthDate,
                weight: results.weight,
                height: results.height,
                biologicalSex: results.biologicalSex
            )
        }
        
        return profileData
    }
    
    private func readBirthDate() throws -> Date? {
        do {
            print("   • Lese Geburtsdatum...")
            let birthDateComponents = try healthStore.dateOfBirthComponents()
            let birthDate = Calendar.current.date(from: birthDateComponents)
            print("   • Geburtsdatum: \(birthDate != nil ? "✓" : "✗")")
            return birthDate
        } catch {
            print("❌ Fehler beim Lesen des Geburtsdatums: \(error)")
            return nil
        }
    }
    
    private func readWeight() async throws -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withTimeout(seconds: 10) {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: weightType,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        print("❌ Fehler beim Lesen des Gewichts: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let sample = samples?.first as? HKQuantitySample else {
                        print("   • Kein Gewichtswert in HealthKit gefunden")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    print("   • Gewicht: \(weightInKg) kg")
                    continuation.resume(returning: weightInKg)
                }
                
                self.healthStore.execute(query)
            }
        }
    }
    
    private func readHeight() async throws -> Double? {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withTimeout(seconds: 10) {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: heightType,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        print("❌ Fehler beim Lesen der Größe: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let sample = samples?.first as? HKQuantitySample else {
                        print("   • Keine Größe in HealthKit gefunden")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let heightInCm = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
                    print("   • Größe: \(heightInCm) cm")
                    continuation.resume(returning: heightInCm)
                }
                
                self.healthStore.execute(query)
            }
        }
    }
    
    private func readBiologicalSex() throws -> HKBiologicalSex? {
        do {
            print("   • Lese Geschlecht...")
            let sexObject = try healthStore.biologicalSex()
            print("   • Geschlecht: \(sexObject.biologicalSex.displayName)")
            return sexObject.biologicalSex
        } catch {
            print("❌ Fehler beim Lesen des Geschlechts: \(error)")
            return nil
        }
    }
    
    // MARK: - Heart Rate Reading
    
    func readHeartRate(from startDate: Date, to endDate: Date) async throws -> [HeartRateReading] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        // Begrenze die Anzahl der Herzfrequenz-Messwerte um Memory-Probleme zu vermeiden
        let maxSamples = 1000 // Maximal 1000 Messwerte
        
        return try await withTimeout(seconds: 20) {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: maxSamples, // Nicht mehr unbegrenzt!
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        print("❌ Fehler beim Lesen der Herzfrequenz: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let heartRateReadings = samples?.compactMap { sample -> HeartRateReading? in
                        guard let quantitySample = sample as? HKQuantitySample else { return nil }
                        
                        let heartRate = quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                        return HeartRateReading(
                            timestamp: quantitySample.startDate,
                            heartRate: heartRate
                        )
                    } ?? []
                    
                    print("   • \(heartRateReadings.count) Herzfrequenz-Messwerte geladen")
                    continuation.resume(returning: heartRateReadings)
                }
                
                self.healthStore.execute(query)
            }
        }
    }

    /// Liest NUR Ruhepuls-Daten (nicht während Training)
    /// ⚠️ Apple Watch misst den Ruhepuls automatisch im Hintergrund, meist nachts/in Ruhe
    func readRestingHeartRate(from startDate: Date, to endDate: Date) async throws -> [HeartRateReading] {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.invalidType
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withTimeout(seconds: 20) {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: restingHRType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        print("❌ Fehler beim Lesen des Ruhepulses: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }

                    let restingHRReadings = samples?.compactMap { sample -> HeartRateReading? in
                        guard let quantitySample = sample as? HKQuantitySample else { return nil }

                        let heartRate = quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                        return HeartRateReading(
                            timestamp: quantitySample.startDate,
                            heartRate: heartRate
                        )
                    } ?? []

                    print("   • \(restingHRReadings.count) Ruhepuls-Messwerte geladen")
                    continuation.resume(returning: restingHRReadings)
                }

                self.healthStore.execute(query)
            }
        }
    }

    // MARK: - Workout Writing
    
    func saveWorkout(_ workoutSession: WorkoutSessionV1) async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        // Map workout type
        let hkWorkoutType = mapToHKWorkoutActivityType(from: workoutSession)
        
        // Calculate calories if possible
        let totalCalories = calculateEstimatedCalories(for: workoutSession)
        
        // Create workout
        let workout = HKWorkout(
            activityType: hkWorkoutType,
            start: workoutSession.date,
            end: workoutSession.date.addingTimeInterval(workoutSession.duration ?? 3600), // Default 1 hour if no duration
            duration: workoutSession.duration ?? 3600,
            totalEnergyBurned: totalCalories > 0 ? HKQuantity(unit: .kilocalorie(), doubleValue: totalCalories) : nil,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "Workout App",
                "WorkoutName": workoutSession.name,
                "ExerciseCount": workoutSession.exercises.count
            ]
        )
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.healthStore.save(workout) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.saveFailed)
                }
            }
        }
    }
    
    private func mapToHKWorkoutActivityType(from session: WorkoutSessionV1) -> HKWorkoutActivityType {
        // Hier könnte man basierend auf den Übungen intelligenter mappen
        // Für jetzt verwenden wir einen generischen Typ
        .functionalStrengthTraining
    }
    
    private func calculateEstimatedCalories(for session: WorkoutSessionV1) -> Double {
        // Einfache Schätzung: 5-8 Kalorien pro Minute für Krafttraining
        guard let duration = session.duration else { return 0 }
        let minutes = duration / 60.0
        return minutes * 6.5 // Durchschnittswert
    }
    
    // MARK: - Health Data Reading
    
    func readWeight(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading] {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withTimeout(seconds: 20) {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: weightType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        print("❌ Fehler beim Lesen der Gewichtsdaten: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let weightReadings = samples?.compactMap { sample -> BodyWeightReading? in
                        guard let quantitySample = sample as? HKQuantitySample else { return nil }
                        
                        let weight = quantitySample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                        return BodyWeightReading(
                            date: quantitySample.startDate,
                            weight: weight
                        )
                    } ?? []
                    
                    print("   • \(weightReadings.count) Gewichtsmessungen geladen")
                    continuation.resume(returning: weightReadings)
                }
                
                self.healthStore.execute(query)
            }
        }
    }
    
    func readBodyFat(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading] {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withTimeout(seconds: 20) {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: bodyFatType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        print("❌ Fehler beim Lesen der Körperfettdaten: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    let bodyFatReadings = samples?.compactMap { sample -> BodyFatReading? in
                        guard let quantitySample = sample as? HKQuantitySample else { return nil }
                        
                        let bodyFatPercentage = quantitySample.quantity.doubleValue(for: HKUnit.percent())
                        return BodyFatReading(
                            date: quantitySample.startDate,
                            bodyFatPercentage: bodyFatPercentage
                        )
                    } ?? []
                    
                    print("   • \(bodyFatReadings.count) Körperfett-Messungen geladen")
                    continuation.resume(returning: bodyFatReadings)
                }
                
                self.healthStore.execute(query)
            }
        }
    }
    
    func saveWeight(_ weight: Double, date: Date) async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidType
        }
        
        let weightQuantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight)
        let weightSample = HKQuantitySample(
            type: weightType,
            quantity: weightQuantity,
            start: date,
            end: date,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.healthStore.save(weightSample) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.saveFailed)
                }
            }
        }
    }
    
    func saveBodyFatPercentage(_ fatPercentage: Double, date: Date) async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            throw HealthKitError.invalidType
        }
        
        let fatPercentageQuantity = HKQuantity(unit: HKUnit.percent(), doubleValue: fatPercentage)
        let fatPercentageSample = HKQuantitySample(
            type: bodyFatType,
            quantity: fatPercentageQuantity,
            start: date,
            end: date,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.healthStore.save(fatPercentageSample) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.saveFailed)
                }
            }
        }
    }
}

// MARK: - Data Models

struct HealthKitProfileData {
    let birthDate: Date?
    let weight: Double? // in kg
    let height: Double? // in cm
    let biologicalSex: HKBiologicalSex?
}

struct HeartRateReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let heartRate: Double // beats per minute
}

struct BodyWeightReading: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double // in kg
}

struct BodyFatReading: Identifiable {
    let id = UUID()
    let date: Date
    let bodyFatPercentage: Double // as decimal (0.0 - 1.0)
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case invalidType
    case saveFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit ist auf diesem Gerät nicht verfügbar"
        case .notAuthorized:
            return "Zugriff auf HealthKit wurde nicht gewährt"
        case .invalidType:
            return "Ungültiger HealthKit-Datentyp"
        case .saveFailed:
            return "Fehler beim Speichern in HealthKit"
        case .timeout:
            return "HealthKit-Anfrage hat zu lange gedauert"
        }
    }
}

// MARK: - Timeout Helper

extension HealthKitManager {
    /// Führt eine async Operation mit Timeout aus
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Operation Task
            group.addTask {
                try await operation()
            }
            
            // Timeout Task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw HealthKitError.timeout
            }
            
            // Return first completed result
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Extensions

extension HKBiologicalSex {
    var displayName: String {
        switch self {
        case .female:
            return "Weiblich"
        case .male:
            return "Männlich"
        case .other:
            return "Divers"
        case .notSet:
            return "Nicht angegeben"
        @unknown default:
            return "Unbekannt"
        }
    }
}

extension HKAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined:
            return "Nicht bestimmt"
        case .sharingDenied:
            return "Verweigert"
        case .sharingAuthorized:
            return "Autorisiert"
        @unknown default:
            return "Unbekannt (\(rawValue))"
        }
    }
}
