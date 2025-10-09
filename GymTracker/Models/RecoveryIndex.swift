import Foundation
import HealthKit

/// Recovery Index: Bewertet den Erholungszustand basierend auf HealthKit-Daten
/// Kombiniert: Ruhepuls, Schlaf, Trainingsvolumen, Trainingsfrequenz
struct RecoveryIndex {
    let score: Int // 0-100 (100 = optimal erholt)
    let status: RecoveryStatus
    let recommendation: String
    let details: RecoveryDetails

    enum RecoveryStatus {
        case excellent // 80-100
        case good // 60-79
        case moderate // 40-59
        case poor // 20-39
        case critical // 0-19

        var color: (light: String, dark: String) {
            switch self {
            case .excellent: return ("mossGreen", "turquoiseBoost")
            case .good: return ("deepBlue", "turquoiseBoost")
            case .moderate: return ("powerOrange", "powerOrange")
            case .poor: return ("red", "red")
            case .critical: return ("red", "red")
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "heart.circle.fill"
            case .good: return "heart.fill"
            case .moderate: return "heart"
            case .poor: return "heart.slash"
            case .critical: return "exclamationmark.triangle.fill"
            }
        }

        var title: String {
            switch self {
            case .excellent: return "Bestens erholt!"
            case .good: return "Gut erholt"
            case .moderate: return "Mäßig erholt"
            case .poor: return "Wenig erholt"
            case .critical: return "Erschöpft"
            }
        }
    }

    /// Berechnet den Recovery Index
    static func calculate(
        restingHeartRate: Double?, // Ruhepuls (bpm)
        baselineRestingHR: Double?, // Baseline Ruhepuls (Durchschnitt der letzten 30 Tage)
        sleepHours: Double?, // Schlafstunden letzte Nacht
        recentSessions: [WorkoutSessionEntity], // Letzte 7 Tage
        weeklyGoal: Int
    ) -> RecoveryIndex {
        var totalScore = 0.0
        var factors: [String: Double] = [:]

        // 1. Ruhepuls-Score (0-30)
        let hrScore = calculateHRScore(
            current: restingHeartRate,
            baseline: baselineRestingHR
        )
        totalScore += hrScore
        factors["Herzfrequenz"] = hrScore

        // 2. Schlaf-Score (0-30)
        let sleepScore = calculateSleepScore(sleepHours: sleepHours)
        totalScore += sleepScore
        factors["Schlaf"] = sleepScore

        // 3. Trainingsbelastung-Score (0-25)
        let loadScore = calculateTrainingLoadScore(sessions: recentSessions)
        totalScore += loadScore
        factors["Belastung"] = loadScore

        // 4. Frequenz-Score (0-15)
        let frequencyScore = calculateFrequencyScore(sessions: recentSessions, weeklyGoal: weeklyGoal)
        totalScore += frequencyScore
        factors["Frequenz"] = frequencyScore

        let finalScore = Int(min(100, max(0, totalScore)))
        let status = determineStatus(score: finalScore)
        let recommendation = generateRecommendation(
            score: finalScore,
            status: status,
            hrScore: hrScore,
            sleepScore: sleepScore,
            loadScore: loadScore
        )

        let details = RecoveryDetails(
            restingHR: restingHeartRate,
            baselineHR: baselineRestingHR,
            sleepHours: sleepHours,
            trainingsThisWeek: recentSessions.count,
            factors: factors
        )

        return RecoveryIndex(
            score: finalScore,
            status: status,
            recommendation: recommendation,
            details: details
        )
    }

    // MARK: - Score Calculations

    private static func calculateHRScore(current: Double?, baseline: Double?) -> Double {
        guard let current = current, let baseline = baseline else {
            return 15.0 // Neutral wenn keine Daten
        }

        let difference = current - baseline
        let percentageChange = (difference / baseline) * 100

        // Niedrigerer Ruhepuls = besser erholt
        // -5% oder mehr = 30 Punkte (sehr gut erholt)
        // Normal (±2%) = 20 Punkte
        // +5% oder mehr = 10 Punkte (schlecht erholt)
        // +10% oder mehr = 0 Punkte (sehr schlecht)

        if percentageChange <= -5 {
            return 30.0
        } else if percentageChange <= -2 {
            return 25.0
        } else if percentageChange <= 2 {
            return 20.0
        } else if percentageChange <= 5 {
            return 15.0
        } else if percentageChange <= 10 {
            return 10.0
        } else {
            return max(0, 10.0 - (percentageChange - 10) * 2)
        }
    }

