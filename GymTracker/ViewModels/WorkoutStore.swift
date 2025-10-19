import Combine
import Foundation
import HealthKit
import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
class WorkoutStore: ObservableObject {
    @Published var activeSessionID: UUID?
    @Published var isShowingWorkoutDetail: Bool = false

    // MARK: - Phase 5 Integration (Complete)

    /// Rest timer state manager - Single Source of Truth for rest timer
    let restTimerStateManager: RestTimerStateManager

    /// In-app overlay manager (Phase 2)
    weak var overlayManager: InAppOverlayManager?

    // MARK: - Profile & UI State

    @Published var profileUpdateTrigger: UUID = UUID()  // Triggers UI updates when profile changes

    // Herzfrequenz-Tracking
    private var heartRateTracker: HealthKitWorkoutTracker?

    // MARK: - Services
    private let analyticsService = WorkoutAnalyticsService()
    private let dataService = WorkoutDataService()
    private let profileService = ProfileService()
    private let sessionService = WorkoutSessionService()
    private let metricsService = LastUsedMetricsService()
    private let generationService = WorkoutGenerationService()
    typealias ExerciseStats = WorkoutAnalyticsService.ExerciseStats

    @AppStorage("weeklyGoal") var weeklyGoal: Int = 5
    @AppStorage("restNotificationsEnabled") var restNotificationsEnabled: Bool = true
    @AppStorage("exercisesTranslatedToGerman") private var exercisesTranslatedToGerman: Bool = false

    // SwiftData context reference (wird von ContentView gesetzt)
    var modelContext: ModelContext? {
        didSet {
            analyticsService.setContext(modelContext)
            dataService.setContext(modelContext)
            sessionService.setContext(modelContext)
            metricsService.setContext(modelContext)

            if let context = modelContext {
                // Phase 8: Automatische Markdown-Migration beim ersten App-Start
                checkAndPerformAutomaticMigration(context: context)

                // Alte automatische Übersetzung (kann eventuell entfernt werden)
                checkAndPerformAutomaticGermanTranslation(context: context)
            }
        }
    }

    // HealthKit integration
    @Published var healthKitManager = HealthKitManager.shared

    var activeWorkout: Workout? {
        if let workout = dataService.activeWorkout(with: activeSessionID) {
            return workout
        }

        if let staleId = activeSessionID {
            print("⚠️ Aktives Workout mit ID \(staleId.uuidString) nicht gefunden")
            activeSessionID = nil
            WorkoutLiveActivityController.shared.end()
        }

        return nil
    }

    var homeWorkouts: [Workout] {
        dataService.homeWorkouts()
    }

    var userProfile: UserProfile {
        profileService.loadProfile(context: modelContext)
    }

    // MARK: - Active Session Management

    init() {
        // Initialize the new rest timer state manager (Phase 1+2)
        let manager = RestTimerStateManager()
        self.restTimerStateManager = manager

        // overlayManager will be set later by ContentView.onAppear
    }

    deinit {
        // Note: Can't call MainActor-isolated methods in deinit
        // Rest timer cleanup is handled by RestTimerStateManager
        // WorkoutLiveActivityController will handle cleanup when the rest state is cleared elsewhere
    }

    func startSession(for workoutId: UUID) {
        do {
            guard let workoutEntity = try sessionService.prepareSessionStart(for: workoutId) else {
                print("❌ Workout mit ID \(workoutId) nicht gefunden")
                return
            }

            activeSessionID = workoutId
            UserDefaults.standard.set(workoutId.uuidString, forKey: "activeWorkoutID")
            print("✅ Session gestartet für Workout: \(workoutEntity.name)")

            startHeartRateTracking(workoutId: workoutId, workoutName: workoutEntity.name)
        } catch WorkoutSessionService.SessionError.missingModelContext {
            print("❌ WorkoutStore: ModelContext ist nil beim Starten einer Session")
        } catch {
            print("❌ Fehler beim Starten der Session: \(error)")
        }
    }

    func endCurrentSession() {
        if let sessionID = activeSessionID {
            print("🔚 Session beendet für Workout-ID: \(sessionID)")
            activeSessionID = nil
            stopRest()

            // Lösche persistierten Workout-State
            UserDefaults.standard.removeObject(forKey: "activeWorkoutID")

            // Stoppe Herzfrequenz-Tracking
            stopHeartRateTracking()

            WorkoutLiveActivityController.shared.end()
        }
    }

    // MARK: - Data Access Helpers

    var exercises: [Exercise] {
        dataService.exercises()
    }

    var workouts: [Workout] {
        dataService.allWorkouts()
    }

    /// Findet ähnliche Übungen basierend auf Muskelgruppen, Equipment und Schwierigkeit
    /// - Parameters:
    ///   - exercise: Die Referenz-Übung
    ///   - count: Anzahl der zurückzugebenden ähnlichen Übungen (default: 10)
    ///   - userLevel: Optional - bevorzugt Übungen die zum User-Level passen
    /// - Returns: Array von ähnlichen Übungen, sortiert nach Similarity-Score
    func getSimilarExercises(
        to exercise: Exercise, count: Int = 10, userLevel: ExperienceLevel? = nil
    ) -> [Exercise] {
        dataService.similarExercises(to: exercise, count: count, userLevel: userLevel)
    }

    func getSessionHistory(limit: Int = 100) -> [WorkoutSession] {
        analyticsService.getSessionHistory(limit: limit)
    }

    func addExercise(_ exercise: Exercise) {
        dataService.addExercise(exercise)
        invalidateCaches()
    }

    func updateExercise(_ exercise: Exercise) {
        dataService.updateExercise(exercise)
        analyticsService.invalidateExerciseCache(for: exercise.id)
    }

    func addWorkout(_ workout: Workout) {
        dataService.addWorkout(workout)
    }

    func updateWorkout(_ workout: Workout) {
        dataService.updateWorkout(workout)
    }

    func exercise(named name: String) -> Exercise {
        dataService.exercise(named: name)
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        let sessionHistory = analyticsService.getSessionHistory()
        return
            sessionHistory
            .filter { $0.templateId == workout.id }
            .sorted { $0.date > $1.date }
            .first
            .map(Workout.init(session:))
    }

