import Foundation

// MARK: - Tip Engine

class TipEngine {

    // MARK: - Main Generation Method

    func generateTips(
        from analysis: WorkoutAnalyzer.AnalysisResult,
        profile: UserProfile,
        healthData: HealthData?,
        maxTips: Int = 3
    ) -> [TrainingTip] {
        var allTips: [TrainingTip] = []

        // Regel 1-3: Progression
        allTips.append(contentsOf: progressionTips(analysis.progressionOpportunities))

        // Regel 4-5: Balance
        allTips.append(contentsOf: balanceTips(analysis.muscleGroupBalance))

        // Regel 6-7: Recovery
        allTips.append(contentsOf: recoveryTips(analysis.recoveryStatus))

        // Regel 8-9: Consistency
        allTips.append(contentsOf: consistencyTips(analysis.consistencyMetrics))

        // Regel 10-12: Goal Alignment
        allTips.append(contentsOf: goalTips(analysis.goalAlignment, profile: profile))

        // Regel 13: Achievements
        allTips.append(contentsOf: achievementTips(analysis.recentAchievements))

        // Regel 14-15: Health Integration
        if let health = healthData {
            allTips.append(contentsOf: healthTips(health, profile: profile))
        }

        // Sortiere nach Priorität und nimm Top N
        return Array(allTips.sorted { $0.priority > $1.priority }.prefix(maxTips))
    }

    // MARK: - Regel 1-3: Progression Tips

    private func progressionTips(_ opportunities: [WorkoutAnalyzer.ProgressionOpportunity]) -> [TrainingTip] {
        var tips: [TrainingTip] = []

        // Regel 1: Gewicht erhöhen bei Plateau
        if let topOpportunity = opportunities.sorted(by: { $0.weeksAtSameLevel > $1.weeksAtSameLevel }).first {
            if topOpportunity.weeksAtSameLevel >= 3 {
                let currentWeight = String(format: "%.1f", topOpportunity.currentWeight)
                let suggestedWeight = String(format: "%.1f", topOpportunity.suggestedWeight ?? 0)

                tips.append(TrainingTip(
                    category: .progression,
                    title: "Zeit für mehr Gewicht!",
                    message: "Du trainierst \(topOpportunity.exerciseName) seit \(topOpportunity.weeksAtSameLevel) Wochen mit \(currentWeight) kg. Versuche heute \(suggestedWeight) kg - du schaffst das! 💪",
                    emoji: "🏋️‍♂️",
                    priority: .high,
                    metadata: TipMetadata(
                        exerciseName: topOpportunity.exerciseName,
                        currentValue: topOpportunity.currentWeight,
                        suggestedValue: topOpportunity.suggestedWeight
                    )
                ))
            }
        }

        // Regel 2: Reps erhöhen
        if let opportunity = opportunities.first(where: { $0.currentReps < 8 && $0.weeksAtSameLevel >= 2 }) {
            tips.append(TrainingTip(
                category: .progression,
                title: "Erhöhe deine Wiederholungen",
                message: "Bei \(opportunity.exerciseName) schaffst du aktuell \(opportunity.currentReps) Wiederholungen. Versuche \(opportunity.suggestedReps ?? opportunity.currentReps + 1) zu erreichen! 🎯",
                emoji: "📈",
                priority: .medium,
                metadata: TipMetadata(
                    exerciseName: opportunity.exerciseName,
                    currentValue: Double(opportunity.currentReps),
                    suggestedValue: Double(opportunity.suggestedReps ?? opportunity.currentReps + 1)
                )
            ))
        }

        // Regel 3: Progressive Overload generell
        if opportunities.count >= 3 {
            tips.append(TrainingTip(
                category: .progression,
                title: "Progressive Überladung",
                message: "Du hast bei mehreren Übungen Plateau erreicht. Zeit für einen Deload oder neue Trainingsreize! 🔄",
                emoji: "⚡️",
                priority: .medium
            ))
        }

        return tips
    }

    // MARK: - Regel 4-5: Balance Tips

    private func balanceTips(_ balance: WorkoutAnalyzer.MuscleGroupBalance) -> [TrainingTip] {
        var tips: [TrainingTip] = []

        // Regel 4: Push-Pull Ungleichgewicht
        if let pushPullImbalance = balance.imbalances.first(where: {
            ($0.overtrainedGroup == .chest && $0.undertrainedGroup == .back) ||
            ($0.overtrainedGroup == .back && $0.undertrainedGroup == .chest)
        }) {
            let ratio = String(format: "%.1f", pushPullImbalance.ratio)

            tips.append(TrainingTip(
                category: .balance,
                title: "Muskel-Ungleichgewicht erkannt",
                message: "Dein \(pushPullImbalance.overtrainedGroup.rawValue)-Training ist \(ratio)x höher als dein \(pushPullImbalance.undertrainedGroup.rawValue)-Training. Fokussiere dich mehr auf \(pushPullImbalance.undertrainedGroup.rawValue) für eine ausgewogene Entwicklung! ⚖️",
                emoji: "🎯",
                priority: .high,
                metadata: TipMetadata(
                    muscleGroup: pushPullImbalance.undertrainedGroup.rawValue
                )
            ))
        }

        // Regel 5: Beine vs Oberkörper
        if let upperLowerImbalance = balance.imbalances.first(where: {
            $0.undertrainedGroup == .legs
        }) {
            let ratio = String(format: "%.1f", upperLowerImbalance.ratio)

            tips.append(TrainingTip(
                category: .balance,
                title: "Never skip Leg Day!",
                message: "Dein Oberkörper bekommt \(ratio)x mehr Volumen als deine Beine. Wie wäre ein Leg Day diese Woche? 🦵",
                emoji: "🏃‍♂️",
                priority: .high,
                metadata: TipMetadata(
                    muscleGroup: MuscleGroup.legs.rawValue
                )
            ))
        }

        return tips
    }

