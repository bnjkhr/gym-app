import Foundation
import SwiftUI
import HealthKit

struct UserProfile: Codable {
    let id: UUID
    var name: String
    var birthDate: Date?
    var weight: Double? // in kg
    var height: Double? // in cm
    var biologicalSex: HKBiologicalSex?
    var goal: FitnessGoal
    var experience: ExperienceLevel = .intermediate
    var equipment: EquipmentPreference = .mixed
    var preferredDuration: WorkoutDuration = .medium
    var profileImageData: Data?
    var healthKitSyncEnabled: Bool = false
    var lockerNumber: String? // Spintnummer
    var hasExploredWorkouts: Bool = false // Onboarding: Beispielworkouts entdeckt
    var hasCreatedFirstWorkout: Bool = false // Onboarding: Erstes Workout erstellt
    var hasSetupProfile: Bool = false // Onboarding: Profil eingerichtet
    var createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, name, birthDate, weight, height, biologicalSex, goal, profileImageData, createdAt, updatedAt, experience, equipment, preferredDuration, healthKitSyncEnabled, lockerNumber, hasExploredWorkouts, hasCreatedFirstWorkout, hasSetupProfile
    }
    
    init(id: UUID = UUID(), name: String = "", birthDate: Date? = nil, weight: Double? = nil, height: Double? = nil, biologicalSex: HKBiologicalSex? = nil, goal: FitnessGoal = .general, profileImageData: Data? = nil, experience: ExperienceLevel = .intermediate, equipment: EquipmentPreference = .mixed, preferredDuration: WorkoutDuration = .medium, healthKitSyncEnabled: Bool = false, lockerNumber: String? = nil) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.weight = weight
        self.height = height
        self.biologicalSex = biologicalSex
        self.goal = goal
        self.profileImageData = profileImageData
        self.createdAt = Date()
        self.updatedAt = Date()
        self.experience = experience
        self.equipment = equipment
        self.preferredDuration = preferredDuration
        self.healthKitSyncEnabled = healthKitSyncEnabled
        self.lockerNumber = lockerNumber
        self.hasExploredWorkouts = false
        self.hasCreatedFirstWorkout = false
        self.hasSetupProfile = false
    }
    
    init(entity: UserProfileEntity) {
        self.id = entity.id
        self.name = entity.name
        self.birthDate = entity.birthDate
        self.weight = entity.weight
        self.height = entity.height
        self.biologicalSex = HKBiologicalSex(rawValue: Int(entity.biologicalSexRaw))
        self.goal = FitnessGoal(rawValue: entity.goalRaw) ?? .general
        self.experience = ExperienceLevel(rawValue: entity.experienceRaw) ?? .intermediate
        self.equipment = EquipmentPreference(rawValue: entity.equipmentRaw) ?? .mixed
        self.preferredDuration = WorkoutDuration(rawValue: entity.preferredDurationRaw) ?? .medium
        self.profileImageData = entity.profileImageData
        self.healthKitSyncEnabled = entity.healthKitSyncEnabled
        self.lockerNumber = entity.lockerNumber
        self.hasExploredWorkouts = entity.hasExploredWorkouts
        self.hasCreatedFirstWorkout = entity.hasCreatedFirstWorkout
        self.hasSetupProfile = entity.hasSetupProfile
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.birthDate = try container.decodeIfPresent(Date.self, forKey: .birthDate)
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        self.height = try container.decodeIfPresent(Double.self, forKey: .height)
        if let sexRaw = try container.decodeIfPresent(Int.self, forKey: .biologicalSex) {
            self.biologicalSex = HKBiologicalSex(rawValue: sexRaw)
        } else {
            self.biologicalSex = nil
        }
        self.goal = try container.decodeIfPresent(FitnessGoal.self, forKey: .goal) ?? .general
        self.profileImageData = try container.decodeIfPresent(Data.self, forKey: .profileImageData)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.experience = try container.decodeIfPresent(ExperienceLevel.self, forKey: .experience) ?? .intermediate
        self.equipment = try container.decodeIfPresent(EquipmentPreference.self, forKey: .equipment) ?? .mixed
        self.preferredDuration = try container.decodeIfPresent(WorkoutDuration.self, forKey: .preferredDuration) ?? .medium
        self.healthKitSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .healthKitSyncEnabled) ?? false
        self.lockerNumber = try container.decodeIfPresent(String.self, forKey: .lockerNumber)
        self.hasExploredWorkouts = try container.decodeIfPresent(Bool.self, forKey: .hasExploredWorkouts) ?? false
        self.hasCreatedFirstWorkout = try container.decodeIfPresent(Bool.self, forKey: .hasCreatedFirstWorkout) ?? false
        self.hasSetupProfile = try container.decodeIfPresent(Bool.self, forKey: .hasSetupProfile) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(birthDate, forKey: .birthDate)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(biologicalSex?.rawValue, forKey: .biologicalSex)
        try container.encode(goal, forKey: .goal)
        try container.encodeIfPresent(profileImageData, forKey: .profileImageData)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(experience, forKey: .experience)
        try container.encode(equipment, forKey: .equipment)
        try container.encode(preferredDuration, forKey: .preferredDuration)
        try container.encode(healthKitSyncEnabled, forKey: .healthKitSyncEnabled)
        try container.encodeIfPresent(lockerNumber, forKey: .lockerNumber)
        try container.encode(hasExploredWorkouts, forKey: .hasExploredWorkouts)
        try container.encode(hasCreatedFirstWorkout, forKey: .hasCreatedFirstWorkout)
        try container.encode(hasSetupProfile, forKey: .hasSetupProfile)
    }
    
    var age: Int? {
        guard let birthDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.year], from: birthDate, to: Date()).year
    }
    
    var profileImage: UIImage? {
        guard let profileImageData else { return nil }
        return UIImage(data: profileImageData)
    }
    
    mutating func updateProfileImage(_ image: UIImage?) {
        if let image {
            // Komprimiere das Bild für bessere Performance
            let targetSize = CGSize(width: 200, height: 200)
            let resizedImage = image.resized(to: targetSize)
            self.profileImageData = resizedImage.jpegData(compressionQuality: 0.8)
        } else {
            self.profileImageData = nil
        }
        self.updatedAt = Date()
    }
    
    mutating func updateInfo(name: String, birthDate: Date?, weight: Double?, height: Double?, biologicalSex: HKBiologicalSex?, goal: FitnessGoal, experience: ExperienceLevel, equipment: EquipmentPreference, preferredDuration: WorkoutDuration, healthKitSyncEnabled: Bool = false) {
        self.name = name
        self.birthDate = birthDate
        self.weight = weight
        self.height = height
        self.biologicalSex = biologicalSex
        self.goal = goal
        self.experience = experience
        self.equipment = equipment
        self.preferredDuration = preferredDuration
        self.healthKitSyncEnabled = healthKitSyncEnabled
        self.updatedAt = Date()
    }
    
    mutating func updateFromHealthKit(_ data: HealthKitProfileData) {
        if let birthDate = data.birthDate {
            self.birthDate = birthDate
        }
        if let weight = data.weight {
            self.weight = weight
        }
        if let height = data.height {
            self.height = height
        }
        if let sex = data.biologicalSex {
            self.biologicalSex = sex
        }
        self.updatedAt = Date()
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
