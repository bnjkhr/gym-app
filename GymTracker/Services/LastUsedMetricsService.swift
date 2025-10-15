import Foundation
import SwiftData

// MARK: - ExerciseLastUsedMetrics

/// Struktur für Last-Used Metriken einer Übung
///
/// Diese Struktur enthält alle relevanten Informationen über die letzte Verwendung
/// einer Übung, inklusive Gewicht, Wiederholungen, Sätze und Zeitpunkt.
public struct ExerciseLastUsedMetrics {
    let weight: Double?
    let reps: Int?
    let setCount: Int?
    let lastUsedDate: Date?
    let restTime: TimeInterval?

    /// Gibt an ob verwertbare Daten vorhanden sind
    var hasData: Bool {
        weight != nil && reps != nil
    }

    /// Kurze Darstellung für UI (z.B. "20kg × 12 Wdh.")
    var displayText: String {
        guard let weight = weight, let reps = reps else {
            return "Keine vorherigen Daten"
        }
        return "Letztes Mal: \(weight.formatted())kg × \(reps) Wdh."
    }

    /// Detaillierte Darstellung mit allen verfügbaren Infos
    var detailedDisplayText: String {
        guard hasData else { return "Keine vorherigen Daten" }

        var parts: [String] = []

        if let weight = weight, let reps = reps {
            parts.append("\(weight.formatted())kg × \(reps) Wdh.")
        }

        if let setCount = setCount {
            parts.append("\(setCount) Sätze")
        }

        if let date = lastUsedDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            parts.append("am \(formatter.string(from: date))")
        }

        return parts.joined(separator: " • ")
    }
}

// MARK: - LastUsedMetricsService

/// Service für die Verwaltung von "Last-Used" Metriken
///
/// Dieser Service verwaltet die letzten verwendeten Werte für Übungen,
/// was dem Benutzer hilft, bei der nächsten Ausführung schnell die richtigen
/// Gewichte und Wiederholungszahlen zu finden.
///
/// Features:
/// - Schneller Zugriff via ExerciseEntity.lastUsed* Properties
/// - Legacy-Fallback via Session-History-Iteration (langsamer)
/// - Automatische Updates nach jedem abgeschlossenen Workout
/// - Validierung: Nur neuere Daten überschreiben ältere
@MainActor
final class LastUsedMetricsService {

    // MARK: - Properties

    private var modelContext: ModelContext?

    // MARK: - Context Management

    /// Setzt den ModelContext für Datenbankoperationen
    ///
    /// - Parameter context: Der zu verwendende ModelContext
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    // MARK: - Quick Access Methods

