import SwiftData

/// MIGRATION PLAN: Beispielworkouts von DataManager zu ExerciseSeeder
/// 
/// AKTUELLER ZUSTAND:
/// - SettingsView -> workoutStore.resetToSampleData() 
/// - -> DataManager.shared.ensureSampleData(context:)
/// - -> DataManager.createSampleWorkouts(using:) 
/// - -> Verwendet ALTE Übungsnamen (Englisch/gemischt)
///
/// ZIEL-ZUSTAND:
/// - SettingsView -> workoutStore.resetToSampleDataV2()
/// - -> ExerciseSeeder.ensureSampleWorkoutsExist(context:)
/// - -> ExerciseSeeder.createSampleWorkouts(availableExercises:)
/// - -> Verwendet NEUE deutsche Übungsnamen
///
/// MIGRATIONS-SCHRITTE:
/// 1. ✅ Analysiere aktuelle resetToSampleData() Methode
/// 2. 🔄 Erstelle resetToSampleDataV2() parallel zur alten Methode
/// 3. 🧪 Teste neue Methode mit temporärem Button in Settings
/// 4. ✅ Ersetze alte Methode wenn Test erfolgreich
/// 5. 🧹 Cleanup: Entferne temporäre Methoden und alte DataManager-Logik

@MainActor
class SampleWorkoutMigrationHelper {
    
