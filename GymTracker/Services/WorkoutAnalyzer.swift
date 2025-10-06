import Foundation

// MARK: - Workout Analyzer

struct WorkoutAnalyzer {

    // MARK: - Analysis Result

    struct AnalysisResult {
        let progressionOpportunities: [ProgressionOpportunity]
        let muscleGroupBalance: MuscleGroupBalance
        let recoveryStatus: RecoveryStatus
        let consistencyMetrics: ConsistencyMetrics
        let goalAlignment: GoalAlignment
        let recentAchievements: [Achievement]
    }

    // MARK: - Progression

    struct ProgressionOpportunity {
        let exerciseName: String
        let currentWeight: Double
        let currentReps: Int
        let weeksAtSameLevel: Int
        let suggestedWeight: Double?
        let suggestedReps: Int?
        let confidence: Double // 0.0 - 1.0
    }

    // MARK: - Muscle Balance

    struct MuscleGroupBalance {
        let distribution: [MuscleGroup: Double] // Prozent des Volumens
        let imbalances: [MuscleGroupImbalance]
        let totalVolume: Double
    }

    struct MuscleGroupImbalance {
        let overtrainedGroup: MuscleGroup
        let undertrainedGroup: MuscleGroup
        let ratio: Double // z.B. 3.0 = 3x mehr Volumen
    }

    // MARK: - Recovery

    struct RecoveryStatus {
        let daysSinceLastWorkout: Int
        let needsRest: Bool
        let overtrainingRisk: Bool
        let workoutsInLastWeek: Int
    }

    // MARK: - Consistency

    struct ConsistencyMetrics {
        let currentStreak: Int
        let avgWorkoutsPerWeek: Double
        let totalWorkouts: Int
        let lastWorkoutDate: Date?
    }

    // MARK: - Goal Alignment

    struct GoalAlignment {
        let goal: FitnessGoal
        let repRangeMatch: RepRangeAlignment
        let volumeAdequate: VolumeAlignment
        let suggestions: [String]
    }

    enum RepRangeAlignment {
        case good
        case tooLow
        case tooHigh
    }

    enum VolumeAlignment {
        case good
        case tooLow
        case tooHigh
    }

    // MARK: - Achievements

    struct Achievement {
        let exerciseName: String
        let type: AchievementType
        let date: Date
    }

    enum AchievementType {
        case newPersonalRecord(weight: Double, reps: Int)
        case volumeIncrease(percent: Double)
        case consistencyMilestone(days: Int)
    }

    // MARK: - Main Analysis Method

    func analyze(
        sessions: [WorkoutSession],
        profile: UserProfile,
        healthData: HealthData?
    ) -> AnalysisResult {
        let progression = analyzeProgression(sessions: sessions)
        let balance = analyzeMuscleBalance(sessions: sessions)
        let recovery = analyzeRecovery(sessions: sessions)
        let consistency = analyzeConsistency(sessions: sessions)
        let goalAlignment = analyzeGoalAlignment(sessions: sessions, profile: profile)
        let achievements = findRecentAchievements(sessions: sessions)

        return AnalysisResult(
            progressionOpportunities: progression,
            muscleGroupBalance: balance,
            recoveryStatus: recovery,
            consistencyMetrics: consistency,
            goalAlignment: goalAlignment,
            recentAchievements: achievements
        )
    }

    // MARK: - Progression Analysis

    private func analyzeProgression(sessions: [WorkoutSession]) -> [ProgressionOpportunity] {
        var opportunities: [ProgressionOpportunity] = []

        // Gruppiere Sessions nach Übungen
        let exerciseHistory = groupByExercise(sessions: sessions)

        for (exerciseName, history) in exerciseHistory {
            guard history.count >= 2 else { continue }

            // Sortiere nach Datum
            let sorted = history.sorted { $0.date < $1.date }
            guard let latest = sorted.last else { continue }

            // Berechne durchschnittliches Gewicht und Reps der letzten 3 Sessions
            let recent = Array(sorted.suffix(3))
            let avgWeight = recent.flatMap { $0.sets }.map { $0.weight }.reduce(0, +) / Double(recent.flatMap { $0.sets }.count)
            let avgReps = Double(recent.flatMap { $0.sets }.map { $0.reps }.reduce(0, +)) / Double(recent.flatMap { $0.sets }.count)

            // Prüfe ob Plateau (gleiches Gewicht/Reps seit 3+ Wochen)
            let weeksAtSameLevel = calculateWeeksAtSameLevel(history: sorted)

            if weeksAtSameLevel >= 3 {
                let suggestedWeight = avgWeight * 1.025 // 2.5% Erhöhung
                let suggestedReps = Int(avgReps) + 1

                opportunities.append(ProgressionOpportunity(
                    exerciseName: exerciseName,
                    currentWeight: avgWeight,
                    currentReps: Int(avgReps),
                    weeksAtSameLevel: weeksAtSameLevel,
                    suggestedWeight: suggestedWeight,
                    suggestedReps: suggestedReps,
                    confidence: 0.8
                ))
            }
        }

        return opportunities
    }

