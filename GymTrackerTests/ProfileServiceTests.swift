//
//  ProfileServiceTests.swift
//  GymTrackerTests
//
//  Created by Claude on 2025-10-20.
//  Unit tests for ProfileService
//

import HealthKit
import SwiftData
import XCTest

@testable import GymBo

@MainActor
final class ProfileServiceTests: XCTestCase {

    var service: ProfileService!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        service = ProfileService()
        context = try createTestContext()
        // Clear UserDefaults for clean tests
        clearUserDefaults()
    }

    override func tearDown() async throws {
        service = nil
        context = nil
        clearUserDefaults()
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func clearUserDefaults() {
        // Clear the profile from UserDefaults
        UserDefaults.standard.removeObject(forKey: "userProfile")
    }

    // MARK: - Load Profile Tests

    func testLoadProfile_WithNilContext_ReturnsDefaultProfile() {
        let profile = service.loadProfile(context: nil)

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile.name, "")
        XCTAssertNil(profile.weight)
        XCTAssertNil(profile.height)
    }

    func testLoadProfile_WithEmptyDatabase_ReturnsDefaultProfile() {
        let profile = service.loadProfile(context: context)

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile.name, "")
        XCTAssertEqual(profile.goal, .general)
        XCTAssertEqual(profile.experience, .intermediate)
    }

    func testLoadProfile_WithExistingProfile_ReturnsStoredProfile() {
        // Create a profile first
        let updated = service.updateProfile(
            context: context,
            name: "Test User",
            birthDate: Date(),
            weight: 75.0,
            height: 180.0,
            biologicalSex: .male,
            goal: .weightLoss,
            experience: .advanced,
            equipment: .machines,
            preferredDuration: .long,
            healthKitSyncEnabled: true
        )

        // Load it
        let loaded = service.loadProfile(context: context)

        XCTAssertEqual(loaded.name, "Test User")
        XCTAssertEqual(loaded.weight, 75.0)
        XCTAssertEqual(loaded.height, 180.0)
        XCTAssertEqual(loaded.goal, .weightLoss)
        XCTAssertEqual(loaded.experience, .advanced)
        XCTAssertEqual(loaded.equipment, .machines)
        XCTAssertEqual(loaded.healthKitSyncEnabled, true)
    }

    // MARK: - Update Profile Tests

    func testUpdateProfile_CreatesNewProfile() {
        let profile = service.updateProfile(
            context: context,
            name: "John Doe",
            birthDate: nil,
            weight: 80.0,
            height: 175.0,
            biologicalSex: .male,
            goal: .muscleBuilding,
            experience: .beginner,
            equipment: .freeWeights,
            preferredDuration: .medium,
            healthKitSyncEnabled: false
        )

        XCTAssertEqual(profile.name, "John Doe")
        XCTAssertEqual(profile.weight, 80.0)
        XCTAssertEqual(profile.height, 175.0)
        XCTAssertEqual(profile.goal, .muscleBuilding)
        XCTAssertEqual(profile.experience, .beginner)
    }

    func testUpdateProfile_UpdatesExistingProfile() {
        // Create initial profile
        _ = service.updateProfile(
            context: context,
            name: "Initial Name",
            birthDate: nil,
            weight: 70.0,
            height: 170.0,
            biologicalSex: .male,
            goal: .muscleBuilding,
            experience: .beginner,
            equipment: .freeWeights,
            preferredDuration: .short,
            healthKitSyncEnabled: false
        )

        // Update it
        let updated = service.updateProfile(
            context: context,
            name: "Updated Name",
            birthDate: nil,
            weight: 75.0,
            height: 175.0,
            biologicalSex: .male,
            goal: .weightLoss,
            experience: .advanced,
            equipment: .machines,
            preferredDuration: .long,
            healthKitSyncEnabled: true
        )

        XCTAssertEqual(updated.name, "Updated Name")
        XCTAssertEqual(updated.weight, 75.0)
        XCTAssertEqual(updated.height, 175.0)
        XCTAssertEqual(updated.goal, .weightLoss)
        XCTAssertEqual(updated.experience, .advanced)
        XCTAssertEqual(updated.equipment, .machines)
        XCTAssertEqual(updated.healthKitSyncEnabled, true)

        // Verify it's the same profile (not a new one)
        let loaded = service.loadProfile(context: context)
        XCTAssertEqual(loaded.name, "Updated Name")
    }

    func testUpdateProfile_WithNilContext_UsesUserDefaults() {
        let profile = service.updateProfile(
            context: nil,
            name: "UserDefaults User",
            birthDate: nil,
            weight: 65.0,
            height: 165.0,
            biologicalSex: .female,
            goal: .endurance,
            experience: .intermediate,
            equipment: .mixed,
            preferredDuration: .medium,
            healthKitSyncEnabled: false
        )

        XCTAssertEqual(profile.name, "UserDefaults User")
        XCTAssertEqual(profile.weight, 65.0)

        // Verify it's saved to UserDefaults
        let loaded = service.loadProfile(context: nil)
        XCTAssertEqual(loaded.name, "UserDefaults User")
    }

    func testUpdateProfile_SetsUpdatedAt() {
        let before = Date()

        let profile = service.updateProfile(
            context: context,
            name: "Test",
            birthDate: nil,
            weight: nil,
            height: nil,
            biologicalSex: nil,
            goal: .muscleBuilding,
            experience: .beginner,
            equipment: .freeWeights,
            preferredDuration: .short,
            healthKitSyncEnabled: false
        )

        let after = Date()

        XCTAssertGreaterThanOrEqual(profile.updatedAt, before)
        XCTAssertLessThanOrEqual(profile.updatedAt, after)
    }

    // MARK: - Update Profile Image Tests

    func testUpdateProfileImageData_UpdatesImage() {
        // Create initial profile
        _ = service.updateProfile(
            context: context,
            name: "Test User",
            birthDate: nil,
            weight: nil,
            height: nil,
            biologicalSex: nil,
            goal: .muscleBuilding,
            experience: .beginner,
            equipment: .freeWeights,
            preferredDuration: .short,
            healthKitSyncEnabled: false
        )

        // Update image
        let imageData = Data([0x01, 0x02, 0x03, 0x04])
        let updated = service.updateProfileImageData(imageData, context: context)

        XCTAssertEqual(updated.profileImageData, imageData)

        // Verify it persists
        let loaded = service.loadProfile(context: context)
        XCTAssertEqual(loaded.profileImageData, imageData)
    }

    func testUpdateProfileImageData_WithNilData_DoesNotClearImage() {
        // Create profile with image
        let imageData = Data([0x01, 0x02, 0x03, 0x04])
        _ = service.updateProfile(
            context: context,
            name: "Test",
            birthDate: nil,
            weight: nil,
            height: nil,
            biologicalSex: nil,
            goal: .muscleBuilding,
            experience: .beginner,
            equipment: .freeWeights,
            preferredDuration: .short,
            healthKitSyncEnabled: false,
            profileImageData: imageData
        )

        // Try to clear image with nil (but it won't actually clear due to implementation)
        let updated = service.updateProfileImageData(nil, context: context)

        // Image should still be there (current behavior - known limitation)
        XCTAssertEqual(updated.profileImageData, imageData)
    }

    // MARK: - Update Locker Number Tests

    func testUpdateLockerNumber_SetsLockerNumber() {
        // Create initial profile
        _ = service.updateProfile(
            context: context,
            name: "Test",
            birthDate: nil,
            weight: nil,
            height: nil,
            biologicalSex: nil,
            goal: .muscleBuilding,
            experience: .beginner,
            equipment: .freeWeights,
            preferredDuration: .short,
            healthKitSyncEnabled: false
        )

        let updated = service.updateLockerNumber("42", context: context)

        XCTAssertEqual(updated.lockerNumber, "42")

        // Verify it persists
        let loaded = service.loadProfile(context: context)
        XCTAssertEqual(loaded.lockerNumber, "42")
    }

    func testUpdateLockerNumber_WithEmptyString_ClearsLockerNumber() {
        // Create profile with locker number
        _ = service.updateLockerNumber("42", context: context)

        // Clear it with empty string
        let updated = service.updateLockerNumber("", context: context)

        XCTAssertNil(updated.lockerNumber)
    }

    func testUpdateLockerNumber_WithNil_ClearsLockerNumber() {
        // Create profile with locker number
        _ = service.updateLockerNumber("42", context: context)

        // Clear it with nil
        let updated = service.updateLockerNumber(nil, context: context)

        XCTAssertNil(updated.lockerNumber)
    }

    // MARK: - Onboarding Tests

    func testMarkOnboardingStep_HasExploredWorkouts() {
        let profile = service.markOnboardingStep(
            context: context,
            hasExploredWorkouts: true,
            hasCreatedFirstWorkout: nil,
            hasSetupProfile: nil
        )

        XCTAssertTrue(profile.hasExploredWorkouts)
        XCTAssertFalse(profile.hasCreatedFirstWorkout)
        XCTAssertFalse(profile.hasSetupProfile)
    }

    func testMarkOnboardingStep_HasCreatedFirstWorkout() {
        let profile = service.markOnboardingStep(
            context: context,
            hasExploredWorkouts: nil,
            hasCreatedFirstWorkout: true,
            hasSetupProfile: nil
        )

        XCTAssertFalse(profile.hasExploredWorkouts)
        XCTAssertTrue(profile.hasCreatedFirstWorkout)
        XCTAssertFalse(profile.hasSetupProfile)
    }

    func testMarkOnboardingStep_HasSetupProfile() {
        let profile = service.markOnboardingStep(
            context: context,
            hasExploredWorkouts: nil,
            hasCreatedFirstWorkout: nil,
            hasSetupProfile: true
        )

        XCTAssertFalse(profile.hasExploredWorkouts)
        XCTAssertFalse(profile.hasCreatedFirstWorkout)
        XCTAssertTrue(profile.hasSetupProfile)
    }

    func testMarkOnboardingStep_AllSteps() {
        let profile = service.markOnboardingStep(
            context: context,
            hasExploredWorkouts: true,
            hasCreatedFirstWorkout: true,
            hasSetupProfile: true
        )

        XCTAssertTrue(profile.hasExploredWorkouts)
        XCTAssertTrue(profile.hasCreatedFirstWorkout)
        XCTAssertTrue(profile.hasSetupProfile)
    }

    func testMarkOnboardingStep_PreservesExistingSteps() {
        // Mark first step
        _ = service.markOnboardingStep(
            context: context,
            hasExploredWorkouts: true,
            hasCreatedFirstWorkout: nil,
            hasSetupProfile: nil
        )

        // Mark second step
        let profile = service.markOnboardingStep(
            context: context,
            hasExploredWorkouts: nil,
            hasCreatedFirstWorkout: true,
            hasSetupProfile: nil
        )

        // Both should be true
        XCTAssertTrue(profile.hasExploredWorkouts)
        XCTAssertTrue(profile.hasCreatedFirstWorkout)
        XCTAssertFalse(profile.hasSetupProfile)
    }

    func testMarkOnboardingStep_CanUnmarkStep() {
        // Mark step
        _ = service.markOnboardingStep(
            context: context,
            hasExploredWorkouts: true,
            hasCreatedFirstWorkout: nil,
            hasSetupProfile: nil
        )

        // Unmark it
        let profile = service.markOnboardingStep(
            context: context,
            hasExploredWorkouts: false,
            hasCreatedFirstWorkout: nil,
            hasSetupProfile: nil
        )

        XCTAssertFalse(profile.hasExploredWorkouts)
    }

    // MARK: - Edge Cases

    func testUpdateProfile_WithBirthDate() {
        let birthDate = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1))!

        let profile = service.updateProfile(
            context: context,
            name: "Test",
            birthDate: birthDate,
            weight: nil,
            height: nil,
            biologicalSex: nil,
            goal: .muscleBuilding,
            experience: .beginner,
            equipment: .freeWeights,
            preferredDuration: .short,
            healthKitSyncEnabled: false
        )

        XCTAssertEqual(profile.birthDate, birthDate)
    }

    func testUpdateProfile_WithAllBiologicalSexOptions() {
        for sex in [HKBiologicalSex.notSet, .female, .male, .other] {
            let profile = service.updateProfile(
                context: context,
                name: "Test",
                birthDate: nil,
                weight: nil,
                height: nil,
                biologicalSex: sex,
                goal: .muscleBuilding,
                experience: .beginner,
                equipment: .freeWeights,
                preferredDuration: .short,
                healthKitSyncEnabled: false
            )

            XCTAssertEqual(profile.biologicalSex, sex)
        }
    }

    func testLoadProfile_RestoresFromUserDefaultsBackup() {
        // Create profile in UserDefaults (simulating a previous save)
        let userDefaultsProfile = service.updateProfile(
            context: nil,
            name: "Backup User",
            birthDate: nil,
            weight: 70.0,
            height: nil,
            biologicalSex: nil,
            goal: .endurance,
            experience: .advanced,
            equipment: .machines,
            preferredDuration: .medium,
            healthKitSyncEnabled: false
        )

        // Load with a new context (simulating fresh database)
        let newContext = try! createTestContext()
        let loaded = service.loadProfile(context: newContext)

        // Should restore from UserDefaults backup
        XCTAssertEqual(loaded.name, "Backup User")
        XCTAssertEqual(loaded.weight, 70.0)
        XCTAssertEqual(loaded.goal, .endurance)
    }
}