    // MARK: - Last-Used Metrics (Delegated to LastUsedMetricsService)

    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        return metricsService.lastMetrics(for: exercise)
    }

    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics? {
        return metricsService.completeLastMetrics(for: exercise)
    }

    func deleteExercise(at indexSet: IndexSet) {
        let removedIDs = dataService.deleteExercises(at: indexSet)
        removedIDs.forEach { analyticsService.invalidateExerciseCache(for: $0) }
    }

    func deleteWorkout(at indexSet: IndexSet) {
        dataService.deleteWorkouts(at: indexSet)
    }

    func recordSession(from workout: Workout) {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Speichern einer Session")
            return
        }

        let sortedExercises = workout.exercises

        let session = WorkoutSession(
            templateId: workout.id,
            name: workout.name,
            date: workout.date,
            exercises: sortedExercises,
            defaultRestTime: workout.defaultRestTime,
            duration: workout.duration,
            notes: workout.notes
        )

        do {
            let savedEntity = try sessionService.recordSession(session)

            updateLastUsedMetrics(from: session)

            Task {
                await ExerciseRecordMigration.updateRecords(from: savedEntity, context: context)
            }

            invalidateCaches()
            print("✅ Workout-Session erfolgreich gespeichert: \(workout.name)")

            if userProfile.healthKitSyncEnabled && healthKitManager.isAuthorized {
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        try await self.saveWorkoutToHealthKit(session)
                        await MainActor.run {
                            print("✅ Workout in HealthKit gespeichert: \(session.name)")
                        }
                    } catch {
                        await MainActor.run {
                            print("⚠️ Fehler beim Sync zu HealthKit: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch WorkoutSessionService.SessionError.missingModelContext {
            print("❌ WorkoutStore: ModelContext ist nil beim Speichern einer Session")
        } catch {
            print("❌ Fehler beim Speichern der Workout-Session: \(error)")
        }
    }

    // MARK: - Last-Used Metrics Management (Delegated to LastUsedMetricsService)

    private func updateLastUsedMetrics(from session: WorkoutSession) {
        metricsService.updateLastUsedMetrics(from: session)
    }

    func removeSession(with id: UUID) {
        do {
            try sessionService.removeSession(with: id)
            invalidateCaches()
        } catch WorkoutSessionService.SessionError.missingModelContext {
            print("❌ WorkoutStore: ModelContext ist nil beim Entfernen einer Session")
        } catch {
            print("❌ Fehler beim Entfernen der Session: \(error)")
        }
    }

    // MARK: - Profile Management

    // MARK: - Profile Management
    func updateProfile(
        name: String, birthDate: Date?, weight: Double?, height: Double? = nil,
        biologicalSex: HKBiologicalSex? = nil, goal: FitnessGoal, experience: ExperienceLevel,
        equipment: EquipmentPreference, preferredDuration: WorkoutDuration,
        healthKitSyncEnabled: Bool = false, profileImageData: Data? = nil
    ) {
        let profile = profileService.updateProfile(
            context: modelContext,
            name: name,
            birthDate: birthDate,
            weight: weight,
            height: height,
            biologicalSex: biologicalSex,
            goal: goal,
            experience: experience,
            equipment: equipment,
            preferredDuration: preferredDuration,
            healthKitSyncEnabled: healthKitSyncEnabled,
            profileImageData: profileImageData
        )

        profileUpdateTrigger = UUID()
        print("✅ Profil gespeichert: \(profile.name) - \(profile.goal.displayName)")
    }

    func updateProfileImage(_ image: UIImage?) {
        let data: Data?
        if let image {
            let targetSize = CGSize(width: 200, height: 200)
            let resizedImage = image.resized(to: targetSize)
            data = resizedImage.jpegData(compressionQuality: 0.8)
        } else {
            data = nil
        }

        _ = profileService.updateProfileImageData(data, context: modelContext)
        profileUpdateTrigger = UUID()
        print("✅ Profilbild gespeichert")
    }

    func updateLockerNumber(_ lockerNumber: String) {
        _ = profileService.updateLockerNumber(lockerNumber, context: modelContext)
        profileUpdateTrigger = UUID()
        print("✅ Spintnummer gespeichert: \(lockerNumber)")
    }

    // MARK: - Onboarding Progress

    func markOnboardingStep(
        hasExploredWorkouts: Bool? = nil, hasCreatedFirstWorkout: Bool? = nil,
        hasSetupProfile: Bool? = nil
    ) {
        _ = profileService.markOnboardingStep(
            context: modelContext,
            hasExploredWorkouts: hasExploredWorkouts,
            hasCreatedFirstWorkout: hasCreatedFirstWorkout,
            hasSetupProfile: hasSetupProfile
        )

        profileUpdateTrigger = UUID()
        print(
            "✅ Onboarding-Status aktualisiert: exploredWorkouts=\(hasExploredWorkouts?.description ?? "-") createdFirstWorkout=\(hasCreatedFirstWorkout?.description ?? "-") setupProfile=\(hasSetupProfile?.description ?? "-")"
        )
    }

    // MARK: - HealthKit Integration

    func requestHealthKitAuthorization() async throws {
        try await healthKitManager.requestAuthorization()

        // Automatically import profile data after successful authorization
        if healthKitManager.isAuthorized {
            print("🔄 HealthKit authorized - importing profile data automatically...")
            try await importFromHealthKit()
        }
    }

    func importFromHealthKit() async throws {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        print("🏥 Starte HealthKit-Import...")

        do {
            let data = try await healthKitManager.readProfileData()

            guard let context = modelContext else {
                print("❌ ModelContext nicht verfügbar")
                return
            }

            let descriptor = FetchDescriptor<UserProfileEntity>()

            let entity: UserProfileEntity
            if let existing = try? context.fetch(descriptor).first {
                entity = existing
            } else {
                entity = UserProfileEntity()
                context.insert(entity)
            }

            // Update only if we got valid data from HealthKit
            var updatedFields: [String] = []

            if let birthDate = data.birthDate {
                entity.birthDate = birthDate
                updatedFields.append("Geburtsdatum")
            }
            if let weight = data.weight {
                entity.weight = weight
                updatedFields.append("Gewicht")
            }
            if let height = data.height {
                entity.height = height
                updatedFields.append("Größe")
            }
            if let sex = data.biologicalSex {
                entity.biologicalSexRaw = Int16(sex.rawValue)
                updatedFields.append("Geschlecht")
            }

            entity.healthKitSyncEnabled = true
            entity.updatedAt = Date()

            try context.save()

            // Trigger UI update
            profileUpdateTrigger = UUID()

            // Post notification for immediate UI updates
            NotificationCenter.default.post(name: .profileUpdatedFromHealthKit, object: nil)

            print("✅ HealthKit-Import erfolgreich abgeschlossen")
            print("   • Aktualisierte Felder: \(updatedFields.joined(separator: ", "))")

        } catch let error as HealthKitError {
            print("❌ HealthKit-Fehler: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Unbekannter Fehler beim HealthKit-Import: \(error)")
            throw HealthKitError.saveFailed
        }
    }

    func saveWorkoutToHealthKit(_ workoutSession: WorkoutSession) async throws {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        guard userProfile.healthKitSyncEnabled else {
            return  // User has not enabled HealthKit sync
        }

        try await healthKitManager.saveWorkout(workoutSession)
    }

    func readHeartRateData(from startDate: Date, to endDate: Date) async throws
        -> [HeartRateReading]
    {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        return try await healthKitManager.readHeartRate(from: startDate, to: endDate)
    }

    func readWeightData(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading]
    {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        return try await healthKitManager.readWeight(from: startDate, to: endDate)
    }

    func readBodyFatData(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading] {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        return try await healthKitManager.readBodyFat(from: startDate, to: endDate)
    }

    // MARK: - Favorites

    func toggleFavorite(for workoutID: UUID) {
        dataService.toggleFavorite(for: workoutID)
    }

    func toggleHomeFavorite(workoutID: UUID) -> Bool {
        dataService.toggleHomeFavorite(workoutID: workoutID)
    }

    // MARK: - Zentrale Rest-Timer Steuerung

    func startRest(for workout: Workout, exerciseIndex: Int, setIndex: Int, totalSeconds: Int) {
        // Extract exercise names for Live Activity display
        let currentExerciseName: String? =
            workout.exercises.indices.contains(exerciseIndex)
            ? workout.exercises[exerciseIndex].exercise.name
            : nil

        let nextExerciseName: String? =
            workout.exercises.indices.contains(exerciseIndex + 1)
            ? workout.exercises[exerciseIndex + 1].exercise.name
            : nil

        // Phase 5: Use RestTimerStateManager as single source of truth
        restTimerStateManager.startRest(
            for: workout,
            exercise: exerciseIndex,
            set: setIndex,
            duration: totalSeconds,
            currentExerciseName: currentExerciseName,
            nextExerciseName: nextExerciseName
        )
    }

    func pauseRest() {
        // Phase 5: Delegate to RestTimerStateManager
        restTimerStateManager.pauseRest()
    }

    func resumeRest() {
        // Phase 5: Delegate to RestTimerStateManager
        restTimerStateManager.resumeRest()
    }

    func addRest(seconds: Int) {
        // Phase 5: Delegate to RestTimerStateManager
        restTimerStateManager.addRest(seconds: seconds)
    }

    func setRest(remaining: Int, total: Int? = nil) {
        // Phase 5: Delegate to RestTimerStateManager
        restTimerStateManager.setRest(remaining: remaining, total: total)
    }

    func stopRest() {
        // Phase 5: Delegate to RestTimerStateManager
        restTimerStateManager.cancelRest()
    }

    /// Clear rest state after user interaction (e.g. "Continue" button)
    /// Does NOT cancel notification - only called after user acknowledged timer end
    func clearRestState() {
        // Phase 5: Delegate to RestTimerStateManager (acknowledges expired timer)
        restTimerStateManager.acknowledgeExpired()
    }

    // MARK: - ExerciseRecord Management

    /// Get ExerciseRecord for a specific exercise
    func getExerciseRecord(for exercise: Exercise) -> ExerciseRecord? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExerciseRecordEntity>(
            predicate: #Predicate<ExerciseRecordEntity> { record in
                record.exerciseId == exercise.id
            }
        )

        guard let entity = try? context.fetch(descriptor).first else { return nil }

        return ExerciseRecord(
            id: entity.id,
            exerciseId: entity.exerciseId,
            exerciseName: entity.exerciseName,
            maxWeight: entity.maxWeight,
            maxWeightReps: entity.maxWeightReps,
            maxWeightDate: entity.maxWeightDate,
            maxReps: entity.maxReps,
            maxRepsWeight: entity.maxRepsWeight,
            maxRepsDate: entity.maxRepsDate,
            bestEstimatedOneRepMax: entity.bestEstimatedOneRepMax,
            bestOneRepMaxWeight: entity.bestOneRepMaxWeight,
            bestOneRepMaxReps: entity.bestOneRepMaxReps,
            bestOneRepMaxDate: entity.bestOneRepMaxDate,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    /// Get all ExerciseRecords
    func getAllExerciseRecords() -> [ExerciseRecord] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<ExerciseRecordEntity>(
            sortBy: [SortDescriptor(\.exerciseName)]
        )

        let entities = (try? context.fetch(descriptor)) ?? []

        return entities.map { entity in
            ExerciseRecord(
                id: entity.id,
                exerciseId: entity.exerciseId,
                exerciseName: entity.exerciseName,
                maxWeight: entity.maxWeight,
                maxWeightReps: entity.maxWeightReps,
                maxWeightDate: entity.maxWeightDate,
                maxReps: entity.maxReps,
                maxRepsWeight: entity.maxRepsWeight,
                maxRepsDate: entity.maxRepsDate,
                bestEstimatedOneRepMax: entity.bestEstimatedOneRepMax,
                bestOneRepMaxWeight: entity.bestOneRepMaxWeight,
                bestOneRepMaxReps: entity.bestOneRepMaxReps,
                bestOneRepMaxDate: entity.bestOneRepMaxDate,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt
            )
        }
    }

    /// Check if a set would be a new personal record
    func checkForNewRecord(exercise: Exercise, weight: Double, reps: Int) -> RecordType? {
        guard let record = getExerciseRecord(for: exercise) else {
            // If no record exists yet, any completed set is a new record
            if weight > 0 && reps > 0 {
                return .maxWeight  // Default to weight record for first achievement
            }
            return nil
        }

        return record.hasNewRecord(weight: weight, reps: reps)
    }

    // MARK: - Cache Management

    func invalidateCaches() {
        analyticsService.invalidateCaches()
    }

    // MARK: - Exercise Database Update
    func updateExerciseDatabase() {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Update der Übungsdatenbank")
            return
        }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                print("🔄 Starte sichere Übungsdatenbank-Aktualisierung...")

                // Get all existing exercises
                let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                print("📚 Gefunden: \(existingExercises.count) bestehende Übungen")

                // Get all new German exercises
                let germanExercises = ExerciseSeeder.createRealisticExercises()
                print("🇩🇪 Erstelle Mapping für \(germanExercises.count) deutsche Übungen")

                // Create comprehensive mapping from English to German names
                let nameMapping: [String: String] = [
                    // === BRUST ===
                    "Hammer Strength Chest Press": "Brustpresse Hammer",
                    "Pec Deck Flys": "Butterfly Maschine",
                    "Incline Chest Press Maschine": "Schrägbankdrücken Maschine",
                    "Decline Chest Press Maschine": "Negativbankdrücken Maschine",
                    "Chest Supported Dips Maschine": "Assistierte Barrenstütze",
                    "Dips an Barren": "Barrenstütze",
                    "Kabelzug Crossover": "Kabelzug Überkreuz",
                    "Negativ Schrägbankdrücken": "Negativbankdrücken",
                    "Fliegende Kurzhanteln": "Fliegende Bewegung",
                    "Kurzhantel Fliegende schräg": "Schrägbank Fliegende",

                    // === RÜCKEN ===
                    "Lat Pulldown breit": "Latzug breit",
                    "Lat Pulldown eng": "Latzug eng",
                    "Assisted Pull-up Maschine": "Assistierte Klimmzüge",
                    "Low Row Maschine": "Tiefes Rudern Maschine",
                    "High Row Maschine": "Hohes Rudern Maschine",
                    "Lat Pullover Maschine": "Latzug Überzug Maschine",
                    "Back Extension Maschine": "Rückenstrecker Maschine",
                    "Shrugs Kurzhanteln": "Schulterheben Kurzhanteln",
                    "Shrugs Langhantel": "Schulterheben Langhantel",
                    "T-Bar Rudern": "T-Hantel Rudern",
                    "Hyperextensions": "Rückenstrecker",

                    // === BEINE ===
                    "Front Squats": "Frontkniebeugen",
                    "Goblet Squats": "Goblet Kniebeugen",
                    "Hack Squats": "Hackenschmidt Kniebeugen",
                    "Ausfallschritte rückwärts": "Rückwärts Ausfallschritte",
                    "Walking Lunges": "Gehende Ausfallschritte",
                    "Bulgarische Split Squats": "Bulgarische Kniebeuge",
                    "Sumo Deadlift": "Sumo Kreuzheben",
                    "Stiff Leg Deadlift": "Gestrecktes Kreuzheben",
                    "Single Leg Press": "Einbeinige Beinpresse",
                    "Step-ups": "Aufstiege",
                    "Leg Press 45°": "Beinpresse 45°",
                    "Smith Machine Squats": "Smith Maschine Kniebeugen",
                    "Glute Ham Raise": "Glute Ham Entwicklung",

                    // === SCHULTERN ===
                    "Arnold Press": "Arnold Drücken",
                    "Upright Rows": "Aufrechtes Rudern",
                    "Face Pulls": "Gesichtszüge",
                    "Pike Push-ups": "Pike Liegestütze",
                    "Reverse Pec Deck": "Reverse Butterfly",
                    "Front Raise Maschine": "Frontheben Maschine",
                    "Shrug Maschine": "Schulterheben Maschine",

                    // === BIZEPS ===
                    "Bizep Curls": "Bizeps Curls",
                    "Bizep Curls Langhantel": "Bizeps Curls Langhantel",
                    "Konzentration Curls": "Konzentrations Curls",
                    "21s Bizep Curls": "21er Bizeps Curls",
                    "Kabel Bizep Curls": "Kabel Bizeps Curls",
                    "Preacher Curls": "Prediger Curls",
                    "Spider Curls": "Spinnen Curls",
                    "Bizep Curls Maschine": "Bizeps Curls Maschine",

                    // === TRIZEPS ===
                    "Trizep Dips": "Trizeps Dips",
                    "French Press": "Französisches Drücken",
                    "French Press Kurzhantel": "Französisches Drücken Kurzhantel",
                    "Trizeps Pushdown": "Trizeps Drücken",
                    "Trizeps Pushdown Seil": "Trizeps Drücken Seil",
                    "Overhead Trizep Extension": "Trizeps Überkopfstreckung",
                    "Diamond Push-ups": "Diamant Liegestütze",
                    "Close Grip Bench Press": "Enges Bankdrücken",
                    "Trizeps Extension Maschine": "Trizeps Streckung Maschine",

                    // === BAUCH ===
                    "Plank": "Unterarmstütz",
                    "Side Plank": "Seitlicher Unterarmstütz",
                    "Bicycle Crunches": "Fahrrad Crunches",
                    "Russian Twists": "Russische Drehungen",
                    "Mountain Climbers": "Bergsteiger",
                    "Dead Bug": "Toter Käfer",
                    "Hanging Knee Raises": "Hängendes Knieheben",
                    "Hanging Leg Raises": "Hängendes Beinheben",
                    "Ab Wheel Rollout": "Bauchroller",
                    "Flutter Kicks": "Beinflattern",
                    "Leg Raises": "Beinheben",
                    "Wood Choppers": "Holzhacker",
                    "Captain's Chair Knee Raises": "Kapitänsstuhl Knieheben",
                    "Ab Crunch Maschine": "Bauchpresse Maschine",
                    "Torso Rotation Maschine": "Rumpfdrehung Maschine",

                    // === FUNKTIONELLE ÜBUNGEN ===
                    "Turkish Get-up": "Türkisches Aufstehen",
                    "Kettlebell Swings": "Kettlebell Schwünge",
                    "Kettlebell Goblet Squats": "Kettlebell Goblet Kniebeugen",
                    "Box Jumps": "Kastensprünge",
                    "Bear Crawl": "Bärengang",
                    "Wall Sit": "Wandsitz",
                    "Jump Squats": "Sprungkniebeugen",
                    "Single Leg Deadlift": "Einbeiniges Kreuzheben",
                    "Hindu Push-ups": "Hindu Liegestütze",
                    "Pistol Squats": "Pistolen Kniebeugen",
                    "Archer Push-ups": "Bogenschützen Liegestütze",
                    "Clean and Press": "Umsetzen und Drücken",
                    "Sled Push": "Schlitten schieben",
                    "Sled Pull": "Schlitten ziehen",
                    "Farmer's Walk": "Farmers Walk",
                ]

                var updatedCount = 0

                // Update existing exercises with German names
                for existingExercise in existingExercises {
                    if let germanName = nameMapping[existingExercise.name] {
                        print("🔄 Aktualisiere: '\(existingExercise.name)' → '\(germanName)'")
                        existingExercise.name = germanName
                        updatedCount += 1
                    } else {
                        // Check if we can find a corresponding German exercise by similar name
                        if let germanExercise = germanExercises.first(where: {
                            $0.name == existingExercise.name
                        }) {
                            // Exercise already has German name, update description etc.
                            existingExercise.muscleGroupsRaw = germanExercise.muscleGroups.map {
                                $0.rawValue
                            }
                            existingExercise.equipmentTypeRaw =
                                germanExercise.equipmentType.rawValue
                            existingExercise.descriptionText = germanExercise.description
                            existingExercise.instructions = germanExercise.instructions
                        }
                    }
                }

                // Add any missing German exercises
                let existingNames = Set(existingExercises.map { $0.name })
                var addedCount = 0

                for germanExercise in germanExercises {
                    if !existingNames.contains(germanExercise.name)
                        && !nameMapping.values.contains(germanExercise.name)
                    {
                        let entity = ExerciseEntity(
                            id: germanExercise.id,
                            name: germanExercise.name,
                            muscleGroupsRaw: germanExercise.muscleGroups.map { $0.rawValue },
                            equipmentTypeRaw: germanExercise.equipmentType.rawValue,
                            descriptionText: germanExercise.description,
                            instructions: germanExercise.instructions,
                            createdAt: germanExercise.createdAt
                        )
                        context.insert(entity)
                        addedCount += 1
                        print("➕ Neue Übung hinzugefügt: '\(germanExercise.name)'")
                    }
                }

                // Save changes
                try context.save()

                await MainActor.run {
                    print("✅ Übungsdatenbank erfolgreich aktualisiert!")
                    print("   - \(updatedCount) Übungen auf Deutsch aktualisiert")
                    print("   - \(addedCount) neue Übungen hinzugefügt")

                    // Trigger UI refresh
                    self.invalidateCaches()
                    self.objectWillChange.send()
                }

            } catch {
                print("❌ Fehler beim Aktualisieren der Übungsdatenbank: \(error)")
            }
        }
    }

    // MARK: - Automatic German Translation on App Start
    private func checkAndPerformAutomaticGermanTranslation(context: ModelContext) {
        // Nur ausführen, wenn noch nicht übersetzt wurde
        guard !exercisesTranslatedToGerman else {
            print(
                "✅ Deutsche Übersetzung bereits durchgeführt - überspringe automatische Aktualisierung"
            )
            return
        }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                print("🚀 Starte automatische einmalige Deutsche Übersetzung beim App-Start...")

                // Prüfe ob überhaupt Übungen vorhanden sind
                let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                guard !existingExercises.isEmpty else {
                    print("ℹ️ Keine bestehenden Übungen gefunden - markiere als übersetzt")
                    await MainActor.run {
                        self.exercisesTranslatedToGerman = true
                    }
                    return
                }

                print(
                    "📚 Gefunden: \(existingExercises.count) bestehende Übungen - starte Übersetzung..."
                )

                // Get all new German exercises
                let germanExercises = ExerciseSeeder.createRealisticExercises()

                // Create comprehensive mapping from English to German names
                let nameMapping: [String: String] = [
                    // === BRUST ===
                    "Hammer Strength Chest Press": "Brustpresse Hammer",
                    "Pec Deck Flys": "Butterfly Maschine",
                    "Incline Chest Press Maschine": "Schrägbankdrücken Maschine",
                    "Decline Chest Press Maschine": "Negativbankdrücken Maschine",
                    "Chest Supported Dips Maschine": "Assistierte Barrenstütze",
                    "Dips an Barren": "Barrenstütze",
                    "Kabelzug Crossover": "Kabelzug Überkreuz",
                    "Negativ Schrägbankdrücken": "Negativbankdrücken",
                    "Fliegende Kurzhanteln": "Fliegende Bewegung",
                    "Kurzhantel Fliegende schräg": "Schrägbank Fliegende",

                    // === RÜCKEN ===
                    "Lat Pulldown breit": "Latzug breit",
                    "Lat Pulldown eng": "Latzug eng",
                    "Assisted Pull-up Maschine": "Assistierte Klimmzüge",
                    "Low Row Maschine": "Tiefes Rudern Maschine",
                    "High Row Maschine": "Hohes Rudern Maschine",
                    "Lat Pullover Maschine": "Latzug Überzug Maschine",
                    "Back Extension Maschine": "Rückenstrecker Maschine",
                    "Shrugs Kurzhanteln": "Schulterheben Kurzhanteln",
                    "Shrugs Langhantel": "Schulterheben Langhantel",
                    "T-Bar Rudern": "T-Hantel Rudern",
                    "Hyperextensions": "Rückenstrecker",

                    // === BEINE ===
                    "Front Squats": "Frontkniebeugen",
                    "Goblet Squats": "Goblet Kniebeugen",
                    "Hack Squats": "Hackenschmidt Kniebeugen",
                    "Ausfallschritte rückwärts": "Rückwärts Ausfallschritte",
                    "Walking Lunges": "Gehende Ausfallschritte",
                    "Bulgarische Split Squats": "Bulgarische Kniebeuge",
                    "Sumo Deadlift": "Sumo Kreuzheben",
                    "Stiff Leg Deadlift": "Gestrecktes Kreuzheben",
                    "Single Leg Press": "Einbeinige Beinpresse",
                    "Step-ups": "Aufstiege",
                    "Leg Press 45°": "Beinpresse 45°",
                    "Smith Machine Squats": "Smith Maschine Kniebeugen",
                    "Glute Ham Raise": "Glute Ham Entwicklung",

                    // === SCHULTERN ===
                    "Arnold Press": "Arnold Drücken",
                    "Upright Rows": "Aufrechtes Rudern",
                    "Face Pulls": "Gesichtszüge",
                    "Pike Push-ups": "Pike Liegestütze",
                    "Reverse Pec Deck": "Reverse Butterfly",
                    "Front Raise Maschine": "Frontheben Maschine",
                    "Shrug Maschine": "Schulterheben Maschine",

                    // === BIZEPS ===
                    "Bizep Curls": "Bizeps Curls",
                    "Bizep Curls Langhantel": "Bizeps Curls Langhantel",
                    "Konzentration Curls": "Konzentrations Curls",
                    "21s Bizep Curls": "21er Bizeps Curls",
                    "Kabel Bizep Curls": "Kabel Bizeps Curls",
                    "Preacher Curls": "Prediger Curls",
                    "Spider Curls": "Spinnen Curls",
                    "Bizep Curls Maschine": "Bizeps Curls Maschine",

                    // === TRIZEPS ===
                    "Trizep Dips": "Trizeps Dips",
                    "French Press": "Französisches Drücken",
                    "French Press Kurzhantel": "Französisches Drücken Kurzhantel",
                    "Trizeps Pushdown": "Trizeps Drücken",
                    "Trizeps Pushdown Seil": "Trizeps Drücken Seil",
                    "Overhead Trizep Extension": "Trizeps Überkopfstreckung",
                    "Diamond Push-ups": "Diamant Liegestütze",
                    "Close Grip Bench Press": "Enges Bankdrücken",
                    "Trizeps Extension Maschine": "Trizeps Streckung Maschine",

                    // === BAUCH ===
                    "Plank": "Unterarmstütz",
                    "Side Plank": "Seitlicher Unterarmstütz",
                    "Bicycle Crunches": "Fahrrad Crunches",
                    "Russian Twists": "Russische Drehungen",
                    "Mountain Climbers": "Bergsteiger",
                    "Dead Bug": "Toter Käfer",
                    "Hanging Knee Raises": "Hängendes Knieheben",
                    "Hanging Leg Raises": "Hängendes Beinheben",
                    "Ab Wheel Rollout": "Bauchroller",
                    "Flutter Kicks": "Beinflattern",
                    "Leg Raises": "Beinheben",
                    "Wood Choppers": "Holzhacker",
                    "Captain's Chair Knee Raises": "Kapitänsstuhl Knieheben",
                    "Ab Crunch Maschine": "Bauchpresse Maschine",
                    "Torso Rotation Maschine": "Rumpfdrehung Maschine",

                    // === FUNKTIONELLE ÜBUNGEN ===
                    "Turkish Get-up": "Türkisches Aufstehen",
                    "Kettlebell Swings": "Kettlebell Schwünge",
                    "Kettlebell Goblet Squats": "Kettlebell Goblet Kniebeugen",
                    "Box Jumps": "Kastensprünge",
                    "Bear Crawl": "Bärengang",
                    "Wall Sit": "Wandsitz",
                    "Jump Squats": "Sprungkniebeugen",
                    "Single Leg Deadlift": "Einbeiniges Kreuzheben",
                    "Hindu Push-ups": "Hindu Liegestütze",
                    "Pistol Squats": "Pistolen Kniebeugen",
                    "Archer Push-ups": "Bogenschützen Liegestütze",
                    "Clean and Press": "Umsetzen und Drücken",
                    "Sled Push": "Schlitten schieben",
                    "Sled Pull": "Schlitten ziehen",
                    "Farmer's Walk": "Farmers Walk",
                ]

                var updatedCount = 0

                // Update existing exercises with German names
                for existingExercise in existingExercises {
                    if let germanName = nameMapping[existingExercise.name] {
                        print(
                            "🔄 Automatische Übersetzung: '\(existingExercise.name)' → '\(germanName)'"
                        )
                        existingExercise.name = germanName

                        // Aktualisiere auch andere Eigenschaften wenn möglich
                        if let germanExercise = germanExercises.first(where: {
                            $0.name == germanName
                        }) {
                            existingExercise.muscleGroupsRaw = germanExercise.muscleGroups.map {
                                $0.rawValue
                            }
                            existingExercise.equipmentTypeRaw =
                                germanExercise.equipmentType.rawValue
                            existingExercise.descriptionText = germanExercise.description
                            existingExercise.instructions = germanExercise.instructions
                        }

                        updatedCount += 1
                    } else {
                        // Check if we can find a corresponding German exercise by similar name
                        if let germanExercise = germanExercises.first(where: {
                            $0.name == existingExercise.name
                        }) {
                            // Exercise already has German name, update description etc.
                            existingExercise.muscleGroupsRaw = germanExercise.muscleGroups.map {
                                $0.rawValue
                            }
                            existingExercise.equipmentTypeRaw =
                                germanExercise.equipmentType.rawValue
                            existingExercise.descriptionText = germanExercise.description
                            existingExercise.instructions = germanExercise.instructions
                        }
                    }
                }

                // Add any missing German exercises
                let existingNames = Set(existingExercises.map { $0.name })
                var addedCount = 0

                for germanExercise in germanExercises {
                    if !existingNames.contains(germanExercise.name)
                        && !nameMapping.values.contains(germanExercise.name)
                    {
                        let entity = ExerciseEntity(
                            id: germanExercise.id,
                            name: germanExercise.name,
                            muscleGroupsRaw: germanExercise.muscleGroups.map { $0.rawValue },
                            equipmentTypeRaw: germanExercise.equipmentType.rawValue,
                            descriptionText: germanExercise.description,
                            instructions: germanExercise.instructions,
                            createdAt: germanExercise.createdAt
                        )
                        context.insert(entity)
                        addedCount += 1
                        print("➕ Automatisch hinzugefügt: '\(germanExercise.name)'")
                    }
                }

                // Save changes
                try context.save()

                await MainActor.run {
                    // Markiere als abgeschlossen
                    self.exercisesTranslatedToGerman = true

                    print("✅ Automatische Deutsche Übersetzung abgeschlossen!")
                    print("   - \(updatedCount) Übungen auf Deutsch aktualisiert")
                    print("   - \(addedCount) neue Übungen hinzugefügt")
                    print("   - Translation-Flag gesetzt: Diese Aktion wird nicht wiederholt")

                    // Trigger UI refresh
                    self.invalidateCaches()
                    self.objectWillChange.send()
                }

            } catch {
                print("❌ Fehler bei der automatischen deutschen Übersetzung: \(error)")
            }
        }
    }

    // MARK: - Complete App Reset
    func resetAllData() async throws {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim kompletten Reset")
            return
        }

        do {
            // Stop any active timers and sessions
            stopRest()
            activeSessionID = nil
            WorkoutLiveActivityController.shared.end()

            // Fetch and delete all entities
            let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
            let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            let profiles = try context.fetch(FetchDescriptor<UserProfileEntity>())

            // Delete all data
            for workout in workouts {
                context.delete(workout)
            }
            for session in sessions {
                context.delete(session)
            }
            for exercise in exercises {
                context.delete(exercise)
            }
            for profile in profiles {
                context.delete(profile)
            }

            // Clear all caches
            invalidateCaches()

            // Save the empty context
            try context.save()

            // Reset published properties to defaults
            restTimerStateManager.cancelRest()
            weeklyGoal = 5
            restNotificationsEnabled = true
            exercisesTranslatedToGerman = false  // Reset translation flag
            profileUpdateTrigger = UUID()

            print("✅ Alle App-Daten erfolgreich gelöscht")

        } catch {
            print("❌ Fehler beim kompletten Reset: \(error)")
            throw error
        }
    }

    // MARK: - Debug Helper
    func debugState() {
        print("=== WorkoutStore Debug ===")
        print("ModelContext: \(modelContext != nil ? "✅ Gesetzt" : "❌ Nil")")
        print("Active Session ID: \(activeSessionID?.uuidString ?? "Keine")")
        if let context = modelContext {
            do {
                let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
                let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())

                print("Gespeicherte Workouts: \(workouts.count)")
                for workout in workouts.prefix(5) {
                    print(
                        "  - \(workout.name) (ID: \(workout.id.uuidString.prefix(8)), Übungen: \(workout.exercises.count))"
                    )
                }

                print("Gespeicherte Übungen: \(exercises.count)")
                for exercise in exercises.prefix(10) {
                    print("  - \(exercise.name) (ID: \(exercise.id.uuidString.prefix(8)))")
                }

                print("Sessions: \(sessions.count)")
                for session in sessions.prefix(3) {
                    print(
                        "  - \(session.name) (Datum: \(session.date.formatted(.dateTime.day().month())))"
                    )
                }
            } catch {
                print("❌ Fehler beim Abrufen der Debug-Daten: \(error)")
            }
        }
        print("========================")
    }


    // MARK: - Phase 8: Automatic Migration on App Start

    /// AppStorage Flag um zu verfolgen ob die Markdown-Migration bereits durchgeführt wurde
    @AppStorage("markdownExercisesMigrationCompleted") private
        var markdownExercisesMigrationCompleted: Bool = false

    // MARK: - Phase 9: UI State for Migration

    /// Status der automatischen Migration für UI-Feedback
    enum MigrationStatus {
        case notStarted
        case parsing
        case deletingOld
        case addingNew
        case saving
        case completed
        case error(String)

        var displayText: String {
            switch self {
            case .notStarted:
                return "Migration wird vorbereitet..."
            case .parsing:
                return "Lade neue Übungen aus Datenbank..."
            case .deletingOld:
                return "Entferne alte Übungen..."
            case .addingNew:
                return "Füge neue Übungen hinzu..."
            case .saving:
                return "Speichere Änderungen..."
            case .completed:
                return "Migration abgeschlossen!"
            case .error(let message):
                return "Fehler: \(message)"
            }
        }

        var isCompleted: Bool {
            switch self {
            case .completed, .error:
                return true
            default:
                return false
            }
        }

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    /// Aktueller Status der Migration für UI-Binding
    @Published var migrationStatus: MigrationStatus = .notStarted

    /// Ob Migration aktuell läuft
    @Published var isMigrationInProgress: Bool = false

    /// Fortschritt der Migration (0.0 - 1.0)
    @Published var migrationProgress: Double = 0.0

    /// Prüft beim App-Start ob eine automatische Migration durchgeführt werden soll
    /// Diese Funktion wird automatisch aufgerufen wenn modelContext gesetzt wird
    private func checkAndPerformAutomaticMigration(context: ModelContext) {
        // Nur ausführen wenn Migration noch nicht durchgeführt wurde
        guard !markdownExercisesMigrationCompleted else {
            print("✅ Markdown-Migration bereits durchgeführt - überspringe automatische Migration")
            return
        }

        print("🚀 Starte automatische Markdown-Migration beim App-Start...")

        // Phase 9: UI-Status Updates
        isMigrationInProgress = true
        migrationStatus = .parsing
        migrationProgress = 0.0

        Task { [weak self] in
            guard let self = self else { return }

            do {
                // Phase 9.1: Parsing (20% Progress)
                await MainActor.run {
                    self.migrationStatus = .parsing
                    self.migrationProgress = 0.2
                }

                // Prüfe ob bereits Übungen vorhanden sind
                let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                print("📊 Gefundene bestehende Übungen: \(existingExercises.count)")

                // Parse neue Übungen aus Markdown
                let newExercises = ExerciseMarkdownParser.parseCompleteExerciseList()
                print("📖 Neue Übungen aus Markdown: \(newExercises.count)")

                if newExercises.isEmpty {
                    print("⚠️ Keine Übungen aus Markdown geparst - setze Flag trotzdem")
                    await MainActor.run {
                        self.markdownExercisesMigrationCompleted = true
                        self.migrationStatus = .error("Keine Übungen gefunden")
                        self.isMigrationInProgress = false
                    }
                    return
                }

                // Phase 9.2: Lösche alte Übungen (40% Progress)
                await MainActor.run {
                    self.migrationStatus = .deletingOld
                    self.migrationProgress = 0.4
                }

                if !existingExercises.isEmpty {
                    print("🗑️ Lösche \(existingExercises.count) bestehende Übungen...")
                    for exercise in existingExercises {
                        context.delete(exercise)
                    }
                    try context.save()
                    print("✅ Bestehende Übungen gelöscht")
                }

                // Phase 9.3: Füge neue Übungen hinzu (70% Progress)
                await MainActor.run {
                    self.migrationStatus = .addingNew
                    self.migrationProgress = 0.7
                }

                print("➕ Füge \(newExercises.count) neue Übungen hinzu...")
                for exercise in newExercises {
                    let entity = ExerciseEntity.make(from: exercise)
                    context.insert(entity)
                }

                // Phase 9.4: Speichere (90% Progress)
                await MainActor.run {
                    self.migrationStatus = .saving
                    self.migrationProgress = 0.9
                }

                try context.save()

                // Phase 9.5: Abgeschlossen (100% Progress)
                await MainActor.run {
                    // Setze Migration-Flag
                    self.markdownExercisesMigrationCompleted = true

                    // Cache invalidieren
                    self.invalidateCaches()
                    self.objectWillChange.send()

                    // UI-Status Updates
                    self.migrationStatus = .completed
                    self.migrationProgress = 1.0
                    self.isMigrationInProgress = false

                    print("🎉 Automatische Markdown-Migration erfolgreich abgeschlossen!")
                    print("   📊 Neue Übungen: \(newExercises.count)")
                    print("   🏁 Migration-Flag gesetzt - wird nicht mehr wiederholt")

                    // Zeige kurze Statistik
                    let byEquipment = Dictionary(grouping: newExercises) { $0.equipmentType }
                    for (equipment, exs) in byEquipment.sorted(by: {
                        $0.key.rawValue < $1.key.rawValue
                    }) {
                        print("   🏋️ \(equipment.rawValue): \(exs.count)")
                    }
                }

            } catch {
                print("❌ Fehler bei automatischer Migration: \(error)")

                await MainActor.run {
                    // Setze Flag trotzdem, um Endlosschleife zu vermeiden
                    self.markdownExercisesMigrationCompleted = true

                    // UI-Status Updates
                    self.migrationStatus = .error(error.localizedDescription)
                    self.isMigrationInProgress = false
                    self.migrationProgress = 0.0
                }
            }
        }
    }

    /// Setzt das Migration-Flag zurück (nur für Debugging/Testing)
    func resetMigrationFlag() {
        print("🔄 Setze Migration-Flag zurück - Migration wird beim nächsten App-Start wiederholt")
        markdownExercisesMigrationCompleted = false
    }

}

