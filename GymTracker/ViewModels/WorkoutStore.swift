import Foundation
import SwiftUI
import SwiftData
import HealthKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class WorkoutStore: ObservableObject {
    @Published var activeSessionID: UUID?

    // Zentrale Rest-Timer-State
    struct ActiveRestState {
        let workoutId: UUID
        let workoutName: String
        let exerciseIndex: Int
        let setIndex: Int
        var remainingSeconds: Int
        var totalSeconds: Int
        var isRunning: Bool
        var endDate: Date?
    }

    @Published var activeRestState: ActiveRestState?
    @Published var profileUpdateTrigger: UUID = UUID() // Triggers UI updates when profile changes

    private var restTimer: Timer?
    private var exerciseStatsCache: [UUID: ExerciseStats] = [:]
    private var weekStreakCache: (date: Date, value: Int)?
    @AppStorage("weeklyGoal") var weeklyGoal: Int = 5
    @AppStorage("restNotificationsEnabled") var restNotificationsEnabled: Bool = true

    // SwiftData context reference (wird von ContentView gesetzt)
    var modelContext: ModelContext?
    
    // HealthKit integration
    @Published var healthKitManager = HealthKitManager.shared

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
                // Clear the invalid activeSessionID
                self.activeSessionID = nil
                return nil
            }
        } catch {
            print("❌ Fehler beim Laden des aktiven Workouts: \(error)")
            return nil
        }
    }

    var userProfile: UserProfile {
        guard let context = modelContext else { 
            // Fallback: Load from UserDefaults if SwiftData isn't available
            return ProfilePersistenceHelper.loadFromUserDefaults()
        }
        let descriptor = FetchDescriptor<UserProfileEntity>()
        if let entity = try? context.fetch(descriptor).first {
            let profile = UserProfile(entity: entity)
            // Always keep UserDefaults as backup
            ProfilePersistenceHelper.saveToUserDefaults(profile)
            return profile
        }
        
        // Try to restore from UserDefaults backup
        let backupProfile = ProfilePersistenceHelper.loadFromUserDefaults()
        if !backupProfile.name.isEmpty || backupProfile.weight != nil {
            // Restore to SwiftData
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
                healthKitSyncEnabled: backupProfile.healthKitSyncEnabled
            )
            print("✅ Profil aus UserDefaults-Backup wiederhergestellt")
            return backupProfile
        }
        
        return UserProfile()
    }

    // MARK: - Active Session Management
    
    init() {}
    
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
                
                for exercise in workout.exercises {
                    for set in exercise.sets {
                        set.completed = false
                    }
                }
                
                try context.save()
                activeSessionID = workoutId
                print("✅ Session gestartet für Workout: \(workout.name)")
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

        let groups: [MuscleGroup] = validSource.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
        let equipmentType = EquipmentType(rawValue: validSource.equipmentTypeRaw) ?? .mixed
        
        return Exercise(
            id: validSource.id,
            name: validSource.name,
            muscleGroups: groups,
            equipmentType: equipmentType,
            description: validSource.descriptionText,
            instructions: validSource.instructions,
            createdAt: validSource.createdAt
        )
    }

    private func mapWorkoutEntity(_ entity: WorkoutEntity) -> Workout {
        let exercises: [WorkoutExercise] = entity.exercises.compactMap { we in
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
        let descriptor = FetchDescriptor<ExerciseEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { mapExerciseEntity($0) }
    }

    private func getSessionHistory() -> [WorkoutSession] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { WorkoutSession(entity: $0) }
    }



    func addExercise(_ exercise: Exercise) {
        guard let context = modelContext else { return }
        
        // Check if exercise already exists by ID first
        let idDescriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { $0.id == exercise.id }
        )
        
        if (try? context.fetch(idDescriptor).first) != nil {
            return // Exercise already exists
        }
        
        // Check by name using case-insensitive comparison
        let nameDescriptor = FetchDescriptor<ExerciseEntity>()
        let allExercises = (try? context.fetch(nameDescriptor)) ?? []
        
        if allExercises.contains(where: { $0.name.localizedCaseInsensitiveCompare(exercise.name) == .orderedSame }) {
            return // Exercise with same name already exists
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
        
        if let existing = allExercises.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return mapExerciseEntity(existing)
        }

        let newExercise = Exercise(name: name, muscleGroups: [], equipmentType: .mixed, description: "")
        let entity = ExerciseEntity.make(from: newExercise)
        context.insert(entity)
        try? context.save()
        return newExercise
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        let sessionHistory = getSessionHistory()
        return sessionHistory
            .filter { $0.templateId == workout.id }
            .sorted { $0.date > $1.date }
            .first
            .map(Workout.init(session:))
    }

    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
        let sessionHistory = getSessionHistory()
        let sortedSessions = sessionHistory.sorted { $0.date > $1.date }

        for workout in sortedSessions {
            if let workoutExercise = workout.exercises.first(where: { $0.exercise.id == exercise.id }) {
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
            let session = WorkoutSession(
                templateId: workout.id,
                name: workout.name,
                date: workout.date,
                exercises: workout.exercises,
                defaultRestTime: workout.defaultRestTime,
                duration: workout.duration,
                notes: workout.notes
            )
            
            try DataManager.shared.recordSession(session, to: context)
            invalidateCaches() // stats/streak may change
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
    func updateProfile(name: String, birthDate: Date?, weight: Double?, height: Double? = nil, biologicalSex: HKBiologicalSex? = nil, goal: FitnessGoal, experience: ExperienceLevel, equipment: EquipmentPreference, preferredDuration: WorkoutDuration, healthKitSyncEnabled: Bool = false) {
        // Create updated profile
        let updatedProfile = UserProfile(
            name: name,
            birthDate: birthDate,
            weight: weight,
            height: height,
            biologicalSex: biologicalSex,
            goal: goal,
            profileImageData: userProfile.profileImageData, // Keep existing image
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
            entity.biologicalSexRaw = Int16(biologicalSex?.rawValue ?? HKBiologicalSex.notSet.rawValue)
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
    
    // MARK: - HealthKit Integration
    
    func requestHealthKitAuthorization() async throws {
        try await healthKitManager.requestAuthorization()
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
            profileUpdateTrigger = UUID()
            
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
            return // User has not enabled HealthKit sync
        }
        
        try await healthKitManager.saveWorkout(workoutSession)
    }
    
    func readHeartRateData(from startDate: Date, to endDate: Date) async throws -> [HeartRateReading] {
        guard healthKitManager.isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        return try await healthKitManager.readHeartRate(from: startDate, to: endDate)
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

    // MARK: - Zentrale Rest-Timer Steuerung

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
        state.endDate = nil // Wichtig: endDate zurücksetzen beim Pausieren
        activeRestState = state
        restTimer?.invalidate() // Timer stoppen
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
            let exerciseName: String? = activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true ? 
                activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
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
            let exerciseName: String? = activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true ? 
                activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
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
            let exerciseName: String? = activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true ? 
                activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
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

    private func setupRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        
        guard let state = activeRestState, state.isRunning, state.remainingSeconds > 0 else { return }
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickRest()
            }
        }
        
        if let timer = restTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tickRest() {
        guard var state = activeRestState, state.isRunning else { return }
        if let end = state.endDate {
            let remaining = max(0, Int(floor(end.timeIntervalSinceNow)))
            state.remainingSeconds = remaining
            activeRestState = state
            updateLiveActivityRest()
            if remaining <= 0 {
                SoundPlayer.playBoxBell()
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                WorkoutLiveActivityController.shared.showRestEnded(workoutName: state.workoutName)
                stopRest()
            }
        } else {
            // Fallback: decrement by one
            if state.remainingSeconds > 0 {
                state.remainingSeconds -= 1
                activeRestState = state
                updateLiveActivityRest()
                if state.remainingSeconds <= 0 {
                    SoundPlayer.playBoxBell()
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                    WorkoutLiveActivityController.shared.showRestEnded(workoutName: state.workoutName)
                    stopRest()
                }
            } else {
                stopRest()
            }
        }
    }

    private func updateLiveActivityRest() {
        guard let state = activeRestState else { return }
        let exerciseName: String? = activeWorkout?.exercises.indices.contains(state.exerciseIndex) == true ? 
            activeWorkout?.exercises[state.exerciseIndex].exercise.name : nil
        WorkoutLiveActivityController.shared.updateRest(
            workoutName: state.workoutName,
            exerciseName: exerciseName,
            remainingSeconds: state.remainingSeconds,
            totalSeconds: max(state.totalSeconds, 1)
        )
    }

    // Refresh rest timer from wall clock (for example after app resumes from background)
    func refreshRestFromWallClock() {
        guard var state = activeRestState, state.isRunning, let end = state.endDate else { 
            return 
        }
        
        let remaining = max(0, Int(floor(end.timeIntervalSinceNow)))
        state.remainingSeconds = remaining
        activeRestState = state
        
        if remaining <= 0 {
            // If already elapsed while in background, just stop without duplicating sounds
            stopRest()
        } else {
            // Only setup timer if we still have remaining time
            setupRestTimer()
        }
    }

    // MARK: - Cache Management

    private func invalidateCaches() {
        exerciseStatsCache.removeAll()
        weekStreakCache = nil
    }
    
    // MARK: - Sample Data Management
    func resetToSampleData() {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Reset zu Sample-Daten")
            return
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            
            // Alle bestehenden Workouts löschen, aber Übungen beibehalten
            do {
                let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
                let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
                
                // Lösche alle Workouts und Sessions
                for workout in workouts {
                    context.delete(workout)
                }
                for session in sessions {
                    context.delete(session)
                }
                
                try context.save()
                print("🗑️ Bestehende Workouts und Sessions gelöscht")
                
                // Lade Sample-Workouts neu
                await DataManager.shared.ensureSampleData(context: context)
                
                // Aktive Session zurücksetzen
                await MainActor.run { [weak self] in
                    self?.activeSessionID = nil
                }
                
                print("✅ Neue Sample-Workouts erfolgreich geladen!")
                
            } catch {
                print("❌ Fehler beim Reset zu Sample-Daten: \(error)")
            }
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
                    print("  - \(workout.name) (ID: \(workout.id.uuidString.prefix(8)), Übungen: \(workout.exercises.count))")
                }
                
                print("Gespeicherte Übungen: \(exercises.count)")
                for exercise in exercises.prefix(10) {
                    print("  - \(exercise.name) (ID: \(exercise.id.uuidString.prefix(8)))")
                }
                
                print("Sessions: \(sessions.count)")
                for session in sessions.prefix(3) {
                    print("  - \(session.name) (Datum: \(session.date.formatted(.dateTime.day().month())))")
                }
            } catch {
                print("❌ Fehler beim Abrufen der Debug-Daten: \(error)")
            }
        }
        print("========================")
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
        getSessionHistory().count
    }

    var averageWorkoutsPerWeek: Double {
        let sessionHistory = getSessionHistory()
        guard let earliestDate = sessionHistory.min(by: { $0.date < $1.date })?.date else { return 0 }
        let span = max(Date().timeIntervalSince(earliestDate), 1)
        let weeks = max(span / (7 * 24 * 60 * 60), 1)
        return Double(sessionHistory.count) / weeks
    }

    var currentWeekStreak: Int {
        let today = Date()
        let calendar = Calendar.current

        // Cache prüfen
        if let cached = weekStreakCache,
           calendar.isDate(cached.date, equalTo: today, toGranularity: .day) {
            return cached.value
        }

        let sessionHistory = getSessionHistory()
        guard !sessionHistory.isEmpty else {
            weekStreakCache = (today, 0)
            return 0
        }

        let weekStarts: Set<Date> = Set(sessionHistory.compactMap { session in
            calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date))
        })

        guard var cursor = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            weekStreakCache = (today, 0)
            return 0
        }

        var streak = 0
        while weekStarts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }

        // Cache aktualisieren
        weekStreakCache = (today, streak)
        return streak
    }

    var averageDurationMinutes: Int {
        let sessionHistory = getSessionHistory()
        let durations = sessionHistory.compactMap { $0.duration }
        guard !durations.isEmpty else { return 0 }
        let total = durations.reduce(0, +)
        return Int(total / Double(durations.count) / 60)
    }

    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)] {
        let calendar = Calendar.current
        let threshold = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()

        let sessionHistory = getSessionHistory()
        let filtered = sessionHistory.filter { $0.date >= threshold }
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
            let oneRepMax = sets.map { estimateOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? maxSetWeight

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
        let selectedExercises = selectExercises(for: preferences, targeting: muscleGroups, from: exercises)
        let workoutExercises = createWorkoutExercises(from: selectedExercises, preferences: preferences)

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

    private func selectExercises(for preferences: WorkoutPreferences, targeting muscleGroups: [MuscleGroup], from exercises: [Exercise]) -> [Exercise] {
        var selectedExercises: [Exercise] = []
        let availableExercises = filterExercisesByEquipment(preferences.equipment, from: exercises)

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

        // Wähle Compound-Übungen
        for muscleGroup in muscleGroups.prefix(compoundCount) {
            if let exercise = compoundExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup) && !selectedExercises.contains(where: { $0.id == exercise.id })
            }) {
                selectedExercises.append(exercise)
            }
        }

        // Fülle mit Isolation-Übungen auf
        for muscleGroup in muscleGroups.prefix(isolationCount) {
            if let exercise = isolationExercises.first(where: { exercise in
                exercise.muscleGroups.contains(muscleGroup) && !selectedExercises.contains(where: { $0.id == exercise.id })
            }) {
                selectedExercises.append(exercise)
            }
        }

        // Stelle sicher, dass wir genug Übungen haben
        while selectedExercises.count < targetExerciseCount && selectedExercises.count < availableExercises.count {
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

    private func filterExercisesByEquipment(_ equipment: EquipmentPreference, from exercises: [Exercise]) -> [Exercise] {
        switch equipment {
        case .freeWeights:
            return exercises.filter { exercise in
                !exercise.name.lowercased().contains("maschine") &&
                !exercise.name.lowercased().contains("machine")
            }
        case .machines:
            return exercises.filter { exercise in
                exercise.name.lowercased().contains("maschine") ||
                exercise.name.lowercased().contains("machine")
            }
        case .mixed:
            return exercises
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

    private func createWorkoutExercises(from exercises: [Exercise], preferences: WorkoutPreferences) -> [WorkoutExercise] {
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
}

