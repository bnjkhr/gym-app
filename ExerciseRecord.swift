import Foundation
import SwiftData

struct ExerciseRecord: Identifiable, Codable {
    let id: UUID
    let exerciseId: UUID
    let exerciseName: String
    
    // Record types
    let maxWeight: Double
    let maxWeightReps: Int
    let maxWeightDate: Date
    
    let maxReps: Int
    let maxRepsWeight: Double
    let maxRepsDate: Date
    
    let bestEstimatedOneRepMax: Double
    let bestOneRepMaxWeight: Double
    let bestOneRepMaxReps: Int
    let bestOneRepMaxDate: Date
    
    // Metadata
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        exerciseName: String,
        maxWeight: Double = 0,
        maxWeightReps: Int = 0,
        maxWeightDate: Date = Date(),
        maxReps: Int = 0,
        maxRepsWeight: Double = 0,
        maxRepsDate: Date = Date(),
        bestEstimatedOneRepMax: Double = 0,
        bestOneRepMaxWeight: Double = 0,
        bestOneRepMaxReps: Int = 0,
        bestOneRepMaxDate: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.maxWeight = maxWeight
        self.maxWeightReps = maxWeightReps
        self.maxWeightDate = maxWeightDate
        self.maxReps = maxReps
        self.maxRepsWeight = maxRepsWeight
        self.maxRepsDate = maxRepsDate
        self.bestEstimatedOneRepMax = bestEstimatedOneRepMax
        self.bestOneRepMaxWeight = bestOneRepMaxWeight
        self.bestOneRepMaxReps = bestOneRepMaxReps
        self.bestOneRepMaxDate = bestOneRepMaxDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Helper Methods
extension ExerciseRecord {
    /// Estimate 1RM using Brzycki formula: weight / (1.0278 - 0.0278 * reps)
    static func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return weight }
        if reps == 1 { return weight }
        return weight / (1.0278 - 0.0278 * Double(reps))
    }
    
    /// Check if the given set represents a new personal record
    func hasNewRecord(weight: Double, reps: Int, date: Date = Date()) -> RecordType? {
        let estimatedMax = Self.estimateOneRepMax(weight: weight, reps: reps)
        
        if weight > maxWeight {
            return .maxWeight
        } else if reps > maxReps {
            return .maxReps
        } else if estimatedMax > bestEstimatedOneRepMax {
            return .estimatedOneRepMax
        }
        
        return nil
    }
    
    /// Create an updated record with new personal best values
    func updatedWith(weight: Double, reps: Int, date: Date = Date()) -> ExerciseRecord {
        let estimatedMax = Self.estimateOneRepMax(weight: weight, reps: reps)
        
        let newMaxWeight = max(weight, maxWeight)
        let newMaxWeightReps = weight > maxWeight ? reps : maxWeightReps
        let newMaxWeightDate = weight > maxWeight ? date : maxWeightDate
        
        let newMaxReps = max(reps, maxReps)
        let newMaxRepsWeight = reps > maxReps ? weight : maxRepsWeight
        let newMaxRepsDate = reps > maxReps ? date : maxRepsDate
        
        let newBestOneRepMax = max(estimatedMax, bestEstimatedOneRepMax)
        let newBestOneRepMaxWeight = estimatedMax > bestEstimatedOneRepMax ? weight : bestOneRepMaxWeight
        let newBestOneRepMaxReps = estimatedMax > bestEstimatedOneRepMax ? reps : bestOneRepMaxReps
        let newBestOneRepMaxDate = estimatedMax > bestEstimatedOneRepMax ? date : bestOneRepMaxDate
        
        return ExerciseRecord(
            id: id,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            maxWeight: newMaxWeight,
            maxWeightReps: newMaxWeightReps,
            maxWeightDate: newMaxWeightDate,
            maxReps: newMaxReps,
            maxRepsWeight: newMaxRepsWeight,
            maxRepsDate: newMaxRepsDate,
            bestEstimatedOneRepMax: newBestOneRepMax,
            bestOneRepMaxWeight: newBestOneRepMaxWeight,
            bestOneRepMaxReps: newBestOneRepMaxReps,
            bestOneRepMaxDate: newBestOneRepMaxDate,
            createdAt: createdAt,
            updatedAt: date
        )
    }
}

// MARK: - Record Types
enum RecordType: String, CaseIterable {
    case maxWeight = "Höchstes Gewicht"
    case maxReps = "Meiste Wiederholungen"
    case estimatedOneRepMax = "Beste geschätzte 1RM"
    
    var emoji: String {
        switch self {
        case .maxWeight: return "🏋️‍♀️"
        case .maxReps: return "🔥"
        case .estimatedOneRepMax: return "💪"
        }
    }
}