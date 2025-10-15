import Foundation
import SwiftData

@MainActor
final class WorkoutAnalyticsService {
    struct ExerciseStats: Identifiable {
        struct HistoryPoint: Identifiable {
            let id = UUID()
            let date: Date
            let volume: Double
            let estimatedOneRepMax: Double
        }

        let id = UUID()
        let exercise: Exercise
        let totalVolume: Double
        let totalReps: Int
        let maxWeight: Double
        let estimatedOneRepMax: Double
        let history: [HistoryPoint]
    }

    private var modelContext: ModelContext?
    private var exerciseStatsCache: [UUID: ExerciseStats] = [:]
    private var weekStreakCache: (date: Date, value: Int)?

    func setContext(_ context: ModelContext?) {
        modelContext = context
    }

    func invalidateCaches() {
        exerciseStatsCache.removeAll()
        weekStreakCache = nil
    }

    func invalidateExerciseCache(for exerciseId: UUID) {
        exerciseStatsCache[exerciseId] = nil
    }

    func totalWorkoutCount() -> Int {
        let sessions = sessionHistory()
        let importedCount = sessions.filter { $0.notes.contains("Importiert aus") }.count
        let regularCount = sessions.count - importedCount
        print(
            "📊 Workout-Statistik: Gesamt: \(sessions.count), Importiert: \(importedCount), Regulär: \(regularCount)"
        )
        return sessions.count
    }

    func averageWorkoutsPerWeek() -> Double {
        let sessionHistory = sessionHistory()
        guard let earliestDate = sessionHistory.min(by: { $0.date < $1.date })?.date else {
            return 0
        }
        let span = max(Date().timeIntervalSince(earliestDate), 1)
        let weeks = max(span / (7 * 24 * 60 * 60), 1)
        return Double(sessionHistory.count) / weeks
    }

    func currentWeekStreak(today: Date = Date()) -> Int {
        let calendar = Calendar.current

        if let cached = weekStreakCache,
            calendar.isDate(cached.date, equalTo: today, toGranularity: .day)
        {
            return cached.value
        }

        let sessionHistory = sessionHistory()
        guard !sessionHistory.isEmpty else {
            weekStreakCache = (today, 0)
            return 0
        }

        let weekStarts: Set<Date> = Set(
            sessionHistory.compactMap { session in
                calendar.date(
                    from: calendar.dateComponents(
                        [.yearForWeekOfYear, .weekOfYear], from: session.date))
            })

        guard
            var cursor = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))
        else {
            weekStreakCache = (today, 0)
            return 0
        }

        var streak = 0
        while weekStarts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        weekStreakCache = (today, streak)
        return streak
    }

    func averageDurationMinutes() -> Int {
        let sessionHistory = sessionHistory()
        let durations = sessionHistory.compactMap { $0.duration }

        let importedSessions = sessionHistory.filter { $0.notes.contains("Importiert aus") }
        let importedDurations = importedSessions.compactMap { $0.duration }

        if !importedSessions.isEmpty {
            print(
                "📊 Dauer-Statistik: Gesamt: \(sessionHistory.count) Sessions, Importiert: \(importedSessions.count)"
            )
            print(
                "   Durationen verfügbar: Gesamt: \(durations.count), Importiert: \(importedDurations.count)"
            )
        }

        guard !durations.isEmpty else { return 0 }
        let total = durations.reduce(0, +)
        return Int(total / Double(durations.count) / 60)
    }

    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)] {
        let calendar = Calendar.current
        let sessionHistory = sessionHistory()

        guard let cutoffDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) else {
            return []
        }

        let filtered = sessionHistory.filter { $0.date >= cutoffDate }

        let importedSessions = filtered.filter { $0.notes.contains("Importiert aus") }
        if !importedSessions.isEmpty {
            print(
                "📊 Muskelvolumen: Gesamt: \(filtered.count) Workouts, Importiert: \(importedSessions.count)"
            )
            let importedFiltered = importedSessions.filter { $0.date >= cutoffDate }
            print(
                "   Gefilterte Sessions: \(filtered.count), davon importiert: \(importedFiltered.count)"
            )
        }

        var totals: [MuscleGroup: Double] = [:]

        for workout in filtered {
            for exercise in workout.exercises {
                let volume = exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
                for muscle in exercise.exercise.muscleGroups {
                    totals[muscle, default: 0] += volume
                }
            }
        }

        return totals.sorted { $0.value > $1.value }
    }

    func exerciseStats(for exercise: Exercise) -> ExerciseStats? {
        if let cached = exerciseStatsCache[exercise.id] {
            return cached
        }

        let sessionHistory = sessionHistory()
        let relevantSessions = sessionHistory.filter { workout in
            workout.exercises.contains { $0.exercise.id == exercise.id }
        }

        guard !relevantSessions.isEmpty else { return nil }

        var totalVolume: Double = 0
        var totalReps: Int = 0
        var maxWeight: Double = 0
        var history: [ExerciseStats.HistoryPoint] = []

        for workout in relevantSessions.sorted(by: { $0.date < $1.date }) {
            let sets = workout.exercises
                .filter { $0.exercise.id == exercise.id }
                .flatMap { $0.sets }

            let volume = sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
            let reps = sets.reduce(0) { $0 + $1.reps }
            let maxSetWeight = sets.map { $0.weight }.max() ?? 0
            let oneRepMax =
                sets.map { estimateOneRepMax(weight: $0.weight, reps: $0.reps) }.max()
                ?? maxSetWeight

            totalVolume += volume
            totalReps += reps
            maxWeight = max(maxWeight, maxSetWeight)

            history.append(
                ExerciseStats.HistoryPoint(
                    date: workout.date,
                    volume: volume,
                    estimatedOneRepMax: oneRepMax
                )
            )
        }

        let bestOneRepMax = history.map { $0.estimatedOneRepMax }.max() ?? maxWeight

        let stats = ExerciseStats(
            exercise: exercise,
            totalVolume: totalVolume,
            totalReps: totalReps,
            maxWeight: maxWeight,
            estimatedOneRepMax: bestOneRepMax,
            history: history
        )
        exerciseStatsCache[exercise.id] = stats
        return stats
    }

    func workoutsByDay(in range: ClosedRange<Date>) -> [Date: [WorkoutSession]] {
        let calendar = Calendar.current
        let sessionHistory = sessionHistory()
        return Dictionary(grouping: sessionHistory.filter { range.contains($0.date) }) { workout in
            calendar.startOfDay(for: workout.date)
        }
    }

    func getSessionHistory(limit: Int = 100) -> [WorkoutSession] {
        sessionHistory(limit: limit)
    }

    private func sessionHistory(limit: Int = 100) -> [WorkoutSession] {
        guard let context = modelContext else { return [] }
        var descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.includePendingChanges = false
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { WorkoutSession(entity: $0) }
    }

    private func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
}
