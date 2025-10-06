import SwiftUI
import SwiftData
import Foundation
import OSLog

@main
struct GymTrackerApp: App {
    // Performance: Track migration state to show app immediately
    @State private var isMigrationComplete = false

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
            AppLogger.app.info("Application Support directory created: \(appSupportURL.path)")
        }

        do {
            // Erstelle einen einfachen persistenten Container
            let container = try ModelContainer(for: schema)
            AppLogger.app.info("ModelContainer successfully created")
            return container
        } catch {
            AppLogger.app.error("Failed to create ModelContainer: \(error.localizedDescription)")

            // Fallback: Versuche mit Documents-Verzeichnis
            do {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let storeURL = documentsURL.appendingPathComponent("GymTracker.sqlite")

                AppLogger.app.info("Trying fallback with Documents path: \(storeURL.path)")

                let config = ModelConfiguration(url: storeURL)
                let container = try ModelContainer(for: schema, configurations: [config])
                AppLogger.app.info("ModelContainer created with Documents path")
                return container
            } catch {
                AppLogger.app.error("Documents path fallback failed: \(error.localizedDescription)")

                // Als allerletzte Option: In-Memory mit Warnung
                do {
                    let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                    let container = try ModelContainer(for: schema, configurations: [memoryConfig])
                    AppLogger.app.warning("Using in-memory database - data will be lost on restart!")
                    return container
                } catch {
                    fatalError("All ModelContainer options failed: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .modelContainer(sharedModelContainer)
                    .opacity(isMigrationComplete ? 1 : 0)

                // Performance: Show loading overlay during migrations
                if !isMigrationComplete {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Daten werden geladen...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task(priority: .userInitiated) {
                // Performance: Run migrations in background with higher priority than .background
                // but lower than main UI thread
                await performMigrations()

                // Show UI after migrations complete
                withAnimation(.easeIn(duration: 0.3)) {
                    isMigrationComplete = true
                }
            }
        }
    }

    // MARK: - Performance: Background Migration

    /// Performs all database migrations in the background to avoid blocking UI
    private func performMigrations() async {
        let context = sharedModelContainer.mainContext

        // 🔄 SCHRITT 1: Exercise-Migration (alte Übungen → CSV-Übungen)
        do {
            if await ExerciseDatabaseMigration.isMigrationNeeded() {
                await ExerciseDatabaseMigration.migrateToCSVExercises(context: context)
            }
        } catch {
            AppLogger.exercises.error("Exercise migration failed: \(error.localizedDescription)")
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
                    AppLogger.exercises.info("Deleting \(existingExercises.count) exercises with incorrect UUIDs")
                    for exercise in existingExercises {
                        context.delete(exercise)
                    }
                    try context.save()
                }

                AppLogger.exercises.info("Loading 161 exercises from CSV")
                ExerciseSeeder.seedExercises(context: context)
                AppLogger.exercises.info("Exercises loaded successfully")
            } else {
                AppLogger.exercises.info("\(existingExercises.count) exercises with correct UUIDs already present")
            }
        } catch {
            AppLogger.exercises.error("Exercise check failed: \(error.localizedDescription)")
        }

        // 🌱 SCHRITT 3: Versioniertes Sample-Workout Update
        do {
            let SAMPLE_WORKOUT_VERSION = 2 // Bei neuen Samples erhöhen!
            let lastVersion = UserDefaults.standard.integer(forKey: "sampleWorkoutVersion")

            let workoutDescriptor = FetchDescriptor<WorkoutEntity>()
            let existingWorkouts = try context.fetch(workoutDescriptor)

            // Migration: Alte Workouts ohne Flag als Benutzer-Workouts markieren
            for workout in existingWorkouts where workout.isSampleWorkout == nil {
                workout.isSampleWorkout = false // Alte Workouts = Benutzer-Workouts
            }
            try? context.save()

            // Wenn Version veraltet ist ODER keine Workouts vorhanden
            if lastVersion < SAMPLE_WORKOUT_VERSION || existingWorkouts.isEmpty {
                // Lösche nur Sample-Workouts (Benutzerdaten bleiben!)
                let sampleWorkouts = existingWorkouts.filter { $0.isSampleWorkout == true }
                if !sampleWorkouts.isEmpty {
                    AppLogger.workouts.info("Deleting \(sampleWorkouts.count) outdated sample workouts")
                    for workout in sampleWorkouts {
                        context.delete(workout)
                    }
                    try context.save()
                }

                // Lade neue Sample-Workouts
                AppLogger.workouts.info("Loading sample workouts (Version \(SAMPLE_WORKOUT_VERSION))")
                WorkoutSeeder.seedWorkouts(context: context)

                // Speichere neue Version
                UserDefaults.standard.set(SAMPLE_WORKOUT_VERSION, forKey: "sampleWorkoutVersion")
                AppLogger.workouts.info("Sample workouts updated to version \(SAMPLE_WORKOUT_VERSION)")
            } else {
                let userWorkouts = existingWorkouts.filter { $0.isSampleWorkout == false }
                let samples = existingWorkouts.filter { $0.isSampleWorkout == true }
                AppLogger.workouts.info("Sample workouts up to date (v\(SAMPLE_WORKOUT_VERSION)): \(samples.count) samples, \(userWorkouts.count) user workouts")
            }
        } catch {
            AppLogger.workouts.error("Sample workout update failed: \(error.localizedDescription)")
        }

        // 🏆 SCHRITT 4: Migration - ExerciseRecords aus bestehenden Sessions generieren
        do {
            if await ExerciseRecordMigration.isMigrationNeeded(context: context) {
                await ExerciseRecordMigration.migrateExistingData(context: context)
            }
        } catch {
            AppLogger.data.error("ExerciseRecord migration failed: \(error.localizedDescription)")
        }

        // 📊 SCHRITT 5: Migration - Last-Used Daten für bessere UX
        do {
            await ExerciseLastUsedMigration.performInitialMigration(context: context)
        } catch {
            AppLogger.data.error("LastUsed migration failed: \(error.localizedDescription)")
        }

        // Wait a bit for app to fully initialize before testing Live Activities
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            AppLogger.liveActivity.info("Live Activity setup initiated")
            WorkoutLiveActivityController.shared.requestPermissionIfNeeded()

            // Live Activity Test nur im Debug-Modus
            #if DEBUG
            // WorkoutLiveActivityController.shared.testLiveActivity()
            #endif
        }
        #endif
    }
}