    /// Schneller Zugriff auf letzte Gewicht und Satz-Anzahl
    ///
    /// Diese Methode nutzt die optimierten lastUsed* Properties der ExerciseEntity
    /// für schnellen Zugriff. Falls keine Daten vorhanden, wird automatisch
    /// die Legacy-Methode als Fallback verwendet.
    ///
    /// - Parameter exercise: Die Übung
    /// - Returns: Tuple mit Gewicht und Satz-Anzahl, oder nil
    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { entity in entity.id == exercise.id }
        )

        guard let exerciseEntity = try? context.fetch(descriptor).first,
            let weight = exerciseEntity.lastUsedWeight,
            let setCount = exerciseEntity.lastUsedSetCount
        else {
            // Fallback: alte Methode als Backup
            return legacyLastMetrics(for: exercise)
        }

        return (weight, setCount)
    }

    /// Erweiterte lastMetrics mit allen verfügbaren Informationen
    ///
    /// Diese Methode gibt alle verfügbaren Last-Used Metriken zurück,
    /// inklusive Wiederholungen, Datum und Pausenzeit.
    ///
    /// - Parameter exercise: Die Übung
    /// - Returns: ExerciseLastUsedMetrics mit allen Daten, oder nil
    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { entity in entity.id == exercise.id }
        )

        guard let exerciseEntity = try? context.fetch(descriptor).first else { return nil }

        return ExerciseLastUsedMetrics(
            weight: exerciseEntity.lastUsedWeight,
            reps: exerciseEntity.lastUsedReps,
            setCount: exerciseEntity.lastUsedSetCount,
            lastUsedDate: exerciseEntity.lastUsedDate,
            restTime: exerciseEntity.lastUsedRestTime
        )
    }

    // MARK: - Legacy Fallback

    /// Legacy-Fallback Methode - iteriert durch Session-History (langsamer)
    ///
    /// Diese Methode wird nur verwendet, wenn keine lastUsed* Properties
    /// in der ExerciseEntity vorhanden sind. Sie durchsucht die gesamte
    /// Session-History, was bei vielen Sessions langsam sein kann.
    ///
    /// **Performance:** O(n×m) wobei n = Anzahl Sessions, m = Übungen pro Session
    ///
    /// - Parameter exercise: Die Übung
    /// - Returns: Tuple mit Gewicht und Satz-Anzahl, oder nil
    private func legacyLastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        guard let context = modelContext else { return nil }

        // Hole alle Sessions, sortiert nach Datum (neueste zuerst)
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor) else { return nil }

        // Durchsuche Sessions nach der Übung
        for sessionEntity in sessions {
            // Finde WorkoutExercise mit passender Exercise
            if let workoutExercise = sessionEntity.exercises.first(where: { we in
                we.exercise?.id == exercise.id
            }) {
                let setCount = max(workoutExercise.sets.count, 1)
                let weight = workoutExercise.sets.last?.weight ?? 0
                return (weight, setCount)
            }
        }

        return nil
    }

    // MARK: - Update Methods

    /// Aktualisiert die "letzte Verwendung" Daten für alle Übungen in einem Workout
    ///
    /// Diese Methode wird automatisch nach jedem abgeschlossenen Workout aufgerufen.
    /// Sie aktualisiert die lastUsed* Properties aller verwendeten Übungen.
    ///
    /// **Validierung:** Nur neuere Workouts überschreiben ältere Werte
    ///
    /// Algorithmus:
    /// 1. Für jede Übung im Workout
    /// 2. Hole ExerciseEntity aus Datenbank
    /// 3. Finde letzten abgeschlossenen Satz
    /// 4. Prüfe ob neuer als bisheriger Wert
    /// 5. Update Properties und speichere
    ///
    /// - Parameter session: Die abgeschlossene Workout-Session
    func updateLastUsedMetrics(from session: WorkoutSession) {
        guard let context = modelContext else {
            print("⚠️ LastUsedMetricsService: ModelContext ist nil")
            return
        }

        for workoutExercise in session.exercises {
            // Hole die ExerciseEntity frisch aus dem Context
            let descriptor = FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { entity in
                    entity.id == workoutExercise.exercise.id
                }
            )

            guard let exerciseEntity = try? context.fetch(descriptor).first else {
                print("⚠️ ExerciseEntity nicht gefunden für: \(workoutExercise.exercise.name)")
                continue
            }

            // Finde den letzten abgeschlossenen Satz
            let completedSets = workoutExercise.sets.filter { $0.completed }
            guard let lastSet = completedSets.last else {
                print("ℹ️ Keine abgeschlossenen Sätze für: \(workoutExercise.exercise.name)")
                continue
            }

            // Aktualisiere die Last-Used Werte nur wenn das neue Workout neuer ist
            if exerciseEntity.lastUsedDate == nil || session.date > exerciseEntity.lastUsedDate! {
                exerciseEntity.lastUsedWeight = lastSet.weight
                exerciseEntity.lastUsedReps = lastSet.reps
                exerciseEntity.lastUsedSetCount = completedSets.count
                exerciseEntity.lastUsedDate = session.date
                exerciseEntity.lastUsedRestTime = lastSet.restTime

                print(
                    "✅ Last-Used aktualisiert für \(exerciseEntity.name): \(lastSet.weight)kg × \(lastSet.reps)"
                )
            } else {
                print(
                    "ℹ️ Last-Used NICHT aktualisiert für \(exerciseEntity.name): neuere Daten vorhanden"
                )
            }
        }

        // Speichere alle Änderungen
        do {
            try context.save()
            print("✅ Alle Last-Used Metriken gespeichert")
        } catch {
            print("❌ Fehler beim Speichern der Last-Used Metriken: \(error)")
        }
    }

    // MARK: - Utility Methods

    /// Löscht die Last-Used Daten für eine bestimmte Übung
    ///
    /// Nützlich z.B. wenn eine Übung zurückgesetzt werden soll.
    ///
    /// - Parameter exercise: Die Übung
    func clearLastUsedMetrics(for exercise: Exercise) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { entity in entity.id == exercise.id }
        )

        guard let exerciseEntity = try? context.fetch(descriptor).first else { return }

        exerciseEntity.lastUsedWeight = nil
        exerciseEntity.lastUsedReps = nil
        exerciseEntity.lastUsedSetCount = nil
        exerciseEntity.lastUsedDate = nil
        exerciseEntity.lastUsedRestTime = nil

        do {
            try context.save()
            print("✅ Last-Used Metriken gelöscht für: \(exercise.name)")
        } catch {
            print("❌ Fehler beim Löschen der Last-Used Metriken: \(error)")
        }
    }

    /// Gibt an ob Last-Used Daten für eine Übung vorhanden sind
    ///
    /// - Parameter exercise: Die Übung
    /// - Returns: true wenn Last-Used Daten existieren
    func hasLastUsedMetrics(for exercise: Exercise) -> Bool {
        return lastMetrics(for: exercise) != nil
    }
}
