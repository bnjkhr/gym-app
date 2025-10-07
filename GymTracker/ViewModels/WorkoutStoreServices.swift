import Foundation

/// Service für zentrale Cache-Verwaltung
@MainActor
class CacheService: ObservableObject {
    // MARK: - Cache Storage

    private(set) var exerciseStatsCache: [UUID: ExerciseStats] = [:]
    private(set) var weekStreakCache: (date: Date, value: Int)?

    // MARK: - Public API

    func invalidateCaches() {
        exerciseStatsCache.removeAll()
        weekStreakCache = nil
    }

    func invalidateExerciseCache(for exerciseId: UUID) {
        exerciseStatsCache[exerciseId] = nil
    }

    func cacheExerciseStats(_ stats: ExerciseStats, for exerciseId: UUID) {
        exerciseStatsCache[exerciseId] = stats
    }

    func getExerciseStats(for exerciseId: UUID) -> ExerciseStats? {
        exerciseStatsCache[exerciseId]
    }

    func cacheWeekStreak(value: Int, date: Date) {
        weekStreakCache = (date, value)
    }

    func getWeekStreak() -> (date: Date, value: Int)? {
        weekStreakCache
    }
}

// MARK: - Supporting Structures

struct ExerciseStats {
    struct HistoryPoint {
        let date: Date
        let weight: Double
        let reps: Int
        let volume: Double
    }

    let exercise: Exercise
    let maxWeight: Double?
    let maxReps: Int?
    let totalSets: Int
    let totalReps: Int
    let averageWeight: Double?
    let history: [HistoryPoint]
}
import Foundation
import SwiftUI
import SwiftData

/// Repository für Exercise CRUD-Operationen und Abfragen
@MainActor
class ExerciseRepository: ObservableObject {
    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var cacheService: CacheService?

    // MARK: - Computed Properties

    var exercises: [Exercise] {
        getExercises()
    }

    // MARK: - Initialization

    init() {}

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func setCacheService(_ service: CacheService) {
        self.cacheService = service
    }

    // MARK: - Public API