    // MARK: - Regel 6-7: Recovery Tips

    private func recoveryTips(_ recovery: WorkoutAnalyzer.RecoveryStatus) -> [TrainingTip] {
        var tips: [TrainingTip] = []

        // Regel 6: Übertraining-Warnung
        if recovery.overtrainingRisk {
            tips.append(TrainingTip(
                category: .recovery,
                title: "Achtung: Übertraining!",
                message: "Du hast \(recovery.workoutsInLastWeek) Workouts in 7 Tagen absolviert. Gönn dir eine Pause für optimale Regeneration und Muskelwachstum! 🛌",
                emoji: "⚠️",
                priority: .high
            ))
        }

        // Regel 7: Zurück nach Pause
        if recovery.daysSinceLastWorkout >= 5 && recovery.daysSinceLastWorkout <= 10 {
            tips.append(TrainingTip(
                category: .recovery,
                title: "Willkommen zurück!",
                message: "Dein letztes Workout ist \(recovery.daysSinceLastWorkout) Tage her. Du bist erholt - Zeit für ein neues Training! 💪",
                emoji: "🔥",
                priority: .high
            ))
        }

        // Regel 7b: Lange Pause
        if recovery.daysSinceLastWorkout > 14 {
            tips.append(TrainingTip(
                category: .consistency,
                title: "Lange nicht gesehen!",
                message: "Es ist schon \(recovery.daysSinceLastWorkout) Tage her. Jeder Schritt zählt - starte noch heute mit einem leichten Workout! 🚀",
                emoji: "💫",
                priority: .high
            ))
        }

        return tips
    }

    // MARK: - Regel 8-9: Consistency Tips

    private func consistencyTips(_ metrics: WorkoutAnalyzer.ConsistencyMetrics) -> [TrainingTip] {
        var tips: [TrainingTip] = []

        // Regel 8: Streak feiern
        if metrics.currentStreak >= 3 {
            tips.append(TrainingTip(
                category: .motivation,
                title: "Streak läuft! 🔥",
                message: "Du hast \(metrics.currentStreak) Workouts in Folge absolviert! Das ist beeindruckende Konsistenz - weiter so! 💪",
                emoji: "🔥",
                priority: .medium
            ))
        }

        // Regel 9: Konsistenz verbessern
        if metrics.avgWorkoutsPerWeek < 2.0 && metrics.totalWorkouts >= 5 {
            let avg = String(format: "%.1f", metrics.avgWorkoutsPerWeek)
            tips.append(TrainingTip(
                category: .consistency,
                title: "Mehr Konsistenz = Mehr Erfolg",
                message: "Du trainierst aktuell \(avg)x pro Woche. Versuche 3-4x zu erreichen für optimale Fortschritte! 📅",
                emoji: "📆",
                priority: .medium
            ))
        }

        // Regel 9b: Perfekte Konsistenz
        if metrics.avgWorkoutsPerWeek >= 3.0 && metrics.avgWorkoutsPerWeek <= 5.0 {
            let avg = String(format: "%.1f", metrics.avgWorkoutsPerWeek)
            tips.append(TrainingTip(
                category: .motivation,
                title: "Perfekte Trainingsfrequenz!",
                message: "Du trainierst \(avg)x pro Woche - genau richtig für optimales Muskelwachstum und Regeneration! Exzellent! 🌟",
                emoji: "⭐️",
                priority: .low
            ))
        }

        return tips
    }

    // MARK: - Regel 10-12: Goal Alignment Tips

