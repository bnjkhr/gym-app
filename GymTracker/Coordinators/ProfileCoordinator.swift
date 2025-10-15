import Combine
import Foundation
import HealthKit
import SwiftData
import SwiftUI

/// ProfileCoordinator manages all user profile-related operations
///
/// **Responsibilities:**
/// - User profile CRUD operations
/// - Profile image management
/// - Locker number management
/// - Onboarding state tracking
/// - HealthKit profile sync
///
/// **Dependencies:**
/// - ProfileService (profile persistence)
/// - HealthKitManager (HealthKit integration)
///
/// **Used by:**
/// - ProfileView
/// - ProfileEditView
/// - SettingsView
/// - WorkoutWizardView
/// - OnboardingView
@MainActor
final class ProfileCoordinator: ObservableObject {
    // MARK: - Published State

    /// Current user profile
    @Published var profile: UserProfile

    /// Trigger to force UI updates when profile changes
    /// Views can observe this to refresh when profile data changes
    @Published var profileUpdateTrigger: UUID = UUID()

    // MARK: - Dependencies

    private let profileService: ProfileService
    private let healthKitManager = HealthKitManager.shared
    private var modelContext: ModelContext?

    // MARK: - Initialization

    init(profileService: ProfileService = ProfileService()) {
        self.profileService = profileService
        self.profile = profileService.loadProfile(context: nil)
    }

    // MARK: - Context Management

