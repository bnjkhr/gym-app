import Combine
import Foundation
import HealthKit
import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Supporting Structures

/// Struktur für Last-Used Metriken einer Übung
struct ExerciseLastUsedMetrics {
    let weight: Double?
    let reps: Int?
    let setCount: Int?
    let lastUsedDate: Date?
    let restTime: TimeInterval?

    var hasData: Bool {
        weight != nil && reps != nil
    }

    var displayText: String {
        guard let weight = weight, let reps = reps else {
            return "Keine vorherigen Daten"
        }
        return "Letztes Mal: \(weight.formatted())kg × \(reps) Wdh."
    }

    var detailedDisplayText: String {
        guard hasData else { return "Keine vorherigen Daten" }

        var parts: [String] = []

        if let weight = weight, let reps = reps {
            parts.append("\(weight.formatted())kg × \(reps) Wdh.")
        }

        if let setCount = setCount {
            parts.append("\(setCount) Sätze")
        }

        if let date = lastUsedDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            parts.append("am \(formatter.string(from: date))")
        }

        return parts.joined(separator: " • ")
    }
}

@MainActor
class WorkoutStore: ObservableObject {
    @Published var activeSessionID: UUID?
    @Published var isShowingWorkoutDetail: Bool = false

    // MARK: - Phase 2 Integration

    /// Rest timer state manager (Phase 1 - New System)
    var restTimerStateManager: RestTimerStateManager?

    /// In-app overlay manager (Phase 2)
    weak var overlayManager: InAppOverlayManager?

    // Zentrale Rest-Timer-State
    // Performance: Equatable to prevent unnecessary UI updates
    struct ActiveRestState: Equatable, Codable {
        let workoutId: UUID
        let workoutName: String
        let exerciseIndex: Int
        let setIndex: Int
        var remainingSeconds: Int
        var totalSeconds: Int
        var isRunning: Bool
        var endDate: Date?

        // Performance: Only trigger updates when meaningful changes occur
        static func == (lhs: ActiveRestState, rhs: ActiveRestState) -> Bool {
            lhs.workoutId == rhs.workoutId && lhs.exerciseIndex == rhs.exerciseIndex
                && lhs.setIndex == rhs.setIndex && lhs.remainingSeconds == rhs.remainingSeconds
                && lhs.isRunning == rhs.isRunning
            // Note: Deliberately ignore endDate and compare remainingSeconds instead
        }
    }

    // Performance: Custom publisher to avoid unnecessary updates
    // Only publishes when actual state changes, not every second
    @Published private(set) var activeRestState: ActiveRestState?

    @Published var profileUpdateTrigger: UUID = UUID()  // Triggers UI updates when profile changes

    // Herzfrequenz-Tracking
    private var heartRateTracker: HealthKitWorkoutTracker?

    private var restTimer: Timer?
    private var exerciseStatsCache: [UUID: ExerciseStats] = [:]
    private var weekStreakCache: (date: Date, value: Int)?
    @AppStorage("weeklyGoal") var weeklyGoal: Int = 5
    @AppStorage("restNotificationsEnabled") var restNotificationsEnabled: Bool = true
    @AppStorage("exercisesTranslatedToGerman") private var exercisesTranslatedToGerman: Bool = false

    // SwiftData context reference (wird von ContentView gesetzt)
    var modelContext: ModelContext? {
        didSet {
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
        guard let activeSessionID, let context = modelContext else {
            return nil
        }

        do {
            let descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate<WorkoutEntity> { $0.id == activeSessionID })
            if let entity = try context.fetch(descriptor).first {
                return mapWorkoutEntity(entity)
            } else {
                print("⚠️ Aktives Workout mit ID \(activeSessionID) nicht gefunden")
                // Clear the invalid activeSessionID
                self.activeSessionID = nil
                WorkoutLiveActivityController.shared.end()
                return nil
            }
        } catch {
            print("❌ Fehler beim Laden des aktiven Workouts: \(error)")
            return nil
        }
    }