    private func goalTips(_ alignment: WorkoutAnalyzer.GoalAlignment, profile: UserProfile) -> [TrainingTip] {
        var tips: [TrainingTip] = []

        // Regel 10: Rep-Range anpassen (Muskelaufbau)
        if alignment.goal == .muscleBuilding && alignment.repRangeMatch == .tooLow {
            tips.append(TrainingTip(
                category: .goal,
                title: "Optimiere für Muskelaufbau",
                message: "Für optimalen Muskelaufbau solltest du 8-12 Wiederholungen pro Satz anstreben. Reduziere das Gewicht etwas und erhöhe die Wiederholungen! 💪",
                emoji: "🎯",
                priority: .high
            ))
        }

        // Regel 11: Rep-Range anpassen (Kraft)
        if alignment.goal == .strength && alignment.repRangeMatch == .tooHigh {
            tips.append(TrainingTip(
                category: .goal,
                title: "Optimiere für Kraftzuwachs",
                message: "Für maximale Kraft solltest du 3-6 Wiederholungen mit schwerem Gewicht trainieren. Erhöhe das Gewicht und reduziere die Wiederholungen! ⚡️",
                emoji: "💪",
                priority: .high
            ))
        }

        // Regel 12: Volumen anpassen
        if alignment.volumeAdequate == .tooLow {
            tips.append(TrainingTip(
                category: .goal,
                title: "Erhöhe dein Trainingsvolumen",
                message: "Dein aktuelles Volumen ist etwas niedrig für dein Ziel (\(alignment.goal.displayName)). Füge 1-2 Sätze pro Übung hinzu! 📈",
                emoji: "📊",
                priority: .medium
            ))
        }

        return tips
    }

    // MARK: - Regel 13: Achievement Tips

    private func achievementTips(_ achievements: [WorkoutAnalyzer.Achievement]) -> [TrainingTip] {
        var tips: [TrainingTip] = []

        for achievement in achievements {
            switch achievement.type {
            case .newPersonalRecord(let weight, let reps):
                tips.append(TrainingTip(
                    category: .motivation,
                    title: "Neuer Personal Record! 🏆",
                    message: "Glückwunsch zu deinem neuen PR bei \(achievement.exerciseName): \(weight)kg × \(reps) Wiederholungen! Du bist ein Champion! 🎉",
                    emoji: "🏆",
                    priority: .high,
                    metadata: TipMetadata(
                        exerciseName: achievement.exerciseName,
                        currentValue: weight
                    )
                ))

            case .volumeIncrease(let percent):
                let percentStr = String(format: "%.0f", percent)
                tips.append(TrainingTip(
                    category: .motivation,
                    title: "Volumen-Steigerung!",
                    message: "Dein Trainingsvolumen bei \(achievement.exerciseName) ist um \(percentStr)% gestiegen! Großartige Progression! 📈",
                    emoji: "📊",
                    priority: .medium
                ))

            case .consistencyMilestone(let days):
                tips.append(TrainingTip(
                    category: .motivation,
                    title: "Konsistenz-Meilenstein!",
                    message: "\(days) Tage Training in Folge! Das ist wahre Hingabe - du bist ein Vorbild! 🌟",
                    emoji: "🎖",
                    priority: .medium
                ))
            }
        }

        return tips
    }

    // MARK: - Regel 14-15: Health Tips

    private func healthTips(_ health: HealthData, profile: UserProfile) -> [TrainingTip] {
        var tips: [TrainingTip] = []

        // Regel 14: Gewichtstrend bei Muskelaufbau
        if profile.goal == .muscleBuilding, let trend = health.weightTrend {
            switch trend {
            case .increasing(let amount, let weeks):
                let amountStr = String(format: "%.1f", amount)
                tips.append(TrainingTip(
                    category: .motivation,
                    title: "Gewichtszunahme - Perfekt!",
                    message: "Du hast in \(weeks) Wochen \(amountStr) kg zugenommen - genau richtig für Muskelaufbau! Weiter so! 💪",
                    emoji: "📈",
                    priority: .medium
                ))

            case .decreasing(let amount, let weeks):
                let amountStr = String(format: "%.1f", amount)
                tips.append(TrainingTip(
                    category: .goal,
                    title: "Gewicht sinkt",
                    message: "Dein Gewicht ist um \(amountStr) kg gefallen. Für Muskelaufbau solltest du mehr Kalorien zu dir nehmen. Iss mehr Protein! 🍗",
                    emoji: "🥗",
                    priority: .high
                ))

            case .stable:
                break
            }
        }

        // Regel 15: Gewichtstrend bei Gewichtsreduktion
        if profile.goal == .weightLoss, let trend = health.weightTrend {
            switch trend {
            case .decreasing(let amount, let weeks):
                let amountStr = String(format: "%.1f", amount)
                tips.append(TrainingTip(
                    category: .motivation,
                    title: "Super Fortschritt!",
                    message: "Du hast in \(weeks) Wochen \(amountStr) kg abgenommen! Deine harte Arbeit zahlt sich aus! 🎉",
                    emoji: "🎯",
                    priority: .high
                ))

            case .increasing:
                tips.append(TrainingTip(
                    category: .goal,
                    title: "Kalorien-Check",
                    message: "Dein Gewicht steigt leicht an. Achte auf dein Kaloriendefizit und bleib dran - du schaffst das! 💪",
                    emoji: "🔍",
                    priority: .medium
                ))

            case .stable:
                break
            }
        }

        return tips
    }
}