    /// Sets the SwiftData context for profile operations
    /// - Parameter context: The ModelContext to use for persistence
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        refreshProfile()
    }

    /// Refreshes the profile from persistence and triggers UI update
    func refreshProfile() {
        self.profile = profileService.loadProfile(context: modelContext)
        self.profileUpdateTrigger = UUID()
    }

    // MARK: - Profile Management

    /// Updates the user profile with new values
    ///
    /// - Parameters:
    ///   - name: User's name
    ///   - birthDate: Date of birth
    ///   - weight: Body weight in kg
    ///   - height: Height in cm
    ///   - biologicalSex: Biological sex from HealthKit
    ///   - goal: Fitness goal
    ///   - experience: Experience level
    ///   - equipment: Available equipment
    ///   - preferredDuration: Preferred workout duration
    ///   - healthKitSyncEnabled: Whether HealthKit sync is enabled
    func updateProfile(
        name: String,
        birthDate: Date?,
        weight: Double?,
        height: Double?,
        biologicalSex: HKBiologicalSex?,
        goal: FitnessGoal,
        experience: ExperienceLevel,
        equipment: EquipmentPreference,
        preferredDuration: WorkoutDuration,
        healthKitSyncEnabled: Bool
    ) {
        self.profile = profileService.updateProfile(
            context: modelContext,
            name: name,
            birthDate: birthDate,
            weight: weight,
            height: height,
            biologicalSex: biologicalSex,
            goal: goal,
            experience: experience,
            equipment: equipment,
            preferredDuration: preferredDuration,
            healthKitSyncEnabled: healthKitSyncEnabled
        )
        self.profileUpdateTrigger = UUID()

        AppLogger.app.info("✅ Profil aktualisiert: \(name)")
    }

    /// Updates the profile image
    ///
    /// - Parameter image: The new profile image, or nil to remove
    func updateProfileImage(_ image: UIImage?) {
        let imageData = image?.jpegData(compressionQuality: 0.8)
        self.profile = profileService.updateProfileImageData(imageData, context: modelContext)
        self.profileUpdateTrigger = UUID()

        if image != nil {
            AppLogger.app.info("✅ Profilbild aktualisiert")
        } else {
            AppLogger.app.info("✅ Profilbild entfernt")
        }
    }

    /// Updates the locker number
    ///
    /// - Parameter lockerNumber: The new locker number, or nil to remove
    func updateLockerNumber(_ lockerNumber: String?) {
        self.profile = profileService.updateLockerNumber(lockerNumber, context: modelContext)
        self.profileUpdateTrigger = UUID()

        if let number = lockerNumber, !number.isEmpty {
            AppLogger.app.info("✅ Spintnummer aktualisiert: \(number)")
        } else {
            AppLogger.app.info("✅ Spintnummer entfernt")
        }
    }

    // MARK: - Onboarding

    /// Marks an onboarding step as completed
    ///
    /// - Parameters:
    ///   - hasExploredWorkouts: Whether user has explored workouts
    ///   - hasCreatedFirstWorkout: Whether user has created their first workout
    ///   - hasSetupProfile: Whether user has setup their profile
    func markOnboardingStep(
        hasExploredWorkouts: Bool? = nil,
        hasCreatedFirstWorkout: Bool? = nil,
        hasSetupProfile: Bool? = nil
    ) {
        self.profile = profileService.markOnboardingStep(
            context: modelContext,
            hasExploredWorkouts: hasExploredWorkouts,
            hasCreatedFirstWorkout: hasCreatedFirstWorkout,
            hasSetupProfile: hasSetupProfile
        )
        self.profileUpdateTrigger = UUID()

        var steps: [String] = []
        if hasExploredWorkouts == true { steps.append("explored workouts") }
        if hasCreatedFirstWorkout == true { steps.append("created first workout") }
        if hasSetupProfile == true { steps.append("setup profile") }

        if !steps.isEmpty {
            AppLogger.app.info(
                "✅ Onboarding-Schritte aktualisiert: \(steps.joined(separator: ", "))")
        }
    }

    /// Checks if onboarding is complete
    var isOnboardingComplete: Bool {
        return profile.hasExploredWorkouts && profile.hasCreatedFirstWorkout
            && profile.hasSetupProfile
    }

    // MARK: - HealthKit Integration

    /// Requests HealthKit authorization for profile data
    ///
    /// **Permissions requested:**
    /// - Read: Birth date, biological sex, height, weight
    /// - Write: Workout data, active energy
    ///
    /// - Throws: HealthKitError if authorization fails or HealthKit is unavailable
    func requestHealthKitAuthorization() async throws {
        AppLogger.app.info("🏥 Requesting HealthKit authorization...")

        do {
            try await healthKitManager.requestAuthorization()
            AppLogger.app.info("✅ HealthKit authorization granted")
        } catch {
            AppLogger.app.error("❌ HealthKit authorization failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Imports profile data from HealthKit
    ///
    /// **Imported data:**
    /// - Birth date
    /// - Biological sex
    /// - Height (most recent)
    /// - Weight (most recent)
    ///
    /// Updates the profile with imported data and refreshes UI.
    ///
    /// - Throws: HealthKitError if import fails or HealthKit is unavailable
    func importFromHealthKit() async throws {
        AppLogger.app.info("🏥 Importing profile from HealthKit...")

        do {
            // Request authorization first if needed
            try await healthKitManager.requestAuthorization()

            // Import data
            var birthDate: Date?
            var biologicalSex: HKBiologicalSex?
            var height: Double?
            var weight: Double?

            // Birth date
            birthDate = try? healthKitManager.readBirthDate()

            // Biological sex
            biologicalSex = try? healthKitManager.readBiologicalSex()

            // Height (in cm)
            if let heightValue = try? await healthKitManager.readHeight() {
                height = heightValue
            }

            // Weight (in kg)
            if let weightValue = try? await healthKitManager.readWeight() {
                weight = weightValue
            }

            // Update profile with imported data
            let current = profile
            self.profile = profileService.updateProfile(
                context: modelContext,
                name: current.name,
                birthDate: birthDate ?? current.birthDate,
                weight: weight ?? current.weight,
                height: height ?? current.height,
                biologicalSex: biologicalSex ?? current.biologicalSex,
                goal: current.goal,
                experience: current.experience,
                equipment: current.equipment,
                preferredDuration: current.preferredDuration,
                healthKitSyncEnabled: true  // Enable sync after import
            )
            self.profileUpdateTrigger = UUID()

            // Log success
            var importedFields: [String] = []
            if birthDate != nil { importedFields.append("birth date") }
            if biologicalSex != nil { importedFields.append("sex") }
            if height != nil { importedFields.append("height") }
            if weight != nil { importedFields.append("weight") }

            AppLogger.app.info(
                "✅ HealthKit import complete: \(importedFields.joined(separator: ", "))")

        } catch {
            AppLogger.app.error("❌ HealthKit import failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Computed Properties

    /// User's age in years (if birth date is set)
    var age: Int? {
        guard let birthDate = profile.birthDate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year], from: birthDate, to: now)
        return components.year
    }

    /// User's BMI (Body Mass Index) if height and weight are set
    var bmi: Double? {
        guard let weight = profile.weight,
            let height = profile.height,
            height > 0
        else { return nil }

        let heightInMeters = height / 100.0
        return weight / (heightInMeters * heightInMeters)
    }

    /// BMI category description (Underweight, Normal, Overweight, Obese)
    var bmiCategory: String? {
        guard let bmi = bmi else { return nil }

        switch bmi {
        case ..<18.5:
            return "Untergewicht"
        case 18.5..<25:
            return "Normalgewicht"
        case 25..<30:
            return "Übergewicht"
        case 30...:
            return "Adipositas"
        default:
            return nil
        }
    }
}