    private func groupByExercise(sessions: [WorkoutSession]) -> [String: [SessionExercise]] {
        var grouped: [String: [SessionExercise]] = [:]

        for session in sessions {
            for exercise in session.exercises {
                let name = exercise.exercise.name
                let sessionExercise = SessionExercise(
                    exerciseName: name,
                    sets: exercise.sets,
                    date: session.date
                )

                if grouped[name] != nil {
                    grouped[name]?.append(sessionExercise)
                } else {
                    grouped[name] = [sessionExercise]
                }
            }
        }

        return grouped
    }

    private struct SessionExercise {
        let exerciseName: String
        let sets: [ExerciseSet]
        let date: Date
    }

    private func calculateWeeksAtSameLevel(history: [SessionExercise]) -> Int {
        guard history.count >= 2 else { return 0 }

        let recent = Array(history.suffix(4))
        let avgWeights = recent.map { session in
            session.sets.map { $0.weight }.reduce(0, +) / Double(session.sets.count)
        }

        // Prüfe ob Gewicht stagniert
        let variance = calculateVariance(avgWeights)
        if variance < 0.5 { // Sehr geringe Varianz = Plateau
            let weeks = Calendar.current.dateComponents([.weekOfYear], from: recent.first!.date, to: recent.last!.date).weekOfYear ?? 0
            return weeks
        }

        return 0
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return variance
    }

    // MARK: - Muscle Balance Analysis

    private func analyzeMuscleBalance(sessions: [WorkoutSession]) -> MuscleGroupBalance {
        var muscleVolume: [MuscleGroup: Double] = [:]
        var totalVolume: Double = 0

        // Berechne Volumen pro Muskelgruppe (letzten 4 Wochen)
        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= fourWeeksAgo }

        for session in recentSessions {
            for exercise in session.exercises {
                let volume = exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

                for muscleGroup in exercise.exercise.muscleGroups {
                    muscleVolume[muscleGroup, default: 0] += volume
                }

                totalVolume += volume
            }
        }

        // Berechne Prozentverteilung
        var distribution: [MuscleGroup: Double] = [:]
        for (muscle, volume) in muscleVolume {
            distribution[muscle] = (volume / totalVolume) * 100
        }

        // Finde Ungleichgewichte
        let imbalances = findImbalances(distribution: distribution)