    var homeWorkouts: [Workout] {
        guard let context = modelContext else { return [] }

        do {
            // Performance: Optimize favorites query
            var descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate<WorkoutEntity> { $0.isFavorite == true },
                sortBy: [SortDescriptor(\.name)]
            )
            descriptor.fetchLimit = 50  // Reasonable limit for home screen
            descriptor.includePendingChanges = false
            let entities = try context.fetch(descriptor)
            return entities.map { mapWorkoutEntity($0) }
        } catch {
            print("❌ Fehler beim Laden der Home-Favoriten: \(error)")
            return []
        }
    }

    var userProfile: UserProfile {
        guard let context = modelContext else {
            // Fallback: Load from UserDefaults if SwiftData isn't available
            return ProfilePersistenceHelper.loadFromUserDefaults()
        }

        do {
            let descriptor = FetchDescriptor<UserProfileEntity>()
            if let entity = try context.fetch(descriptor).first {
                let profile = UserProfile(entity: entity)
                ProfilePersistenceHelper.saveToUserDefaults(profile)
                return profile
            }
        } catch {
            print("⚠️ Fehler beim Laden des Profils aus SwiftData: \(error)")
            return ProfilePersistenceHelper.loadFromUserDefaults()
        }

        // Try to restore from UserDefaults backup
        let backupProfile = ProfilePersistenceHelper.loadFromUserDefaults()
        if !backupProfile.name.isEmpty || backupProfile.weight != nil {
            // Restore to SwiftData - pass profileImageData to prevent recursion
            updateProfile(
                name: backupProfile.name,
                birthDate: backupProfile.birthDate,
                weight: backupProfile.weight,
                height: backupProfile.height,
                biologicalSex: backupProfile.biologicalSex,
                goal: backupProfile.goal,
                experience: backupProfile.experience,
                equipment: backupProfile.equipment,
                preferredDuration: backupProfile.preferredDuration,
                healthKitSyncEnabled: backupProfile.healthKitSyncEnabled,
                profileImageData: backupProfile.profileImageData
            )
            print("✅ Profil aus UserDefaults-Backup wiederhergestellt")
            return backupProfile
        }

        return UserProfile()
    }

    // MARK: - Active Session Management

    init() {
        // Initialize the new rest timer state manager (Phase 1+2)
        let manager = RestTimerStateManager()
        self.restTimerStateManager = manager

        // overlayManager will be set later by ContentView.onAppear
    }

    deinit {
        // Ensure proper cleanup to prevent crashes
        restTimer?.invalidate()
        restTimer = nil
        NotificationManager.shared.cancelRestEndNotification()

        // Note: Can't access @Published properties in deinit due to main actor isolation
        // The WorkoutLiveActivityController will handle cleanup when the rest state is cleared elsewhere
    }

    func startSession(for workoutId: UUID) {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Starten einer Session")
            return
        }

        // Verify workout exists and reset its sets
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { $0.id == workoutId }
        )

        do {
            if let workout = try context.fetch(descriptor).first {
                // Reset all sets as not completed and update the date
                workout.date = Date()
                workout.duration = nil

                // Sort exercises by order to maintain correct sequence
                let sortedExercises = workout.exercises.sorted { $0.order < $1.order }
                for exercise in sortedExercises {
                    for set in exercise.sets {
                        set.completed = false
                    }
                }

                try context.save()
                activeSessionID = workoutId

                // Persistiere Workout-State für Wiederherstellung nach Force Quit
                UserDefaults.standard.set(workoutId.uuidString, forKey: "activeWorkoutID")
                print("✅ Session gestartet für Workout: \(workout.name)")

                // Starte Herzfrequenz-Tracking
                startHeartRateTracking(workoutId: workoutId, workoutName: workout.name)
            } else {
                print("❌ Workout mit ID \(workoutId) nicht gefunden")
            }
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
        getExercises()
    }

    var workouts: [Workout] {
        getWorkouts()
    }

    private func getWorkouts() -> [Workout] {
        guard let context = modelContext else {
            print("⚠️ WorkoutStore: ModelContext ist nil beim Abrufen von Workouts")
            return []
        }

        // Performance: Optimize query for large datasets
        var descriptor = FetchDescriptor<WorkoutEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        // Limit to most recent 200 workouts for initial load
        descriptor.fetchLimit = 200
        descriptor.includePendingChanges = false

        do {
            let entities = try context.fetch(descriptor)
            return entities.map { mapWorkoutEntity($0) }
        } catch {
            print("❌ Fehler beim Abrufen der Workouts: \(error)")
            return []
        }
    }

    private func mapExerciseEntity(_ entity: ExerciseEntity) -> Exercise {
        // Safely refetch by id from the current ModelContext to avoid invalid snapshot access
        let id = entity.id
        let name = entity.name
        let muscleGroupsRaw = entity.muscleGroupsRaw
        let equipmentTypeRaw = entity.equipmentTypeRaw
        let descriptionText = entity.descriptionText
        let instructions = entity.instructions
        let createdAt = entity.createdAt

        // Try to get a fresh reference if possible
        var source: ExerciseEntity? = entity
        if let context = modelContext {
            let descriptor = FetchDescriptor<ExerciseEntity>(predicate: #Predicate { $0.id == id })
            if let fresh = try? context.fetch(descriptor).first {
                source = fresh
            }
        }

        guard let validSource = source else {
            // Return a placeholder exercise to avoid crash
            return Exercise(
                id: UUID(),
                name: "Übung nicht verfügbar",
                muscleGroups: [],
                equipmentType: .mixed,
                description: "",
                instructions: [],
                createdAt: Date()
            )
        }

        let groups: [MuscleGroup] = validSource.muscleGroupsRaw.compactMap {
            MuscleGroup(rawValue: $0)
        }
        let equipmentType = EquipmentType(rawValue: validSource.equipmentTypeRaw) ?? .mixed
        let difficultyLevel = DifficultyLevel(rawValue: validSource.difficultyLevelRaw) ?? .anfänger

        return Exercise(
            id: validSource.id,
            name: validSource.name,
            muscleGroups: groups,
            equipmentType: equipmentType,
            difficultyLevel: difficultyLevel,
            description: validSource.descriptionText,
            instructions: validSource.instructions,
            createdAt: validSource.createdAt
        )
    }

    private func mapWorkoutEntity(_ entity: WorkoutEntity) -> Workout {
        // Sort exercises by order to maintain correct sequence
        let sortedExercises = entity.exercises.sorted { $0.order < $1.order }
        let exercises: [WorkoutExercise] = sortedExercises.compactMap { we in
            guard let exerciseEntity = we.exercise else { return nil }
            let ex = mapExerciseEntity(exerciseEntity)
            let sets: [ExerciseSet] = we.sets.map { set in
                ExerciseSet(
                    reps: set.reps,
                    weight: set.weight,
                    restTime: set.restTime,
                    completed: set.completed
                )
            }
            return WorkoutExercise(exercise: ex, sets: sets)
        }
        return Workout(
            id: entity.id,
            name: entity.name,
            date: entity.date,
            exercises: exercises,
            defaultRestTime: entity.defaultRestTime,
            duration: entity.duration,
            notes: entity.notes,
            isFavorite: entity.isFavorite
        )
    }

    private func getExercises() -> [Exercise] {
        guard let context = modelContext else { return [] }
        // Performance: Limit query results and disable pending changes tracking
        var descriptor = FetchDescriptor<ExerciseEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        // No fetchLimit here - we need all exercises for filtering
        // But we optimize by not tracking pending changes
        descriptor.includePendingChanges = false
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { mapExerciseEntity($0) }
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
        let allExercises = getExercises()

        // Filtere die aktuelle Übung aus und nur Übungen mit gemeinsamen Muskelgruppen
        let candidates = allExercises.filter { candidate in
            candidate.id != exercise.id && exercise.hasSimilarMuscleGroups(to: candidate)
        }

        // Berechne Similarity-Scores für alle Kandidaten
        let scoredExercises = candidates.compactMap {
            candidate -> (exercise: Exercise, score: Int, matchesLevel: Bool, sharesPrimary: Bool)?
            in
            let score = exercise.similarityScore(to: candidate)
            guard score > 0 else { return nil }

            let matchesLevel =
                userLevel != nil ? matchesDifficultyLevel(candidate, for: userLevel!) : true
            let sharesPrimary = exercise.sharesPrimaryMuscleGroup(with: candidate)
            return (candidate, score, matchesLevel, sharesPrimary)
        }

        // Sortiere nach:
        // 1. Gleiche primäre Muskelgruppe (wichtig!)
        // 2. Passendes Level
        // 3. Similarity Score
        let sorted = scoredExercises.sorted { first, second in
            // Bevorzuge gleiche primäre Muskelgruppe
            if first.sharesPrimary && !second.sharesPrimary {
                return true
            }
            if !first.sharesPrimary && second.sharesPrimary {
                return false
            }

            // Wenn ein userLevel angegeben ist, bevorzuge passende Level
            if userLevel != nil {
                if first.matchesLevel && !second.matchesLevel {
                    return true
                }
                if !first.matchesLevel && second.matchesLevel {
                    return false
                }
            }

            return first.score > second.score
        }

        // Nimm die Top N Übungen
        return Array(sorted.prefix(count).map { $0.exercise })
    }

    private func getSessionHistory() -> [WorkoutSession] {
        guard let context = modelContext else { return [] }
        // Performance: Limit session history to recent 100 sessions
        var descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        descriptor.includePendingChanges = false
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { WorkoutSession(entity: $0) }
    }

    private func getHomeFavoritesCount() -> Int {
        guard let context = modelContext else { return 0 }

        do {
            let descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate<WorkoutEntity> { $0.isFavorite == true }
            )
            let entities = try context.fetch(descriptor)
            return entities.count
        } catch {
            print("❌ Fehler beim Zählen der Home-Favoriten: \(error)")
            return 0
        }
    }

    func addExercise(_ exercise: Exercise) {
        guard let context = modelContext else { return }

        // Check if exercise already exists by ID first
        let idDescriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
        )

        if (try? context.fetch(idDescriptor).first) != nil {
            return  // Exercise already exists
        }

        // Check by name using case-insensitive comparison
        let nameDescriptor = FetchDescriptor<ExerciseEntity>()
        let allExercises = (try? context.fetch(nameDescriptor)) ?? []

        if allExercises.contains(where: {
            $0.name.localizedCaseInsensitiveCompare(exercise.name) == .orderedSame
        }) {
            return  // Exercise with same name already exists
        }

        let entity = ExerciseEntity.make(from: exercise)
        context.insert(entity)
        try? context.save()
        invalidateCaches()
    }

    func updateExercise(_ exercise: Exercise) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
        )

        guard let entity = try? context.fetch(descriptor).first else { return }

        entity.name = exercise.name
        entity.muscleGroupsRaw = exercise.muscleGroups.map { $0.rawValue }
        entity.equipmentTypeRaw = exercise.equipmentType.rawValue
        entity.difficultyLevelRaw = exercise.difficultyLevel.rawValue
        entity.descriptionText = exercise.description
        entity.instructions = exercise.instructions

        try? context.save()

        // Invalidate cache for this exercise id
        exerciseStatsCache[exercise.id] = nil
    }

    func addWorkout(_ workout: Workout) {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Speichern eines Workouts")
            return
        }

        do {
            try DataManager.shared.saveWorkout(workout, to: context)
            print("✅ Workout erfolgreich gespeichert: \(workout.name)")
        } catch {
            print("❌ Fehler beim Speichern des Workouts: \(error)")
        }
    }

    func updateWorkout(_ workout: Workout) {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Aktualisieren eines Workouts")
            return
        }

        do {
            try DataManager.shared.saveWorkout(workout, to: context)
            print("✅ Workout erfolgreich aktualisiert: \(workout.name)")
        } catch {
            print("❌ Fehler beim Aktualisieren des Workouts: \(error)")
        }
    }

    func exercise(named name: String) -> Exercise {
        guard let context = modelContext else {
            return Exercise(name: name, muscleGroups: [], equipmentType: .mixed, description: "")
        }

        // Fetch all exercises and find by case-insensitive name comparison
        let descriptor = FetchDescriptor<ExerciseEntity>()
        let allExercises = (try? context.fetch(descriptor)) ?? []

        if let existing = allExercises.first(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return mapExerciseEntity(existing)
        }

        let newExercise = Exercise(
            name: name, muscleGroups: [], equipmentType: .mixed, description: "")
        let entity = ExerciseEntity.make(from: newExercise)
        context.insert(entity)
        try? context.save()
        return newExercise
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        let sessionHistory = getSessionHistory()
        return
            sessionHistory
            .filter { $0.templateId == workout.id }
            .sorted { $0.date > $1.date }
            .first
            .map(Workout.init(session:))
    }

    /// Vereinfachte lastMetrics Funktion - nutzt jetzt die gespeicherten Werte für bessere Performance
    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
        )

        guard let exerciseEntity = try? context.fetch(descriptor).first,
            let weight = exerciseEntity.lastUsedWeight,
            let setCount = exerciseEntity.lastUsedSetCount
        else {
            // Fallback: alte Methode als Backup
            return legacyLastMetrics(for: exercise)
        }

        return (weight, setCount)
    }

    /// Erweiterte lastMetrics mit allen verfügbaren Infos
    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
        )

        guard let exerciseEntity = try? context.fetch(descriptor).first else { return nil }

        return ExerciseLastUsedMetrics(
            weight: exerciseEntity.lastUsedWeight,
            reps: exerciseEntity.lastUsedReps,
            setCount: exerciseEntity.lastUsedSetCount,
            lastUsedDate: exerciseEntity.lastUsedDate,
            restTime: exerciseEntity.lastUsedRestTime
        )
    }

    /// Legacy-Fallback Methode - iteriert durch Session-History (langsamer)
    private func legacyLastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        let sessionHistory = getSessionHistory()
        let sortedSessions = sessionHistory.sorted { $0.date > $1.date }

        for workout in sortedSessions {
            if let workoutExercise = workout.exercises.first(where: {
                $0.exercise.id == exercise.id
            }) {
                let setCount = max(workoutExercise.sets.count, 1)
                let weight = workoutExercise.sets.last?.weight ?? 0
                return (weight, setCount)
            }
        }

        return nil
    }

    func deleteExercise(at indexSet: IndexSet) {
        guard let context = modelContext else { return }
        let exercises = getExercises()
        let removedExercises = indexSet.map { exercises[$0] }

        for exercise in removedExercises {
            let descriptor = FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
            )

            if let entity = try? context.fetch(descriptor).first {
                context.delete(entity)
            }

            // Invalidate caches for removed exercise IDs
            exerciseStatsCache[exercise.id] = nil
        }

        try? context.save()
    }

    func deleteWorkout(at indexSet: IndexSet) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WorkoutEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []

        for index in indexSet {
            guard index < entities.count else { continue }
            context.delete(entities[index])
        }

        try? context.save()
    }

    func recordSession(from workout: Workout) {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Speichern einer Session")
            return
        }

        do {
            // Ensure exercises are sorted by order before recording session
            // Note: workout.exercises should already be sorted from mapWorkoutEntity,
            // but we sort again here to be absolutely certain
            let sortedExercises = workout.exercises  // Already sorted from UI

            let session = WorkoutSession(
                templateId: workout.id,
                name: workout.name,
                date: workout.date,
                exercises: sortedExercises,
                defaultRestTime: workout.defaultRestTime,
                duration: workout.duration,
                notes: workout.notes
            )

            let savedEntity = try DataManager.shared.recordSession(session, to: context)

            // 🆕 NEU: Update Last-Used Metrics für alle Übungen
            updateLastUsedMetrics(from: session)

            // Update ExerciseRecords with new personal bests
            // Memory: Capture only what's needed, not self
            Task {
                await ExerciseRecordMigration.updateRecords(from: savedEntity, context: context)
            }

            invalidateCaches()  // stats/streak may change
            print("✅ Workout-Session erfolgreich gespeichert: \(workout.name)")

            // Sync to HealthKit if enabled
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
        } catch {
            print("❌ Fehler beim Speichern der Workout-Session: \(error)")
        }
    }

    // MARK: - Last-Used Metrics Management

    /// Aktualisiert die "letzte Verwendung" Daten für alle Übungen in einem abgeschlossenen Workout
    private func updateLastUsedMetrics(from session: WorkoutSession) {
        guard let context = modelContext else { return }

        for workoutExercise in session.exercises {
            // Hole die ExerciseEntity frisch aus dem Context
            let descriptor = FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { $0.id == workoutExercise.exercise.id }
            )

            guard let exerciseEntity = try? context.fetch(descriptor).first else {
                print("⚠️ ExerciseEntity nicht gefunden für: \(workoutExercise.exercise.name)")
                continue
            }

            // Finde den letzten abgeschlossenen Satz
            let completedSets = workoutExercise.sets.filter { $0.completed }
            guard let lastSet = completedSets.last else {
                print("ℹ️ Keine abgeschlossenen Sätze für: \(workoutExercise.exercise.name)")
                continue
            }

            // Aktualisiere die Last-Used Werte nur wenn das neue Workout neuer ist
            if exerciseEntity.lastUsedDate == nil || session.date > exerciseEntity.lastUsedDate! {
                exerciseEntity.lastUsedWeight = lastSet.weight
                exerciseEntity.lastUsedReps = lastSet.reps
                exerciseEntity.lastUsedSetCount = completedSets.count
                exerciseEntity.lastUsedDate = session.date
                exerciseEntity.lastUsedRestTime = lastSet.restTime

                print(
                    "✅ Last-Used aktualisiert für \(exerciseEntity.name): \(lastSet.weight)kg × \(lastSet.reps)"
                )
            }
        }

        do {
            try context.save()
            print("✅ Alle Last-Used Metriken gespeichert")
        } catch {
            print("❌ Fehler beim Speichern der Last-Used Metriken: \(error)")
        }
    }

    func removeSession(with id: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate<WorkoutSessionEntity> { $0.id == id }
        )

        if let entity = try? context.fetch(descriptor).first {
            context.delete(entity)
            try? context.save()
        }

        invalidateCaches()
    }

    // MARK: - Profile Management
    func updateProfile(
        name: String, birthDate: Date?, weight: Double?, height: Double? = nil,
        biologicalSex: HKBiologicalSex? = nil, goal: FitnessGoal, experience: ExperienceLevel,
        equipment: EquipmentPreference, preferredDuration: WorkoutDuration,
        healthKitSyncEnabled: Bool = false, profileImageData: Data? = nil
    ) {
        // Preserve existing profile image if not provided
        let imageData =
            profileImageData ?? ProfilePersistenceHelper.loadFromUserDefaults().profileImageData

        // Create updated profile
        let updatedProfile = UserProfile(
            name: name,
            birthDate: birthDate,
            weight: weight,
            height: height,
            biologicalSex: biologicalSex,
            goal: goal,
            profileImageData: imageData,
            experience: experience,
            equipment: equipment,
            preferredDuration: preferredDuration,
            healthKitSyncEnabled: healthKitSyncEnabled
        )

        // Always save to UserDefaults as backup
        ProfilePersistenceHelper.saveToUserDefaults(updatedProfile)

        // Save to SwiftData if available
        if let context = modelContext {
            let descriptor = FetchDescriptor<UserProfileEntity>()

            let entity: UserProfileEntity
            if let existing = try? context.fetch(descriptor).first {
                entity = existing
            } else {
                entity = UserProfileEntity()
                context.insert(entity)
            }

            entity.name = name
            entity.birthDate = birthDate
            entity.weight = weight
            entity.height = height
            entity.biologicalSexRaw = Int16(
                biologicalSex?.rawValue ?? HKBiologicalSex.notSet.rawValue)
            entity.healthKitSyncEnabled = healthKitSyncEnabled
            entity.goalRaw = goal.rawValue
            entity.experienceRaw = experience.rawValue
            entity.equipmentRaw = equipment.rawValue
            entity.preferredDurationRaw = preferredDuration.rawValue
            entity.updatedAt = Date()

            try? context.save()
        }

        // Trigger UI update
        profileUpdateTrigger = UUID()
        print("✅ Profil gespeichert: \(name) - \(goal.displayName)")
    }

    func updateProfileImage(_ image: UIImage?) {
        // Create updated profile with new image
        var updatedProfile = userProfile
        updatedProfile.updateProfileImage(image)

        // Always save to UserDefaults as backup
        ProfilePersistenceHelper.saveToUserDefaults(updatedProfile)

        // Save to SwiftData if available
        if let context = modelContext {
            let descriptor = FetchDescriptor<UserProfileEntity>()

            let entity: UserProfileEntity
            if let existing = try? context.fetch(descriptor).first {
                entity = existing
            } else {
                entity = UserProfileEntity()
                context.insert(entity)
            }

            entity.profileImageData = image?.jpegData(compressionQuality: 0.8)
            entity.updatedAt = Date()

            try? context.save()
        }

        // Trigger UI update
        profileUpdateTrigger = UUID()
        print("✅ Profilbild gespeichert")
    }

    func updateLockerNumber(_ lockerNumber: String) {
        // Save to SwiftData if available
        if let context = modelContext {
            let descriptor = FetchDescriptor<UserProfileEntity>()

            let entity: UserProfileEntity
            if let existing = try? context.fetch(descriptor).first {
                entity = existing
            } else {
                entity = UserProfileEntity()
                context.insert(entity)
            }

            entity.lockerNumber = lockerNumber.isEmpty ? nil : lockerNumber
            entity.updatedAt = Date()

            try? context.save()

            // Save updated profile to UserDefaults as backup
            let updatedProfile = UserProfile(entity: entity)
            ProfilePersistenceHelper.saveToUserDefaults(updatedProfile)
        } else {
            // Fallback: Update UserDefaults directly
            var updatedProfile = userProfile
            updatedProfile.lockerNumber = lockerNumber.isEmpty ? nil : lockerNumber
            updatedProfile.updatedAt = Date()
            ProfilePersistenceHelper.saveToUserDefaults(updatedProfile)
        }

        // Trigger UI update
        profileUpdateTrigger = UUID()
        print("✅ Spintnummer gespeichert: \(lockerNumber)")
    }

    // MARK: - Onboarding Progress

    func markOnboardingStep(
        hasExploredWorkouts: Bool? = nil, hasCreatedFirstWorkout: Bool? = nil,
        hasSetupProfile: Bool? = nil
    ) {
        // Save to SwiftData if available
        if let context = modelContext {
            let descriptor = FetchDescriptor<UserProfileEntity>()

            let entity: UserProfileEntity
            if let existing = try? context.fetch(descriptor).first {
                entity = existing
            } else {
                entity = UserProfileEntity()
                context.insert(entity)
            }

            // Update entity
            if let hasExploredWorkouts = hasExploredWorkouts {
                entity.hasExploredWorkouts = hasExploredWorkouts
            }
            if let hasCreatedFirstWorkout = hasCreatedFirstWorkout {
                entity.hasCreatedFirstWorkout = hasCreatedFirstWorkout
            }
            if let hasSetupProfile = hasSetupProfile {
                entity.hasSetupProfile = hasSetupProfile
            }
            entity.updatedAt = Date()

            try? context.save()

            // Also save to UserDefaults as backup
            let updatedProfile = UserProfile(entity: entity)
            ProfilePersistenceHelper.saveToUserDefaults(updatedProfile)
        } else {
            // Fallback: Update UserDefaults directly
            var updatedProfile = userProfile

            if let hasExploredWorkouts = hasExploredWorkouts {
                updatedProfile.hasExploredWorkouts = hasExploredWorkouts
            }
            if let hasCreatedFirstWorkout = hasCreatedFirstWorkout {
                updatedProfile.hasCreatedFirstWorkout = hasCreatedFirstWorkout
            }
            if let hasSetupProfile = hasSetupProfile {
                updatedProfile.hasSetupProfile = hasSetupProfile
            }
            updatedProfile.updatedAt = Date()

            ProfilePersistenceHelper.saveToUserDefaults(updatedProfile)
        }

        // Trigger UI update
        profileUpdateTrigger = UUID()
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
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { $0.id == workoutID }
        )

        guard let entity = try? context.fetch(descriptor).first else { return }
        entity.isFavorite.toggle()
        try? context.save()
    }

    func toggleHomeFavorite(workoutID: UUID) -> Bool {
        guard let context = modelContext else { return false }

        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { $0.id == workoutID }
        )

        guard let entity = try? context.fetch(descriptor).first else { return false }

        // Check if we're trying to add to home favorites
        if !entity.isFavorite {
            // Adding to favorites - check 4-workout limit
            let currentCount = getHomeFavoritesCount()
            if currentCount >= 4 {
                print("⚠️ Home-Favoriten Limit erreicht: \(currentCount)/4")
                return false
            }
        }

        // Toggle the favorite status
        entity.isFavorite.toggle()

        do {
            try context.save()
            // Force SwiftData to process changes immediately
            context.processPendingChanges()
            let action = entity.isFavorite ? "hinzugefügt" : "entfernt"
            print("✅ Home-Favorit für Workout '\(entity.name)' \(action)")
            return true
        } catch {
            print("❌ Fehler beim Speichern des Home-Favoriten: \(error)")
            return false
        }
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

        // Use new RestTimerStateManager system (Phase 1+2)
        restTimerStateManager?.startRest(
            for: workout,
            exercise: exerciseIndex,
            set: setIndex,
            duration: totalSeconds,
            currentExerciseName: currentExerciseName,
            nextExerciseName: nextExerciseName
        )

        // Keep old system for backward compatibility (will be removed in Phase 5)
        let total = max(totalSeconds, 0)
        var state = ActiveRestState(
            workoutId: workout.id,
            workoutName: workout.name,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            remainingSeconds: total,
            totalSeconds: total,
            isRunning: total > 0,
            endDate: Date().addingTimeInterval(TimeInterval(total))
        )
        activeRestState = state
        persistRestState(state)
        setupRestTimer()
        updateLiveActivityRest()
    }

    func pauseRest() {
        guard var state = activeRestState else { return }
        state.isRunning = false
        state.endDate = nil  // Wichtig: endDate zurücksetzen beim Pausieren
        activeRestState = state
        restTimer?.invalidate()  // Timer stoppen
        restTimer = nil
        NotificationManager.shared.cancelRestEndNotification()
        updateLiveActivityRest()

        // Persistiere pausierter State
        persistRestState(state)
    }

    func resumeRest() {
        guard var state = activeRestState, state.remainingSeconds > 0 else { return }
        state.isRunning = true
        state.endDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        activeRestState = state
        setupRestTimer()
        updateLiveActivityRest()

        // Persistiere resumed State
        persistRestState(state)
        if restNotificationsEnabled {
            let exerciseName: String? =
                activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true
                ? activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
            NotificationManager.shared.scheduleRestEndNotification(
                remainingSeconds: state.remainingSeconds,
                workoutName: state.workoutName,
                exerciseName: exerciseName,
                workoutId: state.workoutId
            )
        }
    }

    func addRest(seconds: Int) {
        guard var state = activeRestState else { return }
        state.remainingSeconds = max(0, state.remainingSeconds + seconds)

        // Nur endDate anpassen wenn Timer läuft
        if state.isRunning {
            state.endDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        }

        activeRestState = state
        if state.isRunning { setupRestTimer() }
        updateLiveActivityRest()
        if restNotificationsEnabled {
            let exerciseName: String? =
                activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true
                ? activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
            NotificationManager.shared.scheduleRestEndNotification(
                remainingSeconds: state.remainingSeconds,
                workoutName: state.workoutName,
                exerciseName: exerciseName,
                workoutId: state.workoutId
            )
        }
    }

    func setRest(remaining: Int, total: Int? = nil) {
        guard var state = activeRestState else { return }
        state.remainingSeconds = max(0, remaining)
        if let total { state.totalSeconds = max(1, total) }

        // Nur endDate setzen wenn Timer läuft
        if state.isRunning {
            state.endDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        }

        activeRestState = state
        if state.isRunning { setupRestTimer() }
        updateLiveActivityRest()
        if restNotificationsEnabled {
            let exerciseName: String? =
                activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true
                ? activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
            NotificationManager.shared.scheduleRestEndNotification(
                remainingSeconds: state.remainingSeconds,
                workoutName: state.workoutName,
                exerciseName: exerciseName,
                workoutId: state.workoutId
            )
        }
    }

    func stopRest() {
        restTimer?.invalidate()
        restTimer = nil
        NotificationManager.shared.cancelRestEndNotification()
        if let state = activeRestState {
            WorkoutLiveActivityController.shared.clearRest(
                workoutId: state.workoutId, workoutName: state.workoutName)
        }
        activeRestState = nil

        // Lösche persistierten Rest-Timer State
        clearPersistedRestState()
    }

    /// Clear rest state after user interaction (e.g. "Continue" button)
    /// Does NOT cancel notification - only called after user acknowledged timer end
    func clearRestState() {
        restTimer?.invalidate()
        restTimer = nil
        // Note: We DON'T cancel notification here - it already fired or user dismissed it
        if let state = activeRestState {
            WorkoutLiveActivityController.shared.clearRest(
                workoutId: state.workoutId, workoutName: state.workoutName)
        }
        activeRestState = nil

        // Lösche persistierten Rest-Timer State
        clearPersistedRestState()
    }

    private func setupRestTimer() {
        restTimer?.invalidate()
        restTimer = nil

        guard let state = activeRestState, state.isRunning, state.remainingSeconds > 0 else {
            return
        }

        // FIXED: Direkter Aufruf statt Task { @MainActor } um Race Conditions zu vermeiden
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickRest()
        }

        if let timer = restTimer {
            // Toleranz für bessere Batterie-Performance
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tickRest() {
        // FIXED: Validiere, dass Timer noch aktiv sein sollte
        guard restTimer != nil else {
            print("[RestTimer] ⚠️ tickRest called but timer is nil - ghost timer detected")
            return
        }

        guard var state = activeRestState, state.isRunning else {
            // FIXED: Timer stoppen wenn State ungültig ist
            print("[RestTimer] ⚠️ State invalid or not running - stopping timer")
            restTimer?.invalidate()
            restTimer = nil
            return
        }

        if let end = state.endDate {
            let remaining = max(0, Int(floor(end.timeIntervalSinceNow)))
            let previousRemaining = state.remainingSeconds
            state.remainingSeconds = remaining

            // Performance: Only update if remainingSeconds actually changed
            if previousRemaining != remaining {
                activeRestState = state
                updateLiveActivityRest()
            }

            if remaining <= 0 {
                // Timer sofort stoppen
                restTimer?.invalidate()
                restTimer = nil

                // Sound & Haptic Feedback (nur im Foreground)
                SoundPlayer.playBoxBell()
                #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                #endif

                // Live Activity zeigt "Pause beendet"
                WorkoutLiveActivityController.shared.showRestEnded(
                    workoutId: state.workoutId, workoutName: state.workoutName)

                // Timer automatisch clearen nach 2 Sekunden
                // Memory: Use weak self to prevent retain cycle
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self?.clearRestState()
                }
            }
        } else {
            // Fallback: decrement by one
            if state.remainingSeconds > 0 {
                state.remainingSeconds -= 1
                activeRestState = state  // Always update since we decrement
                updateLiveActivityRest()
                if state.remainingSeconds <= 0 {
                    // Timer sofort stoppen
                    restTimer?.invalidate()
                    restTimer = nil

                    // Sound & Haptic Feedback
                    SoundPlayer.playBoxBell()
                    #if canImport(UIKit)
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    #endif

                    // Live Activity zeigt "Pause beendet"
                    WorkoutLiveActivityController.shared.showRestEnded(
                        workoutId: state.workoutId, workoutName: state.workoutName)

                    // Timer automatisch clearen nach 2 Sekunden
                    // Memory: Use weak self to prevent retain cycle
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        self?.clearRestState()
                    }
                }
            } else {
                stopRest()
            }
        }
    }

    private func updateLiveActivityRest() {
        guard let state = activeRestState else {
            print("[RestTimer] ⚠️ updateLiveActivityRest: No active rest state")
            return
        }
        let exerciseName: String? =
            activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true
            ? activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
        print(
            "[RestTimer] 📱 Updating LiveActivity: \(state.remainingSeconds)s remaining, endDate: \(state.endDate?.description ?? "nil")"
        )
        WorkoutLiveActivityController.shared.updateRest(
            workoutId: state.workoutId,
            workoutName: state.workoutName,
            exerciseName: exerciseName,
            remainingSeconds: state.remainingSeconds,
            totalSeconds: max(state.totalSeconds, 1),
            endDate: state.endDate
        )
    }

    // Refresh rest timer from wall clock (for example after app resumes from background)
    func refreshRestFromWallClock() {
        guard var state = activeRestState, state.isRunning, let end = state.endDate else {
            return
        }

        let remaining = max(0, Int(floor(end.timeIntervalSinceNow)))
        state.remainingSeconds = remaining

        if remaining <= 0 {
            // Timer ist abgelaufen während App im Background war
            // Live Activity zeigt "Pause beendet"
            WorkoutLiveActivityController.shared.showRestEnded(
                workoutId: state.workoutId, workoutName: state.workoutName)

            // Timer automatisch clearen nach 2 Sekunden
            // Notification kommt durch, da wir sie nicht canceln
            // Memory: Use weak self to prevent retain cycle
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.clearRestState()
            }
        } else {
            // Timer läuft noch - fortsetzen
            activeRestState = state
            setupRestTimer()
        }
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
        exerciseStatsCache.removeAll()
        weekStreakCache = nil
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
            activeRestState = nil
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

    // MARK: - Markdown Parser Test (Phase 3-6)
    func testMarkdownParser() {
        print("🧪 Teste Markdown Parser...")
        ExerciseMarkdownParser.testWithSampleData()
    }

    func testMuscleGroupMapping() {
        print("🔬 Teste Muskelgruppen-Mapping...")
        ExerciseMarkdownParser.testMuscleGroupMapping()
    }

    func testEquipmentAndDifficultyMapping() {
        print("🔧 Teste Equipment und Schwierigkeitsgrad-Mapping...")
        ExerciseMarkdownParser.testEquipmentAndDifficultyMapping()
    }

    func testCompleteExerciseCreation() {
        print("🎯 Teste vollständige Exercise-Erstellung...")
        ExerciseMarkdownParser.testCompleteExerciseCreation()
    }

    func testCompleteEmbeddedExerciseList() {
        print("📖 Teste vollständige eingebettete Übungsliste...")
        ExerciseMarkdownParser.testCompleteEmbeddedList()
    }

    // MARK: - Phase 7: Replace Exercises with Markdown Data

    /// Ersetzt alle bestehenden Übungen durch die Übungen aus der Markdown-Datei
    /// WARNUNG: Diese Funktion löscht ALLE bestehenden Übungen!
    func replaceAllExercisesWithMarkdownData() {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Ersetzen der Übungen")
            return
        }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                print("🔄 Starte vollständigen Austausch der Übungsdatenbank...")

                // Phase 7.1: Parse neue Übungen aus Markdown
                let newExercises = ExerciseMarkdownParser.parseCompleteExerciseList()
                print("📊 \(newExercises.count) neue Übungen aus Markdown geparst")

                if newExercises.isEmpty {
                    print("⚠️ Keine Übungen aus Markdown geparst - Abbruch")
                    return
                }

                // Phase 7.2: Lösche alle bestehenden Übungen
                let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                print("🗑️ Lösche \(existingExercises.count) bestehende Übungen...")

                for exercise in existingExercises {
                    context.delete(exercise)
                }

                // Phase 7.3: Speichere Löschungen
                try context.save()
                print("✅ Alle bestehenden Übungen gelöscht")

                // Phase 7.4: Füge neue Übungen hinzu
                print("➕ Füge \(newExercises.count) neue Übungen hinzu...")

                for exercise in newExercises {
                    let entity = ExerciseEntity.make(from: exercise)
                    context.insert(entity)
                }

                // Phase 7.5: Speichere neue Übungen
                try context.save()

                await MainActor.run {
                    // Phase 7.6: Cache invalidieren und UI aktualisieren
                    self.invalidateCaches()
                    self.objectWillChange.send()

                    print("🎉 Übungsdatenbank-Austausch erfolgreich abgeschlossen!")
                    print("   📊 Neue Übungen: \(newExercises.count)")

                    // Statistiken anzeigen
                    let byEquipment = Dictionary(grouping: newExercises) { $0.equipmentType }
                    for (equipment, exs) in byEquipment.sorted(by: {
                        $0.key.rawValue < $1.key.rawValue
                    }) {
                        print("   🏋️ \(equipment.rawValue): \(exs.count) Übungen")
                    }

                    let byDifficulty = Dictionary(grouping: newExercises) { $0.difficultyLevel }
                    for (difficulty, exs) in byDifficulty.sorted(by: {
                        $0.key.sortOrder < $1.key.sortOrder
                    }) {
                        print("   📊 \(difficulty.rawValue): \(exs.count) Übungen")
                    }
                }

            } catch {
                print("❌ Fehler beim Ersetzen der Übungsdatenbank: \(error)")
            }
        }
    }

    /// Test-Funktion für den Übungsaustausch (nur zu Testzwecken)
    func testReplaceExercises() {
        print("⚠️ WARNUNG: Diese Funktion löscht ALLE bestehenden Übungen!")
        print("🧪 Starte Test des Übungsaustauschs...")

        // Zeige aktuelle Statistiken
        let currentExercises = getExercises()
        print("📊 Aktuelle Übungen: \(currentExercises.count)")

        if !currentExercises.isEmpty {
            let currentByEquipment = Dictionary(grouping: currentExercises) { $0.equipmentType }
            print("   Aktuelle Verteilung:")
            for (equipment, exs) in currentByEquipment.sorted(by: {
                $0.key.rawValue < $1.key.rawValue
            }) {
                print("   - \(equipment.rawValue): \(exs.count)")
            }
        }

        print("\n🔄 Führe Austausch aus...")
        replaceAllExercisesWithMarkdownData()
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

    /// Test-Funktion für automatische Migration
    func testAutomaticMigration() {
        print("🧪 Teste automatische Migration...")
        print("   📊 Migration-Flag aktuell: \(markdownExercisesMigrationCompleted)")
        print("   📈 Migration-Status: \(migrationStatus.displayText)")
        print("   🔄 Migration läuft: \(isMigrationInProgress)")
        print("   📊 Fortschritt: \(Int(migrationProgress * 100))%")

        if markdownExercisesMigrationCompleted {
            print("   ✅ Migration bereits durchgeführt")
            print("   💡 Verwende resetMigrationFlag() zum Zurücksetzen")
        } else {
            print("   🔄 Migration steht noch aus")
            if let context = modelContext {
                print("   🚀 Führe Migration jetzt aus...")
                checkAndPerformAutomaticMigration(context: context)
            } else {
                print("   ❌ ModelContext nicht verfügbar")
            }
        }
    }

    /// Test-Funktion um Migration-UI ohne echte Migration zu simulieren
    func simulateMigrationProgress() {
        print("🎭 Simuliere Migration-Fortschritt für UI-Tests...")

        isMigrationInProgress = true

        Task { [weak self] in
            guard let self = self else { return }

            let steps: [MigrationStatus] = [
                .parsing, .deletingOld, .addingNew, .saving, .completed,
            ]
            let progressValues: [Double] = [0.2, 0.4, 0.7, 0.9, 1.0]

            for (step, progress) in zip(steps, progressValues) {
                await MainActor.run {
                    self.migrationStatus = step
                    self.migrationProgress = progress
                    print("   📊 \(step.displayText) (\(Int(progress * 100))%)")
                }

                // Simuliere Verzögerung
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 Sekunde
            }

            await MainActor.run {
                self.isMigrationInProgress = false
                print("🎉 Migration-Simulation abgeschlossen!")
            }
        }
    }

    // MARK: - Phase 10: Cleanup & Final Testing

    /// Vollständiger Test aller Migration-Szenarien
    func runCompleteMigrationTests() {
        print("🧪 Starte vollständige Migration-Tests...")
        print(String(repeating: "=", count: 50))

        // Test 1: Parser-Funktionalität
        print("\n📖 Test 1: Markdown-Parser")
        testCompleteEmbeddedExerciseList()

        // Test 2: Migration-Status
        print("\n📊 Test 2: Migration-Status prüfen")
        print("   Migration-Flag: \(markdownExercisesMigrationCompleted)")
        print("   Migration aktiv: \(isMigrationInProgress)")
        print("   Aktueller Status: \(migrationStatus.displayText)")

        // Test 3: Datenbank-Status
        print("\n💾 Test 3: Aktuelle Datenbank-Statistiken")
        let currentExercises = getExercises()
        print("   Übungen in DB: \(currentExercises.count)")

        if !currentExercises.isEmpty {
            let byEquipment = Dictionary(grouping: currentExercises) { $0.equipmentType }
            print("   Verteilung nach Equipment:")
            for (equipment, exs) in byEquipment.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                print("     - \(equipment.rawValue): \(exs.count)")
            }

            let byDifficulty = Dictionary(grouping: currentExercises) { $0.difficultyLevel }
            print("   Verteilung nach Schwierigkeitsgrad:")
            for (difficulty, exs) in byDifficulty.sorted(by: { $0.key.sortOrder < $1.key.sortOrder }
            ) {
                print("     - \(difficulty.rawValue): \(exs.count)")
            }
        }

        // Test 4: Validierung
        print("\n✅ Test 4: Datenvalidierung")
        validateExerciseData()

        print("\n🎉 Vollständige Tests abgeschlossen!")
        print(String(repeating: "=", count: 50))
    }

    /// Validiert die Qualität der aktuellen Übungsdaten
    private func validateExerciseData() {
        let exercises = getExercises()

        var issues: [String] = []

        // Check 1: Mindestanzahl Übungen
        if exercises.count < 100 {
            issues.append("Zu wenige Übungen: \(exercises.count) < 100")
        } else {
            print("   ✅ Übungsanzahl: \(exercises.count)")
        }

        // Check 2: Alle Equipment-Types vertreten
        let equipmentTypes = Set(exercises.map { $0.equipmentType })
        let expectedTypes: Set<EquipmentType> = [.freeWeights, .bodyweight, .machine]
        let missingTypes = expectedTypes.subtracting(equipmentTypes)

        if !missingTypes.isEmpty {
            issues.append("Fehlende Equipment-Types: \(missingTypes.map { $0.rawValue })")
        } else {
            print("   ✅ Equipment-Types vollständig")
        }

        // Check 3: Alle Schwierigkeitsgrade vertreten
        let difficultyLevels = Set(exercises.map { $0.difficultyLevel })
        let expectedLevels: Set<DifficultyLevel> = [.anfänger, .fortgeschritten, .profi]
        let missingLevels = expectedLevels.subtracting(difficultyLevels)

        if !missingLevels.isEmpty {
            issues.append("Fehlende Schwierigkeitsgrade: \(missingLevels.map { $0.rawValue })")
        } else {
            print("   ✅ Schwierigkeitsgrade vollständig")
        }

        // Check 4: Alle Muskelgruppen vertreten
        let allMuscleGroups = Set(exercises.flatMap { $0.muscleGroups })
        let expectedMuscles: Set<MuscleGroup> = [
            .chest, .back, .shoulders, .biceps, .triceps, .legs, .glutes, .abs,
        ]
        let missingMuscles = expectedMuscles.subtracting(allMuscleGroups)

        if !missingMuscles.isEmpty {
            issues.append("Fehlende Muskelgruppen: \(missingMuscles.map { $0.rawValue })")
        } else {
            print("   ✅ Muskelgruppen vollständig")
        }

        // Check 5: Übungen ohne Muskelgruppen
        let exercisesWithoutMuscles = exercises.filter { $0.muscleGroups.isEmpty }
        if !exercisesWithoutMuscles.isEmpty {
            issues.append("\(exercisesWithoutMuscles.count) Übungen ohne Muskelgruppen")
            print("   ⚠️ Übungen ohne Muskelgruppen:")
            for exercise in exercisesWithoutMuscles.prefix(5) {
                print("     - \(exercise.name)")
            }
        } else {
            print("   ✅ Alle Übungen haben Muskelgruppen")
        }

        // Check 6: Übungen ohne Beschreibung
        let exercisesWithoutDescription = exercises.filter { $0.description.isEmpty }
        if !exercisesWithoutDescription.isEmpty {
            issues.append("\(exercisesWithoutDescription.count) Übungen ohne Beschreibung")
        } else {
            print("   ✅ Alle Übungen haben Beschreibungen")
        }

        // Zusammenfassung
        if issues.isEmpty {
            print("   🎉 Alle Validierungen bestanden!")
        } else {
            print("   ⚠️ Gefundene Probleme:")
            for issue in issues {
                print("     - \(issue)")
            }
        }
    }

    /// Edge-Case Testing für Migration
    func testMigrationEdgeCases() {
        print("🧪 Teste Migration Edge Cases...")

        // Test 1: Was passiert wenn Markdown leer ist?
        print("\n📝 Test 1: Leerer Markdown")
        let emptyResult = ExerciseMarkdownParser.parseMarkdownTable("")
        print("   Ergebnis bei leerem Markdown: \(emptyResult.count) Übungen")

        // Test 2: Malformed Markdown
        print("\n📝 Test 2: Fehlerhafter Markdown")
        let badMarkdown = "Das ist kein Markdown | Test | Fehler"
        let badResult = ExerciseMarkdownParser.parseMarkdownTable(badMarkdown)
        print("   Ergebnis bei fehlerhaftem Markdown: \(badResult.count) Übungen")

        // Test 3: Migration-Status nach Fehlern
        print("\n📊 Test 3: Migration-Status Validation")
        let allStatuses: [MigrationStatus] = [
            .notStarted, .parsing, .deletingOld, .addingNew, .saving, .completed,
            .error("Test-Fehler"),
        ]

        for status in allStatuses {
            print("   Status: \(status.displayText)")
            print("     Abgeschlossen: \(status.isCompleted)")
            print("     Fehler: \(status.isError)")
        }

        print("\n✅ Edge-Case Tests abgeschlossen")
    }

    /// Performance-Test für große Übungsmengen
    func testPerformance() {
        print("⚡ Performance-Test...")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Test Markdown-Parsing
        let exercises = ExerciseMarkdownParser.parseCompleteExerciseList()

        let parseTime = CFAbsoluteTimeGetCurrent() - startTime

        print("   📊 \(exercises.count) Übungen in \(String(format: "%.3f", parseTime))s geparst")
        print(
            "   📈 Performance: \(String(format: "%.1f", Double(exercises.count) / parseTime)) Übungen/s"
        )

        if parseTime > 2.0 {
            print("   ⚠️ Parsing dauert länger als 2 Sekunden!")
        } else {
            print("   ✅ Performance akzeptabel")
        }
    }

    /// Finaler Integrations-Test
    func runFinalIntegrationTest() {
        print("🎯 Starte finalen Integrations-Test...")
        print(String(repeating: "=", count: 60))

        print("\n1️⃣ Parser-Test")
        testPerformance()

        print("\n2️⃣ Edge-Case-Test")
        testMigrationEdgeCases()

        print("\n3️⃣ Vollständiger System-Test")
        runCompleteMigrationTests()

        print("\n4️⃣ Migration-Simulation")
        print("   🎭 Starte UI-Simulation...")
        simulateMigrationProgress()

        print("\n🏁 Finaler Integrations-Test abgeschlossen!")
        print("📋 System bereit für Produktion")
        print(String(repeating: "=", count: 60))
    }

}

