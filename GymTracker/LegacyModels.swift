import Foundation

// MARK: - Legacy JSON Models
// These should mirror the structure of your existing JSON files.
// Adjust fields and naming to match your actual JSON if needed.

struct LegacyExercise: Codable, Identifiable {
    var id: UUID
    var name: String
    var muscleGroups: [String] = []
    var descriptionText: String = ""
    var instructions: [String] = []
    var createdAt: Date?
}

struct LegacyExerciseSet: Codable, Identifiable {
    var id: UUID
    var reps: Int
    var weight: Double
    var restTime: TimeInterval?
    var completed: Bool?
}

struct LegacyWorkoutExercise: Codable, Identifiable {
    var id: UUID
    var exerciseId: UUID
    var sets: [LegacyExerciseSet] = []
}

struct LegacyWorkout: Codable, Identifiable {
    var id: UUID
    var name: String
    var date: Date
    var exercises: [LegacyWorkoutExercise] = []
    var defaultRestTime: TimeInterval?
    var duration: TimeInterval?
    var notes: String?
    var isFavorite: Bool?
}

struct LegacyWorkoutSession: Codable, Identifiable {
    var id: UUID
    var templateId: UUID?
    var name: String
    var date: Date
    var exercises: [LegacyWorkoutExercise] = []
    var defaultRestTime: TimeInterval?
    var duration: TimeInterval?
    var notes: String?
}

struct LegacyUserProfile: Codable, Identifiable {
    var id: UUID
    var name: String
    var birthDate: Date?
    var weight: Double?
    var goal: String?
    var experience: String?
    var equipment: String?
    var preferredDuration: Int?
    var profileImageBase64: String?
    var createdAt: Date?
    var updatedAt: Date?
}

// MARK: - Helpers
extension Array where Element == UInt8 {
    func toData() -> Data { Data(self) }
}