    private static func calculateSleepScore(sleepHours: Double?) -> Double {
        guard let sleep = sleepHours else {
            return 15.0 // Neutral wenn keine Daten
        }

        // 7-9 Stunden = optimal (30 Punkte)
        // 6-7 oder 9-10 Stunden = gut (20-25 Punkte)
        // <6 oder >10 Stunden = suboptimal (0-15 Punkte)

        if sleep >= 7 && sleep <= 9 {
            return 30.0
        } else if sleep >= 6 && sleep < 7 {
            return 25.0
        } else if sleep > 9 && sleep <= 10 {
            return 20.0
        } else if sleep >= 5 && sleep < 6 {
            return 15.0
        } else if sleep > 10 && sleep <= 11 {
            return 15.0
        } else if sleep >= 4 && sleep < 5 {
            return 10.0
        } else {
            return 5.0
        }
    }

    private static func calculateTrainingLoadScore(sessions: [WorkoutSessionEntity]) -> Double {
        let totalVolume = sessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                    setTotal + (Double(set.reps) * set.weight)
                }
            }
        }

        // Volumen-Belastung: Je höher, desto mehr Recovery nötig
        // 0-10.000 kg = 25 Punkte (leichte Woche)
        // 10.000-20.000 kg = 20 Punkte (moderate Woche)
        // 20.000-30.000 kg = 15 Punkte (harte Woche)
        // 30.000+ kg = 10 Punkte (sehr harte Woche)

        if totalVolume <= 10_000 {
            return 25.0
        } else if totalVolume <= 20_000 {
            return 20.0
        } else if totalVolume <= 30_000 {
            return 15.0
        } else if totalVolume <= 40_000 {
            return 10.0
        } else {
            return 5.0
        }
    }

    private static func calculateFrequencyScore(sessions: [WorkoutSessionEntity], weeklyGoal: Int) -> Double {
        let sessionCount = sessions.count

        // Frequenz: Balance zwischen Aktivität und Erholung
        // Ziel = 15 Punkte
        // Unter Ziel = gut für Recovery (20 Punkte)
        // Über Ziel = evtl. zu viel (10 Punkte)
        // Deutlich über Ziel = definitiv zu viel (5 Punkte)

        if sessionCount < weeklyGoal {
            return 20.0
        } else if sessionCount == weeklyGoal {
            return 15.0
        } else if sessionCount <= weeklyGoal + 1 {
            return 10.0
        } else {
            return max(0, 10.0 - Double(sessionCount - weeklyGoal - 1) * 3)
        }
    }

    private static func determineStatus(score: Int) -> RecoveryStatus {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .moderate
        case 20..<40: return .poor
        default: return .critical
        }
    }

    private static func generateRecommendation(
        score: Int,
        status: RecoveryStatus,
        hrScore: Double,
        sleepScore: Double,
        loadScore: Double
    ) -> String {
        switch status {
        case .excellent:
            return "Perfekt! Dein Körper ist bereit für intensives Training. Zeit für schwere Gewichte! 💪"

        case .good:
            if sleepScore < 20 {
                return "Gut erholt! Achte heute Abend auf ausreichend Schlaf für optimale Recovery."
            } else {
                return "Gute Form! Folge deinem normalen Trainingsplan."
            }

        case .moderate:
            if hrScore < 15 {
                return "Erhöhter Ruhepuls. Vielleicht heute ein moderates Training oder Deload?"
            } else if sleepScore < 15 {
                return "Wenig Schlaf. Erwäge ein leichteres Training oder aktive Erholung (Cardio, Dehnen)."
            } else if loadScore < 15 {
                return "Hohes Trainingsvolumen diese Woche. Gönn dir heute etwas Leichteres."
            } else {
                return "Mäßig erholt. Trainiere moderat oder mach einen Deload-Tag."
            }

        case .poor:
            return "Wenig erholt. Empfehlung: Ruhetag oder nur leichtes Cardio/Mobility-Training."

        case .critical:
            return "⚠️ Kritisch! Dein Körper braucht dringend Ruhe. Nimm einen Ruhetag und priorisiere Schlaf!"
        }
    }
}

// MARK: - Supporting Types

struct RecoveryDetails {
    let restingHR: Double?
    let baselineHR: Double?
    let sleepHours: Double?
    let trainingsThisWeek: Int
    let factors: [String: Double] // Score-Beiträge einzelner Faktoren

    var hrChangePercentage: Double? {
        guard let resting = restingHR, let baseline = baselineHR else { return nil }
        return ((resting - baseline) / baseline) * 100
    }

    var hrStatus: String {
        guard let change = hrChangePercentage else { return "Keine Daten" }
        if change <= -5 { return "Sehr gut ↓" }
        else if change <= -2 { return "Gut ↓" }
        else if change <= 2 { return "Normal →" }
        else if change <= 5 { return "Erhöht ↑" }
        else { return "Stark erhöht ↑↑" }
    }

    var sleepStatus: String {
        guard let sleep = sleepHours else { return "Keine Daten" }
        if sleep >= 7 && sleep <= 9 { return "Optimal ✓" }
        else if sleep >= 6 && sleep < 7 { return "Gut" }
        else if sleep < 6 { return "Zu wenig" }
        else { return "Sehr lang" }
    }
}
