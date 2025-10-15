import Foundation
import SwiftData

/// Service für die Generierung von Workout-Plänen basierend auf Benutzer-Präferenzen
///
/// Dieser Service enthält die komplette Workout Wizard Logic und ist verantwortlich für:
/// - Auswahl passender Übungen basierend auf Equipment, Erfahrung und Muskelgruppen
/// - Berechnung von Sets, Reps und Pausenzeiten
/// - Generierung von Workout-Namen und -Notizen
/// - Anpassung an verschiedene Trainingsziele (Kraft, Muskelaufbau, Ausdauer, etc.)
@MainActor
final class WorkoutGenerationService {

    // MARK: - Error Types

    enum GenerationError: Error, LocalizedError {
        case noExercisesAvailable
        case insufficientExercises(required: Int, available: Int)
        case invalidPreferences

        var errorDescription: String? {
            switch self {
            case .noExercisesAvailable:
                return "Keine Übungen verfügbar für die gewählten Präferenzen"
            case .insufficientExercises(let required, let available):
                return
                    "Nicht genug Übungen gefunden (benötigt: \(required), verfügbar: \(available))"
            case .invalidPreferences:
                return "Ungültige Workout-Präferenzen"
            }
        }
    }

    // MARK: - Public API

    /// Generiert ein komplettes Workout basierend auf Benutzer-Präferenzen
    ///
    /// - Parameters:
    ///   - preferences: Die Workout-Präferenzen des Benutzers
    ///   - exercises: Alle verfügbaren Übungen aus der Datenbank
    /// - Returns: Ein vollständig konfiguriertes Workout
    /// - Throws: GenerationError bei Problemen während der Generierung
    func generateWorkout(from preferences: WorkoutPreferences, using exercises: [Exercise]) throws
        -> Workout
    {
        guard !exercises.isEmpty else {
            throw GenerationError.noExercisesAvailable
        }

        let muscleGroups = selectMuscleGroups(for: preferences)
        let selectedExercises = selectExercises(
            for: preferences,
            targeting: muscleGroups,
            from: exercises
        )

        guard !selectedExercises.isEmpty else {
            throw GenerationError.insufficientExercises(
                required: calculateExerciseCount(for: preferences),
                available: 0
            )
        }

        let workoutExercises = createWorkoutExercises(
            from: selectedExercises,
            preferences: preferences
        )

        return Workout(
            name: generateWorkoutName(for: preferences),
            exercises: workoutExercises,
            defaultRestTime: calculateRestTime(for: preferences),
            notes: generateWorkoutNotes(for: preferences)
        )
    }

    // MARK: - Muscle Group Selection

    /// Wählt die zu trainierenden Muskelgruppen basierend auf der Trainingsfrequenz
    ///
    /// - Parameter preferences: Die Workout-Präferenzen
    /// - Returns: Array der zu trainierenden Muskelgruppen
    private func selectMuscleGroups(for preferences: WorkoutPreferences) -> [MuscleGroup] {
        switch preferences.frequency {
        case 1, 2:
            // Ganzkörper-Workouts
            return [.chest, .back, .shoulders, .legs, .abs]
        case 3:
            // 3er Split: Push/Pull/Legs
            return [.chest, .back, .legs, .shoulders, .abs]
        case 4, 5:
            // 4-5er Split: mehr Fokus auf spezifische Gruppen
            return [.chest, .back, .shoulders, .legs, .biceps, .triceps, .abs]
        default:
            // 6+ Split: sehr spezifisch
            return MuscleGroup.allCases
        }
    }

    // MARK: - Exercise Selection