// MARK: - Analytics Helpers

extension WorkoutStore {
    struct ExerciseStats: Identifiable {
        struct HistoryPoint: Identifiable {
            let id = UUID()
            let date: Date
            let volume: Double
            let estimatedOneRepMax: Double
        }

        let id = UUID()
        let exercise: Exercise
        let totalVolume: Double
        let totalReps: Int
        let maxWeight: Double
        let estimatedOneRepMax: Double
        let history: [HistoryPoint]
    }

    var totalWorkoutCount: Int {
        let sessions = getSessionHistory()
        let importedCount = sessions.filter { $0.notes.contains("Importiert aus") }.count
        let regularCount = sessions.count - importedCount
        print(
            "📊 Workout-Statistik: Gesamt: \(sessions.count), Importiert: \(importedCount), Regulär: \(regularCount)"
        )
        return sessions.count
    }

    var averageWorkoutsPerWeek: Double {
        let sessionHistory = getSessionHistory()
        guard let earliestDate = sessionHistory.min(by: { $0.date < $1.date })?.date else {
            return 0
        }
        let span = max(Date().timeIntervalSince(earliestDate), 1)
        let weeks = max(span / (7 * 24 * 60 * 60), 1)
        return Double(sessionHistory.count) / weeks
    }

    var currentWeekStreak: Int {
        let today = Date()
        let calendar = Calendar.current

        // Cache prüfen
        if let cached = weekStreakCache,
            calendar.isDate(cached.date, equalTo: today, toGranularity: .day)
        {
            return cached.value
        }

        let sessionHistory = getSessionHistory()
        guard !sessionHistory.isEmpty else {
            weekStreakCache = (today, 0)
            return 0
        }

        let weekStarts: Set<Date> = Set(
            sessionHistory.compactMap { session in
                calendar.date(
                    from: calendar.dateComponents(
                        [.yearForWeekOfYear, .weekOfYear], from: session.date))
            })

        guard
            var cursor = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))
        else {
            weekStreakCache = (today, 0)
            return 0
        }

        var streak = 0
        while weekStarts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        // Cache aktualisieren
        weekStreakCache = (today, streak)
        return streak
    }

    var averageDurationMinutes: Int {
        let sessionHistory = getSessionHistory()
        let durations = sessionHistory.compactMap { $0.duration }

        // Debug information for imported workouts
        let importedSessions = sessionHistory.filter { $0.notes.contains("Importiert aus") }
        let importedDurations = importedSessions.compactMap { $0.duration }

        if !importedSessions.isEmpty {
            print(
                "📊 Dauer-Statistik: Gesamt: \(sessionHistory.count) Sessions, Importiert: \(importedSessions.count)"
            )
            print(
                "   Durationen verfügbar: Gesamt: \(durations.count), Importiert: \(importedDurations.count)"
            )
        }

        guard !durations.isEmpty else { return 0 }
        let total = durations.reduce(0, +)
        return Int(total / Double(durations.count) / 60)
    }

    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)] {
        let calendar = Calendar.current
        let threshold = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()

        let sessionHistory = getSessionHistory()
        let filtered = sessionHistory.filter { $0.date >= threshold }

        // Debug information
        let importedFiltered = filtered.filter { $0.notes.contains("Importiert aus") }
        if !importedFiltered.isEmpty {
            print("📊 Muskelvolumen-Statistik (letzte \(weeks) Wochen):")
            print(
                "   Gefilterte Sessions: \(filtered.count), davon importiert: \(importedFiltered.count)"
            )
        }

        var totals: [MuscleGroup: Double] = [:]

        for workout in filtered {
            for exercise in workout.exercises {
                let volume = exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
                for muscle in exercise.exercise.muscleGroups {
                    totals[muscle, default: 0] += volume
                }
            }
        }

        return totals.sorted { $0.value > $1.value }
    }

    func exerciseStats(for exercise: Exercise) -> ExerciseStats? {
        if let cached = exerciseStatsCache[exercise.id] {
            return cached
        }

        let sessionHistory = getSessionHistory()
        let relevantSessions = sessionHistory.filter { workout in
            workout.exercises.contains { $0.exercise.id == exercise.id }
        }

        guard !relevantSessions.isEmpty else { return nil }

        var totalVolume: Double = 0
        var totalReps: Int = 0
        var maxWeight: Double = 0
        var history: [ExerciseStats.HistoryPoint] = []

        for workout in relevantSessions.sorted(by: { $0.date < $1.date }) {
            let sets = workout.exercises
                .filter { $0.exercise.id == exercise.id }
                .flatMap { $0.sets }

            let volume = sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
            let reps = sets.reduce(0) { $0 + $1.reps }
            let maxSetWeight = sets.map { $0.weight }.max() ?? 0
            let oneRepMax =
                sets.map { estimateOneRepMax(weight: $0.weight, reps: $0.reps) }.max()
                ?? maxSetWeight

            totalVolume += volume
            totalReps += reps
            maxWeight = max(maxWeight, maxSetWeight)

            history.append(
                ExerciseStats.HistoryPoint(
                    date: workout.date,
                    volume: volume,
                    estimatedOneRepMax: oneRepMax
                )
            )
        }

        let bestOneRepMax = history.map { $0.estimatedOneRepMax }.max() ?? maxWeight

        let stats = ExerciseStats(
            exercise: exercise,
            totalVolume: totalVolume,
            totalReps: totalReps,
            maxWeight: maxWeight,
            estimatedOneRepMax: bestOneRepMax,
            history: history
        )
        exerciseStatsCache[exercise.id] = stats
        return stats
    }

    func workoutsByDay(in range: ClosedRange<Date>) -> [Date: [WorkoutSession]] {
        let calendar = Calendar.current
        let sessionHistory = getSessionHistory()
        return Dictionary(grouping: sessionHistory.filter { range.contains($0.date) }) { workout in
            calendar.startOfDay(for: workout.date)
        }
    }

    private func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    // MARK: - Workout Generation

    func generateWorkout(from preferences: WorkoutPreferences) -> Workout {
        let exercises = getExercises()
        let muscleGroups = selectMuscleGroups(for: preferences)
        let selectedExercises = selectExercises(
            for: preferences, targeting: muscleGroups, from: exercises)
        let workoutExercises = createWorkoutExercises(
            from: selectedExercises, preferences: preferences)

        return Workout(
            name: generateWorkoutName(for: preferences),
            exercises: workoutExercises,
            defaultRestTime: calculateRestTime(for: preferences),
            notes: generateWorkoutNotes(for: preferences)
        )
    }

    private func selectMuscleGroups(for preferences: WorkoutPreferences) -> [MuscleGroup] {
        switch preferences.frequency {
        case 1, 2:
            // Ganzkörper-Workouts
            return [.chest, .back, .shoulders, .legs, .abs]
        case 3:
            // 3er Split: Push/Pull/Legs
            return [.chest, .back, .legs, .shoulders, .abs]
        case 4, 5:
            // 4-5er Split: mehr Fokus auf spezifische Gruppen
            return [.chest, .back, .shoulders, .legs, .biceps, .triceps, .abs]
        default:
            // 6+ Split: sehr spezifisch
            return MuscleGroup.allCases
        }
    }

    private func selectExercises(
        for preferences: WorkoutPreferences, targeting muscleGroups: [MuscleGroup],
        from exercises: [Exercise]
    ) -> [Exercise] {
        var selectedExercises: [Exercise] = []

        // Filter nach Equipment UND Difficulty-Level
        let equipmentFiltered = filterExercisesByEquipment(preferences.equipment, from: exercises)
        let availableExercises = filterExercisesByDifficulty(
            equipmentFiltered, for: preferences.experience)

        // Grundübungen basierend auf Erfahrung
        let compoundExercises = availableExercises.filter { exercise in
            exercise.muscleGroups.count >= 2
        }

        let isolationExercises = availableExercises.filter { exercise in
            exercise.muscleGroups.count == 1
        }

        // Anzahl Übungen basierend auf Trainingsdauer
        let targetExerciseCount = calculateExerciseCount(for: preferences)

        // Compound-zu-Isolation Verhältnis basierend auf Erfahrung
        let compoundRatio: Double
        switch preferences.experience {
        case .beginner:
            compoundRatio = 0.8
        case .intermediate:
            compoundRatio = 0.6
        case .advanced:
            compoundRatio = 0.4
        }

        let compoundCount = Int(Double(targetExerciseCount) * compoundRatio)
        let isolationCount = targetExerciseCount - compoundCount

        // Wähle Compound-Übungen (bevorzuge passende Difficulty)
        for muscleGroup in muscleGroups.prefix(compoundCount) {
            // Versuche erst passende Difficulty zu finden
            if let exercise = compoundExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup)
                    && !selectedExercises.contains(where: { $0.id == exercise.id })
                    && matchesDifficultyLevel(exercise, for: preferences.experience)
            }) {
                selectedExercises.append(exercise)
            }
            // Fallback: Ignoriere Difficulty wenn nichts passendes gefunden
            else if let exercise = compoundExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup)
                    && !selectedExercises.contains(where: { $0.id == exercise.id })
            }) {
                selectedExercises.append(exercise)
            }
        }

        // Fülle mit Isolation-Übungen auf (bevorzuge passende Difficulty)
        for muscleGroup in muscleGroups.prefix(isolationCount) {
            // Versuche erst passende Difficulty zu finden
            if let exercise = isolationExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup)
                    && !selectedExercises.contains(where: { $0.id == exercise.id })
                    && matchesDifficultyLevel(exercise, for: preferences.experience)
            }) {
                selectedExercises.append(exercise)
            }
            // Fallback: Ignoriere Difficulty wenn nichts passendes gefunden
            else if let exercise = isolationExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup)
                    && !selectedExercises.contains(where: { $0.id == exercise.id })
            }) {
                selectedExercises.append(exercise)
            }
        }

        // Stelle sicher, dass wir genug Übungen haben
        while selectedExercises.count < targetExerciseCount
            && selectedExercises.count < availableExercises.count
        {
            if let nextExercise = availableExercises.first(where: { candidate in
                !selectedExercises.contains(where: { $0.id == candidate.id })
            }) {
                selectedExercises.append(nextExercise)
            } else {
                break
            }
        }

        return Array(selectedExercises.prefix(targetExerciseCount))
    }

    /// Filtert Übungen basierend auf dem Erfahrungslevel
    /// Priorisiert passende Übungen, lässt aber andere als Fallback zu
    private func filterExercisesByDifficulty(_ exercises: [Exercise], for level: ExperienceLevel)
        -> [Exercise]
    {
        // Sortiere so dass passende Übungen zuerst kommen
        return exercises.sorted { first, second in
            let firstMatches = matchesDifficultyLevel(first, for: level)
            let secondMatches = matchesDifficultyLevel(second, for: level)

            if firstMatches && !secondMatches {
                return true
            }
            if !firstMatches && secondMatches {
                return false
            }
            return false  // Behalte ursprüngliche Reihenfolge bei
        }
    }

    private func filterExercisesByEquipment(
        _ equipment: EquipmentPreference, from exercises: [Exercise]
    ) -> [Exercise] {
        switch equipment {
        case .freeWeights:
            return exercises.filter { exercise in
                !exercise.name.lowercased().contains("maschine")
                    && !exercise.name.lowercased().contains("machine")
            }
        case .machines:
            return exercises.filter { exercise in
                exercise.name.lowercased().contains("maschine")
                    || exercise.name.lowercased().contains("machine")
            }
        case .mixed:
            return exercises
        }
    }

    /// Prüft ob eine Übung zum Erfahrungslevel des Users passt
    /// - Parameters:
    ///   - exercise: Die zu prüfende Übung
    ///   - level: Das Erfahrungslevel des Users
    /// - Returns: true wenn die Übung zum Level passt oder nahe dran ist
    private func matchesDifficultyLevel(_ exercise: Exercise, for level: ExperienceLevel) -> Bool {
        switch level {
        case .beginner:
            // Anfänger: Hauptsächlich Anfänger-Übungen, einige Fortgeschritten
            return exercise.difficultyLevel == .anfänger
                || exercise.difficultyLevel == .fortgeschritten
        case .intermediate:
            // Fortgeschritten: Alle Levels sind ok (Mix)
            return true
        case .advanced:
            // Experte: Hauptsächlich Fortgeschritten und Profi-Übungen
            return exercise.difficultyLevel == .fortgeschritten
                || exercise.difficultyLevel == .profi
        }
    }

    private func calculateExerciseCount(for preferences: WorkoutPreferences) -> Int {
        let baseCount: Int
        switch preferences.duration {
        case .short: baseCount = 4
        case .medium: baseCount = 6
        case .long: baseCount = 8
        case .extended: baseCount = 10
        }

        // Anpassung basierend auf Erfahrung
        switch preferences.experience {
        case .beginner:
            return max(3, baseCount - 1)
        case .intermediate:
            return baseCount
        case .advanced:
            return baseCount + 1
        }
    }

    private func createWorkoutExercises(from exercises: [Exercise], preferences: WorkoutPreferences)
        -> [WorkoutExercise]
    {
        return exercises.map { exercise in
            let setCount = calculateSetCount(for: exercise, preferences: preferences)
            let reps = calculateReps(for: exercise, preferences: preferences)
            let restTime = calculateRestTime(for: preferences)

            let sets = (0..<setCount).map { _ in
                ExerciseSet(reps: reps, weight: 0, restTime: restTime, completed: false)
            }

            return WorkoutExercise(exercise: exercise, sets: sets)
        }
    }

    private func calculateSetCount(for exercise: Exercise, preferences: WorkoutPreferences) -> Int {
        let baseSetCount: Int
        switch preferences.experience {
        case .beginner: baseSetCount = 2
        case .intermediate: baseSetCount = 3
        case .advanced: baseSetCount = 4
        }

        let isCompound = exercise.muscleGroups.count >= 2
        return isCompound ? baseSetCount + 1 : baseSetCount
    }

    private func calculateReps(for exercise: Exercise, preferences: WorkoutPreferences) -> Int {
        switch preferences.goal {
        case .strength:
            return Int.random(in: 3...6)
        case .muscleBuilding:
            return Int.random(in: 8...12)
        case .endurance:
            return Int.random(in: 15...20)
        case .weightLoss:
            return Int.random(in: 12...15)
        case .general:
            return Int.random(in: 10...12)
        }
    }

    private func calculateRestTime(for preferences: WorkoutPreferences) -> Double {
        switch preferences.goal {
        case .strength:
            return 120
        case .muscleBuilding:
            return 90
        case .endurance:
            return 60
        case .weightLoss:
            return 45
        case .general:
            return 75
        }
    }

    private func generateWorkoutName(for preferences: WorkoutPreferences) -> String {
        let goalPrefix: String
        switch preferences.goal {
        case .muscleBuilding: goalPrefix = "Muskelaufbau"
        case .strength: goalPrefix = "Kraft"
        case .endurance: goalPrefix = "Ausdauer"
        case .weightLoss: goalPrefix = "Fettverbrennung"
        case .general: goalPrefix = "Fitness"
        }

        let equipmentSuffix: String
        switch preferences.equipment {
        case .freeWeights: equipmentSuffix = "Freie Gewichte"
        case .machines: equipmentSuffix = "Maschinen"
        case .mixed: equipmentSuffix = "Mixed"
        }

        return "\(goalPrefix) - \(equipmentSuffix)"
    }

    private func generateWorkoutNotes(for preferences: WorkoutPreferences) -> String {
        var notes: [String] = []

        notes.append("🎯 Ziel: \(preferences.goal.displayName)")
        notes.append("📊 Level: \(preferences.experience.displayName)")
        notes.append("⏱️ Dauer: ~\(preferences.duration.rawValue) Minuten")
        notes.append("🔄 Frequenz: \(preferences.frequency)x pro Woche")

        switch preferences.goal {
        case .strength:
            notes.append("💡 Tipp: Fokus auf schwere Gewichte, längere Pausen")
        case .muscleBuilding:
            notes.append("💡 Tipp: Kontrollierte Bewegungen, Muskel-Geist-Verbindung")
        case .endurance:
            notes.append("💡 Tipp: Höhere Wiederholungen, kürzere Pausen")
        case .weightLoss:
            notes.append("💡 Tipp: Intensität hoch halten, Supersätze möglich")
        case .general:
            notes.append("💡 Tipp: Ausgewogenes Training, auf Körper hören")
        }

        return notes.joined(separator: "\n")
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
        exerciseStatsCache.removeAll()
        weekStreakCache = nil

        // Stop timers if no active session
        if activeSessionID == nil {
            restTimer?.invalidate()
            restTimer = nil
            activeRestState = nil
        }

        print("[Memory] ✅ WorkoutStore cleanup completed")
    }

    // MARK: - Rest State Persistence

    /// Persistiert den Rest-Timer State in UserDefaults für Wiederherstellung nach Force Quit
    private func persistRestState(_ state: ActiveRestState) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)
            UserDefaults.standard.set(data, forKey: "activeRestState")
            print("[RestTimer] 💾 Rest state persisted: \(state.remainingSeconds)s remaining")
        } catch {
            print("[RestTimer] ❌ Failed to persist rest state: \(error)")
        }
    }

    /// Löscht den persistierten Rest-Timer State aus UserDefaults
    private func clearPersistedRestState() {
        UserDefaults.standard.removeObject(forKey: "activeRestState")
        print("[RestTimer] 🗑️ Persisted rest state cleared")
    }

    /// Lädt und stellt den Rest-Timer State aus UserDefaults wieder her
    func restorePersistedRestState() {
        guard let data = UserDefaults.standard.data(forKey: "activeRestState") else {
            print("[RestTimer] No persisted rest state found")
            return
        }

        do {
            let decoder = JSONDecoder()
            var state = try decoder.decode(ActiveRestState.self, from: data)

            // Berechne verbleibende Zeit basierend auf endDate
            if let endDate = state.endDate {
                let now = Date()
                let remaining = max(0, Int(endDate.timeIntervalSince(now)))

                if remaining > 0 {
                    // Timer läuft noch
                    state.remainingSeconds = remaining
                    state.isRunning = true
                    activeRestState = state

                    print("[RestTimer] ✅ Rest state restored: \(remaining)s remaining")

                    // Starte Timer und Update Live Activity
                    setupRestTimer()
                    updateLiveActivityRest()

                    // Schedule notification für verbleibende Zeit
                    if restNotificationsEnabled {
                        let exerciseName =
                            activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true
                            ? activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
                        NotificationManager.shared.scheduleRestEndNotification(
                            remainingSeconds: remaining,
                            workoutName: state.workoutName,
                            exerciseName: exerciseName,
                            workoutId: state.workoutId
                        )
                    }
                } else {
                    // Timer ist bereits abgelaufen
                    print("[RestTimer] ⏱️ Rest timer expired during Force Quit")
                    clearPersistedRestState()

                    // Zeige "Pause beendet" in Live Activity
                    WorkoutLiveActivityController.shared.showRestEnded(
                        workoutId: state.workoutId,
                        workoutName: state.workoutName
                    )
                }
            } else {
                // Kein endDate (sollte nicht vorkommen, aber handle gracefully)
                print("[RestTimer] ⚠️ Persisted rest state has no endDate - ignoring")
                clearPersistedRestState()
            }
        } catch {
            print("[RestTimer] ❌ Failed to restore rest state: \(error)")
            clearPersistedRestState()
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let profileUpdatedFromHealthKit = Notification.Name("profileUpdatedFromHealthKit")
}