    /// Debug: Aktuelle Sample-Workouts aus DataManager analysieren
    static func analyzeCurrentSampleWorkouts(context: ModelContext) {
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 ANALYSE: Aktuelle DataManager Sample-Workouts")
        print(String(repeating: "=", count: 50))
        
        do {
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            print("📚 Verfügbare Übungen: \(exercises.count)")
            
            // Da createSampleWorkouts private ist, können wir nur die resultierenden Workouts analysieren
            let existingWorkouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
            print("💪 Aktuell vorhandene Workouts: \(existingWorkouts.count)")
            
            for (i, workout) in existingWorkouts.enumerated() {
                print("  \(i+1). '\(workout.name)' (\(workout.exercises.count) Übungen)")
                
                // Zeige erste 3 Übungen pro Workout
                for (j, workoutExercise) in workout.exercises.prefix(3).enumerated() {
                    if let exercise = workoutExercise.exercise {
                        let exerciseName = exercise.name
                        print("     - \(j+1). \(exerciseName)")
                    } else {
                        print("     - \(j+1). [Übung nicht gefunden]")
                    }
                }
                if workout.exercises.count > 3 {
                    print("     ... und \(workout.exercises.count - 3) weitere")
                }
            }
            
            if existingWorkouts.isEmpty {
                print("ℹ️ Keine Workouts vorhanden - rufe DataManager.ensureSampleData() auf um Beispieldaten zu erstellen")
            }
            
        } catch {
            print("❌ Fehler bei Analyse: \(error)")
        }
        
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    /// Debug: Neue ExerciseSeeder Sample-Workouts analysieren
    static func analyzeExerciseSeederSampleWorkouts(context: ModelContext) {
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 ANALYSE: Neue ExerciseSeeder Sample-Workouts")
        print(String(repeating: "=", count: 50))
        
        do {
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            print("📚 Verfügbare Übungen: \(exercises.count)")
            
            // ExerciseSeeder.createSampleWorkouts ist auch private, also müssen wir die Logik direkt hier implementieren
            // oder einen andere Ansatz verwenden
            print("💪 ExerciseSeeder Beispiel-Workouts:")
            
            // Da wir nicht direkt auf createSampleWorkouts zugreifen können,
            // zeigen wir die erwarteten Workout-Namen und Struktur
            let expectedWorkoutNames = [
                "Ganzkörper Maschinen (Anfänger)",
                "Oberkörper Maschinen (Fortgeschritten)",
                "5x5 Kraft (Freie Gewichte)",
                "Kurzhantel Hypertrophie"
            ]
            
            print("  ExerciseSeeder würde folgende \(expectedWorkoutNames.count) Workouts erstellen:")
            for (i, workoutName) in expectedWorkoutNames.enumerated() {
                print("  \(i+1). '\(workoutName)'")
            }
            
            // Überprüfe ob die benötigten deutschen Übungsnamen vorhanden sind
            let requiredGermanExercises = [
                "Brustpresse Maschine", "Latzug breit", "Schulterdrücken Maschine",
                "Beinpresse", "Beinstrecker", "Beinbeuger sitzend",
                "Kniebeugen", "Bankdrücken", "Kreuzheben",
                "Kurzhantel Bankdrücken", "Bizeps Curls"
            ]
            
            var foundCount = 0
            print("📋 Überprüfung deutscher Übungsnamen:")
            for exerciseName in requiredGermanExercises {
                let found = exercises.contains { $0.name == exerciseName }
                print("  - '\(exerciseName)': \(found ? "✅" : "❌")")
                if found { foundCount += 1 }
            }
            
            print("📊 Deutsche Übungen gefunden: \(foundCount)/\(requiredGermanExercises.count)")
            
        } catch {
            print("❌ Fehler bei Analyse: \(error)")
        }
        
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    /// NOTFALL: Debug kaputte Workout-Referenzen
    static func emergencyDebugBrokenWorkouts(context: ModelContext) {
        print("\n" + String(repeating: "=", count: 60))
        print("🚨 NOTFALL-DIAGNOSE: Kaputte Workout-Referenzen")
        print(String(repeating: "=", count: 60))
        
        do {
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
            
            print("📊 Status:")
            print("  • Übungen in DB: \(exercises.count)")
            print("  • Workouts in DB: \(workouts.count)")
            
            // Zeige erste 20 tatsächliche Übungsnamen
            print("\n📚 Erste 20 tatsächliche Übungsnamen in der Datenbank:")
            for (i, exercise) in exercises.prefix(20).enumerated() {
                print("  \(i+1). '\(exercise.name)'")
            }
            
            // Analysiere kaputte Workout-Referenzen
            print("\n💔 Analyse kaputte Workout-Referenzen:")
            for (i, workout) in workouts.enumerated() {
                print("  \(i+1). '\(workout.name)':")
                for (j, workoutExercise) in workout.exercises.enumerated() {
                    if let exercise = workoutExercise.exercise {
                        print("     ✅ \(j+1). \(exercise.name)")
                    } else {
                        print("     ❌ \(j+1). NIL-Referenz (Exercise ist null)")
                    }
                }
            }
            
            // Suche nach häufigen deutschen Übungsbezeichnungen
            let germanSearchTerms = ["Brust", "Rücken", "Bein", "Schulter", "Bizeps", "Trizeps", "Bauch", "Maschine"]
            print("\n🔍 Suche nach deutschen Begriffen:")
            for term in germanSearchTerms {
                let found = exercises.filter { $0.name.contains(term) }
                print("  '\(term)': \(found.count) Treffer")
                for exercise in found.prefix(3) {
                    print("    - \(exercise.name)")
                }
            }
            
        } catch {
            print("❌ Fehler bei Notfall-Diagnose: \(error)")
        }
        
        print(String(repeating: "=", count: 60) + "\n")
    }

    /// Debug: Vergleiche beide Sample-Workout Systeme
    static func compareWorkoutSystems(context: ModelContext) {
        // NOTFALL: Zuerst die kaputten Referenzen analysieren
        emergencyDebugBrokenWorkouts(context: context)
        
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 VERGLEICH: DataManager vs ExerciseSeeder Sample-Workouts")
        print(String(repeating: "=", count: 60))
        
        analyzeCurrentSampleWorkouts(context: context)
        analyzeExerciseSeederSampleWorkouts(context: context)
        
        print("📋 FAZIT:")
        print("   🚨 NOTFALL: Alle Workout-Referenzen sind kaputt!")
        print("   • Workouts existieren, aber Exercise-Referenzen sind NULL")
        print("   • Mögliche Ursachen: ID-Mismatch, Datenbank-Korruption, Seeding-Fehler")
        print("   • SOFORT-MASSNAHME nötig!")
        print(String(repeating: "=", count: 60) + "\n")
    }
}