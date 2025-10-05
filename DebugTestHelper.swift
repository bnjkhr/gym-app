import SwiftData

/// Temporärer Debug-Helper zur Analyse der Datenüberschreibung
@MainActor
class DebugTestHelper {

    /// Führe einen kontrollierten Test der Ensure-Logik durch
    static func testEnsureLogicStep(context: ModelContext) {
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 KONTROLLIERTER TEST DER ENSURE-LOGIK")
        print(String(repeating: "=", count: 50))

        do {
            // Test Exercise Fetch
            let exerciseDescriptor = FetchDescriptor<ExerciseEntity>()
            let existingExercises = try context.fetch(exerciseDescriptor)
            print("📚 Übungen: \(existingExercises.count)")

            // Test Workout Fetch
            let workoutDescriptor = FetchDescriptor<WorkoutEntity>()
            let existingWorkouts = try context.fetch(workoutDescriptor)
            print("💪 Workouts: \(existingWorkouts.count)")

        } catch {
            print("❌ Fehler beim Testen: \(error)")
        }

        print("\n" + String(repeating: "=", count: 50))
        print("✅ ANALYSE ABGESCHLOSSEN")
        print(String(repeating: "=", count: 50) + "\n")
    }

    /// Zeige alle verfügbaren Debug-Commands
    static func showAvailableCommands() {
        print("\n🔧 DEBUG COMMANDS VERFÜGBAR:")
        print("1. DebugTestHelper.testEnsureLogicStep(context:)")
        print("2. DataManager.shared.debugDatabaseState(context:)")
        print("\nNutzung im GymTrackerApp.swift .task Block\n")
    }
}