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
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.workoutType()
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!
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
        await updateAuthorizationStatus()
        
        print("✅ HealthKit-Autorisierung abgeschlossen")
        print("   Status: \(authorizationStatus)")
        print("   Autorisiert: \(isAuthorized)")
    }
    
    private func checkAuthorizationStatus() {
        guard isHealthDataAvailable else { 
            print("❌ HealthKit nicht verfügbar - kann Status nicht prüfen")
            return 
        }
        
        // Prüfe verschiedene Datentypen für eine genauere Diagnose
        let birthDateType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let workoutType = HKObjectType.workoutType()
        
        let birthDateStatus = healthStore.authorizationStatus(for: birthDateType)
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)
        let workoutShareStatus = healthStore.authorizationStatus(for: workoutType)
        
        print("📊 HealthKit Authorization Status:")
        print("   Geburtsdatum: \(birthDateStatus.debugDescription)")
        print("   Herzfrequenz: \(heartRateStatus.debugDescription)")  
        print("   Workout (Schreiben): \(workoutShareStatus.debugDescription)")
        
        authorizationStatus = birthDateStatus
        
        // Als autorisiert gelten wir, wenn wir wenigstens Read-Zugriff haben
        isAuthorized = birthDateStatus == .sharingAuthorized || heartRateStatus == .sharingAuthorized
        
        print("   Gesamt-Status: \(isAuthorized ? "✅ Autorisiert" : "❌ Nicht autorisiert")")
    }
    
    private func updateAuthorizationStatus() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Profile Data Reading
    
    func readProfileData() async throws -> HealthKitProfileData {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        // Geburtsdatum
        let birthDate = try readBirthDate()
        
        // Gewicht (neuester Wert)
        let weight = try await readWeight()
        
        // Größe (neuester Wert)
        let height = try await readHeight()
        
        // Geschlecht
        let biologicalSex = try readBiologicalSex()
        
        return HealthKitProfileData(
            birthDate: birthDate,
            weight: weight,
            height: height,
            biologicalSex: biologicalSex
        )
    }
    
    private func readBirthDate() throws -> Date? {
        do {
            let birthDateComponents = try healthStore.dateOfBirthComponents()
            return Calendar.current.date(from: birthDateComponents)
        } catch {
            print("Fehler beim Lesen des Geburtsdatums: \(error)")
            return nil
        }
    }
    
    private func readWeight() async throws -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            // Handled in continuation
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                continuation.resume(returning: weightInKg)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func readHeight() async throws -> Double? {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let heightInCm = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
                continuation.resume(returning: heightInCm)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func readBiologicalSex() throws -> HKBiologicalSex? {
        do {
            let sexObject = try healthStore.biologicalSex()
            return sexObject.biologicalSex
        } catch {
            print("Fehler beim Lesen des Geschlechts: \(error)")
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
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
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
                
                continuation.resume(returning: heartRateReadings)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Workout Writing
    
    func saveWorkout(_ workoutSession: WorkoutSession) async throws {
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
            healthStore.save(workout) { success, error in
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
    
    private func mapToHKWorkoutActivityType(from session: WorkoutSession) -> HKWorkoutActivityType {
        // Hier könnte man basierend auf den Übungen intelligenter mappen
        // Für jetzt verwenden wir einen generischen Typ
        .functionalStrengthTraining
    }
    
    private func calculateEstimatedCalories(for session: WorkoutSession) -> Double {
        // Einfache Schätzung: 5-8 Kalorien pro Minute für Krafttraining
        guard let duration = session.duration else { return 0 }
        let minutes = duration / 60.0
        return minutes * 6.5 // Durchschnittswert
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

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case invalidType
    case saveFailed
    
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