    /// Wählt passende Übungen basierend auf Präferenzen und Muskelgruppen
    ///
    /// Algorithmus:
    /// 1. Filtert nach Equipment und Schwierigkeit
    /// 2. Trennt in Compound- und Isolation-Übungen
    /// 3. Wählt Übungen basierend auf Erfahrungslevel-Ratio
    /// 4. Bevorzugt passende Schwierigkeitsgrade, nutzt Fallbacks
    ///
    /// - Parameters:
    ///   - preferences: Die Workout-Präferenzen
    ///   - muscleGroups: Die zu trainierenden Muskelgruppen
    ///   - exercises: Alle verfügbaren Übungen
    /// - Returns: Array der ausgewählten Übungen
    private func selectExercises(
        for preferences: WorkoutPreferences,
        targeting muscleGroups: [MuscleGroup],
        from exercises: [Exercise]
    ) -> [Exercise] {
        var selectedExercises: [Exercise] = []

        // Filter nach Equipment UND Difficulty-Level
        let equipmentFiltered = filterExercisesByEquipment(preferences.equipment, from: exercises)
        let availableExercises = filterExercisesByDifficulty(
            equipmentFiltered,
            for: preferences.experience
        )

        // Grundübungen basierend auf Erfahrung
        let compoundExercises = availableExercises.filter { exercise in
            exercise.muscleGroups.count >= 2
        }

        let isolationExercises = availableExercises.filter { exercise in
            exercise.muscleGroups.count == 1
        }

        // Anzahl Übungen basierend auf Trainingsdauer
        let targetExerciseCount = calculateExerciseCount(for: preferences)

        // Compound-zu-Isolation Verhältnis basierend auf Erfahrung
        let compoundRatio: Double
        switch preferences.experience {
        case .beginner:
            compoundRatio = 0.8
        case .intermediate:
            compoundRatio = 0.6
        case .advanced:
            compoundRatio = 0.4
        }

        let compoundCount = Int(Double(targetExerciseCount) * compoundRatio)
        let isolationCount = targetExerciseCount - compoundCount

        // Wähle Compound-Übungen (bevorzuge passende Difficulty)
        for muscleGroup in muscleGroups.prefix(compoundCount) {
            // Versuche erst passende Difficulty zu finden
            if let exercise = compoundExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup)
                    && !selectedExercises.contains(where: { $0.id == exercise.id })
                    && matchesDifficultyLevel(exercise, for: preferences.experience)
            }) {
                selectedExercises.append(exercise)
            }
            // Fallback: Ignoriere Difficulty wenn nichts passendes gefunden
            else if let exercise = compoundExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup)
                    && !selectedExercises.contains(where: { $0.id == exercise.id })
            }) {
                selectedExercises.append(exercise)
            }
        }

        // Fülle mit Isolation-Übungen auf (bevorzuge passende Difficulty)
        for muscleGroup in muscleGroups.prefix(isolationCount) {
            // Versuche erst passende Difficulty zu finden
            if let exercise = isolationExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup)
                    && !selectedExercises.contains(where: { $0.id == exercise.id })
                    && matchesDifficultyLevel(exercise, for: preferences.experience)
            }) {
                selectedExercises.append(exercise)
            }
            // Fallback: Ignoriere Difficulty wenn nichts passendes gefunden
            else if let exercise = isolationExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup)
                    && !selectedExercises.contains(where: { $0.id == exercise.id })
            }) {
                selectedExercises.append(exercise)
            }
        }

        // Stelle sicher, dass wir genug Übungen haben
        while selectedExercises.count < targetExerciseCount
            && selectedExercises.count < availableExercises.count
        {
            if let nextExercise = availableExercises.first(where: { candidate in
                !selectedExercises.contains(where: { $0.id == candidate.id })
            }) {
                selectedExercises.append(nextExercise)
            } else {
                break
            }
        }

        return Array(selectedExercises.prefix(targetExerciseCount))
    }

    // MARK: - Exercise Filtering

    /// Filtert Übungen basierend auf dem Erfahrungslevel
    ///
    /// Priorisiert passende Übungen, lässt aber andere als Fallback zu
    ///
    /// - Parameters:
    ///   - exercises: Zu filternde Übungen
    ///   - level: Erfahrungslevel des Benutzers
    /// - Returns: Sortierte Übungen (passende zuerst)
    private func filterExercisesByDifficulty(
        _ exercises: [Exercise],
        for level: ExperienceLevel
    ) -> [Exercise] {
        // Sortiere so dass passende Übungen zuerst kommen
        return exercises.sorted { first, second in
            let firstMatches = matchesDifficultyLevel(first, for: level)
            let secondMatches = matchesDifficultyLevel(second, for: level)

            if firstMatches && !secondMatches {
                return true
            }
            if !firstMatches && secondMatches {
                return false
            }
            return false  // Behalte ursprüngliche Reihenfolge bei
        }
    }

    /// Filtert Übungen basierend auf Equipment-Präferenz
    ///
    /// - Parameters:
    ///   - equipment: Equipment-Präferenz
    ///   - exercises: Zu filternde Übungen
    /// - Returns: Gefilterte Übungen
    private func filterExercisesByEquipment(
        _ equipment: EquipmentPreference,
        from exercises: [Exercise]
    ) -> [Exercise] {
        switch equipment {
        case .freeWeights:
            return exercises.filter { exercise in
                !exercise.name.lowercased().contains("maschine")
                    && !exercise.name.lowercased().contains("machine")
            }
        case .machines:
            return exercises.filter { exercise in
                exercise.name.lowercased().contains("maschine")
                    || exercise.name.lowercased().contains("machine")
            }
        case .mixed:
            return exercises
        }
    }

    /// Prüft ob eine Übung zum Erfahrungslevel des Users passt
    ///
    /// - Parameters:
    ///   - exercise: Die zu prüfende Übung
    ///   - level: Das Erfahrungslevel des Users
    /// - Returns: true wenn die Übung zum Level passt oder nahe dran ist
    private func matchesDifficultyLevel(
        _ exercise: Exercise,
        for level: ExperienceLevel
    ) -> Bool {
        switch level {
        case .beginner:
            // Anfänger: Hauptsächlich Anfänger-Übungen, einige Fortgeschritten
            return exercise.difficultyLevel == .anfänger
                || exercise.difficultyLevel == .fortgeschritten
        case .intermediate:
            // Fortgeschritten: Alle Levels sind ok (Mix)
            return true
        case .advanced:
            // Experte: Hauptsächlich Fortgeschritten und Profi-Übungen
            return exercise.difficultyLevel == .fortgeschritten
                || exercise.difficultyLevel == .profi
        }
    }

    // MARK: - Exercise Count Calculation

    /// Berechnet die Anzahl der Übungen basierend auf Dauer und Erfahrung
    ///
    /// - Parameter preferences: Die Workout-Präferenzen
    /// - Returns: Anzahl der Übungen
    private func calculateExerciseCount(for preferences: WorkoutPreferences) -> Int {
        let baseCount: Int
        switch preferences.duration {
        case .short: baseCount = 4
        case .medium: baseCount = 6
        case .long: baseCount = 8
        case .extended: baseCount = 10
        }

        // Anpassung basierend auf Erfahrung
        switch preferences.experience {
        case .beginner:
            return max(3, baseCount - 1)
        case .intermediate:
            return baseCount
        case .advanced:
            return baseCount + 1
        }
    }

    // MARK: - WorkoutExercise Creation

    /// Erstellt WorkoutExercise-Objekte mit Sets und Reps
    ///
    /// - Parameters:
    ///   - exercises: Die ausgewählten Übungen
    ///   - preferences: Die Workout-Präferenzen
    /// - Returns: Array von WorkoutExercise-Objekten
    private func createWorkoutExercises(
        from exercises: [Exercise],
        preferences: WorkoutPreferences
    ) -> [WorkoutExercise] {
        return exercises.map { exercise in
            let setCount = calculateSetCount(for: exercise, preferences: preferences)
            let reps = calculateReps(for: exercise, preferences: preferences)
            let restTime = calculateRestTime(for: preferences)

            let sets = (0..<setCount).map { _ in
                ExerciseSet(reps: reps, weight: 0, restTime: restTime, completed: false)
            }

            return WorkoutExercise(exercise: exercise, sets: sets)
        }
    }

    // MARK: - Set/Rep/Rest Calculations

    /// Berechnet die Anzahl der Sätze für eine Übung
    ///
    /// Compound-Übungen erhalten einen zusätzlichen Satz
    ///
    /// - Parameters:
    ///   - exercise: Die Übung
    ///   - preferences: Die Workout-Präferenzen
    /// - Returns: Anzahl der Sätze
    private func calculateSetCount(
        for exercise: Exercise,
        preferences: WorkoutPreferences
    ) -> Int {
        let baseSetCount: Int
        switch preferences.experience {
        case .beginner: baseSetCount = 2
        case .intermediate: baseSetCount = 3
        case .advanced: baseSetCount = 4
        }

        let isCompound = exercise.muscleGroups.count >= 2
        return isCompound ? baseSetCount + 1 : baseSetCount
    }

    /// Berechnet die Anzahl der Wiederholungen basierend auf Trainingsziel
    ///
    /// - Parameters:
    ///   - exercise: Die Übung
    ///   - preferences: Die Workout-Präferenzen
    /// - Returns: Anzahl der Wiederholungen
    private func calculateReps(
        for exercise: Exercise,
        preferences: WorkoutPreferences
    ) -> Int {
        switch preferences.goal {
        case .strength:
            return Int.random(in: 3...6)
        case .muscleBuilding:
            return Int.random(in: 8...12)
        case .endurance:
            return Int.random(in: 15...20)
        case .weightLoss:
            return Int.random(in: 12...15)
        case .general:
            return Int.random(in: 10...12)
        }
    }

    /// Berechnet die Pausenzeit basierend auf Trainingsziel
    ///
    /// - Parameter preferences: Die Workout-Präferenzen
    /// - Returns: Pausenzeit in Sekunden
    private func calculateRestTime(for preferences: WorkoutPreferences) -> Double {
        switch preferences.goal {
        case .strength:
            return 120
        case .muscleBuilding:
            return 90
        case .endurance:
            return 60
        case .weightLoss:
            return 45
        case .general:
            return 75
        }
    }

    // MARK: - Name & Notes Generation

    /// Generiert einen beschreibenden Workout-Namen
    ///
    /// - Parameter preferences: Die Workout-Präferenzen
    /// - Returns: Generierter Workout-Name
    private func generateWorkoutName(for preferences: WorkoutPreferences) -> String {
        let goalPrefix: String
        switch preferences.goal {
        case .muscleBuilding: goalPrefix = "Muskelaufbau"
        case .strength: goalPrefix = "Kraft"
        case .endurance: goalPrefix = "Ausdauer"
        case .weightLoss: goalPrefix = "Fettverbrennung"
        case .general: goalPrefix = "Fitness"
        }

        let equipmentSuffix: String
        switch preferences.equipment {
        case .freeWeights: equipmentSuffix = "Freie Gewichte"
        case .machines: equipmentSuffix = "Maschinen"
        case .mixed: equipmentSuffix = "Mixed"
        }

        return "\(goalPrefix) - \(equipmentSuffix)"
    }

    /// Generiert hilfreiche Notizen für das Workout
    ///
    /// - Parameter preferences: Die Workout-Präferenzen
    /// - Returns: Generierte Notizen
    private func generateWorkoutNotes(for preferences: WorkoutPreferences) -> String {
        var notes: [String] = []

        notes.append("🎯 Ziel: \(preferences.goal.displayName)")
        notes.append("📊 Level: \(preferences.experience.displayName)")
        notes.append("⏱️ Dauer: ~\(preferences.duration.rawValue) Minuten")
        notes.append("🔄 Frequenz: \(preferences.frequency)x pro Woche")

        switch preferences.goal {
        case .strength:
            notes.append("💡 Tipp: Fokus auf schwere Gewichte, längere Pausen")
        case .muscleBuilding:
            notes.append("💡 Tipp: Kontrollierte Bewegungen, Muskel-Geist-Verbindung")
        case .endurance:
            notes.append("💡 Tipp: Höhere Wiederholungen, kürzere Pausen")
        case .weightLoss:
            notes.append("💡 Tipp: Intensität hoch halten, Supersätze möglich")
        case .general:
            notes.append("💡 Tipp: Ausgewogenes Training, auf Körper hören")
        }

        return notes.joined(separator: "\n")
    }
}
