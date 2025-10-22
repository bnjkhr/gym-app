import Foundation

/// Progression Score: Gesamtmetrik zur Bewertung des Trainingsfortschritts (0-100)
/// Kombiniert mehrere Faktoren: Kraft-PRs, Volumen-Steigerung, Konsistenz, Muskelbalance
struct ProgressionScore {
    let totalScore: Int // 0-100
    let strengthScore: Double // 0-25
    let volumeScore: Double // 0-25
    let consistencyScore: Double // 0-30
    let balanceScore: Double // 0-20

    let details: ProgressionDetails

    /// Berechnet den Progression Score basierend auf Session-Daten und Records
    static func calculate(
        sessions: [WorkoutSessionEntityV1],
        records: [ExerciseRecord],
        weeklyGoal: Int,
        compareWeeks: Int = 4
    ) -> ProgressionScore {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .weekOfYear, value: -compareWeeks, to: now) ?? now

        let recentSessions = sessions.filter { $0.date >= startDate }

        // 1. Kraft-Score (0-25): Basiert auf neuen PRs in der Vergleichsperiode
        let strengthScore = calculateStrengthScore(records: records, startDate: startDate)

        // 2. Volumen-Score (0-25): Basiert auf Volumen-Steigerung
        let volumeScore = calculateVolumeScore(sessions: recentSessions, compareWeeks: compareWeeks)

        // 3. Konsistenz-Score (0-30): Basiert auf Trainingsfrequenz vs. Ziel
        let consistencyScore = calculateConsistencyScore(
            sessions: recentSessions,
            weeklyGoal: weeklyGoal,
            compareWeeks: compareWeeks
        )

        // 4. Balance-Score (0-20): Basiert auf ausgewogenes Training aller Muskelgruppen
        let balanceScore = calculateBalanceScore(sessions: recentSessions)

        let total = Int(strengthScore + volumeScore + consistencyScore + balanceScore)

        let details = ProgressionDetails(
            newPRs: records.filter { $0.updatedAt >= startDate }.count,
            volumeChange: calculateVolumeChange(sessions: recentSessions, compareWeeks: compareWeeks),
            trainingFrequency: Double(recentSessions.count) / Double(compareWeeks),
            completionRate: calculateCompletionRate(sessions: recentSessions, weeklyGoal: weeklyGoal, compareWeeks: compareWeeks)
        )

