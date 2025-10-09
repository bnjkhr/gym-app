import Foundation
import SwiftUI

/// Zentraler Cache für Statistics-Berechnungen
/// Verhindert redundante Berechnungen über alle Cards hinweg
@MainActor
class StatisticsCache: ObservableObject {
    static let shared = StatisticsCache()

    // Cache-Invalidierung
    @Published private(set) var lastSessionCount: Int = 0
    @Published private(set) var lastRecordsCount: Int = 0
    @Published private(set) var cacheVersion: UUID = UUID()

    // Gecachte Daten
    private var cachedProgressionScore: ProgressionScore?
    private var cachedWeekComparison: WeekComparison?
    private var cachedMuscleDistribution: [MuscleGroupVolume] = []
    private var cachedWeeklySets: [MuscleGroupSets] = []

    private init() {}

    /// Invalidiert Cache wenn sich Daten geändert haben
    func invalidateIfNeeded(sessionCount: Int, recordsCount: Int) {
        if sessionCount != lastSessionCount || recordsCount != lastRecordsCount {
            lastSessionCount = sessionCount
            lastRecordsCount = recordsCount
            cacheVersion = UUID()

            // Cache leeren
            cachedProgressionScore = nil
            cachedWeekComparison = nil
            cachedMuscleDistribution = []
            cachedWeeklySets = []

            print("📊 StatisticsCache invalidated (Sessions: \(sessionCount), Records: \(recordsCount))")
        }
    }

    // MARK: - Cached Getters/Setters

    func getProgressionScore() -> ProgressionScore? {
        return cachedProgressionScore
    }

    func setProgressionScore(_ score: ProgressionScore) {
        cachedProgressionScore = score
    }

    func getWeekComparison() -> WeekComparison? {
        return cachedWeekComparison
    }

    func setWeekComparison(_ comparison: WeekComparison) {
        cachedWeekComparison = comparison
    }

    func getMuscleDistribution() -> [MuscleGroupVolume] {
        return cachedMuscleDistribution
    }

    func setMuscleDistribution(_ distribution: [MuscleGroupVolume]) {
        cachedMuscleDistribution = distribution
    }

    func getWeeklySets() -> [MuscleGroupSets] {
        return cachedWeeklySets
    }

    func setWeeklySets(_ sets: [MuscleGroupSets]) {
        cachedWeeklySets = sets
    }
}