        return MuscleGroupBalance(
            distribution: distribution,
            imbalances: imbalances,
            totalVolume: totalVolume
        )
    }

    private func findImbalances(distribution: [MuscleGroup: Double]) -> [MuscleGroupImbalance] {
        var imbalances: [MuscleGroupImbalance] = []

        // Vergleiche Push vs Pull
        let pushGroups: [MuscleGroup] = [.chest, .shoulders, .triceps]
        let pullGroups: [MuscleGroup] = [.back, .biceps]

        let pushVolume = pushGroups.compactMap { distribution[$0] }.reduce(0, +)
        let pullVolume = pullGroups.compactMap { distribution[$0] }.reduce(0, +)

        if pushVolume > 0 && pullVolume > 0 {
            let ratio = pushVolume / pullVolume
            if ratio > 1.5 {
                imbalances.append(MuscleGroupImbalance(
                    overtrainedGroup: .chest,
                    undertrainedGroup: .back,
                    ratio: ratio
                ))
            } else if ratio < 0.67 {
                imbalances.append(MuscleGroupImbalance(
                    overtrainedGroup: .back,
                    undertrainedGroup: .chest,
                    ratio: 1.0 / ratio
                ))
            }
        }

        // Vergleiche Oberkörper vs Unterkörper
        let upperBody: [MuscleGroup] = [.chest, .back, .shoulders, .biceps, .triceps]
        let lowerBody: [MuscleGroup] = [.legs, .glutes]

        let upperVolume = upperBody.compactMap { distribution[$0] }.reduce(0, +)
        let lowerVolume = lowerBody.compactMap { distribution[$0] }.reduce(0, +)

        if upperVolume > 0 && lowerVolume > 0 {
            let ratio = upperVolume / lowerVolume
            if ratio > 2.0 {
                imbalances.append(MuscleGroupImbalance(
                    overtrainedGroup: .chest, // Repräsentativ für Oberkörper
                    undertrainedGroup: .legs,
                    ratio: ratio
                ))
            }
        }

        return imbalances
    }

    // MARK: - Recovery Analysis

    private func analyzeRecovery(sessions: [WorkoutSession]) -> RecoveryStatus {
        guard let lastWorkout = sessions.sorted(by: { $0.date > $1.date }).first else {
            return RecoveryStatus(
                daysSinceLastWorkout: 999,
                needsRest: false,
                overtrainingRisk: false,
                workoutsInLastWeek: 0
            )
        }

        let daysSinceLast = Calendar.current.dateComponents([.day], from: lastWorkout.date, to: Date()).day ?? 0

        // Workouts in letzten 7 Tagen
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let workoutsLastWeek = sessions.filter { $0.date >= weekAgo }.count

        // Übertraining-Risiko: 6+ Workouts in 7 Tagen
        let overtrainingRisk = workoutsLastWeek >= 6

        // Rest nötig: < 1 Tag seit letztem Workout
        let needsRest = daysSinceLast < 1 && workoutsLastWeek >= 3

        return RecoveryStatus(
            daysSinceLastWorkout: daysSinceLast,
            needsRest: needsRest,
            overtrainingRisk: overtrainingRisk,
            workoutsInLastWeek: workoutsLastWeek
        )
    }

    // MARK: - Consistency Analysis

    private func analyzeConsistency(sessions: [WorkoutSession]) -> ConsistencyMetrics {
        guard !sessions.isEmpty else {
            return ConsistencyMetrics(
                currentStreak: 0,
                avgWorkoutsPerWeek: 0,
                totalWorkouts: 0,
                lastWorkoutDate: nil
            )
        }

        let sorted = sessions.sorted { $0.date > $1.date }
        let streak = calculateStreak(sessions: sorted)

        // Durchschnittliche Workouts pro Woche (letzten 8 Wochen)
        let eightWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -8, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= eightWeeksAgo }
        let avgPerWeek = Double(recentSessions.count) / 8.0

        return ConsistencyMetrics(
            currentStreak: streak,
            avgWorkoutsPerWeek: avgPerWeek,
            totalWorkouts: sessions.count,
            lastWorkoutDate: sorted.first?.date
        )
    }

    private func calculateStreak(sessions: [WorkoutSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }

        var streak = 0
        var currentDate = Date()

        for session in sessions {
            let daysDiff = Calendar.current.dateComponents([.day], from: session.date, to: currentDate).day ?? 0

            if daysDiff <= 7 { // Maximal 7 Tage Abstand
                streak += 1
                currentDate = session.date
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Goal Alignment Analysis

    private func analyzeGoalAlignment(sessions: [WorkoutSession], profile: UserProfile) -> GoalAlignment {
        guard !sessions.isEmpty else {
            return GoalAlignment(
                goal: profile.goal,
                repRangeMatch: .good,
                volumeAdequate: .good,
                suggestions: []
            )
        }

        var suggestions: [String] = []

        // Analysiere Rep-Ranges basierend auf Ziel
        let recentSessions = Array(sessions.suffix(5))
        let allSets = recentSessions.flatMap { $0.exercises.flatMap { $0.sets } }
        let avgReps = Double(allSets.map { $0.reps }.reduce(0, +)) / Double(allSets.count)

        let repRangeMatch: RepRangeAlignment
        switch profile.goal {
        case .muscleBuilding:
            if avgReps >= 8 && avgReps <= 12 {
                repRangeMatch = .good
            } else if avgReps < 8 {
                repRangeMatch = .tooLow
                suggestions.append("Erhöhe deine Wiederholungen auf 8-12 für optimalen Muskelaufbau")
            } else {
                repRangeMatch = .tooHigh
                suggestions.append("Reduziere deine Wiederholungen auf 8-12 und erhöhe das Gewicht")
            }

        case .strength:
            if avgReps >= 3 && avgReps <= 6 {
                repRangeMatch = .good
            } else if avgReps < 3 {
                repRangeMatch = .tooLow
                suggestions.append("Erhöhe deine Wiederholungen auf 3-6 für Kraftaufbau")
            } else {
                repRangeMatch = .tooHigh
                suggestions.append("Reduziere deine Wiederholungen auf 3-6 und erhöhe das Gewicht für Kraftzuwachs")
            }

        case .endurance:
            if avgReps >= 15 {
                repRangeMatch = .good
            } else {
                repRangeMatch = .tooLow
                suggestions.append("Erhöhe deine Wiederholungen auf 15+ für Ausdauertraining")
            }

        default:
            repRangeMatch = .good
        }

        // Volumen-Analyse
        let totalVolume = allSets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        let avgVolumePerWorkout = totalVolume / Double(recentSessions.count)

        let volumeAdequate: VolumeAlignment
        if avgVolumePerWorkout < 5000 {
            volumeAdequate = .tooLow
            suggestions.append("Erhöhe dein Trainingsvolumen für bessere Ergebnisse")
        } else if avgVolumePerWorkout > 30000 {
            volumeAdequate = .tooHigh
            suggestions.append("Reduziere dein Volumen, um Übertraining zu vermeiden")
        } else {
            volumeAdequate = .good
        }

        return GoalAlignment(
            goal: profile.goal,
            repRangeMatch: repRangeMatch,
            volumeAdequate: volumeAdequate,
            suggestions: suggestions
        )
    }

    // MARK: - Achievements

    private func findRecentAchievements(sessions: [WorkoutSession]) -> [Achievement] {
        var achievements: [Achievement] = []

        // Finde Personal Records (letzten 2 Wochen)
        let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= twoWeeksAgo }

        // TODO: Implementiere PR-Erkennung
        // Dies würde einen Vergleich mit historischen Daten erfordern

        return achievements
    }
}
