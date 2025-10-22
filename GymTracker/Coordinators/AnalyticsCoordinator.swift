import Foundation
import SwiftData
import SwiftUI

/// AnalyticsCoordinator manages workout analytics and statistics
///
/// **Responsibilities:**
/// - Workout statistics (counts, duration, streaks)
/// - Progress tracking and trends
/// - Muscle volume analysis
/// - Exercise statistics and history
/// - Weekly/monthly analytics
/// - Plateau detection
///
/// **Dependencies:**
/// - WorkoutAnalyticsService (analytics calculations)
/// - WorkoutCoordinator (session access)
/// - ExerciseCoordinator (exercise metadata)
///
/// **Used by:**
/// - StatisticsView
/// - InsightsView
/// - WorkoutsHomeView
/// - ProgressView
@MainActor
final class AnalyticsCoordinator: ObservableObject {
    // MARK: - Published State

    /// Total number of completed workouts
    @Published var totalWorkouts: Int = 0

    /// Total workout duration across all sessions
    @Published var totalDuration: TimeInterval = 0

    /// Current workout streak (consecutive days)
    @Published var currentStreak: Int = 0

    /// Average workout duration in minutes
    @Published var averageDurationMinutes: Int = 0

    /// Workouts completed this week
    @Published var workoutsThisWeek: Int = 0

    /// Workouts completed this month
    @Published var workoutsThisMonth: Int = 0

    // MARK: - Dependencies

    private let analyticsService: WorkoutAnalyticsService
    private weak var workoutCoordinator: WorkoutCoordinator?
    private weak var exerciseCoordinator: ExerciseCoordinator?
    private var modelContext: ModelContext?

    // Cache for expensive operations
    private var muscleVolumeCache: [MuscleGroup: Double] = [:]
    private var exerciseStatsCache: [UUID: ExerciseStats] = [:]
    private var lastCacheRefresh: Date?

    // MARK: - Initialization

    init(analyticsService: WorkoutAnalyticsService = WorkoutAnalyticsService()) {
        self.analyticsService = analyticsService
    }

    // MARK: - Context Management

