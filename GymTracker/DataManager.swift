import Foundation
import SwiftData

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    private init() {}
    
    // MARK: - Sample Data Management
    
    func ensureSampleData(context: ModelContext) async {
        do {
            // Check if we already have data
            let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
            
            print("📊 Datenbank-Status: Workouts: \(workouts.count), Übungen: \(exercises.count), Sessions: \(sessions.count)")
            
            // Exercises are now handled by ExerciseSeeder.ensureExercisesExist()
            // So we only need to check if we need workouts and profiles
            
            // Create sample workouts only if none exist AND we have exercises to work with
            if workouts.isEmpty && !exercises.isEmpty {
                print("🔄 Erstelle Beispiel-Workouts...")
                let sampleWorkouts = createSampleWorkouts(using: exercises)
                for workout in sampleWorkouts {
                    context.insert(workout)
                }
                
                // Save workouts
                try context.save()
                print("✅ \(sampleWorkouts.count) Beispiel-Workouts erstellt")
            }
            
            // Create initial profile if needed
            let profiles = try context.fetch(FetchDescriptor<UserProfileEntity>())
            if profiles.isEmpty {
                let profile = UserProfileEntity()
                context.insert(profile)
                try context.save()
                print("✅ Standard-Profil erstellt")
            }
            
        } catch {
            print("❌ Fehler beim Erstellen der Beispieldaten: \(error)")
        }
    }
    private func createSampleWorkouts(using exercises: [ExerciseEntity]) -> [WorkoutEntity] {
        // Helper function to safely find exercise by name
        func findExercise(_ name: String) -> ExerciseEntity? {
            return exercises.first { $0.name == name }
        }
        
        var workouts: [WorkoutEntity] = []
        
        // 1. Oberkörper Power Workout (ca. 60 Min)
        if let bench = findExercise("Bankdrücken"),
           let pullups = findExercise("Klimmzüge"),
           let shoulderPress = findExercise("Schulterdrücken"),
           let rows = findExercise("Rudern"),
           let bicepCurls = findExercise("Bizep Curls"),
           let tricepDips = findExercise("Trizep Dips"),
           let plank = findExercise("Plank") {
            
            let upperBodyWorkout = WorkoutEntity(
                name: "Oberkörper Power",
                exercises: [],
                defaultRestTime: 90,
                notes: "Komplettes Oberkörpertraining für Kraft und Definition"
            )
            
            // Bankdrücken: 4 Sätze (Hauptübung)
            let benchExercise = WorkoutExerciseEntity(exercise: bench, sets: [
                ExerciseSetEntity(reps: 12, weight: 60, restTime: 120),
                ExerciseSetEntity(reps: 10, weight: 70, restTime: 120),
                ExerciseSetEntity(reps: 8, weight: 80, restTime: 120),
                ExerciseSetEntity(reps: 6, weight: 90, restTime: 120)
            ])
            upperBodyWorkout.exercises.append(benchExercise)
            
            // Klimmzüge: 4 Sätze (Antagonist)
            let pullupsExercise = WorkoutExerciseEntity(exercise: pullups, sets: [
                ExerciseSetEntity(reps: 8, weight: 0, restTime: 90),
                ExerciseSetEntity(reps: 6, weight: 0, restTime: 90),
                ExerciseSetEntity(reps: 5, weight: 0, restTime: 90),
                ExerciseSetEntity(reps: 4, weight: 0, restTime: 90)
            ])
            upperBodyWorkout.exercises.append(pullupsExercise)
            
            // Schulterdrücken: 3 Sätze
            let shoulderExercise = WorkoutExerciseEntity(exercise: shoulderPress, sets: [
                ExerciseSetEntity(reps: 12, weight: 25, restTime: 90),
                ExerciseSetEntity(reps: 10, weight: 30, restTime: 90),
                ExerciseSetEntity(reps: 8, weight: 35, restTime: 90)
            ])
            upperBodyWorkout.exercises.append(shoulderExercise)
            
            // Rudern: 3 Sätze
            let rowsExercise = WorkoutExerciseEntity(exercise: rows, sets: [
                ExerciseSetEntity(reps: 12, weight: 50, restTime: 90),
                ExerciseSetEntity(reps: 10, weight: 60, restTime: 90),
                ExerciseSetEntity(reps: 8, weight: 70, restTime: 90)
            ])
            upperBodyWorkout.exercises.append(rowsExercise)
            
            // Bizep Curls: 3 Sätze
            let bicepExercise = WorkoutExerciseEntity(exercise: bicepCurls, sets: [
                ExerciseSetEntity(reps: 15, weight: 12, restTime: 60),
                ExerciseSetEntity(reps: 12, weight: 15, restTime: 60),
                ExerciseSetEntity(reps: 10, weight: 17.5, restTime: 60)
            ])
            upperBodyWorkout.exercises.append(bicepExercise)
            
            // Trizep Dips: 3 Sätze
            let tricepExercise = WorkoutExerciseEntity(exercise: tricepDips, sets: [
                ExerciseSetEntity(reps: 15, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 12, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 10, weight: 0, restTime: 60)
            ])
            upperBodyWorkout.exercises.append(tricepExercise)
            
            // Plank: 3 Sätze (Abschluss)
            let plankExercise = WorkoutExerciseEntity(exercise: plank, sets: [
                ExerciseSetEntity(reps: 45, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 60, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 75, weight: 0, restTime: 60)
            ])
            upperBodyWorkout.exercises.append(plankExercise)
            
            workouts.append(upperBodyWorkout)
        }
        
        // 2. Unterkörper & Core Workout (ca. 60 Min)
        if let squats = findExercise("Kniebeugen"),
           let deadlifts = findExercise("Kreuzheben"),
           let lunges = findExercise("Ausfallschritte"),
           let plank = findExercise("Plank"),
           let crunches = findExercise("Crunches") {
            
            let lowerBodyWorkout = WorkoutEntity(
                name: "Unterkörper & Core",
                exercises: [],
                defaultRestTime: 120,
                notes: "Intensive Bein- und Rumpfmuskulatur Einheit"
            )
            
            // Kniebeugen: 4 Sätze (Hauptübung)
            let squatsExercise = WorkoutExerciseEntity(exercise: squats, sets: [
                ExerciseSetEntity(reps: 15, weight: 40, restTime: 120),
                ExerciseSetEntity(reps: 12, weight: 60, restTime: 120),
                ExerciseSetEntity(reps: 10, weight: 80, restTime: 120),
                ExerciseSetEntity(reps: 8, weight: 100, restTime: 150)
            ])
            lowerBodyWorkout.exercises.append(squatsExercise)
            
            // Kreuzheben: 4 Sätze (Hauptübung)
            let deadliftExercise = WorkoutExerciseEntity(exercise: deadlifts, sets: [
                ExerciseSetEntity(reps: 10, weight: 80, restTime: 150),
                ExerciseSetEntity(reps: 8, weight: 100, restTime: 150),
                ExerciseSetEntity(reps: 6, weight: 120, restTime: 150),
                ExerciseSetEntity(reps: 5, weight: 140, restTime: 150)
            ])
            lowerBodyWorkout.exercises.append(deadliftExercise)
            
            // Ausfallschritte: 3 Sätze (je Bein)
            let lungesExercise = WorkoutExerciseEntity(exercise: lunges, sets: [
                ExerciseSetEntity(reps: 20, weight: 15, restTime: 90),
                ExerciseSetEntity(reps: 16, weight: 20, restTime: 90),
                ExerciseSetEntity(reps: 12, weight: 25, restTime: 90)
            ])
            lowerBodyWorkout.exercises.append(lungesExercise)
            
            // Plank: 4 Sätze (Core)
            let plankExercise = WorkoutExerciseEntity(exercise: plank, sets: [
                ExerciseSetEntity(reps: 45, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 60, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 75, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 90, weight: 0, restTime: 60)
            ])
            lowerBodyWorkout.exercises.append(plankExercise)
            
            // Crunches: 3 Sätze
            let crunchesExercise = WorkoutExerciseEntity(exercise: crunches, sets: [
                ExerciseSetEntity(reps: 25, weight: 0, restTime: 45),
                ExerciseSetEntity(reps: 30, weight: 0, restTime: 45),
                ExerciseSetEntity(reps: 35, weight: 0, restTime: 45)
            ])
            lowerBodyWorkout.exercises.append(crunchesExercise)
            
            workouts.append(lowerBodyWorkout)
        }
        
        // 3. Push/Pull Ganzkörper (ca. 55 Min)
        if let bench = findExercise("Bankdrücken"),
           let rows = findExercise("Rudern"),
           let shoulderPress = findExercise("Schulterdrücken"),
           let latPulldown = findExercise("Latzug"),
           let squats = findExercise("Kniebeugen"),
           let tricepDips = findExercise("Trizep Dips"),
           let bicepCurls = findExercise("Bizep Curls") {
            
            let pushPullWorkout = WorkoutEntity(
                name: "Push/Pull Ganzkörper",
                exercises: [],
                defaultRestTime: 90,
                notes: "Ausgewogenes Training mit Push- und Zugbewegungen"
            )
            
            // Bankdrücken: 3 Sätze (Push)
            let benchExercise = WorkoutExerciseEntity(exercise: bench, sets: [
                ExerciseSetEntity(reps: 12, weight: 60, restTime: 90),
                ExerciseSetEntity(reps: 10, weight: 70, restTime: 90),
                ExerciseSetEntity(reps: 8, weight: 80, restTime: 90)
            ])
            pushPullWorkout.exercises.append(benchExercise)
            
            // Rudern: 3 Sätze (Pull)
            let rowsExercise = WorkoutExerciseEntity(exercise: rows, sets: [
                ExerciseSetEntity(reps: 12, weight: 50, restTime: 90),
                ExerciseSetEntity(reps: 10, weight: 60, restTime: 90),
                ExerciseSetEntity(reps: 8, weight: 70, restTime: 90)
            ])
            pushPullWorkout.exercises.append(rowsExercise)
            
            // Kniebeugen: 3 Sätze (Unterkörper)
            let squatsExercise = WorkoutExerciseEntity(exercise: squats, sets: [
                ExerciseSetEntity(reps: 15, weight: 50, restTime: 90),
                ExerciseSetEntity(reps: 12, weight: 65, restTime: 90),
                ExerciseSetEntity(reps: 10, weight: 80, restTime: 90)
            ])
            pushPullWorkout.exercises.append(squatsExercise)
            
            // Schulterdrücken: 3 Sätze (Push)
            let shoulderExercise = WorkoutExerciseEntity(exercise: shoulderPress, sets: [
                ExerciseSetEntity(reps: 12, weight: 25, restTime: 75),
                ExerciseSetEntity(reps: 10, weight: 30, restTime: 75),
                ExerciseSetEntity(reps: 8, weight: 35, restTime: 75)
            ])
            pushPullWorkout.exercises.append(shoulderExercise)
            
            // Latzug: 3 Sätze (Pull)
            let latExercise = WorkoutExerciseEntity(exercise: latPulldown, sets: [
                ExerciseSetEntity(reps: 12, weight: 45, restTime: 75),
                ExerciseSetEntity(reps: 10, weight: 55, restTime: 75),
                ExerciseSetEntity(reps: 8, weight: 65, restTime: 75)
            ])
            pushPullWorkout.exercises.append(latExercise)
            
            // Trizep Dips: 2 Sätze (Push Finish)
            let tricepExercise = WorkoutExerciseEntity(exercise: tricepDips, sets: [
                ExerciseSetEntity(reps: 12, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 10, weight: 0, restTime: 60)
            ])
            pushPullWorkout.exercises.append(tricepExercise)
            
            // Bizep Curls: 2 Sätze (Pull Finish)
            let bicepExercise = WorkoutExerciseEntity(exercise: bicepCurls, sets: [
                ExerciseSetEntity(reps: 12, weight: 15, restTime: 60),
                ExerciseSetEntity(reps: 10, weight: 17.5, restTime: 60)
            ])
            pushPullWorkout.exercises.append(bicepExercise)
            
            workouts.append(pushPullWorkout)
        }
        
        // 4. Functional Fitness Workout (ca. 50 Min)
        if let squats = findExercise("Kniebeugen"),
           let pushups = findExercise("Liegestütze"),
           let lunges = findExercise("Ausfallschritte"),
           let plank = findExercise("Plank"),
           let seitheben = findExercise("Seitheben"),
           let crunches = findExercise("Crunches"),
           let tricepDips = findExercise("Trizep Dips") {
            
            let functionalWorkout = WorkoutEntity(
                name: "Functional Fitness",
                exercises: [],
                defaultRestTime: 75,
                notes: "Funktionelles Training für Alltag und Sport - ideal für Einsteiger"
            )
            
            // Kniebeugen (Bodyweight): 3 Sätze
            let squatsExercise = WorkoutExerciseEntity(exercise: squats, sets: [
                ExerciseSetEntity(reps: 20, weight: 0, restTime: 75),
                ExerciseSetEntity(reps: 25, weight: 0, restTime: 75),
                ExerciseSetEntity(reps: 30, weight: 0, restTime: 75)
            ])
            functionalWorkout.exercises.append(squatsExercise)
            
            // Liegestütze: 3 Sätze
            let pushupsExercise = WorkoutExerciseEntity(exercise: pushups, sets: [
                ExerciseSetEntity(reps: 12, weight: 0, restTime: 75),
                ExerciseSetEntity(reps: 15, weight: 0, restTime: 75),
                ExerciseSetEntity(reps: 18, weight: 0, restTime: 75)
            ])
            functionalWorkout.exercises.append(pushupsExercise)
            
            // Ausfallschritte: 3 Sätze
            let lungesExercise = WorkoutExerciseEntity(exercise: lunges, sets: [
                ExerciseSetEntity(reps: 16, weight: 0, restTime: 75),
                ExerciseSetEntity(reps: 20, weight: 0, restTime: 75),
                ExerciseSetEntity(reps: 24, weight: 0, restTime: 75)
            ])
            functionalWorkout.exercises.append(lungesExercise)
            
            // Seitheben: 3 Sätze
            let seitHebenExercise = WorkoutExerciseEntity(exercise: seitheben, sets: [
                ExerciseSetEntity(reps: 15, weight: 5, restTime: 60),
                ExerciseSetEntity(reps: 12, weight: 7.5, restTime: 60),
                ExerciseSetEntity(reps: 10, weight: 10, restTime: 60)
            ])
            functionalWorkout.exercises.append(seitHebenExercise)
            
            // Trizep Dips: 3 Sätze
            let tricepExercise = WorkoutExerciseEntity(exercise: tricepDips, sets: [
                ExerciseSetEntity(reps: 10, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 12, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 15, weight: 0, restTime: 60)
            ])
            functionalWorkout.exercises.append(tricepExercise)
            
            // Plank: 3 Sätze
            let plankExercise = WorkoutExerciseEntity(exercise: plank, sets: [
                ExerciseSetEntity(reps: 30, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 45, weight: 0, restTime: 60),
                ExerciseSetEntity(reps: 60, weight: 0, restTime: 60)
            ])
            functionalWorkout.exercises.append(plankExercise)
            
            // Crunches: 3 Sätze
            let crunchesExercise = WorkoutExerciseEntity(exercise: crunches, sets: [
                ExerciseSetEntity(reps: 20, weight: 0, restTime: 45),
                ExerciseSetEntity(reps: 25, weight: 0, restTime: 45),
                ExerciseSetEntity(reps: 30, weight: 0, restTime: 45)
            ])
            functionalWorkout.exercises.append(crunchesExercise)
            
            workouts.append(functionalWorkout)
        }
        
        return workouts
    }
    
    // MARK: - Data Persistence Helpers
    
    func saveWorkout(_ workout: Workout, to context: ModelContext) throws {
        // Check if workout already exists
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { workout in workout.id == workout.id }
        )
        
        if let existing = try context.fetch(descriptor).first {
            // Update existing workout
            try updateWorkoutEntity(existing, with: workout, in: context)
        } else {
            // Create new workout
            let entity = try createWorkoutEntity(from: workout, in: context)
            context.insert(entity)
        }
        
        try context.save()
    }
    
    private func createWorkoutEntity(from workout: Workout, in context: ModelContext) throws -> WorkoutEntity {
        let workoutEntity = WorkoutEntity(
            id: workout.id,
            name: workout.name,
            date: workout.date,
            exercises: [],
            defaultRestTime: workout.defaultRestTime,
            duration: workout.duration,
            notes: workout.notes,
            isFavorite: workout.isFavorite
        )
        
        // Create or find existing exercises
        for workoutExercise in workout.exercises {
            let exerciseEntity = try findOrCreateExercise(workoutExercise.exercise, in: context)
            let workoutExerciseEntity = WorkoutExerciseEntity.make(from: workoutExercise, using: exerciseEntity)
            workoutEntity.exercises.append(workoutExerciseEntity)
        }
        
        return workoutEntity
    }
    
    private func updateWorkoutEntity(_ entity: WorkoutEntity, with workout: Workout, in context: ModelContext) throws {
        entity.name = workout.name
        entity.date = workout.date
        entity.defaultRestTime = workout.defaultRestTime
        entity.duration = workout.duration
        entity.notes = workout.notes
        entity.isFavorite = workout.isFavorite
        
        // Clear existing exercises
        entity.exercises.removeAll()
        
        // Add updated exercises
        for workoutExercise in workout.exercises {
            let exerciseEntity = try findOrCreateExercise(workoutExercise.exercise, in: context)
            let workoutExerciseEntity = WorkoutExerciseEntity.make(from: workoutExercise, using: exerciseEntity)
            entity.exercises.append(workoutExerciseEntity)
        }
    }
    
    private func findOrCreateExercise(_ exercise: Exercise, in context: ModelContext) throws -> ExerciseEntity {
        // Use the safe fetch helper function
        if let existing = fetchExercise(by: exercise.id, in: context) {
            return existing
        }
        
        // If not found by ID, try to find by name (case insensitive) to prevent duplicates
        let nameDescriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate<ExerciseEntity> { entity in
                entity.name.localizedLowercase == exercise.name.localizedLowercase
            }
        )
        
        if let existing = try context.fetch(nameDescriptor).first {
            // Update the existing exercise's ID to match the one we're looking for
            // This ensures consistency in future lookups
            return existing
        }
        
        // Create new exercise only if no duplicate name exists
        let newExercise = ExerciseEntity.make(from: exercise)
        context.insert(newExercise)
        return newExercise
    }
    
    func recordSession(_ session: WorkoutSession, to context: ModelContext) throws -> WorkoutSessionEntity {
        print("💾 Speichere Session: \(session.name) (ID: \(session.id.uuidString.prefix(8)))")
        
        let sessionEntity = WorkoutSessionEntity(
            id: session.id,
            templateId: session.templateId,
            name: session.name,
            date: session.date,
            exercises: [],
            defaultRestTime: session.defaultRestTime,
            duration: session.duration,
            notes: session.notes
        )
        
        // Create or find existing exercises for the session
        for workoutExercise in session.exercises {
            let exerciseEntity = try findOrCreateExercise(workoutExercise.exercise, in: context)
            let workoutExerciseEntity = WorkoutExerciseEntity.make(from: workoutExercise, using: exerciseEntity)
            sessionEntity.exercises.append(workoutExerciseEntity)
        }
        
        context.insert(sessionEntity)
        try context.save()
        
        print("✅ Session erfolgreich gespeichert: \(session.name) mit \(session.exercises.count) Übungen")
        return sessionEntity
    }
    
    func deleteWorkout(withId id: UUID, from context: ModelContext) throws {
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { workout in workout.id == id }
        )
        
        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
    
    // MARK: - Reset and Maintenance
    
    func resetAllData(context: ModelContext) async throws {
        // Delete all data
        let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
        let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
        let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
        let profiles = try context.fetch(FetchDescriptor<UserProfileEntity>())
        
        for workout in workouts {
            context.delete(workout)
        }
        for exercise in exercises {
            context.delete(exercise)
        }
        for session in sessions {
            context.delete(session)
        }
        for profile in profiles {
            context.delete(profile)
        }
        
        try context.save()
        print("🗑️ Alle Daten gelöscht")
        
        // Re-create sample data
        await ensureSampleData(context: context)
    }
    
    // MARK: - Debug Helpers
    
    func debugDatabaseState(context: ModelContext) {
        do {
            let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
            let profiles = try context.fetch(FetchDescriptor<UserProfileEntity>())
            
            print("=== 📊 Datenbank-Status ===")
            print("Workouts (Templates): \(workouts.count)")
            for workout in workouts.prefix(5) {
                print("  - \(workout.name) (ID: \(workout.id.uuidString.prefix(8)))")
            }
            
            print("Übungen: \(exercises.count)")
            for exercise in exercises.prefix(5) {
                print("  - \(exercise.name) (ID: \(exercise.id.uuidString.prefix(8)))")
            }
            
            print("Sessions (Historie): \(sessions.count)")
            for session in sessions.prefix(5) {
                let dateStr = session.date.formatted(.dateTime.day().month().year())
                let timeStr = session.date.formatted(.dateTime.hour().minute())
                print("  - \(session.name) (\(dateStr) \(timeStr), ID: \(session.id.uuidString.prefix(8)))")
            }
            
            print("Profile: \(profiles.count)")
            print("========================")
        } catch {
            print("❌ Fehler beim Abrufen der Debug-Daten: \(error)")
        }
    }
}