// MARK: - Analytics Helpers

extension WorkoutStore {
    var totalWorkoutCount: Int {
        analyticsService.totalWorkoutCount()
    }

    var averageWorkoutsPerWeek: Double {
        analyticsService.averageWorkoutsPerWeek()
    }

    var currentWeekStreak: Int {
        analyticsService.currentWeekStreak()
    }

    var averageDurationMinutes: Int {
        analyticsService.averageDurationMinutes()
    }

    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)] {
        analyticsService.muscleVolume(byGroupInLastWeeks: weeks)
    }

    func exerciseStats(for exercise: Exercise) -> ExerciseStats? {
        analyticsService.exerciseStats(for: exercise)
    }

    func workoutsByDay(in range: ClosedRange<Date>) -> [Date: [WorkoutSession]] {
        analyticsService.workoutsByDay(in: range)
    }

    // MARK: - Workout Generation (Delegated to WorkoutGenerationService)

    func generateWorkout(from preferences: WorkoutPreferences) -> Workout {
        let exercises = dataService.exercises()
        do {
            return try generationService.generateWorkout(from: preferences, using: exercises)
        } catch {
            print("⚠️ Fehler bei Workout-Generierung: \(error.localizedDescription)")
            // Fallback: Minimales Workout zurückgeben
            return Workout(
                name: "Fehler beim Generieren",
                exercises: [],
                defaultRestTime: 90,
                notes: "Fehler: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Heart Rate Tracking

    private func startHeartRateTracking(workoutId: UUID, workoutName: String) {
        // Prüfe ob HealthKit verfügbar und autorisiert ist
        guard HKHealthStore.isHealthDataAvailable() else {
            AppLogger.health.info(
                "[WorkoutStore] HealthKit nicht verfügbar - kein Herzfrequenz-Tracking")
            return
        }

        let healthStore = HKHealthStore()
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let status = healthStore.authorizationStatus(for: heartRateType)
        guard status == .sharingAuthorized else {
            AppLogger.health.info("[WorkoutStore] Keine HealthKit-Berechtigung für Herzfrequenz")
            return
        }

        // Erstelle und starte Tracker
        let tracker = HealthKitWorkoutTracker()
        tracker.onHeartRateUpdate = { [weak self] heartRate in
            guard let self = self else { return }
            // Memory: Use weak self in nested Task to prevent retain cycle
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Update Live Activity mit neuer Herzfrequenz
                WorkoutLiveActivityController.shared.updateHeartRate(
                    workoutId: workoutId,
                    workoutName: workoutName,
                    heartRate: heartRate
                )
            }
        }

        self.heartRateTracker = tracker
        tracker.startTracking()

        AppLogger.health.info("[WorkoutStore] Herzfrequenz-Tracking gestartet für '\(workoutName)'")
    }

    private func stopHeartRateTracking() {
        guard let tracker = heartRateTracker else { return }

        tracker.stopTracking()
        heartRateTracker = nil

        AppLogger.health.info("[WorkoutStore] Herzfrequenz-Tracking gestoppt")
    }

    // MARK: - Memory Management

    /// Memory: Force cleanup of caches and timers
    /// Call this when app enters background or memory warning occurs
    func performMemoryCleanup() {
        print("[Memory] 🧹 Performing WorkoutStore cleanup")

        // Clear caches
        analyticsService.invalidateCaches()

        // Stop rest timer if no active session
        if activeSessionID == nil {
            restTimerStateManager.cancelRest()
        }

        print("[Memory] ✅ WorkoutStore cleanup completed")
    }

}

// MARK: - Notification Extensions
extension Notification.Name {
    static let profileUpdatedFromHealthKit = Notification.Name("profileUpdatedFromHealthKit")
}

// MARK: - WorkoutStoreCoordinator (Phase 2 Migration)

/// Type alias for backward compatibility during migration
/// All views can use either WorkoutStore or WorkoutStoreCoordinator
typealias WorkoutStoreProtocol = WorkoutStoreCoordinator

/// Koordinator der alle WorkoutStore-Services zusammenführt und als zentrale Schnittstelle dient.
/// In Phase 2: Einfacher Wrapper um WorkoutStore für schrittweise Migration
@MainActor
class WorkoutStoreCoordinator: ObservableObject {

    // MARK: - Legacy Store (Phase 2: Kompletter Fallback)

    private let legacyStore: WorkoutStore

    // MARK: - Published Properties (Synced with legacyStore)

    @Published var activeSessionID: UUID?
    @Published var isShowingWorkoutDetail: Bool = false

    var modelContext: ModelContext? {
        get { legacyStore.modelContext }
        set { legacyStore.modelContext = newValue }
    }

    var overlayManager: InAppOverlayManager? {
        get { legacyStore.overlayManager }
        set { legacyStore.overlayManager = newValue }
    }

    var restTimerStateManager: RestTimerStateManager {
        legacyStore.restTimerStateManager
    }

    // MARK: - Computed Properties

    var exercises: [Exercise] {
        legacyStore.exercises
    }

    var workouts: [Workout] {
        legacyStore.workouts
    }

    var activeWorkout: Workout? {
        legacyStore.activeWorkout
    }

    var homeWorkouts: [Workout] {
        legacyStore.homeWorkouts
    }

    var userProfile: UserProfile {
        legacyStore.userProfile
    }

    var profileUpdateTrigger: UUID {
        get { legacyStore.profileUpdateTrigger }
        set { legacyStore.profileUpdateTrigger = newValue }
    }

    var healthKitManager: HealthKitManager {
        legacyStore.healthKitManager
    }

    var totalWorkoutCount: Int {
        legacyStore.totalWorkoutCount
    }

    var averageWorkoutsPerWeek: Double {
        legacyStore.averageWorkoutsPerWeek
    }

    var currentWeekStreak: Int {
        legacyStore.currentWeekStreak
    }

    var averageDurationMinutes: Int {
        legacyStore.averageDurationMinutes
    }

    // AppStorage properties - forward to legacyStore
    var weeklyGoal: Int {
        get { legacyStore.weeklyGoal }
        set { legacyStore.weeklyGoal = newValue }
    }

    // MARK: - Initialization

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.legacyStore = WorkoutStore()

        // Sync published properties from legacyStore to coordinator (one-way only)
        legacyStore.$activeSessionID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.activeSessionID = newValue
            }
            .store(in: &cancellables)

        legacyStore.$isShowingWorkoutDetail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isShowingWorkoutDetail = newValue
            }
            .store(in: &cancellables)
    }

    // MARK: - Exercise Methods

    func exercise(named name: String) -> Exercise {
        legacyStore.exercise(named: name)
    }

    func getSimilarExercises(
        to exercise: Exercise, count: Int = 10, userLevel: ExperienceLevel? = nil
    ) -> [Exercise] {
        legacyStore.getSimilarExercises(to: exercise, count: count, userLevel: userLevel)
    }

    func addExercise(_ exercise: Exercise) {
        legacyStore.addExercise(exercise)
    }

    func updateExercise(_ exercise: Exercise) {
        legacyStore.updateExercise(exercise)
    }

    func deleteExercise(at indexSet: IndexSet) {
        legacyStore.deleteExercise(at: indexSet)
    }

    // MARK: - Workout Methods

    func addWorkout(_ workout: Workout) {
        legacyStore.addWorkout(workout)
    }

    func updateWorkout(_ workout: Workout) {
        legacyStore.updateWorkout(workout)
    }

    func deleteWorkout(at indexSet: IndexSet) {
        legacyStore.deleteWorkout(at: indexSet)
    }

    func toggleFavorite(for workoutID: UUID) {
        legacyStore.toggleFavorite(for: workoutID)
    }

    func toggleHomeFavorite(workoutID: UUID) -> Bool {
        legacyStore.toggleHomeFavorite(workoutID: workoutID)
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        legacyStore.previousWorkout(before: workout)
    }

    // MARK: - Session Methods

    func startSession(for workoutId: UUID) {
        legacyStore.startSession(for: workoutId)
    }

    func endCurrentSession() {
        legacyStore.endCurrentSession()
    }

    func recordSession(from workout: Workout) {
        legacyStore.recordSession(from: workout)
    }

    func removeSession(with id: UUID) {
        legacyStore.removeSession(with: id)
    }

    func getSessionHistory() -> [WorkoutSession] {
        legacyStore.getSessionHistory()
    }

    // MARK: - Profile Methods

    func updateProfile(
        name: String, birthDate: Date?, weight: Double?, height: Double? = nil,
        biologicalSex: HKBiologicalSex? = nil, goal: FitnessGoal, experience: ExperienceLevel,
        equipment: EquipmentPreference, preferredDuration: WorkoutDuration,
        healthKitSyncEnabled: Bool = false, profileImageData: Data? = nil
    ) {
        legacyStore.updateProfile(
            name: name, birthDate: birthDate, weight: weight, height: height,
            biologicalSex: biologicalSex, goal: goal, experience: experience, equipment: equipment,
            preferredDuration: preferredDuration, healthKitSyncEnabled: healthKitSyncEnabled,
            profileImageData: profileImageData)
    }

    #if canImport(UIKit)
        func updateProfileImage(_ image: UIImage?) {
            legacyStore.updateProfileImage(image)
        }
    #endif

    func updateLockerNumber(_ lockerNumber: String) {
        legacyStore.updateLockerNumber(lockerNumber)
    }

    func markOnboardingStep(
        hasExploredWorkouts: Bool? = nil, hasCreatedFirstWorkout: Bool? = nil,
        hasSetupProfile: Bool? = nil
    ) {
        legacyStore.markOnboardingStep(
            hasExploredWorkouts: hasExploredWorkouts,
            hasCreatedFirstWorkout: hasCreatedFirstWorkout, hasSetupProfile: hasSetupProfile)
    }

    // MARK: - HealthKit Methods

    func requestHealthKitAuthorization() async throws {
        try await legacyStore.requestHealthKitAuthorization()
    }

    func importFromHealthKit() async throws {
        try await legacyStore.importFromHealthKit()
    }

    func readHeartRateData(from startDate: Date, to endDate: Date) async throws
        -> [HeartRateReading]
    {
        try await legacyStore.readHeartRateData(from: startDate, to: endDate)
    }

    func readWeightData(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading]
    {
        try await legacyStore.readWeightData(from: startDate, to: endDate)
    }

    func readBodyFatData(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading] {
        try await legacyStore.readBodyFatData(from: startDate, to: endDate)
    }

    // MARK: - Rest Timer Methods

    func startRest(for workout: Workout, exerciseIndex: Int, setIndex: Int, totalSeconds: Int) {
        legacyStore.startRest(
            for: workout, exerciseIndex: exerciseIndex, setIndex: setIndex,
            totalSeconds: totalSeconds)
    }

    func pauseRest() {
        legacyStore.pauseRest()
    }

    func resumeRest() {
        legacyStore.resumeRest()
    }

    func addRest(seconds: Int) {
        legacyStore.addRest(seconds: seconds)
    }

    func setRest(remaining: Int, total: Int? = nil) {
        legacyStore.setRest(remaining: remaining, total: total)
    }

    func stopRest() {
        legacyStore.stopRest()
    }

    func clearRestState() {
        legacyStore.clearRestState()
    }

    func performMemoryCleanup() {
        legacyStore.performMemoryCleanup()
    }

    // MARK: - Analytics Methods

    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)] {
        legacyStore.muscleVolume(byGroupInLastWeeks: weeks)
    }

    func exerciseStats(for exercise: Exercise) -> WorkoutStore.ExerciseStats? {
        legacyStore.exerciseStats(for: exercise)
    }

    func workoutsByDay(in range: ClosedRange<Date>) -> [Date: [WorkoutSession]] {
        legacyStore.workoutsByDay(in: range)
    }

    func getExerciseStats(exerciseId: UUID) -> WorkoutStore.ExerciseStats? {
        // Find the exercise first
        guard let exercise = legacyStore.exercises.first(where: { $0.id == exerciseId }) else {
            return nil
        }
        // Use the public exerciseStats method
        return legacyStore.exerciseStats(for: exercise)
    }

    // MARK: - Workout Generation

    func generateWorkout(from preferences: WorkoutPreferences) -> Workout {
        legacyStore.generateWorkout(from: preferences)
    }

    // MARK: - Exercise Records

    func getExerciseRecord(for exercise: Exercise) -> ExerciseRecord? {
        legacyStore.getExerciseRecord(for: exercise)
    }

    func getAllExerciseRecords() -> [ExerciseRecord] {
        legacyStore.getAllExerciseRecords()
    }

    func checkForNewRecord(exercise: Exercise, weight: Double, reps: Int) -> RecordType? {
        legacyStore.checkForNewRecord(exercise: exercise, weight: weight, reps: reps)
    }

    // MARK: - Last Used Metrics

    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        legacyStore.lastMetrics(for: exercise)
    }

    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics? {
        legacyStore.completeLastMetrics(for: exercise)
    }

    // MARK: - Cache Management

    func invalidateCaches() {
        legacyStore.invalidateCaches()
    }

    // MARK: - Database Management

    func updateExerciseDatabase() {
        legacyStore.updateExerciseDatabase()
    }

    func resetAllData() async throws {
        try await legacyStore.resetAllData()
    }
}
