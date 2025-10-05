import Foundation
import SwiftData

/// Migration utility for replacing old hardcoded exercises with CSV-based exercises
@MainActor
class ExerciseDatabaseMigration {

    /// UserDefaults key to track if migration was completed
    private static let migrationKey = "exerciseDatabaseMigrationV2Completed"

    /// Check if migration is needed
    /// Migration is needed if:
    /// 1. Migration hasn't been run before (checked via UserDefaults)
    /// 2. There are exercises in the database
    static func isMigrationNeeded() -> Bool {
        let defaults = UserDefaults.standard
        let migrationCompleted = defaults.bool(forKey: migrationKey)

        if migrationCompleted {
            print("✅ Exercise-Migration bereits durchgeführt (überspringe)")
            return false
        }

        print("🔄 Exercise-Migration wird benötigt")
        return true
    }

    /// Migrate from old hardcoded exercises to CSV-based exercises
    /// This will:
    /// 1. Delete all existing ExerciseEntity records
    /// 2. Load new exercises from CSV
    /// 3. Mark migration as completed
    static func migrateToCSVExercises(context: ModelContext) async {
        print("🔄 Starte Exercise-Datenbank Migration...")

        do {
            // Step 1: Fetch and count existing exercises
            let exerciseDescriptor = FetchDescriptor<ExerciseEntity>()
            let existingExercises = try context.fetch(exerciseDescriptor)
            let oldCount = existingExercises.count

            if oldCount == 0 {
                print("ℹ️ Keine alten Übungen gefunden - überspringe Löschung")
            } else {
                print("🗑️ Lösche \(oldCount) alte Übungen...")

                // Step 2: Delete all existing exercises
                for exercise in existingExercises {
                    context.delete(exercise)
                }

                // Save deletions
                try context.save()
                print("✅ \(oldCount) alte Übungen gelöscht")
            }

            // Step 3: Load new exercises from CSV
            print("🌱 Lade neue Übungen aus CSV...")
            ExerciseSeeder.seedExercises(context: context)

            // Verify new exercises were loaded
            let newExercises = try context.fetch(exerciseDescriptor)
            let newCount = newExercises.count

            if newCount > 0 {
                print("✅ \(newCount) neue Übungen erfolgreich geladen")
            } else {
                print("⚠️ Warnung: Keine neuen Übungen geladen - CSV möglicherweise fehlerhaft")
            }

            // Step 4: Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationKey)
            UserDefaults.standard.synchronize()

            print("✅ Exercise-Migration abgeschlossen")
            print("   📊 Alte Übungen: \(oldCount)")
            print("   📊 Neue Übungen: \(newCount)")

        } catch {
            print("❌ Fehler bei Exercise-Migration: \(error)")
            print("⚠️ Migration wird beim nächsten Start erneut versucht")
            // Don't set migration flag on error, so it will retry next time
        }
    }

    /// Reset migration flag (for testing purposes only)
    /// This will cause the migration to run again on next app start
    static func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        UserDefaults.standard.synchronize()
        print("🔄 Exercise-Migration Flag zurückgesetzt")
    }
}
