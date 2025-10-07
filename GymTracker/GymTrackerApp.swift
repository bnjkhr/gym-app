import SwiftUI
import SwiftData
import Foundation
import OSLog

@main
struct GymTrackerApp: App {
    // Performance: Track migration state to show app immediately
    @State private var isMigrationComplete = false

    // Storage location tracking for warnings
    @State private var storageLocation: ModelContainerFactory.StorageLocation = .applicationSupport
    @State private var showStorageWarning = false

    // Shared container with robust fallback chain
    static let containerResult: (container: ModelContainer, location: ModelContainerFactory.StorageLocation) = {
        let schema = Schema([
            ExerciseEntity.self,
            ExerciseSetEntity.self,
            WorkoutExerciseEntity.self,
            WorkoutEntity.self,
            WorkoutSessionEntity.self,
            UserProfileEntity.self,
            ExerciseRecordEntity.self
        ])

        // Check storage health before attempting creation
        let health = ModelContainerFactory.checkStorageHealth()
        AppLogger.app.info("Storage health check:\n\(health.summary)")

        if health.hasCriticalIssues {
            AppLogger.app.warning("Critical storage issues detected, but attempting creation anyway")
        }

        // Use new factory with robust fallback chain
        // This automatically handles lightweight migrations (new optional properties, etc.)
        let result = ModelContainerFactory.createContainer(schema: schema)

        switch result {
        case .success(let container, let location):
            if !location.isPersistent {
                AppLogger.app.warning("⚠️ Using \(location.rawValue) storage - data may be temporary!")
            }
            return (container, location)

        case .failure(let error):
            // This should never happen since in-memory is always available
            // But if it does, we need a fallback container for the app to start
            AppLogger.app.critical("Container creation completely failed: \(error.localizedDescription)")

            // Last resort: try one more in-memory container
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [config])
                AppLogger.app.warning("Using emergency in-memory container")
                return (container, .inMemory)
            } catch {
                // If even this fails, create a minimal container
                // This is the absolute last resort to prevent crash
                fatalError("Emergency container creation failed: \(error)")
            }
        }
    }()

    var sharedModelContainer: ModelContainer {
        Self.containerResult.container
    }

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
                // Check storage location and show warning if needed
                storageLocation = Self.containerResult.location
                if !storageLocation.isPersistent {
                    showStorageWarning = true
                }

                // Performance: Run migrations in background with higher priority than .background
                // but lower than main UI thread
                await performMigrations()

                // Show UI after migrations complete
                withAnimation(.easeIn(duration: 0.3)) {
                    isMigrationComplete = true
                }
            }
            .alert("Temporärer Speicher", isPresented: $showStorageWarning) {
                Button("Verstanden") {
                    showStorageWarning = false
                }
            } message: {
                Text("Die App verwendet temporären Speicher (\(storageLocation.rawValue)).\n\nDeine Daten könnten beim nächsten App-Start verloren gehen.\n\nBitte stelle sicher, dass genug Speicherplatz verfügbar ist und starte die App neu.")
            }
        }
    }

    // MARK: - Performance: Background Migration

    /// Data version constants - increment these manually when database updates are needed
    private struct DataVersions {
        static let EXERCISE_DATABASE_VERSION = 1  // Increment when exercises.csv changes
        static let SAMPLE_WORKOUT_VERSION = 2     // Increment when workouts.csv changes (already in use)
        static let FORCE_FULL_RESET_VERSION = 2   // Increment for critical breaking changes (nuclear option)
    }

    /// Performs all database migrations in the background to avoid blocking UI
    private func performMigrations() async {
        let context = sharedModelContainer.mainContext

        // 🔍 SCHRITT -1: Check if migration from old schema is needed (schema validation)
        do {
            // Try to fetch one entity of each type to verify schema compatibility
            var exerciseDescriptor = FetchDescriptor<ExerciseEntity>()
            exerciseDescriptor.fetchLimit = 1
            _ = try context.fetch(exerciseDescriptor)

            var workoutDescriptor = FetchDescriptor<WorkoutEntity>()
            workoutDescriptor.fetchLimit = 1
            _ = try context.fetch(workoutDescriptor)

            AppLogger.data.info("✅ Schema validation successful - database is compatible")
        } catch {
            // Schema incompatible - this happens when old app version has different entity structure
            AppLogger.data.error("❌ Schema validation failed: \(error.localizedDescription)")
            AppLogger.data.warning("⚠️ Database schema incompatible - this may require a reset")

            // Check if we're using in-memory storage (fallback already happened)
            if storageLocation == .inMemory {
                AppLogger.data.warning("Already using in-memory storage - proceeding with fresh data")
                await performForceReset(context: context)
                return
            }
        }

        // 🚨 SCHRITT 0: Force Full Reset (Nuclear Option - nur bei kritischen Breaking Changes)
        let forceResetVersion = UserDefaults.standard.integer(forKey: "forceResetVersion")
        if forceResetVersion < DataVersions.FORCE_FULL_RESET_VERSION {
            AppLogger.data.warning("🚨 Force full reset triggered (version \(forceResetVersion) → \(DataVersions.FORCE_FULL_RESET_VERSION))")
            await performForceReset(context: context)
            UserDefaults.standard.set(DataVersions.FORCE_FULL_RESET_VERSION, forKey: "forceResetVersion")
            AppLogger.data.info("✅ Force reset completed - all data reloaded")
            return // Nach Force-Reset sind alle Daten bereits neu geladen
        }

        // 🔄 SCHRITT 1: Exercise Database Update (wenn Exercise-CSV sich geändert hat)
        let lastExerciseVersion = UserDefaults.standard.integer(forKey: "exerciseDatabaseVersion")
        if lastExerciseVersion < DataVersions.EXERCISE_DATABASE_VERSION {
            AppLogger.exercises.info("🔄 Exercise database update needed (version \(lastExerciseVersion) → \(DataVersions.EXERCISE_DATABASE_VERSION))")
            await performExerciseUpdate(context: context)
            UserDefaults.standard.set(DataVersions.EXERCISE_DATABASE_VERSION, forKey: "exerciseDatabaseVersion")
            AppLogger.exercises.info("✅ Exercise database updated successfully")
        }

        // 🔄 SCHRITT 1b: Legacy Exercise-Migration (alte Übungen → CSV-Übungen, für alte Installationen)
        do {
            if await ExerciseDatabaseMigration.isMigrationNeeded() {
                await ExerciseDatabaseMigration.migrateToCSVExercises(context: context)
            }
        } catch {
            AppLogger.exercises.error("Exercise migration failed: \(error.localizedDescription)")
        }

        // 🌱 SCHRITT 2: Falls Datenbank leer oder Exercises haben falsche UUIDs, neu laden (Fallback)
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
            let lastVersion = UserDefaults.standard.integer(forKey: "sampleWorkoutVersion")

            let workoutDescriptor = FetchDescriptor<WorkoutEntity>()
            let existingWorkouts = try context.fetch(workoutDescriptor)

            // Migration: Alte Workouts ohne Flag als Benutzer-Workouts markieren
            for workout in existingWorkouts where workout.isSampleWorkout == nil {
                workout.isSampleWorkout = false // Alte Workouts = Benutzer-Workouts
            }
            try? context.save()

            // Wenn Version veraltet ist ODER keine Workouts vorhanden
            if lastVersion < DataVersions.SAMPLE_WORKOUT_VERSION || existingWorkouts.isEmpty {
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
                AppLogger.workouts.info("Loading sample workouts (Version \(DataVersions.SAMPLE_WORKOUT_VERSION))")
                WorkoutSeeder.seedWorkouts(context: context)

                // Speichere neue Version
                UserDefaults.standard.set(DataVersions.SAMPLE_WORKOUT_VERSION, forKey: "sampleWorkoutVersion")
                AppLogger.workouts.info("Sample workouts updated to version \(DataVersions.SAMPLE_WORKOUT_VERSION)")
            } else {
                let userWorkouts = existingWorkouts.filter { $0.isSampleWorkout == false }
                let samples = existingWorkouts.filter { $0.isSampleWorkout == true }
                AppLogger.workouts.info("Sample workouts up to date (v\(DataVersions.SAMPLE_WORKOUT_VERSION)): \(samples.count) samples, \(userWorkouts.count) user workouts")
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

    // MARK: - Reset Functions

    /// Force Full Reset: Deletes all data except workout sessions (history)
    /// Use this for critical breaking changes that require a clean slate
    private func performForceReset(context: ModelContext) async {
        do {
            // 1. Lösche ALLE Exercises (Sample + Custom)
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            AppLogger.data.info("🗑️ Deleting \(exercises.count) exercises")
            for exercise in exercises {
                context.delete(exercise)
            }

            // 2. Lösche ALLE Workouts (Sample + Custom)
            let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
            AppLogger.data.info("🗑️ Deleting \(workouts.count) workouts")
            for workout in workouts {
                context.delete(workout)
            }

            // 3. Lösche User Profile (wird neu erstellt)
            let profiles = try context.fetch(FetchDescriptor<UserProfileEntity>())
            AppLogger.data.info("🗑️ Deleting \(profiles.count) profiles")
            for profile in profiles {
                context.delete(profile)
            }

            // 4. Lösche ExerciseRecords (wird aus Sessions neu generiert)
            let records = try context.fetch(FetchDescriptor<ExerciseRecordEntity>())
            AppLogger.data.info("🗑️ Deleting \(records.count) exercise records")
            for record in records {
                context.delete(record)
            }

            // WICHTIG: Sessions (Workout-Historie) bleiben erhalten!
            let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
            AppLogger.data.info("✅ Preserving \(sessions.count) workout sessions (history)")

            try context.save()
            AppLogger.data.info("✅ Force reset: all data deleted")

            // 5. Lade Daten neu
            AppLogger.data.info("🔄 Reloading fresh data...")

            // Exercises neu laden
            ExerciseSeeder.seedExercises(context: context)
            UserDefaults.standard.set(DataVersions.EXERCISE_DATABASE_VERSION, forKey: "exerciseDatabaseVersion")

            // Sample-Workouts neu laden
            WorkoutSeeder.seedWorkouts(context: context)
            UserDefaults.standard.set(DataVersions.SAMPLE_WORKOUT_VERSION, forKey: "sampleWorkoutVersion")

            // User Profile neu erstellen
            let profile = UserProfileEntity()
            context.insert(profile)
            try context.save()

            // ExerciseRecords aus Sessions regenerieren
            if await ExerciseRecordMigration.isMigrationNeeded(context: context) {
                await ExerciseRecordMigration.migrateExistingData(context: context)
            }

            AppLogger.data.info("✅ Force reset completed successfully")

        } catch {
            AppLogger.data.error("❌ Force reset failed: \(error.localizedDescription)")
        }
    }

    /// Exercise Database Update: Deletes all exercises and reloads from CSV
    /// Use this when exercises.csv has been updated
    private func performExerciseUpdate(context: ModelContext) async {
        do {
            // 1. Lösche ALLE Exercises
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            AppLogger.exercises.info("🗑️ Deleting \(exercises.count) exercises for update")
            for exercise in exercises {
                context.delete(exercise)
            }
            try context.save()

            // 2. Lade Exercises neu aus CSV
            AppLogger.exercises.info("🔄 Loading exercises from CSV")
            ExerciseSeeder.seedExercises(context: context)

            let newExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            AppLogger.exercises.info("✅ Exercise update completed: \(newExercises.count) exercises loaded")

        } catch {
            AppLogger.exercises.error("❌ Exercise update failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - ModelContainer Factory

/// Factory for creating ModelContainer with robust fallback strategy
/// Prevents app crashes by trying multiple storage locations and configurations
enum ModelContainerFactory {

    /// Result of container creation attempt
    enum ContainerResult {
        case success(ModelContainer, location: StorageLocation)
        case failure(Error)
    }

    /// Available storage locations in fallback order
    enum StorageLocation: String {
        case applicationSupport = "Application Support"
        case documents = "Documents"
        case temporary = "Temporary"
        case inMemory = "In-Memory (Temporary)"

        var isPersistent: Bool {
            self != .inMemory
        }
    }

    /// Creates a ModelContainer with comprehensive fallback strategy
    /// - Parameter schema: The SwiftData schema to use
    /// - Returns: ContainerResult with either success or failure
    static func createContainer(schema: Schema) -> ContainerResult {
        // Try each fallback location in order
        let fallbackChain: [(StorageLocation, () throws -> ModelContainer)] = [
            (.applicationSupport, { try createApplicationSupportContainer(schema: schema) }),
            (.documents, { try createDocumentsContainer(schema: schema) }),
            (.temporary, { try createTemporaryContainer(schema: schema) }),
            (.inMemory, { try createInMemoryContainer(schema: schema) })
        ]

        for (location, createAttempt) in fallbackChain {
            do {
                let container = try createAttempt()
                logSuccess(location: location)
                return .success(container, location: location)
            } catch {
                logFailure(location: location, error: error)
                continue
            }
        }

        // This should never happen since in-memory container should always work
        let finalError = NSError(
            domain: "com.gymbo.modelcontainer",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All ModelContainer creation attempts failed"]
        )
        AppLogger.app.critical("All container creation methods failed - this should be impossible!")
        return .failure(finalError)
    }

    // MARK: - Container Creation Methods

    private static func createApplicationSupportContainer(schema: Schema) throws -> ModelContainer {
        // Create Application Support directory if needed
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        }

        // Try default location (Application Support)
        return try ModelContainer(for: schema)
    }

    private static func createDocumentsContainer(schema: Schema) throws -> ModelContainer {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeURL = documentsURL.appendingPathComponent("GymTracker.sqlite")

        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func createTemporaryContainer(schema: Schema) throws -> ModelContainer {
        let tempURL = FileManager.default.temporaryDirectory
        let storeURL = tempURL.appendingPathComponent("GymTracker.sqlite")

        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func createInMemoryContainer(schema: Schema) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Diagnostics

    /// Check storage health before attempting container creation
    static func checkStorageHealth() -> StorageHealth {
        var issues: [String] = []
        var warnings: [String] = []

        // Check available storage
        if let availableBytes = getAvailableStorage() {
            let availableMB = Double(availableBytes) / 1_048_576

            if availableMB < 50 {
                issues.append("Kritisch wenig Speicherplatz: \(String(format: "%.1f", availableMB)) MB")
            } else if availableMB < 100 {
                warnings.append("Wenig Speicherplatz: \(String(format: "%.1f", availableMB)) MB")
            }
        }

        // Check write permissions for common directories
        let fileManager = FileManager.default
        let testDirs: [(String, URL?)] = [
            ("Application Support", fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first),
            ("Documents", fileManager.urls(for: .documentDirectory, in: .userDomainMask).first),
            ("Temporary", URL(fileURLWithPath: NSTemporaryDirectory()))
        ]

        for (name, url) in testDirs {
            guard let url = url else {
                issues.append("\(name)-Verzeichnis nicht verfügbar")
                continue
            }

            if !fileManager.isWritableFile(atPath: url.path) {
                issues.append("Keine Schreibrechte für \(name)")
            }
        }

        // Check for corrupted database files
        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dbURL = docsURL.appendingPathComponent("GymTracker.sqlite")
            if fileManager.fileExists(atPath: dbURL.path) {
                // Check if file is readable
                if !fileManager.isReadableFile(atPath: dbURL.path) {
                    issues.append("Datenbank-Datei beschädigt oder nicht lesbar")
                }
            }
        }

        return StorageHealth(issues: issues, warnings: warnings)
    }

    /// Get available storage in bytes
    private static func getAvailableStorage() -> Int64? {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            AppLogger.app.error("Failed to check storage: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Logging

    private static func logSuccess(location: StorageLocation) {
        AppLogger.app.info("✅ ModelContainer created at: \(location.rawValue)")

        if !location.isPersistent {
            AppLogger.app.warning("⚠️ Using non-persistent storage - data will be lost on restart!")
        }
    }

    private static func logFailure(location: StorageLocation, error: Error) {
        AppLogger.app.error("❌ Failed to create container at \(location.rawValue): \(error.localizedDescription)")
    }
}

// MARK: - Supporting Types

struct StorageHealth {
    let issues: [String]
    let warnings: [String]

    var isHealthy: Bool {
        issues.isEmpty
    }

    var hasCriticalIssues: Bool {
        !issues.isEmpty
    }

    var summary: String {
        var lines: [String] = []

        if issues.isEmpty && warnings.isEmpty {
            lines.append("✅ Speicher ist gesund")
        }

        if !issues.isEmpty {
            lines.append("❌ Probleme:")
            lines.append(contentsOf: issues.map { "  • \($0)" })
        }

        if !warnings.isEmpty {
            lines.append("⚠️ Warnungen:")
            lines.append(contentsOf: warnings.map { "  • \($0)" })
        }

        return lines.joined(separator: "\n")
    }
}
