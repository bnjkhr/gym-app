// HealthKit Permissions and Setup Guide
// Add this to your Info.plist file

/*

Required Info.plist entries:

<key>NSHealthShareUsageDescription</key>
<string>Diese App benötigt Zugriff auf HealthKit, um deine Trainingsdaten zu lesen und dein Profil zu vervollständigen.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Diese App möchte deine Workouts in HealthKit speichern, um sie mit anderen Health-Apps zu teilen.</string>

App Capabilities:
- Add HealthKit capability in Xcode
- Target → Signing & Capabilities → + Capability → HealthKit

Deployment Target:
- Minimum iOS 14.0 (for HealthKit features)

Optional - for more detailed workout tracking:
<key>NSMotionUsageDescription</key>
<string>Diese App verwendet Bewegungsdaten für genauere Workout-Aufzeichnungen.</string>

*/

import HealthKit

// MARK: - HealthKit Data Types Used

struct HealthKitPermissions {
    
    // Read Permissions
    static let readTypes: Set<HKObjectType> = [
        // Characteristics (basic profile data)
        HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
        HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
        
        // Body measurements
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,      // Weight
        HKObjectType.quantityType(forIdentifier: .height)!,        // Height
        
        // Heart rate
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        
        // Activity data
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        
        // Workout data
        HKObjectType.workoutType()
    ]
    
    // Write Permissions
    static let writeTypes: Set<HKSampleType> = [
        // Workouts
        HKObjectType.workoutType(),
        
        // Energy
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        
        // Optional: Heart rate if you want to write estimated heart rate
        // HKObjectType.quantityType(forIdentifier: .heartRate)!
    ]
    
    // Usage examples:
    /*
    
    // Request authorization
    let healthStore = HKHealthStore()
    try await healthStore.requestAuthorization(
        toShare: writeTypes,
        read: readTypes
    )
    
    // Check if HealthKit is available
    guard HKHealthStore.isHealthDataAvailable() else {
        // HealthKit not available on this device
        return
    }
    
    */
}

// MARK: - Integration Checklist

/*

✅ Implementation Checklist:

1. Add Info.plist entries (required)
2. Enable HealthKit capability in Xcode
3. Set minimum deployment target to iOS 14.0+
4. Add HealthKitManager.swift to project
5. Update UserProfile and UserProfileEntity models
6. Add HealthKit integration to WorkoutStore
7. Update ProfileEditView with import functionality
8. Add HeartRateView for heart rate tracking
9. Add HealthKit settings to SettingsView
10. Test on physical device (HealthKit doesn't work in Simulator)

📱 Testing Notes:
- HealthKit only works on physical devices
- Test with different permission states
- Test with existing Health app data
- Verify workout sync with Health app
- Check privacy settings work correctly

🔒 Privacy Considerations:
- Always respect user's privacy choices
- Provide clear explanations for data usage
- Allow users to disable sync at any time
- Handle denied permissions gracefully
- Don't repeatedly prompt for permissions

*/