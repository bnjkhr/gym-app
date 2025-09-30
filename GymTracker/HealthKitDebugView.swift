import SwiftUI
import HealthKit

struct HealthKitDebugView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var debugInfo: [String] = []
    @State private var isRunningDiagnosis = false
    
    private var authorizationStatusText: String {
        switch workoutStore.healthKitManager.authorizationStatus {
        case .notDetermined:
            return "Nicht bestimmt"
        case .sharingDenied:
            return "Verweigert"
        case .sharingAuthorized:
            return "Autorisiert"
        @unknown default:
            return "Unbekannt"
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("HealthKit Status") {
                    HStack {
                        Text("Verfügbar")
                        Spacer()
                        Image(systemName: workoutStore.healthKitManager.isHealthDataAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(workoutStore.healthKitManager.isHealthDataAvailable ? .green : .red)
                    }
                    
                    HStack {
                        Text("Autorisiert")
                        Spacer()
                        Image(systemName: workoutStore.healthKitManager.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(workoutStore.healthKitManager.isAuthorized ? .green : .red)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(authorizationStatusText)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Debug-Informationen") {
                    if debugInfo.isEmpty {
                        Text("Tippe auf 'Diagnose starten' für detaillierte Informationen")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(debugInfo, id: \.self) { info in
                            Text(info)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Aktionen") {
                    Button("Berechtigung anfordern") {
                        requestAuthorization()
                    }
                    .disabled(isRunningDiagnosis)
                    
                    Button("Diagnose starten") {
                        runDiagnosis()
                    }
                    .disabled(isRunningDiagnosis)
                }
            }
            .navigationTitle("HealthKit Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func requestAuthorization() {
        isRunningDiagnosis = true
        debugInfo = ["🔄 Fordere HealthKit-Berechtigung an..."]
        
        Task {
            do {
                try await workoutStore.requestHealthKitAuthorization()
                
                await MainActor.run {
                    debugInfo.append("✅ Berechtigung erfolgreich angefordert")
                    debugInfo.append("   Status: \(authorizationStatusText)")
                    debugInfo.append("   Autorisiert: \(workoutStore.healthKitManager.isAuthorized)")
                    isRunningDiagnosis = false
                }
            } catch {
                await MainActor.run {
                    debugInfo.append("❌ Fehler bei Berechtigung: \(error.localizedDescription)")
                    isRunningDiagnosis = false
                }
            }
        }
    }
    
    private func runDiagnosis() {
        isRunningDiagnosis = true
        debugInfo = ["🔍 Starte HealthKit-Diagnose..."]
        
        Task {
            await MainActor.run {
                // Basic Info
                debugInfo.append("📱 HealthKit verfügbar: \(HKHealthStore.isHealthDataAvailable())")
                
                // Check individual permissions
                let healthStore = HKHealthStore()
                
                let readTypes: [(String, HKObjectType)] = [
                    ("Geburtsdatum", HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!),
                    ("Geschlecht", HKObjectType.characteristicType(forIdentifier: .biologicalSex)!),
                    ("Gewicht", HKObjectType.quantityType(forIdentifier: .bodyMass)!),
                    ("Größe", HKObjectType.quantityType(forIdentifier: .height)!),
                    ("Herzfrequenz", HKObjectType.quantityType(forIdentifier: .heartRate)!)
                ]
                
                debugInfo.append("📖 Read-Berechtigungen:")
                for (name, type) in readTypes {
                    let status = healthStore.authorizationStatus(for: type)
                    debugInfo.append("   \(name): \(statusText(for: status))")
                }
                
                let writeTypes: [(String, HKObjectType)] = [
                    ("Workout", HKObjectType.workoutType()),
                    ("Verbrannte Kalorien", HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!),
                    ("Herzfrequenz", HKObjectType.quantityType(forIdentifier: .heartRate)!)
                ]
                
                debugInfo.append("✍️ Write-Berechtigungen:")
                for (name, type) in writeTypes {
                    let status = healthStore.authorizationStatus(for: type)
                    debugInfo.append("   \(name): \(statusText(for: status))")
                }
                
                // Check Info.plist
                debugInfo.append("📋 Info.plist Check:")
                if Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil {
                    debugInfo.append("   ✅ NSHealthShareUsageDescription vorhanden")
                } else {
                    debugInfo.append("   ❌ NSHealthShareUsageDescription fehlt!")
                }
                
                if Bundle.main.object(forInfoDictionaryKey: "NSHealthUpdateUsageDescription") != nil {
                    debugInfo.append("   ✅ NSHealthUpdateUsageDescription vorhanden")
                } else {
                    debugInfo.append("   ❌ NSHealthUpdateUsageDescription fehlt!")
                }
                
                isRunningDiagnosis = false
            }
        }
    }
    
    private func statusText(for status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Nicht bestimmt"
        case .sharingDenied:
            return "Verweigert"
        case .sharingAuthorized:
            return "Autorisiert"
        @unknown default:
            return "Unbekannt"
        }
    }
}

#Preview {
    HealthKitDebugView()
        .environmentObject(WorkoutStore())
}