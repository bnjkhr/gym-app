import Foundation
import SwiftUI

@MainActor
class WorkoutStore: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var workouts: [Workout] = []
    @Published var sessionHistory: [WorkoutSession] = []
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
    }

    @Published var activeRestState: ActiveRestState?

    private var persistenceTimer: Timer?
    private var restTimer: Timer?
    private var exerciseStatsCache: [UUID: ExerciseStats] = [:]
    private var weekStreakCache: (date: Date, value: Int)?
    @AppStorage("weeklyGoal") var weeklyGoal: Int = 5

    var activeWorkout: Workout? {
        guard let activeSessionID else { return nil }
        return workouts.first { $0.id == activeSessionID }
    }

    init() {
        if !loadFromDisk() {
            loadSampleData()
            persistExercises()
            persistWorkouts()
            persistSessions()
        }
    }

    func resetToSampleData() {
        loadSampleData()
        invalidateCaches()
        schedulePersistence()
    }

    func addExercise(_ exercise: Exercise) {
        guard !exercises.contains(where: { $0.id == exercise.id || $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame }) else { return }
        exercises.append(exercise)
        invalidateCaches()
        schedulePersistence()
    }

    func updateExercise(_ exercise: Exercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[index] = exercise

        workouts = workouts.map { workout in
            var updatedWorkout = workout
            updatedWorkout.exercises = workout.exercises.map { workoutExercise in
                var mutableExercise = workoutExercise
                if workoutExercise.exercise.id == exercise.id {
                    mutableExercise.exercise = exercise
                }
                return mutableExercise
            }
            return updatedWorkout
        }

        // invalidate cache for this exercise id (name/metadata may be used by UI)
        exerciseStatsCache[exercise.id] = nil
        schedulePersistence()
    }

    func addWorkout(_ workout: Workout) {
        workouts.insert(workout, at: 0)
        schedulePersistence()
    }

    func updateWorkout(_ workout: Workout) {
        guard let index = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        workouts[index] = workout
        schedulePersistence()
    }

    func exercise(named name: String) -> Exercise {
        if let existing = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }

        let newExercise = Exercise(name: name, muscleGroups: [], description: "")
        exercises.append(newExercise)
        schedulePersistence()
        return newExercise
    }

    func previousWorkout(before workout: Workout) -> Workout? {
        sessionHistory
            .filter { $0.templateId == workout.id }
            .sorted { $0.date > $1.date }
            .first
            .map(Workout.init(session:))
    }

    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? {
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
        let removedExercises = indexSet.map { exercises[$0] }
        exercises.remove(atOffsets: indexSet)

        workouts = workouts.map { workout in
            var updatedWorkout = workout
            updatedWorkout.exercises.removeAll { workoutExercise in
                removedExercises.contains(where: { $0.id == workoutExercise.exercise.id })
            }
            return updatedWorkout
        }

        // Invalidate caches for removed exercise IDs
        for ex in removedExercises {
            exerciseStatsCache[ex.id] = nil
        }
        schedulePersistence()
    }

    func deleteWorkout(at indexSet: IndexSet) {
        workouts.remove(atOffsets: indexSet)
        schedulePersistence()
    }

    func recordSession(from workout: Workout) {
        let session = WorkoutSession(
            templateId: workout.id,
            name: workout.name,
            date: workout.date,
            exercises: workout.exercises,
            defaultRestTime: workout.defaultRestTime,
            duration: workout.duration,
            notes: workout.notes
        )
        sessionHistory.insert(session, at: 0)
        invalidateCaches() // stats/streak may change
        schedulePersistence()
    }

    func removeSession(with id: UUID) {
        sessionHistory.removeAll { $0.id == id }
        invalidateCaches()
        schedulePersistence()
    }

    // MARK: - Favorites

    func toggleFavorite(for workoutID: UUID) {
        guard let index = workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        workouts[index].isFavorite.toggle()
        // Move favorites to top while preserving relative order
        workouts = workouts.stablePartition { $0.isFavorite }
        schedulePersistence()
    }

    // MARK: - Zentrale Rest-Timer Steuerung

    func startRest(for workout: Workout, exerciseIndex: Int, setIndex: Int, totalSeconds: Int) {
        let total = max(totalSeconds, 0)
        activeRestState = ActiveRestState(
            workoutId: workout.id,
            workoutName: workout.name,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            remainingSeconds: total,
            totalSeconds: total,
            isRunning: total > 0
        )
        setupRestTimer()
        updateLiveActivityRest()
    }

    func pauseRest() {
        guard var state = activeRestState else { return }
        state.isRunning = false
        activeRestState = state
        updateLiveActivityRest()
    }

    func resumeRest() {
        guard var state = activeRestState, state.remainingSeconds > 0 else { return }
        state.isRunning = true
        activeRestState = state
        setupRestTimer()
        updateLiveActivityRest()
    }

    func addRest(seconds: Int) {
        guard var state = activeRestState else { return }
        state.remainingSeconds = max(0, state.remainingSeconds + seconds)
        activeRestState = state
        if state.isRunning { setupRestTimer() }
        updateLiveActivityRest()
    }

    func setRest(remaining: Int, total: Int? = nil) {
        guard var state = activeRestState else { return }
        state.remainingSeconds = max(0, remaining)
        if let total { state.totalSeconds = max(1, total) }
        activeRestState = state
        if state.isRunning { setupRestTimer() }
        updateLiveActivityRest()
    }

    func stopRest() {
        restTimer?.invalidate()
        restTimer = nil
        if let state = activeRestState {
            WorkoutLiveActivityController.shared.clearRest(workoutName: state.workoutName)
        }
        activeRestState = nil
    }

    private func setupRestTimer() {
        restTimer?.invalidate()
        guard let state = activeRestState, state.isRunning, state.remainingSeconds > 0 else { return }
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickRest()
            }
        }
        RunLoop.main.add(restTimer!, forMode: .common)
    }

    private func tickRest() {
        guard var state = activeRestState, state.isRunning else { return }
        if state.remainingSeconds > 0 {
            state.remainingSeconds -= 1
            activeRestState = state
            updateLiveActivityRest()
            if state.remainingSeconds <= 0 {
                SoundPlayer.playBoxBell()
                stopRest()
            }
        } else {
            stopRest()
        }
    }

    private func updateLiveActivityRest() {
        guard let state = activeRestState else { return }
        WorkoutLiveActivityController.shared.updateRest(
            workoutName: state.workoutName,
            remainingSeconds: state.remainingSeconds,
            totalSeconds: max(state.totalSeconds, 1)
        )
    }

    // MARK: - Persistence Sammellogik

    private func schedulePersistence() {
        persistenceTimer?.invalidate()
        persistenceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.global(qos: .background).async {
                self.persistAllData()
            }
        }
    }

    func flushPersistence() {
        persistenceTimer?.invalidate()
        persistenceTimer = nil
        DispatchQueue.global(qos: .background).async {
            self.persistAllData()
        }
    }

    private func persistAllData() {
        persistExercises()
        persistWorkouts()
        persistSessions()
    }

    private func invalidateCaches() {
        exerciseStatsCache.removeAll()
        weekStreakCache = nil
    }

    private func loadSampleData() {
        let sampleExercises = [
            // BRUST (Chest)
            Exercise(name: "Bankdrücken", muscleGroups: [.chest, .triceps, .shoulders], description: "Klassisches Bankdrücken mit Langhantel"),
            Exercise(name: "Kurzhantel Bankdrücken", muscleGroups: [.chest, .triceps, .shoulders], description: "Bankdrücken mit Kurzhanteln für größeren Bewegungsradius"),
            Exercise(name: "Schrägbankdrücken", muscleGroups: [.chest, .triceps, .shoulders], description: "Bankdrücken auf schräger Bank für obere Brust"),
            Exercise(name: "Chest Press (Maschine)", muscleGroups: [.chest, .triceps], description: "Maschinen-gestützte Brustpresse"),
            Exercise(name: "Chest Fly (Maschine)", muscleGroups: [.chest], description: "Fly-Maschine für definierte Brustmuskulatur"),
            Exercise(name: "Kurzhantel Fliegende", muscleGroups: [.chest], description: "Fliegende Bewegung mit Kurzhanteln"),
            Exercise(name: "Dips", muscleGroups: [.chest, .triceps, .shoulders], description: "Eigengewicht-Übung für untere Brust"),
            Exercise(name: "Push-ups", muscleGroups: [.chest, .triceps, .shoulders], description: "Klassische Liegestütze"),

            // RÜCKEN (Back)
            Exercise(name: "Klimmzüge", muscleGroups: [.back, .biceps], description: "Klassische Klimmzüge im Obergriff"),
            Exercise(name: "Lat Pulldown (Maschine)", muscleGroups: [.back, .biceps], description: "Latzug-Maschine mit Fokus auf den breiten Rücken"),
            Exercise(name: "Rudern (Langhantel)", muscleGroups: [.back, .biceps], description: "Vorgebeugtes Rudern mit Langhantel"),
            Exercise(name: "Kurzhantel Rudern", muscleGroups: [.back, .biceps], description: "Einarmiges Kurzhantel-Rudern"),
            Exercise(name: "Seated Row (Maschine)", muscleGroups: [.back, .biceps], description: "Rudermaschine für den mittleren Rücken"),
            Exercise(name: "Cable Row", muscleGroups: [.back, .biceps], description: "Kabel-Rudern für mittleren Rücken"),
            Exercise(name: "T-Bar Row", muscleGroups: [.back, .biceps], description: "T-Bar Rudern für dicken Rücken"),
            Exercise(name: "Kreuzheben", muscleGroups: [.back, .legs, .glutes], description: "Deadlift - King of all exercises"),
            Exercise(name: "Back Extension (Maschine)", muscleGroups: [.back, .glutes], description: "Rückenstrecker an der Maschine"),

            // SCHULTERN (Shoulders)
            Exercise(name: "Schulterdrücken", muscleGroups: [.shoulders, .triceps], description: "Military Press mit Langhantel"),
            Exercise(name: "Kurzhantel Schulterdrücken", muscleGroups: [.shoulders, .triceps], description: "Schulterdrücken mit Kurzhanteln"),
            Exercise(name: "Seitheben", muscleGroups: [.shoulders], description: "Seitliches Heben für mittlere Schulter"),
            Exercise(name: "Frontheben", muscleGroups: [.shoulders], description: "Frontheben für vordere Schulter"),
            Exercise(name: "Reverse Fly", muscleGroups: [.shoulders, .back], description: "Umgekehrte Flys für hintere Schulter"),
            Exercise(name: "Aufrechtes Rudern", muscleGroups: [.shoulders, .back], description: "Upright Row für Schultern und Trapez"),
            Exercise(name: "Face Pulls", muscleGroups: [.shoulders, .back], description: "Kabel Face Pulls für hintere Schulter"),

            // BEINE (Legs)
            Exercise(name: "Kniebeugen", muscleGroups: [.legs, .glutes], description: "Squats - Die Königsübung für Beine"),
            Exercise(name: "Leg Press (Maschine)", muscleGroups: [.legs, .glutes], description: "Kraftvolle Beinpressen-Session"),
            Exercise(name: "Ausfallschritte", muscleGroups: [.legs, .glutes], description: "Lunges für funktionelle Beinkraft"),
            Exercise(name: "Leg Extension (Maschine)", muscleGroups: [.legs], description: "Quadrizeps-Isolation an der Maschine"),
            Exercise(name: "Leg Curl (sitzend, Maschine)", muscleGroups: [.legs, .glutes], description: "Beincurl sitzend für hintere Oberschenkel"),
            Exercise(name: "Bulgarische Kniebeugen", muscleGroups: [.legs, .glutes], description: "Bulgarian Split Squats"),
            Exercise(name: "Sumo Squats", muscleGroups: [.legs, .glutes], description: "Breite Kniebeugen für Innenseite"),
            Exercise(name: "Rumänisches Kreuzheben", muscleGroups: [.legs, .glutes, .back], description: "RDL für hintere Kette"),
            Exercise(name: "Wadenheben (Maschine)", muscleGroups: [.legs], description: "Gezieltes Wadenheben an der Maschine"),
            Exercise(name: "Wadenheben sitzend", muscleGroups: [.legs], description: "Seated Calf Raises"),

            // BIZEPS (Biceps)
            Exercise(name: "Bizeps Curls", muscleGroups: [.biceps], description: "Klassische Bizeps-Curls mit Langhantel"),
            Exercise(name: "Kurzhantel Curls", muscleGroups: [.biceps], description: "Bizeps-Curls mit Kurzhanteln"),
            Exercise(name: "Hammer Curls", muscleGroups: [.biceps], description: "Hammer-Curls für Bizeps und Unterarm"),
            Exercise(name: "Cable Curls", muscleGroups: [.biceps], description: "Bizeps-Curls am Kabelzug"),
            Exercise(name: "Preacher Curls", muscleGroups: [.biceps], description: "Bizeps-Curls an der Scott-Bank"),
            Exercise(name: "Concentration Curls", muscleGroups: [.biceps], description: "Konzentrations-Curls für Isolation"),

            // TRIZEPS (Triceps)
            Exercise(name: "Trizeps Dips", muscleGroups: [.triceps, .chest], description: "Dips für Trizeps-Entwicklung"),
            Exercise(name: "Close-Grip Bankdrücken", muscleGroups: [.triceps, .chest], description: "Enge Bankdrücken für Trizeps"),
            Exercise(name: "Trizeps Pushdowns", muscleGroups: [.triceps], description: "Trizeps-Drücken am Kabelzug"),
            Exercise(name: "Overhead Extension", muscleGroups: [.triceps], description: "Trizeps-Strecken über Kopf"),
            Exercise(name: "Kurzhantel Trizeps Extension", muscleGroups: [.triceps], description: "French Press mit Kurzhanteln"),
            Exercise(name: "Diamond Push-ups", muscleGroups: [.triceps, .chest], description: "Enge Liegestütze für Trizeps"),

            // BAUCH (Abs)
            Exercise(name: "Plank", muscleGroups: [.abs], description: "Planke für Core-Stabilität"),
            Exercise(name: "Crunch (Maschine)", muscleGroups: [.abs], description: "Crunch-Maschine für Core-Stabilität"),
            Exercise(name: "Crunches", muscleGroups: [.abs], description: "Klassische Bauchpressen"),
            Exercise(name: "Russian Twists", muscleGroups: [.abs], description: "Russische Drehungen für seitliche Bauchmuskeln"),
            Exercise(name: "Leg Raises", muscleGroups: [.abs], description: "Beinheben für unteren Bauch"),
            Exercise(name: "Mountain Climbers", muscleGroups: [.abs, .cardio], description: "Bergsteiger für Core und Cardio"),
            Exercise(name: "Dead Bug", muscleGroups: [.abs], description: "Dead Bug für Core-Stabilität"),
            Exercise(name: "Bicycle Crunches", muscleGroups: [.abs], description: "Fahrrad-Crunches für schräge Bauchmuskeln"),
            Exercise(name: "Hanging Leg Raises", muscleGroups: [.abs], description: "Hängendes Beinheben"),

            // CARDIO
            Exercise(name: "Laufband", muscleGroups: [.cardio, .legs], description: "Ausdauertraining auf dem Laufband"),
            Exercise(name: "Crosstrainer", muscleGroups: [.cardio], description: "Elliptical Training für Ganzkörper-Cardio"),
            Exercise(name: "Fahrrad", muscleGroups: [.cardio, .legs], description: "Ergometer-Training"),
            Exercise(name: "Rudergerät", muscleGroups: [.cardio, .back, .legs], description: "Rudern für Cardio und Kraft"),
            Exercise(name: "Burpees", muscleGroups: [.cardio, .chest, .legs], description: "Explosive Ganzkörper-Übung"),
            Exercise(name: "Battle Ropes", muscleGroups: [.cardio, .shoulders, .abs], description: "Seil-Training für explosive Kraft"),
            Exercise(name: "Box Jumps", muscleGroups: [.cardio, .legs], description: "Sprungtraining auf Box"),

            // COMPOUND MOVEMENTS
            Exercise(name: "Thrusters", muscleGroups: [.legs, .shoulders, .cardio], description: "Kniebeuge zu Schulterdrücken"),
            Exercise(name: "Clean & Press", muscleGroups: [.legs, .back, .shoulders], description: "Reißen und Drücken"),
            Exercise(name: "Turkish Get-ups", muscleGroups: [.abs, .shoulders, .legs], description: "Komplexe Aufsteh-Bewegung")
        ]

        exercises = sampleExercises

        let chestPressIndex = sampleExercises.firstIndex { $0.name == "Chest Press (Maschine)" } ?? 0
        let chestFlyIndex = sampleExercises.firstIndex { $0.name == "Chest Fly (Maschine)" } ?? 0
        let legPressIndex = sampleExercises.firstIndex { $0.name == "Leg Press (Maschine)" } ?? 0
        let legExtensionIndex = sampleExercises.firstIndex { $0.name == "Leg Extension (Maschine)" } ?? 0
        let legCurlIndex = sampleExercises.firstIndex { $0.name == "Leg Curl (sitzend, Maschine)" } ?? 0
        let calfRaiseIndex = sampleExercises.firstIndex { $0.name == "Wadenheben (Maschine)" } ?? 0
        let crunchIndex = sampleExercises.firstIndex { $0.name == "Crunch (Maschine)" } ?? 0
        let latPulldownIndex = sampleExercises.firstIndex { $0.name == "Lat Pulldown (Maschine)" } ?? 0
        let seatedRowIndex = sampleExercises.firstIndex { $0.name == "Seated Row (Maschine)" } ?? 0
        let backExtensionIndex = sampleExercises.firstIndex { $0.name == "Back Extension (Maschine)" } ?? 0

        workouts = [
            Workout(
                name: "Tag A – Push",
                exercises: [
                    WorkoutExercise(
                        exercise: sampleExercises[chestPressIndex], // Chest Press (Maschine)
                        sets: presetSets(reps: 11, range: "10-12", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[chestFlyIndex], // Chest Fly (Maschine)
                        sets: presetSets(reps: 11, range: "10-12", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[legPressIndex], // Leg Press (Maschine)
                        sets: presetSets(reps: 11, range: "10-12", count: 4)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[legExtensionIndex], // Leg Extension (Maschine)
                        sets: presetSets(reps: 13, range: "12-15", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[calfRaiseIndex], // Wadenheben (Maschine)
                        sets: presetSets(reps: 17, range: "15-20", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[crunchIndex], // Crunch (Maschine)
                        sets: presetSets(reps: 17, range: "15-20", count: 3)
                    )
                ],
                defaultRestTime: 90,
                notes: "Push-orientiertes Maschinen-Workout"
            ),
            Workout(
                name: "Tag B – Pull",
                exercises: [
                    WorkoutExercise(
                        exercise: sampleExercises[latPulldownIndex], // Lat Pulldown (Maschine)
                        sets: presetSets(reps: 11, range: "10-12", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[seatedRowIndex], // Seated Row (Maschine)
                        sets: presetSets(reps: 11, range: "10-12", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[legCurlIndex], // Leg Curl (sitzend, Maschine)
                        sets: presetSets(reps: 13, range: "12-15", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[legPressIndex], // Leg Press (Maschine, leichter)
                        sets: presetSets(reps: 13, range: "12-15", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[backExtensionIndex], // Back Extension (Maschine)
                        sets: presetSets(reps: 13, range: "12-15", count: 3)
                    ),
                    WorkoutExercise(
                        exercise: sampleExercises[crunchIndex], // Crunch (Maschine)
                        sets: presetSets(reps: 17, range: "15-20", count: 3)
                    )
                ],
                defaultRestTime: 90,
                notes: "Pull-orientiertes Maschinen-Workout"
            ),
            Workout(
                name: "Tag C – Ganzkörper & Core",
                exercises: [
                    WorkoutExercise(exercise: sampleExercises[chestPressIndex], sets: presetSets(reps: 11, range: "10-12", count: 3)), // Chest Press (Maschine)
                    WorkoutExercise(exercise: sampleExercises[latPulldownIndex], sets: presetSets(reps: 11, range: "10-12", count: 3)), // Lat Pulldown (Maschine)
                    WorkoutExercise(exercise: sampleExercises[seatedRowIndex], sets: presetSets(reps: 11, range: "10-12", count: 2)), // Seated Row (Maschine)
                    WorkoutExercise(exercise: sampleExercises[legPressIndex], sets: presetSets(reps: 11, range: "10-12", count: 4)), // Leg Press (Maschine)
                    WorkoutExercise(exercise: sampleExercises[legCurlIndex], sets: presetSets(reps: 13, range: "12-15", count: 2)), // Leg Curl (sitzend, Maschine)
                    WorkoutExercise(exercise: sampleExercises[legExtensionIndex], sets: presetSets(reps: 13, range: "12-15", count: 2)), // Leg Extension (Maschine)
                    WorkoutExercise(exercise: sampleExercises[calfRaiseIndex], sets: presetSets(reps: 17, range: "15-20", count: 3)), // Wadenheben (Maschine)
                    WorkoutExercise(exercise: sampleExercises[crunchIndex], sets: presetSets(reps: 17, range: "15-20", count: 3)), // Crunch (Maschine)
                    WorkoutExercise(exercise: sampleExercises[backExtensionIndex], sets: presetSets(reps: 13, range: "12-15", count: 2))  // Back Extension (Maschine)
                ],
                defaultRestTime: 90,
                notes: "Ganzkörperfokus mit Core-Finisher"
            )
        ]
    }

    private func presetSets(reps: Int, range _: String, count: Int) -> [ExerciseSet] {
        (0..<count).map { _ in
            ExerciseSet(reps: reps, weight: 0, restTime: 90, completed: false)
        }
    }

    // MARK: - Persistence

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var exercisesURL: URL { documentsDirectory.appendingPathComponent("exercises.json") }
    private var workoutsURL: URL { documentsDirectory.appendingPathComponent("workouts.json") }
    private var sessionsURL: URL { documentsDirectory.appendingPathComponent("sessions.json") }

    private func loadFromDisk() -> Bool {
        do {
            let exerciseData = try Data(contentsOf: exercisesURL)
            let workoutData = try Data(contentsOf: workoutsURL)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            exercises = try decoder.decode([Exercise].self, from: exerciseData)
            workouts = try decoder.decode([Workout].self, from: workoutData)

            if let sessionData = try? Data(contentsOf: sessionsURL) {
                sessionHistory = try decoder.decode([WorkoutSession].self, from: sessionData)
            } else {
                sessionHistory = []
            }

            return true
        } catch {
#if DEBUG
            print("[WorkoutStore] Failed to load persisted data: \(error.localizedDescription)")
#endif
            return false
        }
    }

    private func persistExercises() {
        persist(exercises, to: exercisesURL)
    }

    private func persistWorkouts() {
        persist(workouts, to: workoutsURL)
    }

    private func persistSessions() {
        persist(sessionHistory, to: sessionsURL)
    }

    private func applyFileProtection(to url: URL) {
        do {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        } catch {
#if DEBUG
            print("[WorkoutStore] Failed to set file protection on \(url.lastPathComponent): \(error.localizedDescription)")
#endif
        }
    }

    private func persist<T: Encodable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
            applyFileProtection(to: url)
        } catch {
#if DEBUG
            print("[WorkoutStore] Failed to persist data to \(url.lastPathComponent): \(error.localizedDescription)")
#endif
        }
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

    var totalWorkoutCount: Int { sessionHistory.count }

    var averageWorkoutsPerWeek: Double {
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
        let durations = sessionHistory.compactMap { $0.duration }
        guard !durations.isEmpty else { return 0 }
        let total = durations.reduce(0, +)
        return Int(total / Double(durations.count) / 60)
    }

    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)] {
        let calendar = Calendar.current
        let threshold = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()

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
        let muscleGroups = selectMuscleGroups(for: preferences)
        let selectedExercises = selectExercises(for: preferences, targeting: muscleGroups)
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

    private func selectExercises(for preferences: WorkoutPreferences, targeting muscleGroups: [MuscleGroup]) -> [Exercise] {
        var selectedExercises: [Exercise] = []
        let availableExercises = filterExercisesByEquipment(preferences.equipment)

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

    private func filterExercisesByEquipment(_ equipment: EquipmentPreference) -> [Exercise] {
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

extension Array {
    /// Returns a new array with elements partitioned by the predicate while preserving relative order (stable).
    fileprivate func stablePartition(by isInFirstPartition: (Element) -> Bool) -> [Element] {
        var first: [Element] = []
        var second: [Element] = []
        for el in self {
            if isInFirstPartition(el) { first.append(el) } else { second.append(el) }
        }
        return first + second
    }
}