    func getExercises() -> [Exercise] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<ExerciseEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { mapExerciseEntity($0) }
    }

    func exercise(named name: String) -> Exercise {
        guard let context = modelContext else {
            return Exercise(name: name, muscleGroups: [], equipmentType: .mixed, description: "")
        }

        let descriptor = FetchDescriptor<ExerciseEntity>()
        let allExercises = (try? context.fetch(descriptor)) ?? []

        if let existing = allExercises.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return mapExerciseEntity(existing)
        }

        let newExercise = Exercise(name: name, muscleGroups: [], equipmentType: .mixed, description: "")
        let entity = ExerciseEntity.make(from: newExercise)
        context.insert(entity)
        try? context.save()
        return newExercise
    }

    func getSimilarExercises(to exercise: Exercise, count: Int = 10, userLevel: ExperienceLevel? = nil) -> [Exercise] {
        let allExercises = getExercises()

        let candidates = allExercises.filter { candidate in
            candidate.id != exercise.id &&
            exercise.hasSimilarMuscleGroups(to: candidate)
        }

        let scoredExercises = candidates.compactMap { candidate -> (exercise: Exercise, score: Int, matchesLevel: Bool, sharesPrimary: Bool)? in
            let score = exercise.similarityScore(to: candidate)
            guard score > 0 else { return nil }

            let matchesLevel = userLevel != nil ? matchesDifficultyLevel(candidate, for: userLevel!) : true
            let sharesPrimary = exercise.sharesPrimaryMuscleGroup(with: candidate)
            return (candidate, score, matchesLevel, sharesPrimary)
        }

        let sorted = scoredExercises.sorted { first, second in
            if first.sharesPrimary && !second.sharesPrimary {
                return true
            }
            if !first.sharesPrimary && second.sharesPrimary {
                return false
            }

            if let _ = userLevel {
                if first.matchesLevel && !second.matchesLevel {
                    return true
                }
                if !first.matchesLevel && second.matchesLevel {
                    return false
                }
            }

            return first.score > second.score
        }

        return Array(sorted.prefix(count).map { $0.exercise })
    }

    func addExercise(_ exercise: Exercise) {
        guard let context = modelContext else { return }

        let idDescriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
        )

        if (try? context.fetch(idDescriptor).first) != nil {
            return
        }

        let nameDescriptor = FetchDescriptor<ExerciseEntity>()
        let allExercises = (try? context.fetch(nameDescriptor)) ?? []

        if allExercises.contains(where: { $0.name.localizedCaseInsensitiveCompare(exercise.name) == .orderedSame }) {
            return
        }

        let entity = ExerciseEntity.make(from: exercise)
        context.insert(entity)
        try? context.save()
        cacheService?.invalidateCaches()
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
        cacheService?.invalidateExerciseCache(for: exercise.id)
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

            cacheService?.invalidateExerciseCache(for: exercise.id)
        }

        try? context.save()
    }

    // MARK: - Private Helpers

    private func mapExerciseEntity(_ entity: ExerciseEntity) -> Exercise {
        let id = entity.id
        let name = entity.name
        let muscleGroupsRaw = entity.muscleGroupsRaw
        let equipmentTypeRaw = entity.equipmentTypeRaw
        let descriptionText = entity.descriptionText
        let instructions = entity.instructions
        let createdAt = entity.createdAt

        var source: ExerciseEntity? = entity
        if let context = modelContext {
            let descriptor = FetchDescriptor<ExerciseEntity>(predicate: #Predicate { $0.id == id })
            if let fresh = try? context.fetch(descriptor).first {
                source = fresh
            }
        }

        guard let validSource = source else {
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

        let groups: [MuscleGroup] = validSource.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
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

    private func matchesDifficultyLevel(_ exercise: Exercise, for level: ExperienceLevel) -> Bool {
        switch level {
        case .beginner:
            return exercise.difficultyLevel == .anfänger || exercise.difficultyLevel == .fortgeschritten
        case .intermediate:
            return true
        case .advanced:
            return exercise.difficultyLevel == .fortgeschritten || exercise.difficultyLevel == .profi
        }
    }
}
import Foundation
import SwiftData

/// Repository für Workout CRUD-Operationen und Abfragen
@MainActor
class WorkoutRepository: ObservableObject {
    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var exerciseRepository: ExerciseRepository?

    // MARK: - State

    var activeSessionID: UUID?

    // MARK: - Computed Properties

    var workouts: [Workout] {
        getWorkouts()
    }

    var homeWorkouts: [Workout] {
        guard let context = modelContext else { return [] }

        do {
            let descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate<WorkoutEntity> { $0.isFavorite == true },
                sortBy: [SortDescriptor(\.name)]
            )
            let entities = try context.fetch(descriptor)
            return entities.map { mapWorkoutEntity($0) }
        } catch {
            print("❌ Fehler beim Laden der Home-Favoriten: \(error)")
            return []
        }
    }

    var activeWorkout: Workout? {
        guard let activeSessionID, let context = modelContext else {
            return nil
        }

        do {
            let descriptor = FetchDescriptor<WorkoutEntity>(predicate: #Predicate<WorkoutEntity> { $0.id == activeSessionID })
            if let entity = try context.fetch(descriptor).first {
                return mapWorkoutEntity(entity)
            } else {
                print("⚠️ Aktives Workout mit ID \(activeSessionID) nicht gefunden")
                self.activeSessionID = nil
                WorkoutLiveActivityController.shared.end()
                return nil
            }
        } catch {
            print("❌ Fehler beim Laden des aktiven Workouts: \(error)")
            return nil
        }
    }

    // MARK: - Initialization

    init() {}

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func setExerciseRepository(_ repository: ExerciseRepository) {
        self.exerciseRepository = repository
    }

    // MARK: - Public API

    func getWorkouts() -> [Workout] {
        guard let context = modelContext else {
            print("⚠️ WorkoutRepository: ModelContext ist nil beim Abrufen von Workouts")
            return []
        }

        let descriptor = FetchDescriptor<WorkoutEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let entities = try context.fetch(descriptor)
            return entities.map { mapWorkoutEntity($0) }
        } catch {
            print("❌ Fehler beim Abrufen der Workouts: \(error)")
            return []
        }
    }

    func addWorkout(_ workout: Workout) {
        guard let context = modelContext else {
            print("❌ WorkoutRepository: ModelContext ist nil beim Speichern eines Workouts")
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
            print("❌ WorkoutRepository: ModelContext ist nil beim Aktualisieren eines Workouts")
            return
        }

        do {
            try DataManager.shared.saveWorkout(workout, to: context)
            print("✅ Workout erfolgreich aktualisiert: \(workout.name)")
        } catch {
            print("❌ Fehler beim Aktualisieren des Workouts: \(error)")
        }
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

        if !entity.isFavorite {
            let currentCount = getHomeFavoritesCount()
            if currentCount >= 4 {
                print("⚠️ Home-Favoriten Limit erreicht: \(currentCount)/4")
                return false
            }
        }

        entity.isFavorite.toggle()

        do {
            try context.save()
            context.processPendingChanges()
            let action = entity.isFavorite ? "hinzugefügt" : "entfernt"
            print("✅ Home-Favorit für Workout '\(entity.name)' \(action)")
            return true
        } catch {
            print("❌ Fehler beim Speichern des Home-Favoriten: \(error)")
            return false
        }
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        let sessionHistory = getSessionHistory()
        return sessionHistory
            .filter { $0.templateId == workout.id }
            .sorted { $0.date > $1.date }
            .first
            .map(Workout.init(session:))
    }

    // MARK: - Private Helpers

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

    private func getSessionHistory() -> [WorkoutSession] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { WorkoutSession(entity: $0) }
    }

    private func mapWorkoutEntity(_ entity: WorkoutEntity) -> Workout {
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

    private func mapExerciseEntity(_ entity: ExerciseEntity) -> Exercise {
        let id = entity.id
        let name = entity.name
        let muscleGroupsRaw = entity.muscleGroupsRaw
        let equipmentTypeRaw = entity.equipmentTypeRaw
        let descriptionText = entity.descriptionText
        let instructions = entity.instructions
        let createdAt = entity.createdAt

        var source: ExerciseEntity? = entity
        if let context = modelContext {
            let descriptor = FetchDescriptor<ExerciseEntity>(predicate: #Predicate { $0.id == id })
            if let fresh = try? context.fetch(descriptor).first {
                source = fresh
            }
        }

        guard let validSource = source else {
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

        let groups: [MuscleGroup] = validSource.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
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
}
import Foundation
import SwiftData
import HealthKit

/// Service für Active Session Management und Session-Recording
@MainActor
class SessionService: ObservableObject {
    // MARK: - Published State

    @Published var activeSessionID: UUID?
    @Published var isShowingWorkoutDetail: Bool = false

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var cacheService: CacheService?
    private var healthKitService: HealthKitServiceProtocol?
    private var heartRateTrackingService: HeartRateTrackingService?
    private var restTimerService: RestTimerService?
    private var lastUsedMetricsService: LastUsedMetricsService?

    // MARK: - Initialization

    init() {}

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func setCacheService(_ service: CacheService) {
        self.cacheService = service
    }

    func setHealthKitService(_ service: HealthKitServiceProtocol) {
        self.healthKitService = service
    }

    func setHeartRateTrackingService(_ service: HeartRateTrackingService) {
        self.heartRateTrackingService = service
    }

    func setRestTimerService(_ service: RestTimerService) {
        self.restTimerService = service
    }

    func setLastUsedMetricsService(_ service: LastUsedMetricsService) {
        self.lastUsedMetricsService = service
    }

    // MARK: - Public API

    func startSession(for workoutId: UUID) {
        guard let context = modelContext else {
            print("❌ SessionService: ModelContext ist nil beim Starten einer Session")
            return
        }

        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { $0.id == workoutId }
        )

        do {
            if let workout = try context.fetch(descriptor).first {
                workout.date = Date()
                workout.duration = nil

                let sortedExercises = workout.exercises.sorted { $0.order < $1.order }
                for exercise in sortedExercises {
                    for set in exercise.sets {
                        set.completed = false
                    }
                }

                try context.save()
                activeSessionID = workoutId
                print("✅ Session gestartet für Workout: \(workout.name)")

                heartRateTrackingService?.startHeartRateTracking(workoutName: workout.name)
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
            restTimerService?.stopRest()
            heartRateTrackingService?.stopHeartRateTracking()
            WorkoutLiveActivityController.shared.end()
        }
    }

    func recordSession(from workout: Workout, userProfile: UserProfile, healthKitManager: HealthKitManager) {
        guard let context = modelContext else {
            print("❌ SessionService: ModelContext ist nil beim Speichern einer Session")
            return
        }

        do {
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

            let savedEntity = try DataManager.shared.recordSession(session, to: context)

            lastUsedMetricsService?.updateLastUsedMetrics(from: session)

            Task {
                await ExerciseRecordMigration.updateRecords(from: savedEntity, context: context)
            }

            cacheService?.invalidateCaches()
            print("✅ Workout-Session erfolgreich gespeichert: \(workout.name)")

            if userProfile.healthKitSyncEnabled && healthKitManager.isAuthorized {
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        try await self.healthKitService?.saveWorkoutToHealthKit(session)
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

    func removeSession(with id: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate<WorkoutSessionEntity> { $0.id == id }
        )

        if let entity = try? context.fetch(descriptor).first {
            context.delete(entity)
            try? context.save()
        }

        cacheService?.invalidateCaches()
    }

    func getSessionHistory() -> [WorkoutSession] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { WorkoutSession(entity: $0) }
    }
}
import Foundation
import SwiftData
import HealthKit
#if canImport(UIKit)
import UIKit
#endif

/// Service für User Profile Management
@MainActor
class UserProfileService: ObservableObject {
    // MARK: - Published State

    @Published var profileUpdateTrigger: UUID = UUID()
    @Published private(set) var userProfile: UserProfile

    // MARK: - Dependencies

    private var modelContext: ModelContext? {
        didSet {
            // When context is set, immediately reload profile
            loadProfile()
        }
    }

    // MARK: - Initialization

    init() {
        // Initialize with UserDefaults backup or empty profile
        self.userProfile = ProfilePersistenceHelper.loadFromUserDefaults()
    }

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Private Methods

    private func loadProfile() {
        // Early return if no context - load from UserDefaults
        guard let context = modelContext else {
            let backup = ProfilePersistenceHelper.loadFromUserDefaults()
            self.userProfile = backup
            return
        }

        // Try to fetch from SwiftData with full error protection
        do {
            let descriptor = FetchDescriptor<UserProfileEntity>()
            guard let entity = try context.fetch(descriptor).first else {
                // No entity found, return UserDefaults backup or empty profile
                let backup = ProfilePersistenceHelper.loadFromUserDefaults()
                self.userProfile = !backup.name.isEmpty || backup.weight != nil ? backup : UserProfile()
                return
            }

            // Successfully fetched entity, convert to UserProfile
            let profile = UserProfile(entity: entity)
            ProfilePersistenceHelper.saveToUserDefaults(profile)
            self.userProfile = profile
        } catch {
            print("⚠️ Fehler beim Laden des Profils aus SwiftData: \(error.localizedDescription)")
            // On any error, fall back to UserDefaults
            self.userProfile = ProfilePersistenceHelper.loadFromUserDefaults()
        }
    }

    // MARK: - Public API

    func updateProfile(name: String, birthDate: Date?, weight: Double?, height: Double? = nil, biologicalSex: HKBiologicalSex? = nil, goal: FitnessGoal, experience: ExperienceLevel, equipment: EquipmentPreference, preferredDuration: WorkoutDuration, healthKitSyncEnabled: Bool = false, profileImageData: Data? = nil) {
        let imageData = profileImageData ?? ProfilePersistenceHelper.loadFromUserDefaults().profileImageData

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

        ProfilePersistenceHelper.saveToUserDefaults(updatedProfile)

        guard let context = modelContext else {
            print("⚠️ UserProfileService: ModelContext ist nil, nur in UserDefaults gespeichert")
            profileUpdateTrigger = UUID()
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProfileEntity>()
            let existingEntity = try context.fetch(descriptor).first

            if let entity = existingEntity {
                entity.name = name
                entity.birthDate = birthDate
                entity.weight = weight
                entity.height = height
                entity.biologicalSexRaw = biologicalSex.map { Int16($0.rawValue) } ?? 0
                entity.goalRaw = goal.rawValue
                entity.experienceRaw = experience.rawValue
                entity.equipmentRaw = equipment.rawValue
                entity.preferredDurationRaw = preferredDuration.rawValue
                entity.healthKitSyncEnabled = healthKitSyncEnabled
                entity.profileImageData = imageData
            } else {
                let newEntity = UserProfileEntity(
                    name: name,
                    birthDate: birthDate,
                    weight: weight,
                    height: height,
                    biologicalSexRaw: biologicalSex.map { Int16($0.rawValue) } ?? 0,
                    healthKitSyncEnabled: healthKitSyncEnabled,
                    goalRaw: goal.rawValue,
                    experienceRaw: experience.rawValue,
                    equipmentRaw: equipment.rawValue,
                    preferredDurationRaw: preferredDuration.rawValue,
                    profileImageData: imageData
                )
                context.insert(newEntity)
            }

            try context.save()
            profileUpdateTrigger = UUID()
            print("✅ Profil erfolgreich gespeichert")

            // Reload profile from SwiftData to update cached value
            loadProfile()
        } catch {
            print("❌ Fehler beim Speichern des Profils: \(error)")
        }
    }

    #if canImport(UIKit)
    func updateProfileImage(_ image: UIImage?) {
        let imageData: Data? = if let image = image {
            image.jpegData(compressionQuality: 0.8)
        } else {
            nil
        }

        guard let context = modelContext else {
            print("⚠️ UserProfileService: ModelContext ist nil beim Aktualisieren des Profilbilds")
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProfileEntity>()
            if let entity = try context.fetch(descriptor).first {
                entity.profileImageData = imageData

                let profile = UserProfile(entity: entity)
                ProfilePersistenceHelper.saveToUserDefaults(profile)

                try context.save()
                loadProfile()
                profileUpdateTrigger = UUID()
                print("✅ Profilbild erfolgreich aktualisiert")
            }
        } catch {
            print("❌ Fehler beim Aktualisieren des Profilbilds: \(error)")
        }
    }
    #endif

    func updateLockerNumber(_ lockerNumber: String) {
        guard let context = modelContext else {
            print("⚠️ UserProfileService: ModelContext ist nil beim Aktualisieren der Lockernummer")
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProfileEntity>()
            if let entity = try context.fetch(descriptor).first {
                entity.lockerNumber = lockerNumber

                let profile = UserProfile(entity: entity)
                ProfilePersistenceHelper.saveToUserDefaults(profile)

                try context.save()
                loadProfile()
                profileUpdateTrigger = UUID()
                print("✅ Lockernummer aktualisiert: \(lockerNumber)")
            } else {
                print("⚠️ Kein Profil gefunden zum Aktualisieren der Lockernummer")
            }
        } catch {
            print("❌ Fehler beim Aktualisieren der Lockernummer: \(error)")
        }
    }

    func markOnboardingStep(hasExploredWorkouts: Bool? = nil, hasCreatedFirstWorkout: Bool? = nil, hasSetupProfile: Bool? = nil) {
        guard let context = modelContext else {
            print("⚠️ UserProfileService: ModelContext ist nil beim Aktualisieren des Onboarding-Status")
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProfileEntity>()

            if let entity = try context.fetch(descriptor).first {
                if let explored = hasExploredWorkouts {
                    entity.hasExploredWorkouts = explored
                    print("✅ Onboarding-Status aktualisiert: hasExploredWorkouts = \(explored)")
                }
                if let created = hasCreatedFirstWorkout {
                    entity.hasCreatedFirstWorkout = created
                    print("✅ Onboarding-Status aktualisiert: hasCreatedFirstWorkout = \(created)")
                }
                if let setup = hasSetupProfile {
                    entity.hasSetupProfile = setup
                    print("✅ Onboarding-Status aktualisiert: hasSetupProfile = \(setup)")
                }

                let profile = UserProfile(entity: entity)
                ProfilePersistenceHelper.saveToUserDefaults(profile)

                try context.save()
                loadProfile()
                profileUpdateTrigger = UUID()
            } else {
                print("⚠️ Kein Profil gefunden - erstelle neues Profil mit Onboarding-Status")
                let newEntity = UserProfileEntity(
                    name: "",
                    birthDate: nil,
                    weight: nil,
                    height: nil,
                    biologicalSexRaw: 0,
                    healthKitSyncEnabled: false,
                    goalRaw: FitnessGoal.muscleBuilding.rawValue,
                    experienceRaw: ExperienceLevel.beginner.rawValue,
                    equipmentRaw: EquipmentPreference.mixed.rawValue,
                    preferredDurationRaw: WorkoutDuration.short.rawValue,
                    profileImageData: nil
                )

                if let explored = hasExploredWorkouts {
                    newEntity.hasExploredWorkouts = explored
                }
                if let created = hasCreatedFirstWorkout {
                    newEntity.hasCreatedFirstWorkout = created
                }
                if let setup = hasSetupProfile {
                    newEntity.hasSetupProfile = setup
                }

                context.insert(newEntity)
                try context.save()
                loadProfile()
                profileUpdateTrigger = UUID()
            }
        } catch {
            print("❌ Fehler beim Aktualisieren des Onboarding-Status: \(error)")
        }
    }
}
import Foundation
import HealthKit

/// Protocol für HealthKit Integration (für Dependency Injection)
protocol HealthKitServiceProtocol {
    func requestHealthKitAuthorization() async throws
    func importFromHealthKit(userProfileService: UserProfileService) async throws
    func saveWorkoutToHealthKit(_ workoutSession: WorkoutSession) async throws
    func readHeartRateData(from startDate: Date, to endDate: Date) async throws -> [HeartRateReading]
    func readWeightData(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading]
    func readBodyFatData(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading]
}

/// Service für HealthKit Integration
@MainActor
class HealthKitIntegrationService: ObservableObject, HealthKitServiceProtocol {
    // MARK: - Published State

    @Published var healthKitManager = HealthKitManager.shared

    // MARK: - Public API

    func requestHealthKitAuthorization() async throws {
        do {
            try await healthKitManager.requestAuthorization()
            print("✅ HealthKit-Berechtigung erfolgreich angefordert")
        } catch {
            print("❌ Fehler bei HealthKit-Berechtigung: \(error)")
            throw error
        }
    }

    func importFromHealthKit(userProfileService: UserProfileService) async throws {
        guard healthKitManager.isAuthorized else {
            print("⚠️ HealthKit nicht autorisiert")
            return
        }

        do {
            let profile = try await healthKitManager.readProfileData()
            print("✅ HealthKit-Profil abgerufen")

            await MainActor.run {
                let currentProfile = userProfileService.userProfile
                userProfileService.updateProfile(
                    name: currentProfile.name.isEmpty ? "Nutzer" : currentProfile.name,
                    birthDate: profile.birthDate ?? currentProfile.birthDate,
                    weight: profile.weight ?? currentProfile.weight,
                    height: profile.height ?? currentProfile.height,
                    biologicalSex: profile.biologicalSex ?? currentProfile.biologicalSex,
                    goal: currentProfile.goal,
                    experience: currentProfile.experience,
                    equipment: currentProfile.equipment,
                    preferredDuration: currentProfile.preferredDuration,
                    healthKitSyncEnabled: true
                )
                print("✅ Profil mit HealthKit-Daten aktualisiert")
            }
        } catch {
            print("❌ Fehler beim Import aus HealthKit: \(error)")
            throw error
        }
    }

    func saveWorkoutToHealthKit(_ workoutSession: WorkoutSession) async throws {
        guard healthKitManager.isAuthorized else {
            print("⚠️ HealthKit nicht autorisiert")
            return
        }

        try await healthKitManager.saveWorkout(workoutSession)
    }

    func readHeartRateData(from startDate: Date, to endDate: Date) async throws -> [HeartRateReading] {
        guard healthKitManager.isAuthorized else { return [] }
        return try await healthKitManager.readHeartRate(from: startDate, to: endDate)
    }

    func readWeightData(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading] {
        guard healthKitManager.isAuthorized else { return [] }
        return try await healthKitManager.readWeight(from: startDate, to: endDate)
    }

    func readBodyFatData(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading] {
        guard healthKitManager.isAuthorized else { return [] }
        return try await healthKitManager.readBodyFat(from: startDate, to: endDate)
    }
}
import Foundation
import HealthKit

/// Service für Herzfrequenz-Tracking während Workouts
@MainActor
class HeartRateTrackingService: ObservableObject {
    // MARK: - Private State

    private var heartRateTracker: HealthKitWorkoutTracker?

    // MARK: - Public API

    func startHeartRateTracking(workoutName: String) {
        guard heartRateTracker == nil else {
            print("⚠️ Herzfrequenz-Tracking läuft bereits")
            return
        }

        let tracker = HealthKitWorkoutTracker()
        tracker.onHeartRateUpdate = { [weak self] heartRate in
            Task { @MainActor in
                WorkoutLiveActivityController.shared.updateHeartRate(workoutName: workoutName, heartRate: heartRate)
            }
        }
        tracker.startTracking()
        heartRateTracker = tracker
        print("✅ Herzfrequenz-Tracking gestartet für Workout: \(workoutName)")
    }

    func stopHeartRateTracking() {
        guard let tracker = heartRateTracker else {
            return
        }

        tracker.stopTracking()
        heartRateTracker = nil
        print("✅ Herzfrequenz-Tracking beendet")
    }
}
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Service für zentrale Rest-Timer Verwaltung
@MainActor
class RestTimerService: ObservableObject {
    // MARK: - Published State

    @Published private(set) var activeRestState: ActiveRestState?

    // MARK: - Private State

    private var restTimer: Timer?
    @AppStorage("restNotificationsEnabled") var restNotificationsEnabled: Bool = true

    // Weak reference to avoid retain cycle
    weak var workoutProvider: WorkoutProviding?

    // MARK: - Supporting Structures

    struct ActiveRestState: Equatable {
        let workoutId: UUID
        let workoutName: String
        let exerciseIndex: Int
        let setIndex: Int
        var remainingSeconds: Int
        var totalSeconds: Int
        var isRunning: Bool
        var endDate: Date?

        static func == (lhs: ActiveRestState, rhs: ActiveRestState) -> Bool {
            lhs.workoutId == rhs.workoutId &&
            lhs.exerciseIndex == rhs.exerciseIndex &&
            lhs.setIndex == rhs.setIndex &&
            lhs.remainingSeconds == rhs.remainingSeconds &&
            lhs.isRunning == rhs.isRunning
        }
    }

    // MARK: - Lifecycle

    init() {}

    deinit {
        restTimer?.invalidate()
        restTimer = nil
        NotificationManager.shared.cancelRestEndNotification()
    }

    // MARK: - Public API

    func startRest(for workout: Workout, exerciseIndex: Int, setIndex: Int, totalSeconds: Int) {
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
        setupRestTimer()
        updateLiveActivityRest()
        if restNotificationsEnabled {
            let exerciseName = (workout.exercises.indices.contains(exerciseIndex) ? workout.exercises[exerciseIndex].exercise.name : nil)
            NotificationManager.shared.scheduleRestEndNotification(
                remainingSeconds: total,
                workoutName: workout.name,
                exerciseName: exerciseName,
                workoutId: workout.id
            )
        }
    }

    func pauseRest() {
        guard var state = activeRestState else { return }
        state.isRunning = false
        state.endDate = nil
        activeRestState = state
        restTimer?.invalidate()
        restTimer = nil
        NotificationManager.shared.cancelRestEndNotification()
        updateLiveActivityRest()
    }

    func resumeRest() {
        guard var state = activeRestState, state.remainingSeconds > 0 else { return }
        state.isRunning = true
        state.endDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        activeRestState = state
        setupRestTimer()
        updateLiveActivityRest()
        if restNotificationsEnabled {
            let exerciseName = getActiveWorkoutExerciseName(at: state.exerciseIndex)
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

        if state.isRunning {
            state.endDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        }

        activeRestState = state
        if state.isRunning { setupRestTimer() }
        updateLiveActivityRest()
        if restNotificationsEnabled {
            let exerciseName = getActiveWorkoutExerciseName(at: state.exerciseIndex)
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

        if state.isRunning {
            state.endDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        }

        activeRestState = state
        if state.isRunning { setupRestTimer() }
        updateLiveActivityRest()
        if restNotificationsEnabled {
            let exerciseName = getActiveWorkoutExerciseName(at: state.exerciseIndex)
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
            WorkoutLiveActivityController.shared.clearRest(workoutName: state.workoutName)
        }
        activeRestState = nil
    }

    func clearRestState() {
        restTimer?.invalidate()
        restTimer = nil
        if let state = activeRestState {
            WorkoutLiveActivityController.shared.clearRest(workoutName: state.workoutName)
        }
        activeRestState = nil
    }

    func refreshRestFromWallClock() {
        guard var state = activeRestState, state.isRunning, let end = state.endDate else {
            return
        }

        let remaining = max(0, Int(floor(end.timeIntervalSinceNow)))
        state.remainingSeconds = remaining

        if remaining <= 0 {
            WorkoutLiveActivityController.shared.showRestEnded(workoutName: state.workoutName)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.clearRestState()
            }
        } else {
            activeRestState = state
            setupRestTimer()
        }
    }

    // MARK: - Private Helpers

    private func setupRestTimer() {
        restTimer?.invalidate()
        restTimer = nil

        guard let state = activeRestState, state.isRunning, state.remainingSeconds > 0 else { return }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickRest()
        }

        if let timer = restTimer {
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tickRest() {
        guard restTimer != nil else {
            print("[RestTimer] ⚠️ tickRest called but timer is nil")
            return
        }

        guard var state = activeRestState, state.isRunning else {
            print("[RestTimer] ⚠️ State invalid or not running - stopping timer")
            restTimer?.invalidate()
            restTimer = nil
            return
        }

        if let end = state.endDate {
            let remaining = max(0, Int(floor(end.timeIntervalSinceNow)))
            let previousRemaining = state.remainingSeconds
            state.remainingSeconds = remaining

            if previousRemaining != remaining {
                activeRestState = state
                updateLiveActivityRest()
            }

            if remaining <= 0 {
                restTimer?.invalidate()
                restTimer = nil

                SoundPlayer.playBoxBell()
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif

                WorkoutLiveActivityController.shared.showRestEnded(workoutName: state.workoutName)

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self.clearRestState()
                }
            }
        } else {
            if state.remainingSeconds > 0 {
                state.remainingSeconds -= 1
                activeRestState = state
                updateLiveActivityRest()
                if state.remainingSeconds <= 0 {
                    restTimer?.invalidate()
                    restTimer = nil

                    SoundPlayer.playBoxBell()
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif

                    WorkoutLiveActivityController.shared.showRestEnded(workoutName: state.workoutName)

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        self.clearRestState()
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
        let exerciseName = getActiveWorkoutExerciseName(at: state.exerciseIndex)
        print("[RestTimer] 📱 Updating LiveActivity: \(state.remainingSeconds)s remaining")
        WorkoutLiveActivityController.shared.updateRest(
            workoutName: state.workoutName,
            exerciseName: exerciseName,
            remainingSeconds: state.remainingSeconds,
            totalSeconds: max(state.totalSeconds, 1),
            endDate: state.endDate
        )
    }

    private func getActiveWorkoutExerciseName(at index: Int) -> String? {
        guard let workout = workoutProvider?.getActiveWorkout() else { return nil }
        return workout.exercises.indices.contains(index) ? workout.exercises[index].exercise.name : nil
    }
}

// MARK: - Protocol for dependency injection

protocol WorkoutProviding: AnyObject {
    func getActiveWorkout() -> Workout?
}
import Foundation
import SwiftData

/// Service für Last-Used Exercise Metrics Management
@MainActor
class LastUsedMetricsService: ObservableObject {
    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Initialization

    init() {}

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Public API

    func updateLastUsedMetrics(from session: WorkoutSession) {
        guard let context = modelContext else { return }

        for workoutExercise in session.exercises {
            let descriptor = FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { $0.id == workoutExercise.exercise.id }
            )

            guard let exerciseEntity = try? context.fetch(descriptor).first else {
                print("⚠️ ExerciseEntity nicht gefunden für: \(workoutExercise.exercise.name)")
                continue
            }

            let completedSets = workoutExercise.sets.filter { $0.completed }
            guard let lastSet = completedSets.last else {
                print("ℹ️ Keine abgeschlossenen Sätze für: \(workoutExercise.exercise.name)")
                continue
            }

            if exerciseEntity.lastUsedDate == nil || session.date > exerciseEntity.lastUsedDate! {
                exerciseEntity.lastUsedWeight = lastSet.weight
                exerciseEntity.lastUsedReps = lastSet.reps
                exerciseEntity.lastUsedSetCount = completedSets.count
                exerciseEntity.lastUsedDate = session.date
                exerciseEntity.lastUsedRestTime = lastSet.restTime

                print("✅ Last-Used aktualisiert für \(exerciseEntity.name): \(lastSet.weight)kg × \(lastSet.reps)")
            }
        }

        do {
            try context.save()
            print("✅ Alle Last-Used Metriken gespeichert")
        } catch {
            print("❌ Fehler beim Speichern der Last-Used Metriken: \(error)")
        }
    }

    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
        )

        guard let entity = try? context.fetch(descriptor).first,
              let weight = entity.lastUsedWeight,
              let setCount = entity.lastUsedSetCount else {
            return legacyLastMetrics(for: exercise)
        }

        return (weight, setCount)
    }

    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
        )

        guard let entity = try? context.fetch(descriptor).first else {
            return nil
        }

        return ExerciseLastUsedMetrics(
            weight: entity.lastUsedWeight,
            reps: entity.lastUsedReps,
            setCount: entity.lastUsedSetCount,
            lastUsedDate: entity.lastUsedDate,
            restTime: entity.lastUsedRestTime
        )
    }

    // MARK: - Private Helpers

    private func legacyLastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []

        for session in sessions {
            if let exerciseData = session.exercises.first(where: { $0.exercise?.id == exercise.id }) {
                let weight = exerciseData.sets.first?.weight ?? 0
                return (weight, exerciseData.sets.count)
            }
        }

        return nil
    }
}

// MARK: - Supporting Structure

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
import Foundation
import SwiftUI
import SwiftData
import HealthKit

/// Hauptkoordinator der alle Services orchestriert
/// Ersetzt schrittweise den monolithischen WorkoutStore
@MainActor
class WorkoutStoreCoordinator: ObservableObject {
    // MARK: - Services

    let cacheService = CacheService()
    let exerciseRepository = ExerciseRepository()
    let workoutRepository = WorkoutRepository()
    let sessionService = SessionService()
    let userProfileService = UserProfileService()
    let healthKitService = HealthKitIntegrationService()
    let heartRateTrackingService = HeartRateTrackingService()
    let restTimerService = RestTimerService()
    let lastUsedMetricsService = LastUsedMetricsService()

    // MARK: - Legacy WorkoutStore (temporär)
    // Enthält noch komplexe Funktionen die noch nicht extrahiert wurden:
    // - Analytics (exerciseStats, muscleVolume, etc.)
    // - Workout Generation
    // - Exercise Migration/Database Updates
    // - Exercise Records
    // - Debug/Testing Functions

    private let legacyStore: WorkoutStore

    // MARK: - Published State (delegiert zu Services)

    @Published var activeSessionID: UUID? {
        didSet {
            sessionService.activeSessionID = activeSessionID
            workoutRepository.activeSessionID = activeSessionID
        }
    }

    @Published var isShowingWorkoutDetail: Bool = false
    @Published var activeRestState: RestTimerService.ActiveRestState?

    var profileUpdateTrigger: UUID {
        userProfileService.profileUpdateTrigger
    }

    var healthKitManager: HealthKitManager {
        healthKitService.healthKitManager
    }

    // MARK: - Context Management

    var modelContext: ModelContext? {
        didSet {
            guard let context = modelContext else { return }

            // Distribute context to all services
            exerciseRepository.setContext(context)
            workoutRepository.setContext(context)
            sessionService.setContext(context)
            userProfileService.setContext(context)
            lastUsedMetricsService.setContext(context)

            exerciseRepository.setCacheService(cacheService)
            workoutRepository.setExerciseRepository(exerciseRepository)

            sessionService.setCacheService(cacheService)
            sessionService.setHealthKitService(healthKitService)
            sessionService.setHeartRateTrackingService(heartRateTrackingService)
            sessionService.setRestTimerService(restTimerService)
            sessionService.setLastUsedMetricsService(lastUsedMetricsService)

            restTimerService.workoutProvider = workoutRepository

            // Also set context for legacy store
            legacyStore.modelContext = context
        }
    }

    // MARK: - Computed Properties

    var exercises: [Exercise] {
        exerciseRepository.exercises
    }

    var workouts: [Workout] {
        workoutRepository.workouts
    }

    var activeWorkout: Workout? {
        workoutRepository.activeWorkout
    }

    var homeWorkouts: [Workout] {
        workoutRepository.homeWorkouts
    }

    var userProfile: UserProfile {
        userProfileService.userProfile
    }

    // MARK: - Initialization

    init() {
        self.legacyStore = WorkoutStore()

        // Sync activeRestState from restTimerService
        self.activeRestState = restTimerService.activeRestState
    }

    deinit {
        // Cleanup handled by individual services
    }

    // MARK: - Exercise Repository Methods

    func addExercise(_ exercise: Exercise) {
        exerciseRepository.addExercise(exercise)
    }

    func updateExercise(_ exercise: Exercise) {
        exerciseRepository.updateExercise(exercise)
    }

    func deleteExercise(at indexSet: IndexSet) {
        exerciseRepository.deleteExercise(at: indexSet)
    }

    func exercise(named name: String) -> Exercise {
        exerciseRepository.exercise(named: name)
    }

    func getSimilarExercises(to exercise: Exercise, count: Int = 10, userLevel: ExperienceLevel? = nil) -> [Exercise] {
        exerciseRepository.getSimilarExercises(to: exercise, count: count, userLevel: userLevel)
    }

    // MARK: - Workout Repository Methods

    func addWorkout(_ workout: Workout) {
        workoutRepository.addWorkout(workout)
    }

    func updateWorkout(_ workout: Workout) {
        workoutRepository.updateWorkout(workout)
    }

    func deleteWorkout(at indexSet: IndexSet) {
        workoutRepository.deleteWorkout(at: indexSet)
    }

    func toggleFavorite(for workoutID: UUID) {
        workoutRepository.toggleFavorite(for: workoutID)
    }

    func toggleHomeFavorite(workoutID: UUID) -> Bool {
        workoutRepository.toggleHomeFavorite(workoutID: workoutID)
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        workoutRepository.previousWorkout(before: workout)
    }

    // MARK: - Session Service Methods

    func startSession(for workoutId: UUID) {
        sessionService.startSession(for: workoutId)
        activeSessionID = workoutId
    }

    func endCurrentSession() {
        sessionService.endCurrentSession()
        activeSessionID = nil
    }

    func recordSession(from workout: Workout) {
        sessionService.recordSession(from: workout, userProfile: userProfile, healthKitManager: healthKitManager)
    }

    func removeSession(with id: UUID) {
        sessionService.removeSession(with: id)
    }

    // MARK: - Profile Service Methods

    func updateProfile(name: String, birthDate: Date?, weight: Double?, height: Double? = nil, biologicalSex: HKBiologicalSex? = nil, goal: FitnessGoal, experience: ExperienceLevel, equipment: EquipmentPreference, preferredDuration: WorkoutDuration, healthKitSyncEnabled: Bool = false, profileImageData: Data? = nil) {
        userProfileService.updateProfile(name: name, birthDate: birthDate, weight: weight, height: height, biologicalSex: biologicalSex, goal: goal, experience: experience, equipment: equipment, preferredDuration: preferredDuration, healthKitSyncEnabled: healthKitSyncEnabled, profileImageData: profileImageData)
    }

    #if canImport(UIKit)
    func updateProfileImage(_ image: UIImage?) {
        userProfileService.updateProfileImage(image)
    }
    #endif

    func updateLockerNumber(_ lockerNumber: String) {
        userProfileService.updateLockerNumber(lockerNumber)
    }

    func markOnboardingStep(hasExploredWorkouts: Bool? = nil, hasCreatedFirstWorkout: Bool? = nil, hasSetupProfile: Bool? = nil) {
        userProfileService.markOnboardingStep(hasExploredWorkouts: hasExploredWorkouts, hasCreatedFirstWorkout: hasCreatedFirstWorkout, hasSetupProfile: hasSetupProfile)
    }

    // MARK: - HealthKit Integration Methods

    func requestHealthKitAuthorization() async throws {
        try await healthKitService.requestHealthKitAuthorization()
    }

    func importFromHealthKit() async throws {
        try await healthKitService.importFromHealthKit(userProfileService: userProfileService)
    }

    func saveWorkoutToHealthKit(_ workoutSession: WorkoutSession) async throws {
        try await healthKitService.saveWorkoutToHealthKit(workoutSession)
    }

    func readHeartRateData(from startDate: Date, to endDate: Date) async throws -> [HeartRateReading] {
        try await healthKitService.readHeartRateData(from: startDate, to: endDate)
    }

    func readWeightData(from startDate: Date, to endDate: Date) async throws -> [BodyWeightReading] {
        try await healthKitService.readWeightData(from: startDate, to: endDate)
    }

    func readBodyFatData(from startDate: Date, to endDate: Date) async throws -> [BodyFatReading] {
        try await healthKitService.readBodyFatData(from: startDate, to: endDate)
    }

    // MARK: - Rest Timer Methods

    func startRest(for workout: Workout, exerciseIndex: Int, setIndex: Int, totalSeconds: Int) {
        restTimerService.startRest(for: workout, exerciseIndex: exerciseIndex, setIndex: setIndex, totalSeconds: totalSeconds)
        activeRestState = restTimerService.activeRestState
    }

    func pauseRest() {
        restTimerService.pauseRest()
        activeRestState = restTimerService.activeRestState
    }

    func resumeRest() {
        restTimerService.resumeRest()
        activeRestState = restTimerService.activeRestState
    }

    func addRest(seconds: Int) {
        restTimerService.addRest(seconds: seconds)
        activeRestState = restTimerService.activeRestState
    }

    func setRest(remaining: Int, total: Int? = nil) {
        restTimerService.setRest(remaining: remaining, total: total)
        activeRestState = restTimerService.activeRestState
    }

    func stopRest() {
        restTimerService.stopRest()
        activeRestState = restTimerService.activeRestState
    }

    func clearRestState() {
        restTimerService.clearRestState()
        activeRestState = restTimerService.activeRestState
    }

    func refreshRestFromWallClock() {
        restTimerService.refreshRestFromWallClock()
        activeRestState = restTimerService.activeRestState
    }

    // MARK: - Last Used Metrics Methods

    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        lastUsedMetricsService.lastMetrics(for: exercise)
    }

    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics? {
        lastUsedMetricsService.completeLastMetrics(for: exercise)
    }

    // MARK: - Cache Management

    func invalidateCaches() {
        cacheService.invalidateCaches()
    }

    // MARK: - Legacy Methods (delegiert an WorkoutStore)
    // Diese Methoden werden später in eigene Services extrahiert

    @AppStorage("weeklyGoal") var weeklyGoal: Int = 5

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

    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)] {
        legacyStore.muscleVolume(byGroupInLastWeeks: weeks)
    }

    func exerciseStats(for exercise: Exercise) -> WorkoutStore.ExerciseStats? {
        legacyStore.exerciseStats(for: exercise)
    }

    func workoutsByDay(in range: ClosedRange<Date>) -> [Date: [WorkoutSession]] {
        legacyStore.workoutsByDay(in: range)
    }

    func generateWorkout(from preferences: WorkoutPreferences) -> Workout {
        legacyStore.generateWorkout(from: preferences)
    }

    func getExerciseRecord(for exercise: Exercise) -> ExerciseRecord? {
        legacyStore.getExerciseRecord(for: exercise)
    }

    func getAllExerciseRecords() -> [ExerciseRecord] {
        legacyStore.getAllExerciseRecords()
    }

    func checkForNewRecord(exercise: Exercise, weight: Double, reps: Int) -> RecordType? {
        legacyStore.checkForNewRecord(exercise: exercise, weight: weight, reps: reps)
    }

    func updateExerciseDatabase() {
        legacyStore.updateExerciseDatabase()
    }

    func resetAllData() async throws {
        try await legacyStore.resetAllData()
    }
}

// MARK: - WorkoutProviding Conformance

extension WorkoutRepository: WorkoutProviding {
    func getActiveWorkout() -> Workout? {
        activeWorkout
    }
}
