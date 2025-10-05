import SwiftUI
import SwiftData
import Foundation

@main
struct GymTrackerApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ExerciseEntity.self,
            ExerciseSetEntity.self,
            WorkoutExerciseEntity.self,
            WorkoutEntity.self,
            WorkoutSessionEntity.self,
            UserProfileEntity.self,
            ExerciseRecordEntity.self
        ])
        
        do {
            // Erstelle einen einfachen persistenten Container
            let container = try ModelContainer(for: schema)
            print("✅ Persistenter ModelContainer erfolgreich erstellt")
            return container
        } catch {
            print("❌ Persistenter Container fehlgeschlagen: \(error)")
            
            // Fallback: Versuche mit Documents-Verzeichnis
            do {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let storeURL = documentsURL.appendingPathComponent("GymTracker.sqlite")
                
                print("🔄 Versuche mit Documents-Pfad: \(storeURL)")
                
                let config = ModelConfiguration(url: storeURL)
                let container = try ModelContainer(for: schema, configurations: [config])
                print("✅ ModelContainer mit Documents-Pfad erfolgreich erstellt")
                return container
            } catch {
                print("❌ Documents-Pfad auch fehlgeschlagen: \(error)")
                
                // Als allerletzte Option: In-Memory mit Warnung
                do {
                    let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                    let container = try ModelContainer(for: schema, configurations: [memoryConfig])
                    print("⚠️ WARNUNG: Verwende In-Memory-Datenbank - Daten gehen bei Neustart verloren!")
                    return container
                } catch {
                    fatalError("Alle ModelContainer-Optionen fehlgeschlagen: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .task {
                    let context = sharedModelContainer.mainContext
                    
                    // SCHRITT 1: Analysiere Sample-Workout Systeme für Migration
                    SampleWorkoutMigrationHelper.compareWorkoutSystems(context: context)

                    // 🌱 Prüfe ob Übungen bereits existieren
                    do {
                        let descriptor = FetchDescriptor<ExerciseEntity>()
                        let existingExercises = try context.fetch(descriptor)

                        if existingExercises.isEmpty {
                            print("🌱 Lade 161 Übungen aus CSV...")
                            ExerciseSeeder.seedExercises(context: context)
                            print("✅ Übungen erfolgreich geladen")
                        } else {
                            print("✅ \(existingExercises.count) Übungen bereits vorhanden")
                        }
                    } catch {
                        print("❌ Fehler beim Prüfen der Übungen: \(error)")
                    }
                    
                    // 🏆 Migration: ExerciseRecords aus bestehenden Sessions generieren
                    if await ExerciseRecordMigration.isMigrationNeeded(context: context) {
                        await ExerciseRecordMigration.migrateExistingData(context: context)
                    }
                    
                    // 📊 Migration: Last-Used Daten für bessere UX
                    await ExerciseLastUsedMigration.performInitialMigration(context: context)
                    
                    // Wait a bit for app to fully initialize before testing Live Activities
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    #if canImport(ActivityKit)
                    if #available(iOS 16.1, *) {
                        print("=== Live Activity Setup ===")
                        WorkoutLiveActivityController.shared.requestPermissionIfNeeded()
                        
                        // Live Activity Test nur im Debug-Modus
                        #if DEBUG
                        // WorkoutLiveActivityController.shared.testLiveActivity()
                        #endif
                    }
                    #endif
                }
        }
    }
}
