import Foundation
import SwiftData

/// Migration für die neuen Last-Used Felder in ExerciseEntity
class ExerciseLastUsedMigration {
    
    /// Führt eine einmalige Rückwärts-Migration durch, um Last-Used Daten aus der Session-Historie zu befüllen
    @MainActor
    static func performInitialMigration(context: ModelContext) async {
        print("🔄 Starte ExerciseLastUsedMigration...")
        
        do {
            // Hole alle Übungen
            let exerciseDescriptor = FetchDescriptor<ExerciseEntity>()
            let exercises = try context.fetch(exerciseDescriptor)
            
            // Hole alle Sessions sortiert nach Datum (neueste zuerst)
            let sessionDescriptor = FetchDescriptor<WorkoutSessionEntity>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let sessions = try context.fetch(sessionDescriptor)
            
            var migratedCount = 0
            
            for exercise in exercises {
                // Prüfe ob bereits Last-Used Daten vorhanden sind
                if exercise.lastUsedDate != nil {
                    continue // Bereits migriert
                }
                
                // Finde die neueste Session mit dieser Übung
                var foundLastUsage = false
                
                for session in sessions {
                    if let workoutExercise = session.exercises.first(where: { we in
                        we.exercise?.id == exercise.id
                    }) {
                        // Finde abgeschlossene Sätze
                        let completedSets = workoutExercise.sets.filter { $0.completed }
                        
                        if let lastSet = completedSets.last {
                            // Aktualisiere Last-Used Werte
                            exercise.lastUsedWeight = lastSet.weight
                            exercise.lastUsedReps = lastSet.reps
                            exercise.lastUsedSetCount = completedSets.count
                            exercise.lastUsedDate = session.date
                            exercise.lastUsedRestTime = lastSet.restTime
                            
                            print("✅ Migriert: \(exercise.name) - \(lastSet.weight)kg × \(lastSet.reps) vom \(session.date.formatted(.dateTime.day().month()))")
                            
                            migratedCount += 1
                            foundLastUsage = true
                            break // Nur die neueste Session pro Übung
                        }
                    }
                }
                
                if !foundLastUsage {
                    print("ℹ️ Keine Nutzungshistorie gefunden für: \(exercise.name)")
                }
            }
            
            // Speichere alle Änderungen
            try context.save()
            
            print("✅ ExerciseLastUsedMigration abgeschlossen!")
            print("   • \(migratedCount) Übungen mit Last-Used Daten aktualisiert")
            
        } catch {
            print("❌ Fehler bei ExerciseLastUsedMigration: \(error)")
        }
    }
}