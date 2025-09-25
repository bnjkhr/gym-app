import Foundation
import SwiftUI

struct UserProfile: Codable {
    let id: UUID
    var name: String
    var birthDate: Date?
    var weight: Double? // in kg
    var goal: FitnessGoal
    var experience: ExperienceLevel = .intermediate
    var equipment: EquipmentPreference = .mixed
    var preferredDuration: WorkoutDuration = .medium
    var profileImageData: Data?
    var createdAt: Date
    var updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, name, birthDate, weight, goal, profileImageData, createdAt, updatedAt, experience, equipment, preferredDuration
    }
    
    init(id: UUID = UUID(), name: String = "", birthDate: Date? = nil, weight: Double? = nil, goal: FitnessGoal = .general, profileImageData: Data? = nil, experience: ExperienceLevel = .intermediate, equipment: EquipmentPreference = .mixed, preferredDuration: WorkoutDuration = .medium) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.weight = weight
        self.goal = goal
        self.profileImageData = profileImageData
        self.createdAt = Date()
        self.updatedAt = Date()
        self.experience = experience
        self.equipment = equipment
        self.preferredDuration = preferredDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.birthDate = try container.decodeIfPresent(Date.self, forKey: .birthDate)
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        self.goal = try container.decodeIfPresent(FitnessGoal.self, forKey: .goal) ?? .general
        self.profileImageData = try container.decodeIfPresent(Data.self, forKey: .profileImageData)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.experience = try container.decodeIfPresent(ExperienceLevel.self, forKey: .experience) ?? .intermediate
        self.equipment = try container.decodeIfPresent(EquipmentPreference.self, forKey: .equipment) ?? .mixed
        self.preferredDuration = try container.decodeIfPresent(WorkoutDuration.self, forKey: .preferredDuration) ?? .medium
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(birthDate, forKey: .birthDate)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encode(goal, forKey: .goal)
        try container.encodeIfPresent(profileImageData, forKey: .profileImageData)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(experience, forKey: .experience)
        try container.encode(equipment, forKey: .equipment)
        try container.encode(preferredDuration, forKey: .preferredDuration)
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
    
    mutating func updateInfo(name: String, birthDate: Date?, weight: Double?, goal: FitnessGoal, experience: ExperienceLevel, equipment: EquipmentPreference, preferredDuration: WorkoutDuration) {
        self.name = name
        self.birthDate = birthDate
        self.weight = weight
        self.goal = goal
        self.experience = experience
        self.equipment = equipment
        self.preferredDuration = preferredDuration
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