        return ProgressionScore(
            totalScore: min(100, max(0, total)),
            strengthScore: strengthScore,
            volumeScore: volumeScore,
            consistencyScore: consistencyScore,
            balanceScore: balanceScore,
            details: details
        )
    }

    // MARK: - Score Calculations

    private static func calculateStrengthScore(records: [ExerciseRecord], startDate: Date) -> Double {
        let newPRs = records.filter { $0.updatedAt >= startDate }

        // Pro neuen PR gibt es Punkte (max 25)
        // 0 PRs = 0, 1 PR = 5, 2 PRs = 10, 3 PRs = 15, 4 PRs = 20, 5+ PRs = 25
        let prScore = min(25.0, Double(newPRs.count) * 5.0)
        return prScore
    }

    private static func calculateVolumeScore(sessions: [WorkoutSessionEntityV1], compareWeeks: Int) -> Double {
        guard compareWeeks >= 2 else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        let midPoint = calendar.date(byAdding: .weekOfYear, value: -(compareWeeks / 2), to: now) ?? now

        let firstHalf = sessions.filter { $0.date < midPoint }
        let secondHalf = sessions.filter { $0.date >= midPoint }

        let firstHalfVolume = calculateTotalVolume(sessions: firstHalf)
        let secondHalfVolume = calculateTotalVolume(sessions: secondHalf)

        guard firstHalfVolume > 0 else { return 0 }

        // Volumen-Steigerung berechnen
        let volumeIncrease = ((secondHalfVolume - firstHalfVolume) / firstHalfVolume) * 100

        // 0% Steigerung = 10 Punkte (Erhaltung)
        // 10% Steigerung = 17.5 Punkte
        // 20%+ Steigerung = 25 Punkte (max)
        if volumeIncrease >= 20 {
            return 25.0
        } else if volumeIncrease >= 0 {
            return 10.0 + (volumeIncrease / 20.0) * 15.0
        } else {
            // Negative Steigerung = Abzug
            return max(0, 10.0 + (volumeIncrease / 10.0) * 10.0)
        }
    }

    private static func calculateConsistencyScore(
        sessions: [WorkoutSessionEntityV1],
        weeklyGoal: Int,
        compareWeeks: Int
    ) -> Double {
        guard weeklyGoal > 0 else { return 0 }

        let targetSessions = weeklyGoal * compareWeeks
        let actualSessions = sessions.count

        // 100% des Ziels = 30 Punkte
        // 80-100% = 25-30 Punkte
        // 50-80% = 15-25 Punkte
        // <50% = 0-15 Punkte
        let completionRate = Double(actualSessions) / Double(targetSessions)

        if completionRate >= 1.0 {
            return 30.0
        } else if completionRate >= 0.8 {
            return 25.0 + (completionRate - 0.8) * 25.0
        } else if completionRate >= 0.5 {
            return 15.0 + (completionRate - 0.5) * 33.33
        } else {
            return completionRate * 30.0
        }
    }

    private static func calculateBalanceScore(sessions: [WorkoutSessionEntityV1]) -> Double {
        var muscleGroupVolumes: [MuscleGroup: Double] = [:]

        // Volumen pro Muskelgruppe sammeln
        for session in sessions {
            for exercise in session.exercises {
                guard let exerciseEntity = exercise.exercise else { continue }

                let volume = exercise.sets.reduce(0.0) { total, set in
                    total + (Double(set.reps) * set.weight)
                }

                // Zu allen Muskelgruppen der Übung hinzufügen
                for muscleGroupRaw in exerciseEntity.muscleGroupsRaw {
                    if let muscleGroup = MuscleGroup(rawValue: muscleGroupRaw) {
                        muscleGroupVolumes[muscleGroup, default: 0] += volume
                    }
                }
            }
        }

        guard !muscleGroupVolumes.isEmpty else { return 0 }

        // Hauptmuskelgruppen (ohne Cardio)
        let mainMuscleGroups: [MuscleGroup] = [
            .chest, .back, .shoulders, .biceps, .triceps, .legs, .abs
        ]

        let mainVolumes = mainMuscleGroups.compactMap { muscleGroupVolumes[$0] ?? 0 }
        guard !mainVolumes.isEmpty else { return 0 }

        let totalVolume = mainVolumes.reduce(0, +)
        let avgVolume = totalVolume / Double(mainVolumes.count)

        // Berechne Standardabweichung (niedrig = ausgewogen)
        let variance = mainVolumes.reduce(0) { sum, volume in
            let diff = volume - avgVolume
            return sum + (diff * diff)
        } / Double(mainVolumes.count)
        let stdDev = sqrt(variance)

        // Coefficient of Variation: StdDev / Mean
        let cv = avgVolume > 0 ? (stdDev / avgVolume) : 1.0

        // Niedrigere CV = besser ausgewogen
        // CV < 0.3 = sehr ausgewogen = 20 Punkte
        // CV 0.3-0.5 = mäßig = 15-20 Punkte
        // CV 0.5-1.0 = unausgeglichen = 5-15 Punkte
        // CV > 1.0 = sehr unausgeglichen = 0-5 Punkte
        if cv <= 0.3 {
            return 20.0
        } else if cv <= 0.5 {
            return 15.0 + (0.5 - cv) * 25.0
        } else if cv <= 1.0 {
            return 5.0 + (1.0 - cv) * 20.0
        } else {
            return max(0, 5.0 - (cv - 1.0) * 5.0)
        }
    }

    // MARK: - Helper Functions

    private static func calculateTotalVolume(sessions: [WorkoutSessionEntityV1]) -> Double {
        return sessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                    setTotal + (Double(set.reps) * set.weight)
                }
            }
        }
    }

    private static func calculateVolumeChange(sessions: [WorkoutSessionEntityV1], compareWeeks: Int) -> Double {
        guard compareWeeks >= 2 else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        let midPoint = calendar.date(byAdding: .weekOfYear, value: -(compareWeeks / 2), to: now) ?? now

        let firstHalf = sessions.filter { $0.date < midPoint }
        let secondHalf = sessions.filter { $0.date >= midPoint }

        let firstHalfVolume = calculateTotalVolume(sessions: firstHalf)
        let secondHalfVolume = calculateTotalVolume(sessions: secondHalf)

        guard firstHalfVolume > 0 else { return 0 }

        return ((secondHalfVolume - firstHalfVolume) / firstHalfVolume) * 100
    }

    private static func calculateCompletionRate(
        sessions: [WorkoutSessionEntityV1],
        weeklyGoal: Int,
        compareWeeks: Int
    ) -> Double {
        guard weeklyGoal > 0 else { return 0 }
        let targetSessions = weeklyGoal * compareWeeks
        return (Double(sessions.count) / Double(targetSessions)) * 100
    }

    // MARK: - Score Interpretation

    var interpretation: String {
        switch totalScore {
        case 90...100: return "Ausgezeichnet! 🔥"
        case 75..<90: return "Sehr gut! 💪"
        case 60..<75: return "Gut im Plan 👍"
        case 40..<60: return "Solide Basis 📈"
        case 20..<40: return "Am Anfang 🌱"
        default: return "Starte durch! 🚀"
        }
    }

    var color: (light: String, dark: String) {
        switch totalScore {
        case 75...100: return ("mossGreen", "turquoiseBoost")
        case 50..<75: return ("deepBlue", "turquoiseBoost")
        case 25..<50: return ("powerOrange", "powerOrange")
        default: return ("gray", "gray")
        }
    }
}

// MARK: - Supporting Types

struct ProgressionDetails {
    let newPRs: Int
    let volumeChange: Double // Prozent
    let trainingFrequency: Double // Durchschnittliche Trainings pro Woche
    let completionRate: Double // Prozent des wöchentlichen Ziels
}
