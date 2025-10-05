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

        // Erstelle Application Support Verzeichnis falls es nicht existiert
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
            print("📁 Application Support Verzeichnis erstellt/geprüft: \(appSupportURL)")
        }

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

                    // 🔄 SCHRITT 1: Exercise-Migration (alte Übungen → CSV-Übungen)
                    if await ExerciseDatabaseMigration.isMigrationNeeded() {
                        await ExerciseDatabaseMigration.migrateToCSVExercises(context: context)
                    }

                    // 🌱 SCHRITT 2: Falls Datenbank leer oder Exercises haben falsche UUIDs, neu laden
                    do {
                        let descriptor = FetchDescriptor<ExerciseEntity>()
                        let existingExercises = try context.fetch(descriptor)

                        // Prüfe ob Exercises deterministische UUIDs haben (Format: 00000000-0000-0000-0000-XXXXXXXXXXXX)
                        let hasDeterministicUUIDs = existingExercises.contains { exercise in
                            let uuidString = exercise.id.uuidString
                            return uuidString.hasPrefix("00000000-0000-0000-0000-")
                        }

                        if existingExercises.isEmpty || !hasDeterministicUUIDs {
                            if !existingExercises.isEmpty {
                                print("🔧 Lösche \(existingExercises.count) Übungen mit falschen UUIDs...")
                                for exercise in existingExercises {
                                    context.delete(exercise)
                                }
                                try context.save()
                            }

                            print("🌱 Lade 161 Übungen aus CSV...")
                            ExerciseSeeder.seedExercises(context: context)
                            print("✅ Übungen erfolgreich geladen")
                        } else {
                            print("✅ \(existingExercises.count) Übungen mit korrekten UUIDs bereits vorhanden")
                        }
                    } catch {
                        print("❌ Fehler beim Prüfen der Übungen: \(error)")
                    }

                    // 🌱 SCHRITT 3: Sample-Workouts seeden, falls noch keine vorhanden oder defekt
                    do {
                        let workoutDescriptor = FetchDescriptor<WorkoutEntity>()
                        let existingWorkouts = try context.fetch(workoutDescriptor)

                        // Prüfe ob Workouts defekt sind (keine gültigen Exercise-Referenzen)
                        let validWorkouts = existingWorkouts.filter { workout in
                            !workout.exercises.isEmpty && workout.exercises.contains { $0.exercise != nil }
                        }

                        if validWorkouts.isEmpty {
                            // Lösche alte defekte Workouts falls vorhanden
                            if !existingWorkouts.isEmpty {
                                print("🔧 Lösche \(existingWorkouts.count) defekte Workouts...")
                                for workout in existingWorkouts {
                                    context.delete(workout)
                                }
                                try context.save()
                            }

                            print("🌱 Lade 6 Beispielworkouts aus CSV...")
                            WorkoutSeeder.seedWorkouts(context: context)
                            print("✅ Beispielworkouts erfolgreich geladen")
                        } else {
                            print("✅ \(validWorkouts.count) gültige Workouts bereits vorhanden")
                        }
                    } catch {
                        print("❌ Fehler beim Prüfen der Workouts: \(error)")
                    }

                    // 🏆 SCHRITT 4: Migration - ExerciseRecords aus bestehenden Sessions generieren
                    if await ExerciseRecordMigration.isMigrationNeeded(context: context) {
                        await ExerciseRecordMigration.migrateExistingData(context: context)
                    }

                    // 📊 SCHRITT 5: Migration - Last-Used Daten für bessere UX
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
