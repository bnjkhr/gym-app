import Foundation

/// Week Comparison: Vergleicht diese Woche mit der letzten Woche
struct WeekComparison {
    let currentWeek: WeekStats
    let lastWeek: WeekStats

    // Berechnete Änderungen
    let volumeChange: Double // Prozent
    let volumeChangeAbsolute: Double // kg
    let prCountChange: Int
    let frequencyChange: Int
    let avgDurationChange: TimeInterval // Sekunden

    /// Berechnet den Wochenvergleich
    static func calculate(sessions: [WorkoutSessionEntityV1], records: [ExerciseRecord]) -> WeekComparison {
        let calendar = Calendar.current
        let now = Date()

        // Diese Woche (Montag - jetzt)
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let currentWeekSessions = sessions.filter { $0.date >= currentWeekStart }

        // Letzte Woche (Montag - Sonntag der Vorwoche)
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
        let lastWeekEnd = calendar.date(byAdding: .day, value: 6, to: lastWeekStart) ?? lastWeekStart
        let lastWeekSessions = sessions.filter { $0.date >= lastWeekStart && $0.date <= lastWeekEnd }

        // Berechne Stats für beide Wochen
        let currentStats = WeekStats.calculate(sessions: currentWeekSessions, records: records, startDate: currentWeekStart)
        let lastStats = WeekStats.calculate(sessions: lastWeekSessions, records: records, startDate: lastWeekStart)

        // Berechne Änderungen
        let volumeChangeAbs = currentStats.totalVolume - lastStats.totalVolume
        let volumeChangePct = lastStats.totalVolume > 0 ?
            ((currentStats.totalVolume - lastStats.totalVolume) / lastStats.totalVolume) * 100 : 0

        let prChange = currentStats.newPRs - lastStats.newPRs
        let freqChange = currentStats.workoutCount - lastStats.workoutCount
        let durationChange = currentStats.avgDuration - lastStats.avgDuration

        return WeekComparison(
            currentWeek: currentStats,
            lastWeek: lastStats,
            volumeChange: volumeChangePct,
            volumeChangeAbsolute: volumeChangeAbs,
            prCountChange: prChange,
            frequencyChange: freqChange,
            avgDurationChange: durationChange
        )
    }

    // MARK: - Trend Indicators

    var volumeTrend: Trend {
        if volumeChange >= 10 { return .increasing }
        else if volumeChange <= -10 { return .decreasing }
        else { return .stable }
    }

    var prTrend: Trend {
        if prCountChange > 0 { return .increasing }
        else if prCountChange < 0 { return .decreasing }
        else { return .stable }
    }

    var frequencyTrend: Trend {
        if frequencyChange > 0 { return .increasing }
        else if frequencyChange < 0 { return .decreasing }
        else { return .stable }
    }

    var durationTrend: Trend {
        if avgDurationChange >= 300 { return .increasing } // +5 Minuten
        else if avgDurationChange <= -300 { return .decreasing } // -5 Minuten
        else { return .stable }
    }

    enum Trend {
        case increasing
        case decreasing
        case stable

        var icon: String {
            switch self {
            case .increasing: return "arrow.up.right"
            case .decreasing: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }

        var color: (light: String, dark: String) {
            switch self {
            case .increasing: return ("mossGreen", "turquoiseBoost")
            case .decreasing: return ("powerOrange", "powerOrange")
            case .stable: return ("deepBlue", "turquoiseBoost")
            }
        }
    }
}

// MARK: - Week Stats

struct WeekStats {
    let weekStart: Date
    let workoutCount: Int
    let totalVolume: Double // kg
    let avgDuration: TimeInterval // Sekunden
    let newPRs: Int
    let totalSets: Int
    let muscleGroupBreakdown: [MuscleGroup: Double] // Volumen pro Muskelgruppe

    /// Berechnet Statistiken für eine Woche
    static func calculate(
        sessions: [WorkoutSessionEntityV1],
        records: [ExerciseRecord],
        startDate: Date
    ) -> WeekStats {
        let workoutCount = sessions.count

        // Total Volume (nur completed Sets für Konsistenz mit anderen Berechnungen)
        let totalVolume = sessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                exerciseTotal + exercise.sets.filter { $0.completed }.reduce(0.0) { setTotal, set in
                    setTotal + (Double(set.reps) * set.weight)
                }
            }
        }

        // Durchschnittliche Dauer
        let durations = sessions.compactMap { $0.duration }
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

        // Neue PRs (Records die in dieser Woche aktualisiert wurden)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        let newPRs = records.filter {
            $0.updatedAt >= startDate && $0.updatedAt <= weekEnd
        }.count

        // Total Sets
        let totalSets = sessions.reduce(0) { total, session in
            total + session.exercises.reduce(0) { exerciseTotal, exercise in
                exerciseTotal + exercise.sets.filter { $0.completed }.count
            }
        }

        // Muskelgruppen-Breakdown (nur completed Sets)
        var muscleGroupVolumes: [MuscleGroup: Double] = [:]
        for session in sessions {
            for exercise in session.exercises {
                guard let exerciseEntity = exercise.exercise else { continue }

                let volume = exercise.sets.filter { $0.completed }.reduce(0.0) { total, set in
                    total + (Double(set.reps) * set.weight)
                }

                for muscleGroupRaw in exerciseEntity.muscleGroupsRaw {
                    if let muscleGroup = MuscleGroup(rawValue: muscleGroupRaw),
                       muscleGroup != .cardio {
                        muscleGroupVolumes[muscleGroup, default: 0] += volume
                    }
                }
            }
        }

        return WeekStats(
            weekStart: startDate,
            workoutCount: workoutCount,
            totalVolume: totalVolume,
            avgDuration: avgDuration,
            newPRs: newPRs,
            totalSets: totalSets,
            muscleGroupBreakdown: muscleGroupVolumes
        )
    }

    /// Formatiert Volumen für Anzeige
    var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1ft", totalVolume / 1000)
        } else {
            return String(format: "%.0fkg", totalVolume)
        }
    }

    /// Formatiert Dauer für Anzeige
    var formattedDuration: String {
        let minutes = Int(avgDuration / 60)
        return "\(minutes)min"
    }
}
