import Foundation
import SwiftUI

// MARK: - Core Models

struct TrainingTip: Identifiable, Codable, Equatable {
    let id: UUID
    let category: TipCategory
    let title: String
    let message: String
    let emoji: String
    let priority: TipPriority
    let createdAt: Date
    let metadata: TipMetadata?

    init(
        id: UUID = UUID(),
        category: TipCategory,
        title: String,
        message: String,
        emoji: String,
        priority: TipPriority,
        createdAt: Date = Date(),
        metadata: TipMetadata? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.message = message
        self.emoji = emoji
        self.priority = priority
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

// MARK: - Tip Category

enum TipCategory: String, Codable, CaseIterable {
    case progression    // Gewicht/Reps erhöhen
    case balance       // Muskelgruppen-Verteilung
    case recovery      // Pausenempfehlungen
    case motivation    // Erfolge feiern
    case consistency   // Trainingsfrequenz
    case goal          // Ziel-spezifische Tipps

    var displayName: String {
        switch self {
        case .progression: return "Progression"
        case .balance: return "Balance"
        case .recovery: return "Erholung"
        case .motivation: return "Motivation"
        case .consistency: return "Konsistenz"
        case .goal: return "Ziel"
        }
    }

    var icon: String {
        switch self {
        case .progression: return "arrow.up.circle.fill"
        case .balance: return "scale.3d"
        case .recovery: return "bed.double.fill"
        case .motivation: return "flame.fill"
        case .consistency: return "calendar.badge.clock"
        case .goal: return "target"
        }
    }

    var color: Color {
        switch self {
        case .progression: return .green
        case .balance: return .orange
        case .recovery: return .blue
        case .motivation: return .red
        case .consistency: return .purple
        case .goal: return .pink
        }
    }
}

// MARK: - Tip Priority

enum TipPriority: Int, Codable, Comparable {
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: TipPriority, rhs: TipPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Tip Metadata

struct TipMetadata: Codable, Equatable {
    let exerciseName: String?
    let muscleGroup: String?
    let currentValue: Double?
    let suggestedValue: Double?

    init(
        exerciseName: String? = nil,
        muscleGroup: String? = nil,
        currentValue: Double? = nil,
        suggestedValue: Double? = nil
    ) {
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.currentValue = currentValue
        self.suggestedValue = suggestedValue
    }
}

// MARK: - Feedback Models

struct TipFeedback: Codable, Identifiable {
    let id: UUID
    let tipId: UUID
    let rating: TipRating
    let timestamp: Date

    init(id: UUID = UUID(), tipId: UUID, rating: TipRating, timestamp: Date = Date()) {
        self.id = id
        self.tipId = tipId
        self.rating = rating
        self.timestamp = timestamp
    }
}

enum TipRating: String, Codable {
    case helpful = "helpful"       // 👍
    case notHelpful = "notHelpful" // 👎

    var emoji: String {
        switch self {
        case .helpful: return "👍"
        case .notHelpful: return "👎"
        }
    }
}

// MARK: - Health Data Helper

struct HealthData {
    let weight: Double?
    let bodyFat: Double?
    let weightTrend: WeightTrend?

    enum WeightTrend {
        case increasing(amount: Double, weeks: Int)
        case decreasing(amount: Double, weeks: Int)
        case stable
    }
}
