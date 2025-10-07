import Foundation
import Combine

// MARK: - Tip Feedback Manager

@MainActor
class TipFeedbackManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TipFeedbackManager()

    // MARK: - Published Properties

    @Published private(set) var feedbackHistory: [TipFeedback] = []

    // MARK: - Constants

    private let storageKey = "tip_feedback_history"
    private let maxFeedbackItems = 100 // Begrenze auf 100 Einträge

    // MARK: - Initialization

    private init() {
        loadFeedback()
    }

    // MARK: - Public Methods

    func rateTip(_ tip: TrainingTip, rating: TipRating) {
        let feedback = TipFeedback(
            tipId: tip.id,
            tipContentHash: tip.contentHash,
            rating: rating,
            timestamp: Date()
        )

        feedbackHistory.append(feedback)

        // Begrenze die Anzahl gespeicherter Feedbacks
        if feedbackHistory.count > maxFeedbackItems {
            feedbackHistory = Array(feedbackHistory.suffix(maxFeedbackItems))
        }

        saveFeedback()
    }

    func getFeedbackForTip(_ tipId: UUID) -> TipFeedback? {
        feedbackHistory.first(where: { $0.tipId == tipId })
    }

    func getFeedbackForContentHash(_ contentHash: String) -> TipFeedback? {
        feedbackHistory.first(where: { $0.tipContentHash == contentHash })
    }

    func getFeedbackStats() -> FeedbackStats {
        var categoryStats: [TipCategory: CategoryFeedback] = [:]

        // Gruppiere Feedback nach Kategorie
        // Da wir die Kategorie nicht direkt im Feedback speichern,
        // können wir nur generelle Stats zurückgeben

        let totalFeedback = feedbackHistory.count
        let helpfulCount = feedbackHistory.filter { $0.rating == .helpful }.count
        let notHelpfulCount = feedbackHistory.filter { $0.rating == .notHelpful }.count

        return FeedbackStats(
            totalFeedback: totalFeedback,
            helpfulCount: helpfulCount,
            notHelpfulCount: notHelpfulCount,
            helpfulPercentage: totalFeedback > 0 ? Double(helpfulCount) / Double(totalFeedback) * 100 : 0
        )
    }

    func clearOldFeedback(olderThan days: Int = 90) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        feedbackHistory.removeAll { $0.timestamp < cutoffDate }
        saveFeedback()
    }

    func clearAllFeedback() {
        feedbackHistory.removeAll()
        saveFeedback()
    }

    // MARK: - Persistence

    private func saveFeedback() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(feedbackHistory)
            UserDefaults.standard.set(data, forKey: storageKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("❌ Fehler beim Speichern des Feedbacks: \(error)")
        }
    }

    private func loadFeedback() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            feedbackHistory = try decoder.decode([TipFeedback].self, from: data)
        } catch {
            print("❌ Fehler beim Laden des Feedbacks: \(error)")
            feedbackHistory = []
        }
    }
}

// MARK: - Feedback Stats

struct FeedbackStats {
    let totalFeedback: Int
    let helpfulCount: Int
    let notHelpfulCount: Int
    let helpfulPercentage: Double
}

struct CategoryFeedback {
    let category: TipCategory
    let helpful: Int
    let notHelpful: Int

    var total: Int {
        helpful + notHelpful
    }

    var helpfulPercentage: Double {
        total > 0 ? Double(helpful) / Double(total) * 100 : 0
    }
}
