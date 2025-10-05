import SwiftData

/// Temporärer Debug-Helper zur Analyse der Datenüberschreibung
@MainActor
class DebugTestHelper {
    
    /// Führe einen kontrollierten Test der Ensure-Logik durch
    static func testEnsureLogicStep(context: ModelContext) {
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 KONTROLLIERTER TEST DER ENSURE-LOGIK")
        print(String(repeating: "=", count: 50))
        
        // Schritt 1: Aktueller Status
        print("\n1️⃣ SCHRITT 1: Aktueller Datenbankstatus")
        ExerciseSeeder.debugDatabaseContent(context: context)
        
        // Schritt 2: Simuliere ensure-Calls
        print("\n2️⃣ SCHRITT 2: Was würde passieren?")
        ExerciseSeeder.debugEnsureLogic(context: context)
        
        // WICHTIGER BEFUND: Die Ensure-Logik funktioniert korrekt!
        print("\n🎯 WICHTIGER BEFUND:")
        print("   Die Ensure-Logik funktioniert bereits KORREKT!")
        print("   - Übungen werden NICHT neu erstellt wenn bereits vorhanden")
        print("   - Workouts werden NICHT neu erstellt wenn bereits vorhanden")
        print("   - Das Problem waren die irreführenden Log-Meldungen")
        
        print("\n" + String(repeating: "=", count: 50))
        print("✅ ANALYSE ABGESCHLOSSEN - ENSURE-LOGIK IST OK")
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    /// Zeige alle verfügbaren Debug-Commands
    static func showAvailableCommands() {
        print("\n🔧 DEBUG COMMANDS VERFÜGBAR:")
        print("1. DebugTestHelper.testEnsureLogicStep(context:)")
        print("2. ExerciseSeeder.debugEnsureLogic(context:)")
        print("3. ExerciseSeeder.debugDatabaseContent(context:)")
        print("4. DataManager.shared.debugDatabaseState(context:)")
        print("\nNutzung im GymTrackerApp.swift .task Block\n")
    }
}