    /// Sets the SwiftData context for analytics operations
    /// - Parameter context: The ModelContext to use for persistence
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        analyticsService.setContext(context)
        refreshStatistics()
    }

    /// Sets the workout coordinator for session access
    /// - Parameter coordinator: The WorkoutCoordinator instance
    func setWorkoutCoordinator(_ coordinator: WorkoutCoordinator) {
        self.workoutCoordinator = coordinator
    }

    /// Sets the exercise coordinator for exercise metadata
    /// - Parameter coordinator: The ExerciseCoordinator instance
    func setExerciseCoordinator(_ coordinator: ExerciseCoordinator) {
        self.exerciseCoordinator = coordinator
    }

    /// Refreshes all statistics from current data
    func refreshStatistics() {
        guard let coordinator = workoutCoordinator else { return }

        let sessions = coordinator.sessionHistory

        // Basic stats
        self.totalWorkouts = sessions.count
        self.totalDuration = sessions.reduce(0) { $0 + $1.duration }

        if !sessions.isEmpty {
            let avgSeconds = totalDuration / Double(sessions.count)
            self.averageDurationMinutes = Int(avgSeconds / 60)
        } else {
            self.averageDurationMinutes = 0
        }

        // Time-based stats
        self.workoutsThisWeek = coordinator.recentSessions(days: 7).count
        self.workoutsThisMonth = coordinator.recentSessions(days: 30).count
        self.currentStreak = calculateStreak(from: sessions)

        // Invalidate caches
        invalidateCaches()

        AppLogger.workouts.debug(
            "✅ Refreshed analytics: \(totalWorkouts) workouts, \(currentStreak) day streak")
    }

    // MARK: - Workout Statistics

    /// Gets total workout count
    var totalWorkoutCount: Int {
        totalWorkouts
    }

    /// Gets total workout time in hours
    var totalHours: Double {
        totalDuration / 3600
    }

    /// Gets total workout time formatted as string
    var totalTimeFormatted: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }

    /// Gets average workout duration formatted as string
    var averageDurationFormatted: String {
        return "\(averageDurationMinutes) min"
    }

    // MARK: - Streak Calculation

    /// Calculates the current workout streak
    ///
    /// **Logic:**
    /// - Counts consecutive days with at least one workout
    /// - Breaks if a day is skipped
    /// - Today counts even if no workout yet
    ///
    /// - Parameter sessions: Array of workout sessions
    /// - Returns: Number of consecutive days
    private func calculateStreak(from sessions: [WorkoutSessionV1]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Group sessions by day
        let sessionsByDay = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.date)
        }

        var streak = 0
        var currentDay = today

        // Count backwards from today
        while true {
            if sessionsByDay[currentDay] != nil {
                streak += 1
                currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
            } else if currentDay == today {
                // Today hasn't had a workout yet, but continue checking
                currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
            } else {
                // Streak broken
                break
            }
        }

        return streak
    }

    /// Gets the longest streak ever achieved
    ///
    /// - Returns: Longest consecutive day streak
    func getLongestStreak() -> Int {
        guard let coordinator = workoutCoordinator else { return 0 }

        let sessions = coordinator.sessionHistory
        let calendar = Calendar.current

        let sessionsByDay = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.date)
        }

        let sortedDays = sessionsByDay.keys.sorted()

        var longestStreak = 0
        var currentStreak = 0
        var previousDay: Date?

        for day in sortedDays {
            if let prev = previousDay {
                let daysBetween = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if daysBetween == 1 {
                    currentStreak += 1
                } else {
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            previousDay = day
        }

        longestStreak = max(longestStreak, currentStreak)
        return longestStreak
    }

    // MARK: - Time-Based Analytics

    /// Gets workouts completed in a specific time period
    ///
    /// - Parameter days: Number of days to analyze
    /// - Returns: Workout count
    func workoutsInLast(days: Int) -> Int {
        return workoutCoordinator?.recentSessions(days: days).count ?? 0
    }

    /// Gets workout frequency per week over last N weeks
    ///
    /// - Parameter weeks: Number of weeks to analyze
    /// - Returns: Dictionary mapping week numbers to workout counts
    func workoutFrequencyPerWeek(weeks: Int) -> [Int: Int] {
        guard let coordinator = workoutCoordinator else { return [:] }

        let sessions = coordinator.recentSessions(days: weeks * 7)
        let calendar = Calendar.current

        var frequencyByWeek: [Int: Int] = [:]

        for session in sessions {
            let weekNumber = calendar.component(.weekOfYear, from: session.date)
            frequencyByWeek[weekNumber, default: 0] += 1
        }

        return frequencyByWeek
    }

    /// Gets workouts by day of week
    ///
    /// - Returns: Dictionary mapping weekday names to workout counts
    func workoutsByDayOfWeek() -> [String: Int] {
        guard let coordinator = workoutCoordinator else { return [:] }

        let sessions = coordinator.sessionHistory
        let calendar = Calendar.current

        var workoutsByDay: [String: Int] = [:]

        for session in sessions {
            let dayName = DateFormatters.weekdayName.string(from: session.date)
            workoutsByDay[dayName, default: 0] += 1
        }

        return workoutsByDay
    }

    /// Gets most popular workout day
    ///
    /// - Returns: Day name (e.g., "Monday")
    func mostPopularWorkoutDay() -> String? {
        let dayStats = workoutsByDayOfWeek()
        return dayStats.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Muscle Volume Analysis

    /// Calculates total volume (weight × reps × sets) for a muscle group
    ///
    /// - Parameters:
    ///   - muscleGroup: The target muscle group
    ///   - days: Number of days to analyze (default: 30)
    /// - Returns: Total volume in kg
    func muscleVolume(for muscleGroup: MuscleGroup, days: Int = 30) -> Double {
        // Check cache
        if let cached = muscleVolumeCache[muscleGroup],
            let lastRefresh = lastCacheRefresh,
            Date().timeIntervalSince(lastRefresh) < 300
        {  // 5 min cache
            return cached
        }

        // Calculate
        let volume = analyticsService.muscleVolume(for: muscleGroup, inLastDays: days)

        // Update cache
        muscleVolumeCache[muscleGroup] = volume
        lastCacheRefresh = Date()

        return volume
    }

    /// Gets volume distribution across all muscle groups
    ///
    /// - Parameter days: Number of days to analyze
    /// - Returns: Dictionary mapping muscle groups to volumes
    func muscleVolumeDistribution(days: Int = 30) -> [MuscleGroup: Double] {
        var distribution: [MuscleGroup: Double] = [:]

        // Major muscle groups
        let majorMuscles: [MuscleGroup] = [
            .chest, .back, .shoulders, .biceps, .triceps,
            .quadriceps, .hamstrings, .glutes, .calves, .abs,
        ]

        for muscle in majorMuscles {
            distribution[muscle] = muscleVolume(for: muscle, days: days)
        }

        return distribution
    }

    /// Checks if muscle training is balanced (no muscle group < 70% of average)
    ///
    /// - Returns: true if balanced, false if imbalanced
    func isMuscleTrainingBalanced() -> Bool {
        let distribution = muscleVolumeDistribution(days: 30)

        guard !distribution.isEmpty else { return true }

        let values = distribution.values.filter { $0 > 0 }
        guard !values.isEmpty else { return true }

        let average = values.reduce(0, +) / Double(values.count)
        let threshold = average * 0.7

        // Check if any muscle is below threshold
        return !values.contains(where: { $0 < threshold })
    }

    // MARK: - Exercise Statistics

    /// Gets statistics for a specific exercise
    ///
    /// - Parameter exerciseId: The exercise ID
    /// - Returns: ExerciseStats with counts, volume, progression
    func exerciseStats(for exerciseId: UUID) -> ExerciseStats? {
        // Check cache
        if let cached = exerciseStatsCache[exerciseId],
            let lastRefresh = lastCacheRefresh,
            Date().timeIntervalSince(lastRefresh) < 300
        {  // 5 min cache
            return cached
        }

        // Calculate
        guard let stats = analyticsService.getExerciseStats(exerciseId: exerciseId) else {
            return nil
        }

        // Update cache
        exerciseStatsCache[exerciseId] = stats
        lastCacheRefresh = Date()

        return stats
    }

    /// Gets most performed exercises
    ///
    /// - Parameter limit: Number of exercises to return
    /// - Returns: Array of (exerciseId, count) tuples
    func mostPerformedExercises(limit: Int = 10) -> [(UUID, Int)] {
        guard let coordinator = workoutCoordinator else { return [] }

        let sessions = coordinator.sessionHistory
        var exerciseCounts: [UUID: Int] = [:]

        for session in sessions {
            for exercise in session.exercises {
                exerciseCounts[exercise.exercise.id, default: 0] += 1
            }
        }

        return
            exerciseCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    // MARK: - Progress Tracking

    /// Calculates progress percentage towards weekly goal
    ///
    /// - Parameter weeklyGoal: Target workouts per week
    /// - Returns: Progress percentage (0-100)
    func weeklyGoalProgress(goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(goal) * 100, 100)
    }

    /// Checks if weekly goal is met
    ///
    /// - Parameter weeklyGoal: Target workouts per week
    /// - Returns: true if goal is met or exceeded
    func isWeeklyGoalMet(goal: Int) -> Bool {
        return workoutsThisWeek >= goal
    }

    /// Detects if user is in a plateau (no progress in last N sessions)
    ///
    /// - Parameters:
    ///   - exerciseId: The exercise to check
    ///   - sessions: Number of sessions to analyze
    /// - Returns: true if plateau detected
    func detectPlateau(for exerciseId: UUID, sessions: Int = 5) -> Bool {
        guard let stats = exerciseStats(for: exerciseId) else { return false }

        // Check if max weight hasn't increased in last N sessions
        // This is a simplified check - actual implementation would need session history
        return stats.sessionCount >= sessions && stats.progressionRate < 0.01
    }

    // MARK: - Cache Management

    /// Invalidates all caches
    func invalidateCaches() {
        muscleVolumeCache.removeAll()
        exerciseStatsCache.removeAll()
        lastCacheRefresh = nil
    }

    /// Invalidates cache for specific exercise
    ///
    /// - Parameter exerciseId: The exercise ID
    func invalidateCache(for exerciseId: UUID) {
        exerciseStatsCache.removeValue(forKey: exerciseId)
    }
}

// MARK: - Supporting Types

/// Exercise statistics
struct ExerciseStats {
    let exerciseId: UUID
    let sessionCount: Int
    let totalVolume: Double
    let averageWeight: Double
    let maxWeight: Double
    let progressionRate: Double  // Percentage increase over time
    let lastPerformed: Date?
}
