import Foundation

// MARK: - Session Statistics Helper Structs

struct ExerciseStatistic: Identifiable {
    let id: UUID
    let exerciseName: String
    let maxWeight: Double
    let totalVolume: Double
    let averageReps: Double
    let completedSets: Int
    let totalSets: Int
    let progressionPercentage: Double? // Progression vs. vorherige Session
}

struct VolumeDataPoint: Identifiable {
    let id = UUID()
    let exerciseName: String
    let volume: Double
}
