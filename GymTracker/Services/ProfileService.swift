import Foundation
import HealthKit
import SwiftData

@MainActor
final class ProfileService {
    func loadProfile(context: ModelContext?) -> UserProfile {
        guard let context else {
            return ProfilePersistenceHelper.loadFromUserDefaults()
        }

        do {
            let descriptor = FetchDescriptor<UserProfileEntity>()
            if let entity = try context.fetch(descriptor).first {
                let profile = UserProfile(entity: entity)
                ProfilePersistenceHelper.saveToUserDefaults(profile)
                return profile
            }
        } catch {
            print("⚠️ Fehler beim Laden des Profils aus SwiftData: \(error)")
            return ProfilePersistenceHelper.loadFromUserDefaults()
        }

        let backupProfile = ProfilePersistenceHelper.loadFromUserDefaults()
        if !backupProfile.name.isEmpty || backupProfile.weight != nil {
            _ = updateProfile(
                context: context,
                name: backupProfile.name,
                birthDate: backupProfile.birthDate,
                weight: backupProfile.weight,
                height: backupProfile.height,
                biologicalSex: backupProfile.biologicalSex,
                goal: backupProfile.goal,
                experience: backupProfile.experience,
                equipment: backupProfile.equipment,
                preferredDuration: backupProfile.preferredDuration,
                healthKitSyncEnabled: backupProfile.healthKitSyncEnabled,
                profileImageData: backupProfile.profileImageData,
                saveToDefaults: false
            )
            ProfilePersistenceHelper.saveToUserDefaults(backupProfile)
            print("✅ Profil aus UserDefaults-Backup wiederhergestellt")
            return backupProfile
        }

        return UserProfile()
    }

    @discardableResult
    func updateProfile(
        context: ModelContext?,
        name: String,
        birthDate: Date?,
        weight: Double?,
        height: Double?,
        biologicalSex: HKBiologicalSex?,
        goal: FitnessGoal,
        experience: ExperienceLevel,
        equipment: EquipmentPreference,
        preferredDuration: WorkoutDuration,
        healthKitSyncEnabled: Bool,
        profileImageData: Data? = nil,
        saveToDefaults: Bool = true
    ) -> UserProfile {
        let now = Date()

        if let context = context {
            do {
                let entity = try fetchOrCreateProfileEntity(in: context)
                entity.name = name
                entity.birthDate = birthDate
                entity.weight = weight
                entity.height = height
                entity.biologicalSexRaw = Int16(biologicalSex?.rawValue ?? HKBiologicalSex.notSet.rawValue)
                entity.goalRaw = goal.rawValue
                entity.experienceRaw = experience.rawValue
                entity.equipmentRaw = equipment.rawValue
                entity.preferredDurationRaw = preferredDuration.rawValue
                entity.healthKitSyncEnabled = healthKitSyncEnabled
                if let data = profileImageData {
                    entity.profileImageData = data
                }
                entity.updatedAt = now

                try context.save()
                let profile = UserProfile(entity: entity)
                if saveToDefaults {
                    ProfilePersistenceHelper.saveToUserDefaults(profile)
                }
                return profile
            } catch {
                print("❌ Fehler beim Speichern des Profils in SwiftData: \(error)")
            }
        }

        var profile = ProfilePersistenceHelper.loadFromUserDefaults()
        profile.name = name
        profile.birthDate = birthDate
        profile.weight = weight
        profile.height = height
        profile.biologicalSex = biologicalSex
        profile.goal = goal
        profile.experience = experience
        profile.equipment = equipment
        profile.preferredDuration = preferredDuration
        profile.healthKitSyncEnabled = healthKitSyncEnabled
        if let data = profileImageData {
            profile.profileImageData = data
        }
        profile.updatedAt = now
        if saveToDefaults {
            ProfilePersistenceHelper.saveToUserDefaults(profile)
        }
        return profile
    }

    @discardableResult
    func updateProfileImageData(_ data: Data?, context: ModelContext?) -> UserProfile {
        let current = loadProfile(context: context)
        return updateProfile(
            context: context,
            name: current.name,
            birthDate: current.birthDate,
            weight: current.weight,
            height: current.height,
            biologicalSex: current.biologicalSex,
            goal: current.goal,
            experience: current.experience,
            equipment: current.equipment,
            preferredDuration: current.preferredDuration,
            healthKitSyncEnabled: current.healthKitSyncEnabled,
            profileImageData: data
        )
    }

    @discardableResult
    func updateLockerNumber(_ lockerNumber: String?, context: ModelContext?) -> UserProfile {
        let sanitized = lockerNumber?.isEmpty == true ? nil : lockerNumber
        let now = Date()

        if let context = context {
            do {
                let entity = try fetchOrCreateProfileEntity(in: context)
                entity.lockerNumber = sanitized
                entity.updatedAt = now
                try context.save()
                let profile = UserProfile(entity: entity)
                ProfilePersistenceHelper.saveToUserDefaults(profile)
                return profile
            } catch {
                print("❌ Fehler beim Aktualisieren der Spintnummer: \(error)")
            }
        }

        var profile = ProfilePersistenceHelper.loadFromUserDefaults()
        profile.lockerNumber = sanitized
        profile.updatedAt = now
        ProfilePersistenceHelper.saveToUserDefaults(profile)
        return profile
    }

    @discardableResult
    func markOnboardingStep(
        context: ModelContext?,
        hasExploredWorkouts: Bool?,
        hasCreatedFirstWorkout: Bool?,
        hasSetupProfile: Bool?
    ) -> UserProfile {
        let now = Date()

        if let context = context {
            do {
                let entity = try fetchOrCreateProfileEntity(in: context)
                if let explored = hasExploredWorkouts {
                    entity.hasExploredWorkouts = explored
                }
                if let created = hasCreatedFirstWorkout {
                    entity.hasCreatedFirstWorkout = created
                }
                if let setup = hasSetupProfile {
                    entity.hasSetupProfile = setup
                }
                entity.updatedAt = now
                try context.save()
                let profile = UserProfile(entity: entity)
                ProfilePersistenceHelper.saveToUserDefaults(profile)
                return profile
            } catch {
                print("❌ Fehler beim Aktualisieren des Onboarding-Status: \(error)")
            }
        }

        var profile = ProfilePersistenceHelper.loadFromUserDefaults()
        if let explored = hasExploredWorkouts {
            profile.hasExploredWorkouts = explored
        }
        if let created = hasCreatedFirstWorkout {
            profile.hasCreatedFirstWorkout = created
        }
        if let setup = hasSetupProfile {
            profile.hasSetupProfile = setup
        }
        profile.updatedAt = now
        ProfilePersistenceHelper.saveToUserDefaults(profile)
        return profile
    }

    // MARK: - Helpers

    private func fetchOrCreateProfileEntity(in context: ModelContext) throws -> UserProfileEntity {
        let descriptor = FetchDescriptor<UserProfileEntity>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let entity = UserProfileEntity()
        context.insert(entity)
        return entity
    }
}
