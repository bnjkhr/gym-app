import Foundation
import SwiftData

struct ExerciseSeeder {
    
    /// Safely ensure exercises exist - only create if database is empty
    /// This prevents the invalidation issues caused by repeated purging
    static func ensureExercisesExist(context: ModelContext) {
        do {
            let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            
            if !existingExercises.isEmpty {
                print("📚 \(existingExercises.count) Übungen bereits vorhanden - keine neue Erstellung nötig")
                return
            }
            
            print("🌱 Erstelle ca. 100 realistische Beispiel-Übungen...")
            let sampleExercises = createRealisticExercises()
            
            for exercise in sampleExercises {
                let entity = ExerciseEntity.make(from: exercise)
                context.insert(entity)
            }
            
            try context.save()
            print("✅ \(sampleExercises.count) Übungen erfolgreich erstellt")
            
        } catch {
            print("❌ Fehler beim Erstellen der Übungen: \(error)")
        }
    }
    
    /// Safely ensure sample workouts exist - only create if no workouts exist
    /// Creates 4 example workouts: 2 machine-based, 2 free weights
    static func ensureSampleWorkoutsExist(context: ModelContext) {
        do {
            let existingWorkouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
            
            if !existingWorkouts.isEmpty {
                print("💪 \(existingWorkouts.count) Workouts bereits vorhanden - keine neuen Beispiel-Workouts nötig")
                return
            }
            
            // First make sure exercises exist
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            if exercises.isEmpty {
                print("⚠️ Keine Übungen vorhanden - kann keine Beispiel-Workouts erstellen")
                return
            }
            
            print("🏋️ Erstelle 4 Beispiel-Workouts...")
            let sampleWorkouts = createSampleWorkouts(availableExercises: exercises)
            
            for workout in sampleWorkouts {
                let entity = WorkoutEntity.make(from: workout)
                // Link exercises to existing exercise entities
                for (i, workoutExercise) in entity.exercises.enumerated() {
                    if let existingExercise = exercises.first(where: { $0.name == workout.exercises[i].exercise.name }) {
                        workoutExercise.exercise = existingExercise
                    }
                }
                context.insert(entity)
            }
            
            try context.save()
            print("✅ \(sampleWorkouts.count) Beispiel-Workouts erfolgreich erstellt")
            
        } catch {
            print("❌ Fehler beim Erstellen der Beispiel-Workouts: \(error)")
        }
    }
    
    /// Update exercise database by adding new exercises and updating existing ones
    /// This is safer than forceRefresh as it preserves existing workout references
    static func updateExerciseDatabase(context: ModelContext) {
        do {
            let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            print("📚 Aktualisiere Übungsdatenbank (\(existingExercises.count) vorhanden)...")
            
            let sampleExercises = createRealisticExercises()
            let existingNames = Set(existingExercises.map { $0.name })
            
            var addedCount = 0
            var updatedCount = 0
            
            for exercise in sampleExercises {
                if let existingExercise = existingExercises.first(where: { $0.name == exercise.name }) {
                    // Update existing exercise
                    existingExercise.muscleGroupsRaw = exercise.muscleGroups.map { $0.rawValue }
                    existingExercise.equipmentTypeRaw = exercise.equipmentType.rawValue
                    existingExercise.descriptionText = exercise.description
                    existingExercise.instructions = exercise.instructions
                    updatedCount += 1
                } else {
                    // Add new exercise
                    let entity = ExerciseEntity.make(from: exercise)
                    context.insert(entity)
                    addedCount += 1
                }
            }
            
            try context.save()
            print("✅ Übungsdatenbank aktualisiert: \(addedCount) neue, \(updatedCount) aktualisierte Übungen")
            
        } catch {
            print("❌ Fehler beim Aktualisieren der Übungsdatenbank: \(error)")
        }
    }
    
    /// Force refresh the exercise database with the latest comprehensive list
    /// This will delete all existing exercises and recreate them
    /// WARNING: This may invalidate workout references - use with caution
    static func forceRefreshExercises(context: ModelContext) {
        do {
            // Delete all existing exercises
            let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            print("🗑️ Lösche \(existingExercises.count) vorhandene Übungen...")
            
            for exercise in existingExercises {
                context.delete(exercise)
            }
            
            // Save deletion
            try context.save()
            
            // Create new exercises
            print("🌱 Erstelle \(createRealisticExercises().count) neue realistische Beispiel-Übungen...")
            let sampleExercises = createRealisticExercises()
            
            for exercise in sampleExercises {
                let entity = ExerciseEntity.make(from: exercise)
                context.insert(entity)
            }
            
            try context.save()
            print("✅ \(sampleExercises.count) Übungen erfolgreich aktualisiert")
            
        } catch {
            print("❌ Fehler beim Aktualisieren der Übungen: \(error)")
        }
    }
    
    /// Clear all data and then seed with fresh exercises
    /// This provides a complete reset of the app
    static func resetAndSeed(context: ModelContext) {
        print("🔄 Vollständiger Reset der Datenbank...")
        
        // Delete all data first
        do {
            // Delete all workout sessions first (to avoid foreign key issues)
            let workoutSessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
            print("🗑️ Lösche \(workoutSessions.count) Workout-Sessions...")
            for session in workoutSessions {
                context.delete(session)
            }
            
            // Delete all workout templates
            let workoutTemplates = try context.fetch(FetchDescriptor<WorkoutEntity>())
            print("🗑️ Lösche \(workoutTemplates.count) Workout-Vorlagen...")
            for template in workoutTemplates {
                context.delete(template)
            }
            
            // Delete all workout exercises (should cascade, but being explicit)
            let workoutExercises = try context.fetch(FetchDescriptor<WorkoutExerciseEntity>())
            print("🗑️ Lösche \(workoutExercises.count) Workout-Übung-Referenzen...")
            for workoutExercise in workoutExercises {
                context.delete(workoutExercise)
            }
            
            // Delete all exercise sets (should cascade, but being explicit)
            let exerciseSets = try context.fetch(FetchDescriptor<ExerciseSetEntity>())
            print("🗑️ Lösche \(exerciseSets.count) Übungs-Sets...")
            for set in exerciseSets {
                context.delete(set)
            }
            
            // Finally delete all exercises
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
            print("🗑️ Lösche \(exercises.count) Übungen...")
            for exercise in exercises {
                context.delete(exercise)
            }
            
            // Save all deletions
            try context.save()
            print("✅ Alle Daten erfolgreich gelöscht - Datenbank ist jetzt leer")
            
        } catch {
            print("❌ Fehler beim Löschen der Daten: \(error)")
            return
        }
        
        // Create fresh exercises
        print("🌱 Erstelle frische Übungsdatenbank...")
        let sampleExercises = createRealisticExercises()
        
        for exercise in sampleExercises {
            let entity = ExerciseEntity.make(from: exercise)
            context.insert(entity)
        }
        
        do {
            try context.save()
            print("✅ Reset abgeschlossen: \(sampleExercises.count) neue Übungen erstellt")
        } catch {
            print("❌ Fehler beim Erstellen neuer Übungen: \(error)")
        }
    }
    
    /// DEPRECATED: Use ensureExercisesExist instead to prevent entity invalidation
    @available(*, deprecated, message: "Use ensureExercisesExist instead to prevent SwiftData invalidation issues")
    static func purgeAndSeed(context: ModelContext) {
        print("⚠️ DEPRECATED: purgeAndSeed wird nicht mehr verwendet - verwende ensureExercisesExist")
        ensureExercisesExist(context: context)
    }
    
    private static func createSampleWorkouts(availableExercises: [ExerciseEntity]) -> [Workout] {
        // Helper function to find exercise by name
        func findExercise(name: String) -> Exercise? {
            guard let entity = availableExercises.first(where: { $0.name == name }) else { return nil }
            return Exercise(
                id: entity.id,
                name: entity.name,
                muscleGroups: entity.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) },
                equipmentType: EquipmentType(rawValue: entity.equipmentTypeRaw) ?? .mixed,
                description: entity.descriptionText,
                instructions: entity.instructions,
                createdAt: entity.createdAt
            )
        }
        
        // Helper function to create sets with realistic weights
        func createSets(reps: [Int], baseWeight: Double) -> [ExerciseSet] {
            return reps.map { rep in
                ExerciseSet(reps: rep, weight: baseWeight, restTime: 90)
            }
        }
        
        var workouts: [Workout] = []
        
        // === 1. MASCHINEN-WORKOUT: GANZKÖRPER ANFÄNGER ===
        if let brustpresse = findExercise(name: "Brustpresse Maschine"),
           let latzug = findExercise(name: "Lat Pulldown breit"),
           let schultermaschine = findExercise(name: "Schulterdrücken Maschine"),
           let beinpresse = findExercise(name: "Beinpresse"),
           let beinstrecker = findExercise(name: "Beinstrecker"),
           let beinbeuger = findExercise(name: "Beinbeuger sitzend"),
           let rudermaschine = findExercise(name: "Rudermaschine") {
            
            let machineWorkout1 = Workout(
                name: "Ganzkörper Maschinen (Anfänger)",
                exercises: [
                    WorkoutExercise(exercise: brustpresse, sets: createSets(reps: [12, 12, 12], baseWeight: 40.0)),
                    WorkoutExercise(exercise: latzug, sets: createSets(reps: [12, 12, 12], baseWeight: 35.0)),
                    WorkoutExercise(exercise: schultermaschine, sets: createSets(reps: [12, 12, 12], baseWeight: 25.0)),
                    WorkoutExercise(exercise: beinpresse, sets: createSets(reps: [15, 15, 12], baseWeight: 100.0)),
                    WorkoutExercise(exercise: beinstrecker, sets: createSets(reps: [15, 12, 12], baseWeight: 30.0)),
                    WorkoutExercise(exercise: beinbeuger, sets: createSets(reps: [12, 12, 12], baseWeight: 35.0)),
                    WorkoutExercise(exercise: rudermaschine, sets: createSets(reps: [12, 12, 10], baseWeight: 40.0))
                ],
                defaultRestTime: 90,
                notes: "Perfekt für Einsteiger - Maschinen bieten Sicherheit und Stabilität",
                isFavorite: true
            )
            workouts.append(machineWorkout1)
        }
        
        // === 2. MASCHINEN-WORKOUT: OBERKÖRPER FOKUS ===
        if let hammerChest = findExercise(name: "Hammer Strength Chest Press"),
           let latPulldownEng = findExercise(name: "Lat Pulldown eng"),
           let reversePecDeck = findExercise(name: "Reverse Pec Deck"),
           let schultermaschine = findExercise(name: "Schulterdrücken Maschine"),
           let trizepsDip = findExercise(name: "Trizeps Dip Maschine"),
           let kabelBizeps = findExercise(name: "Kabel Bizep Curls"),
           let kabelTrizeps = findExercise(name: "Trizeps Pushdown Seil") {
            
            let machineWorkout2 = Workout(
                name: "Oberkörper Maschinen (Fortgeschritten)",
                exercises: [
                    WorkoutExercise(exercise: hammerChest, sets: createSets(reps: [10, 8, 8], baseWeight: 50.0)),
                    WorkoutExercise(exercise: latPulldownEng, sets: createSets(reps: [10, 10, 8], baseWeight: 45.0)),
                    WorkoutExercise(exercise: reversePecDeck, sets: createSets(reps: [12, 12, 10], baseWeight: 30.0)),
                    WorkoutExercise(exercise: schultermaschine, sets: createSets(reps: [10, 10, 8], baseWeight: 35.0)),
                    WorkoutExercise(exercise: trizepsDip, sets: createSets(reps: [12, 10, 8], baseWeight: 40.0)),
                    WorkoutExercise(exercise: kabelBizeps, sets: createSets(reps: [12, 10, 10], baseWeight: 25.0)),
                    WorkoutExercise(exercise: kabelTrizeps, sets: createSets(reps: [12, 12, 10], baseWeight: 30.0))
                ],
                defaultRestTime: 75,
                notes: "Intensives Oberkörper-Training mit Maschinen und Kabelzug",
                isFavorite: false
            )
            workouts.append(machineWorkout2)
        }
        
        // === 3. FREIE GEWICHTE: KLASSISCHES 5x5 ===
        if let kniebeugen = findExercise(name: "Kniebeugen"),
           let bankdrücken = findExercise(name: "Bankdrücken"),
           let kreuzheben = findExercise(name: "Kreuzheben"),
           let langhantelRudern = findExercise(name: "Langhantel Rudern"),
           let schulterdrücken = findExercise(name: "Schulterdrücken stehend") {
            
            let freeWeightWorkout1 = Workout(
                name: "5x5 Kraft (Freie Gewichte)",
                exercises: [
                    WorkoutExercise(exercise: kniebeugen, sets: createSets(reps: [5, 5, 5, 5, 5], baseWeight: 80.0)),
                    WorkoutExercise(exercise: bankdrücken, sets: createSets(reps: [5, 5, 5, 5, 5], baseWeight: 70.0)),
                    WorkoutExercise(exercise: langhantelRudern, sets: createSets(reps: [5, 5, 5, 5, 5], baseWeight: 60.0)),
                    WorkoutExercise(exercise: schulterdrücken, sets: createSets(reps: [5, 5, 5, 5, 5], baseWeight: 45.0)),
                    WorkoutExercise(exercise: kreuzheben, sets: createSets(reps: [5, 5, 5], baseWeight: 100.0))
                ],
                defaultRestTime: 180, // Längere Pausen für Krafttraining
                notes: "Klassisches Krafttraining - fokussiert auf Grundübungen mit schweren Gewichten",
                isFavorite: true
            )
            workouts.append(freeWeightWorkout1)
        }
        
        // === 4. FREIE GEWICHTE: HYPERTROPHIE MIX ===
        if let kurzhantelBank = findExercise(name: "Kurzhantel Bankdrücken"),
           let kurzhantelRudern = findExercise(name: "Kurzhantel Rudern"),
           let kurzhantelSchulder = findExercise(name: "Kurzhantel Schulterdrücken"),
           let ausfallschritte = findExercise(name: "Ausfallschritte"),
           let bizepsCurls = findExercise(name: "Bizep Curls"),
           let frenchPress = findExercise(name: "French Press Kurzhantel"),
           let seitheben = findExercise(name: "Seitheben"),
           let gobletSquats = findExercise(name: "Goblet Squats") {
            
            let freeWeightWorkout2 = Workout(
                name: "Kurzhantel Hypertrophie",
                exercises: [
                    WorkoutExercise(exercise: gobletSquats, sets: createSets(reps: [15, 12, 12], baseWeight: 20.0)),
                    WorkoutExercise(exercise: kurzhantelBank, sets: createSets(reps: [12, 10, 8], baseWeight: 25.0)),
                    WorkoutExercise(exercise: kurzhantelRudern, sets: createSets(reps: [12, 12, 10], baseWeight: 22.5)),
                    WorkoutExercise(exercise: ausfallschritte, sets: createSets(reps: [12, 12, 12], baseWeight: 15.0)),
                    WorkoutExercise(exercise: kurzhantelSchulder, sets: createSets(reps: [12, 10, 10], baseWeight: 15.0)),
                    WorkoutExercise(exercise: seitheben, sets: createSets(reps: [15, 12, 12], baseWeight: 8.0)),
                    WorkoutExercise(exercise: bizepsCurls, sets: createSets(reps: [12, 12, 10], baseWeight: 12.0)),
                    WorkoutExercise(exercise: frenchPress, sets: createSets(reps: [12, 10, 10], baseWeight: 15.0))
                ],
                defaultRestTime: 60, // Kürzere Pausen für Hypertrophie
                notes: "Komplettes Kurzhantel-Workout für Muskelaufbau - perfekt für das Home Gym",
                isFavorite: false
            )
            workouts.append(freeWeightWorkout2)
        }
        
        return workouts
    }
    
    private static func createRealisticExercises() -> [Exercise] {
        return [
            // === BRUST (Chest) ===
            Exercise(name: "Bankdrücken", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .freeWeights, description: "Klassische Grundübung für die Brustmuskulatur", instructions: ["Auf Bank legen", "Stange mit schulterbreitem Griff fassen", "Kontrolliert zur Brust senken", "Explosiv nach oben drücken"]),
            Exercise(name: "Kurzhantel Bankdrücken", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .freeWeights, description: "Bankdrücken mit Kurzhanteln für besseren Bewegungsumfang", instructions: ["Kurzhanteln über Brust", "Tiefer senken als mit Stange möglich", "Gleichmäßig nach oben drücken"]),
            Exercise(name: "Schrägbankdrücken", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .freeWeights, description: "Bankdrücken auf der Schrägbank für obere Brust", instructions: ["Bank auf 30-45° einstellen", "Stange über obere Brust positionieren", "Kontrollierte Bewegung ausführen"]),
            Exercise(name: "Kurzhantel Schrägbankdrücken", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .freeWeights, description: "Schrägbankdrücken mit Kurzhanteln", instructions: ["Schrägbank 30-45°", "Kurzhanteln parallel drücken", "Volle Dehnung nutzen"]),
            Exercise(name: "Negativ Schrägbankdrücken", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .freeWeights, description: "Bankdrücken auf negativer Schrägbank für untere Brust", instructions: ["Bank -15° bis -30°", "Stange zur unteren Brust", "Kontrolle wichtiger als Gewicht"]),
            Exercise(name: "Fliegende Kurzhanteln", muscleGroups: [.chest], equipmentType: .freeWeights, description: "Isolationsübung für die Brustmuskulatur", instructions: ["Flach auf Bank liegen", "Arme leicht gebeugt seitlich senken", "Halbkreisförmige Bewegung nach oben"]),
            Exercise(name: "Kurzhantel Fliegende schräg", muscleGroups: [.chest], equipmentType: .freeWeights, description: "Fliegende auf der Schrägbank", instructions: ["Schrägbank 30° einstellen", "Kurzhanteln seitlich senken", "Bogen nach oben führen"]),
            Exercise(name: "Liegestütze", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .bodyweight, description: "Bodyweight Übung für Brust und Arme", instructions: ["Plank Position einnehmen", "Körper als gerade Linie", "Kontrolliert nach unten und oben"]),
            Exercise(name: "Dips an Barren", muscleGroups: [.chest, .triceps], equipmentType: .bodyweight, description: "Körpergewichtsübung für untere Brust", instructions: ["An Barren stützen", "Körper leicht nach vorn neigen", "Tief absenken und hochdrücken"]),
            Exercise(name: "Kabelzug Crossover", muscleGroups: [.chest], equipmentType: .cable, description: "Kabelübung für Brustdefinition", instructions: ["Kabel von oben ziehen", "Arme vor dem Körper kreuzen", "Langsame kontrollierte Bewegung"]),
            Exercise(name: "Brustpresse Maschine", muscleGroups: [.chest, .triceps], equipmentType: .machine, description: "Maschinenübung für sichere Brustentwicklung", instructions: ["Rücken fest an Polster", "Griffe auf Brusthöhe", "Gleichmäßig drücken"]),
            Exercise(name: "Hammer Strength Chest Press", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .machine, description: "Einseitige Brustpresse Maschine", instructions: ["Jede Seite einzeln trainieren", "Natürliche Bewegungsbahn", "Vollständige Streckung"]),
            
            // === NEUE MASCHINENÜBUNGEN FÜR BRUST ===
            Exercise(name: "Pec Deck Flys", muscleGroups: [.chest], equipmentType: .machine, description: "Brustmuskel-Fliegende an der Maschine", instructions: ["Rücken an Polster", "Arme in Halbkreis zusammenführen", "Langsame Streckung zurück"]),
            Exercise(name: "Incline Chest Press Maschine", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .machine, description: "Schrägbankdrücken an der Maschine", instructions: ["Sitz auf 30-45° einstellen", "Griffe nach oben drücken", "Kontrolliert zurück"]),
            Exercise(name: "Decline Chest Press Maschine", muscleGroups: [.chest, .triceps], equipmentType: .machine, description: "Negativ-Bankdrücken an der Maschine", instructions: ["Bank leicht nach unten", "Griffe zur unteren Brust", "Fokus auf untere Brustpartie"]),
            Exercise(name: "Chest Supported Dips Maschine", muscleGroups: [.chest, .triceps], equipmentType: .machine, description: "Assistierte Dips an der Maschine", instructions: ["Gewichtsunterstützung einstellen", "Tiefe Dip-Bewegung", "Kontrollierte Ausführung"]),
            
            // === RÜCKEN (Back) ===
            Exercise(name: "Klimmzüge", muscleGroups: [.back, .biceps], equipmentType: .bodyweight, description: "König der Rückenübungen", instructions: ["Obergriff an Stange", "Körper hochziehen bis Kinn über Stange", "Kontrolliert zurück in Startposition"]),
            Exercise(name: "Klimmzüge Untergriff", muscleGroups: [.back, .biceps], equipmentType: .bodyweight, description: "Klimmzüge mit Untergriff für Bizeps-Fokus", instructions: ["Untergriff verwenden", "Schulterbreit greifen", "Brust zur Stange"]),
            Exercise(name: "Lat Pulldown breit", muscleGroups: [.back, .biceps], equipmentType: .machine, description: "Breiter Latzug für Latissimus", instructions: ["Breiter Griff", "Zur oberen Brust ziehen", "Schulterblätter zusammenziehen"]),
            Exercise(name: "Lat Pulldown eng", muscleGroups: [.back, .biceps], equipmentType: .machine, description: "Enger Latzug für mittleren Rücken", instructions: ["Enger V-Griff", "Zur unteren Brust ziehen", "Ellbogen am Körper"]),
            Exercise(name: "Kreuzheben", muscleGroups: [.back, .legs, .glutes], equipmentType: .freeWeights, description: "Ganzkörper-Grundübung", instructions: ["Füße hüftbreit", "Stange nah am Körper", "Gerade aufrichten", "Hüfte und Knie strecken"]),
            Exercise(name: "Rumänisches Kreuzheben", muscleGroups: [.back, .legs, .glutes], equipmentType: .freeWeights, description: "Kreuzheben mit gestreckten Beinen", instructions: ["Stange vor Körper senken", "Beine fast gestreckt", "Hüfte nach hinten"]),
            Exercise(name: "Langhantel Rudern", muscleGroups: [.back, .biceps], equipmentType: .freeWeights, description: "Rudern mit der Langhantel", instructions: ["Vorgebeugte Position", "Stange zur unteren Brust ziehen", "Schulterblätter zusammenziehen"]),
            Exercise(name: "Kurzhantel Rudern", muscleGroups: [.back, .biceps], equipmentType: .freeWeights, description: "Einseitiges Rudern mit Kurzhantel", instructions: ["Eine Hand und Knie auf Bank", "Kurzhantel zur Hüfte ziehen", "Rücken gerade halten"]),
            Exercise(name: "T-Bar Rudern", muscleGroups: [.back, .biceps], equipmentType: .freeWeights, description: "Rudern mit T-Bar für mittleren Rücken", instructions: ["Vorgebeugt über T-Bar", "Griffe zur Brust ziehen", "Starke Rückenspannung"]),
            Exercise(name: "Kabelrudern sitzend", muscleGroups: [.back, .biceps], equipmentType: .cable, description: "Rudern am Kabelzug im Sitzen", instructions: ["Aufrecht sitzen", "Kabel zur Taille ziehen", "Schulterblätter zusammenpressen"]),
            Exercise(name: "Latzug", muscleGroups: [.back, .biceps], equipmentType: .machine, description: "Latissimus Training am Kabelzug", instructions: ["Aufrecht am Gerät sitzen", "Stange zur oberen Brust ziehen", "Ellbogen nach hinten führen"]),
            Exercise(name: "Hyperextensions", muscleGroups: [.back, .glutes], equipmentType: .machine, description: "Rückenstrecker Training", instructions: ["Bauch auf Polster", "Oberkörper senken und heben", "Rücken nicht überstrecken"]),
            Exercise(name: "Shrugs Kurzhanteln", muscleGroups: [.back, .shoulders], equipmentType: .freeWeights, description: "Nackenmuskulatur Training", instructions: ["Kurzhanteln seitlich halten", "Schultern nach oben ziehen", "Kurz halten und senken"]),
            Exercise(name: "Shrugs Langhantel", muscleGroups: [.back, .shoulders], equipmentType: .freeWeights, description: "Nackenmuskulatur mit Langhantel", instructions: ["Langhantel vor Körper", "Schultern hochziehen", "2 Sekunden halten"]),
            Exercise(name: "Reverse Flys", muscleGroups: [.back, .shoulders], equipmentType: .freeWeights, description: "Hintere Schulter und oberer Rücken", instructions: ["Vorgebeugt stehen", "Arme seitlich heben", "Schulterblätter zusammenziehen"]),
            Exercise(name: "Rudermaschine", muscleGroups: [.back, .biceps], equipmentType: .machine, description: "Maschinenrudern für sicheres Training", instructions: ["Brust an Polster", "Griffe zur Brust ziehen", "Schulterblätter aktiv"]),
            
            // === NEUE MASCHINENÜBUNGEN FÜR RÜCKEN ===
            Exercise(name: "Assisted Pull-up Maschine", muscleGroups: [.back, .biceps], equipmentType: .machine, description: "Assistierte Klimmzüge", instructions: ["Gewichtsunterstützung einstellen", "Obergriff verwenden", "Kontrollierte Bewegung"]),
            Exercise(name: "Low Row Maschine", muscleGroups: [.back, .biceps], equipmentType: .machine, description: "Tiefes Rudern an der Maschine", instructions: ["Aufrecht sitzen", "Griffe zur Taille ziehen", "Schulterblätter zusammenpressen"]),
            Exercise(name: "High Row Maschine", muscleGroups: [.back, .biceps], equipmentType: .machine, description: "Hohes Rudern für oberen Rücken", instructions: ["Griffe zur oberen Brust", "Ellbogen nach hinten", "Starke Rückenspannung"]),
            Exercise(name: "Lat Pullover Maschine", muscleGroups: [.back, .chest], equipmentType: .machine, description: "Pullover-Bewegung an der Maschine", instructions: ["Arme gestreckt über Kopf", "Halbkreis nach unten", "Latissimus aktivieren"]),
            Exercise(name: "Back Extension Maschine", muscleGroups: [.back, .glutes], equipmentType: .machine, description: "Rückenstreckung mit Gewicht", instructions: ["Hüfte fest fixiert", "Oberkörper gegen Widerstand aufrichten", "Langsame Bewegung"]),
            
            // === BEINE (Legs) ===
            Exercise(name: "Kniebeugen", muscleGroups: [.legs, .glutes], equipmentType: .freeWeights, description: "Die Königin aller Übungen", instructions: ["Füße schulterbreit", "Hüfte nach hinten schieben", "Tief in die Hocke", "Explosiv aufstehen"]),
            Exercise(name: "Front Squats", muscleGroups: [.legs, .glutes, .abs], equipmentType: .freeWeights, description: "Kniebeugen mit Stange vorn", instructions: ["Stange auf vorderen Deltamuskeln", "Aufrechter Oberkörper", "Tief absenken"]),
            Exercise(name: "Goblet Squats", muscleGroups: [.legs, .glutes], equipmentType: .freeWeights, description: "Kniebeugen mit Kurzhantel", instructions: ["Kurzhantel vor Brust halten", "Tief in Hocke", "Rücken gerade"]),
            Exercise(name: "Hack Squats", muscleGroups: [.legs, .glutes], equipmentType: .machine, description: "Kniebeugen an der Hack Squat Maschine", instructions: ["Rücken an Polster", "Schultern unter Pads", "Tiefe Kniebeuge"]),
            Exercise(name: "Beinpresse", muscleGroups: [.legs, .glutes], equipmentType: .machine, description: "Maschinelle Beinübung", instructions: ["Rücken an Lehne", "Füße auf Fußplatte", "Gewicht kontrolliert drücken"]),
            Exercise(name: "Ausfallschritte", muscleGroups: [.legs, .glutes], equipmentType: .freeWeights, description: "Unilaterale Beinübung", instructions: ["Großer Schritt nach vorn", "Hinteres Knie Richtung Boden", "Zur Startposition zurück"]),
            Exercise(name: "Ausfallschritte rückwärts", muscleGroups: [.legs, .glutes], equipmentType: .freeWeights, description: "Rückwärts-Ausfallschritte", instructions: ["Schritt nach hinten", "Knie senken", "Zurück zur Mitte"]),
            Exercise(name: "Walking Lunges", muscleGroups: [.legs, .glutes], equipmentType: .freeWeights, description: "Laufende Ausfallschritte", instructions: ["Abwechselnd große Schritte", "Knie berührt fast Boden", "Vorwärts laufen"]),
            Exercise(name: "Bulgarische Split Squats", muscleGroups: [.legs, .glutes], equipmentType: .freeWeights, description: "Einbeinige Kniebeuge mit erhöhtem Fuß", instructions: ["Hinterer Fuß auf Bank", "Vorderes Bein in Kniebeuge", "Explosiv nach oben"]),
            Exercise(name: "Beinstrecker", muscleGroups: [.legs], equipmentType: .machine, description: "Isolation für Quadrizeps", instructions: ["Am Gerät sitzen", "Beine gegen Widerstand strecken", "Kurz halten und senken"]),
            Exercise(name: "Beinbeuger liegend", muscleGroups: [.legs], equipmentType: .machine, description: "Isolation für hintere Oberschenkel", instructions: ["Auf Bauch am Gerät", "Fersen zum Gesäß ziehen", "Langsam zurück"]),
            Exercise(name: "Beinbeuger sitzend", muscleGroups: [.legs], equipmentType: .machine, description: "Sitzende Beinbeuger-Variante", instructions: ["Aufrecht sitzen", "Fersen nach unten drücken", "Hintere Oberschenkel anspannen"]),
            Exercise(name: "Sumo Deadlift", muscleGroups: [.legs, .glutes, .back], equipmentType: .freeWeights, description: "Kreuzheben mit breitem Stand", instructions: ["Füße sehr breit", "Zehen nach außen", "Stange zwischen Beinen greifen"]),
            Exercise(name: "Stiff Leg Deadlift", muscleGroups: [.legs, .glutes, .back], equipmentType: .freeWeights, description: "Kreuzheben mit steifen Beinen", instructions: ["Beine gestreckt", "Hüfte nach hinten", "Stange am Körper runter"]),
            Exercise(name: "Wadenheben stehend", muscleGroups: [.legs], equipmentType: .machine, description: "Training der Wadenmuskulatur", instructions: ["Auf Zehenspitzen heben", "Kurz halten", "Langsam senken"]),
            Exercise(name: "Wadenheben sitzend", muscleGroups: [.legs], equipmentType: .machine, description: "Sitzende Wadenheber", instructions: ["Gewicht auf Oberschenkel", "Zehenspitzen nach oben", "Volle Dehnung"]),
            Exercise(name: "Single Leg Press", muscleGroups: [.legs, .glutes], equipmentType: .machine, description: "Einbeinige Beinpresse", instructions: ["Ein Fuß auf Platte", "Volles Gewicht auf einem Bein", "Kontrollierte Bewegung"]),
            Exercise(name: "Step-ups", muscleGroups: [.legs, .glutes], equipmentType: .freeWeights, description: "Aufsteigen auf Bank oder Box", instructions: ["Fuß auf erhöhte Fläche", "Mit einem Bein hochdrücken", "Kontrolliert absteigen"]),
            
            // === NEUE MASCHINENÜBUNGEN FÜR BEINE ===
            Exercise(name: "Leg Press 45°", muscleGroups: [.legs, .glutes], equipmentType: .machine, description: "45-Grad Beinpresse", instructions: ["45° Winkel einstellen", "Füße schulterbreit", "Tiefe Bewegung für Glutes"]),
            Exercise(name: "Smith Machine Squats", muscleGroups: [.legs, .glutes], equipmentType: .machine, description: "Kniebeugen an der Smith Maschine", instructions: ["Geführte Stange", "Sichere Ausführung", "Verschiedene Fußpositionen möglich"]),
            Exercise(name: "Abduktoren Maschine", muscleGroups: [.legs, .glutes], equipmentType: .machine, description: "Äußere Oberschenkel trainieren", instructions: ["Seitlich an Maschine", "Bein nach außen drücken", "Langsame Rückbewegung"]),
            Exercise(name: "Adduktoren Maschine", muscleGroups: [.legs], equipmentType: .machine, description: "Innere Oberschenkel trainieren", instructions: ["Beine gegen Polster", "Zusammendrücken", "Kontrollierte Bewegung"]),
            Exercise(name: "Glute Ham Raise", muscleGroups: [.legs, .glutes], equipmentType: .machine, description: "Hamstrings und Glutes Maschine", instructions: ["Füße fixiert", "Oberkörper senken und heben", "Hamstrings aktivieren"]),
            
            // === SCHULTERN (Shoulders) ===
            Exercise(name: "Schulterdrücken stehend", muscleGroups: [.shoulders, .triceps], equipmentType: .freeWeights, description: "Militärisches Schulterdrücken", instructions: ["Aufrecht stehen", "Stange von Brust über Kopf", "Vollständige Streckung"]),
            Exercise(name: "Schulterdrücken sitzend", muscleGroups: [.shoulders, .triceps], equipmentType: .freeWeights, description: "Sitzende Schulterdrücken-Variante", instructions: ["Aufrecht auf Bank", "Rücken gestützt", "Gewichte über Kopf"]),
            Exercise(name: "Kurzhantel Schulterdrücken", muscleGroups: [.shoulders, .triceps], equipmentType: .freeWeights, description: "Schulterdrücken mit Kurzhanteln", instructions: ["Kurzhanteln seitlich des Kopfes", "Gleichzeitig nach oben drücken", "Volle Kontrolle"]),
            Exercise(name: "Seitheben", muscleGroups: [.shoulders], equipmentType: .freeWeights, description: "Seitliche Schultermuskulatur", instructions: ["Arme seitlich bis Schulterhöhe", "Kurz halten", "Langsam senken"]),
            Exercise(name: "Seitheben Kabel", muscleGroups: [.shoulders], equipmentType: .cable, description: "Seitheben am Kabelzug", instructions: ["Kabel von unten nach oben", "Seitlich bis Schulterhöhe", "Konstante Spannung"]),
            Exercise(name: "Frontheben", muscleGroups: [.shoulders], equipmentType: .freeWeights, description: "Vordere Schultermuskulatur", instructions: ["Arme nach vorn bis Schulterhöhe", "Wechselweise oder gleichzeitig", "Kontrollierte Bewegung"]),
            Exercise(name: "Reverse Flys Kurzhantel", muscleGroups: [.shoulders, .back], equipmentType: .freeWeights, description: "Hintere Schultermuskulatur", instructions: ["Vorgebeugt", "Arme seitlich heben", "Schulterblätter zusammen"]),
            Exercise(name: "Arnold Press", muscleGroups: [.shoulders, .triceps], equipmentType: .freeWeights, description: "Rotierendes Schulterdrücken", instructions: ["Kurzhanteln vor Brust", "Beim Drücken nach außen rotieren", "Vollständige Bewegung"]),
            Exercise(name: "Upright Rows", muscleGroups: [.shoulders, .back], equipmentType: .freeWeights, description: "Aufrechtes Rudern", instructions: ["Stange nah am Körper hochziehen", "Bis zur Brust", "Ellbogen führen Bewegung"]),
            Exercise(name: "Face Pulls", muscleGroups: [.shoulders, .back], equipmentType: .cable, description: "Kabelzug zum Gesicht", instructions: ["Kabel zur Gesichtshöhe ziehen", "Ellbogen hoch", "Schulterblätter zusammen"]),
            Exercise(name: "Pike Push-ups", muscleGroups: [.shoulders, .triceps], equipmentType: .bodyweight, description: "Bodyweight Schulterübung", instructions: ["Herabschauender Hund Position", "Kopf zum Boden senken", "Hochdrücken"]),
            Exercise(name: "Schulterdrücken Maschine", muscleGroups: [.shoulders, .triceps], equipmentType: .machine, description: "Maschinenübung für sichere Ausführung", instructions: ["Rücken fest an Polster", "Griffe nach oben drücken", "Kontrollierte Bewegung"]),
            Exercise(name: "Reverse Pec Deck", muscleGroups: [.shoulders, .back], equipmentType: .machine, description: "Reverse Flys an der Maschine", instructions: ["Brust gegen Polster", "Arme nach hinten ziehen", "Schulterblätter zusammen"]),
            
            // === WEITERE MASCHINENÜBUNGEN FÜR SCHULTERN ===
            Exercise(name: "Seitenheben Maschine", muscleGroups: [.shoulders], equipmentType: .machine, description: "Laterale Schulter an der Maschine", instructions: ["Arme in Polster", "Seitlich bis Schulterhöhe", "Konstante Spannung"]),
            Exercise(name: "Front Raise Maschine", muscleGroups: [.shoulders], equipmentType: .machine, description: "Frontheben an der Maschine", instructions: ["Arme nach vorn heben", "Bis Schulterhöhe", "Langsame Rückbewegung"]),
            Exercise(name: "Shrug Maschine", muscleGroups: [.shoulders, .back], equipmentType: .machine, description: "Schulterheben an der Maschine", instructions: ["Schultern nach oben ziehen", "2 Sekunden halten", "Langsam senken"]),
            
            // === ARME - BIZEPS (Biceps) ===
            Exercise(name: "Bizep Curls", muscleGroups: [.biceps], equipmentType: .freeWeights, description: "Klassische Bizepsübung", instructions: ["Arme seitlich", "Unterarme nach oben rollen", "Langsam zurück"]),
            Exercise(name: "Bizep Curls Langhantel", muscleGroups: [.biceps], equipmentType: .freeWeights, description: "Bizeps Curls mit Langhantel", instructions: ["Schulterbreiter Griff", "Stange zur Brust rollen", "Nicht schwingen"]),
            Exercise(name: "Hammer Curls", muscleGroups: [.biceps], equipmentType: .freeWeights, description: "Bizeps mit neutralem Griff", instructions: ["Kurzhanteln neutral halten", "Wie Hammer schwingen", "Beide Bizepsköpfe trainieren"]),
            Exercise(name: "Konzentration Curls", muscleGroups: [.biceps], equipmentType: .freeWeights, description: "Sitzende Bizeps Isolation", instructions: ["Ellbogen an Oberschenkel stützen", "Nur Unterarm bewegen", "Volle Konzentration"]),
            Exercise(name: "21s Bizep Curls", muscleGroups: [.biceps], equipmentType: .freeWeights, description: "Intensitätstechnik für Bizeps", instructions: ["7 halbe Wiederholungen unten", "7 halbe oben", "7 volle Bewegungen"]),
            Exercise(name: "Kabel Bizep Curls", muscleGroups: [.biceps], equipmentType: .cable, description: "Bizeps am Kabelzug", instructions: ["Konstante Spannung", "Kabel nach oben ziehen", "Langsam zurück"]),
            Exercise(name: "Preacher Curls", muscleGroups: [.biceps], equipmentType: .machine, description: "Bizeps an der Preacher Bank", instructions: ["Arme auf schräges Polster", "Isolierte Bizepsbewegung", "Volle Dehnung"]),
            Exercise(name: "Spider Curls", muscleGroups: [.biceps], equipmentType: .freeWeights, description: "Bizeps an der Schrägbank", instructions: ["Brust gegen Schrägbank", "Arme hängen gerade runter", "Curls ausführen"]),
            Exercise(name: "Zottman Curls", muscleGroups: [.biceps], equipmentType: .freeWeights, description: "Bizeps mit Rotation", instructions: ["Hoch mit Untergriff", "Oben zu Obergriff drehen", "Runter mit Obergriff"]),
            
            // === WEITERE MASCHINENÜBUNGEN FÜR BIZEPS ===
            Exercise(name: "Bizep Curls Maschine", muscleGroups: [.biceps], equipmentType: .machine, description: "Bizeps an der Maschine", instructions: ["Arme auf Polster", "Gleichmäßige Bewegung", "Volle Streckung vermeiden"]),
            
            // === ARME - TRIZEPS (Triceps) ===
            Exercise(name: "Trizep Dips", muscleGroups: [.triceps], equipmentType: .bodyweight, description: "Körpergewicht Trizepsübung", instructions: ["An Bank oder Barren", "Körper senken", "Nur Arme arbeiten"]),
            Exercise(name: "French Press", muscleGroups: [.triceps], equipmentType: .freeWeights, description: "Liegendes Trizepsdrücken", instructions: ["Auf Rücken liegen", "Stange zur Stirn senken", "Nur Unterarme bewegen"]),
            Exercise(name: "French Press Kurzhantel", muscleGroups: [.triceps], equipmentType: .freeWeights, description: "French Press mit Kurzhanteln", instructions: ["Einzeln oder beide gleichzeitig", "Kurzhantel hinter Kopf", "Isoliert den Trizeps"]),
            Exercise(name: "Trizeps Pushdown", muscleGroups: [.triceps], equipmentType: .cable, description: "Trizeps am Kabelzug", instructions: ["Ellbogen am Körper", "Kabel nach unten drücken", "Arme vollständig strecken"]),
            Exercise(name: "Trizeps Pushdown Seil", muscleGroups: [.triceps], equipmentType: .cable, description: "Trizeps Pushdown mit Seilzug", instructions: ["Seil am Ende auseinanderziehen", "Bessere Trizeps-Aktivierung", "Volle Streckung"]),
            Exercise(name: "Overhead Trizep Extension", muscleGroups: [.triceps], equipmentType: .freeWeights, description: "Trizeps über Kopf", instructions: ["Kurzhantel über Kopf", "Hinter Kopf senken", "Nur Unterarme bewegen"]),
            Exercise(name: "Diamond Push-ups", muscleGroups: [.triceps, .chest], equipmentType: .bodyweight, description: "Enge Liegestütze für Trizeps", instructions: ["Hände Diamantform", "Körper gerade", "Trizeps-fokussierte Bewegung"]),
            Exercise(name: "Close Grip Bench Press", muscleGroups: [.triceps, .chest], equipmentType: .freeWeights, description: "Bankdrücken mit engem Griff", instructions: ["Hände enger als schulterbreit", "Fokus auf Trizeps", "Kontrollierte Bewegung"]),
            Exercise(name: "Trizeps Dip Maschine", muscleGroups: [.triceps], equipmentType: .machine, description: "Assistierte Trizeps Dips", instructions: ["Gewichtsunterstützung einstellen", "Körper senken und heben", "Saubere Ausführung"]),
            
            // === WEITERE MASCHINENÜBUNGEN FÜR TRIZEPS ===
            Exercise(name: "Trizeps Extension Maschine", muscleGroups: [.triceps], equipmentType: .machine, description: "Trizeps-Streckung an der Maschine", instructions: ["Sitzend am Gerät", "Arme nach unten drücken", "Nur Unterarme bewegen"]),
            
            // === BAUCH/CORE (Abs/Core) ===
            Exercise(name: "Plank", muscleGroups: [.abs, .back], equipmentType: .bodyweight, description: "Statische Rumpfstabilisation", instructions: ["Unterarmstütz", "Körper gerade Linie", "Position halten"]),
            Exercise(name: "Side Plank", muscleGroups: [.abs, .back], equipmentType: .bodyweight, description: "Seitlicher Unterarmstütz", instructions: ["Seitlich stützen", "Körper gerade", "Position halten"]),
            Exercise(name: "Crunches", muscleGroups: [.abs], equipmentType: .bodyweight, description: "Klassische Bauchmuskelübung", instructions: ["Rückenlage", "Oberkörper zu Knien", "Bauch anspannen"]),
            Exercise(name: "Bicycle Crunches", muscleGroups: [.abs], equipmentType: .bodyweight, description: "Fahrrad-Crunches", instructions: ["Rückenlage", "Ellbogen zu gegenüberliegendem Knie", "Wechselseitig"]),
            Exercise(name: "Russian Twists", muscleGroups: [.abs], equipmentType: .bodyweight, description: "Seitliche Bauchmuskeln", instructions: ["Sitzend leicht zurücklehnen", "Oberkörper rotieren", "Gewicht optional"]),
            Exercise(name: "Mountain Climbers", muscleGroups: [.abs, .legs], equipmentType: .bodyweight, description: "Dynamische Rumpfübung", instructions: ["Plank Position", "Knie wechselweise zur Brust", "Schnelle Bewegung"]),
            Exercise(name: "Dead Bug", muscleGroups: [.abs, .back], equipmentType: .bodyweight, description: "Rumpfstabilisation liegend", instructions: ["Rückenlage", "Gegenüberliegende Arm-Bein Bewegung", "Rücken am Boden"]),
            Exercise(name: "Hanging Knee Raises", muscleGroups: [.abs], equipmentType: .bodyweight, description: "Knieheben hängend", instructions: ["An Stange hängen", "Knie zur Brust ziehen", "Kontrolliert senken"]),
            Exercise(name: "Hanging Leg Raises", muscleGroups: [.abs], equipmentType: .bodyweight, description: "Beinheben hängend", instructions: ["An Stange hängen", "Gestreckte Beine heben", "Bis 90° oder höher"]),
            Exercise(name: "Ab Wheel Rollout", muscleGroups: [.abs, .back], equipmentType: .freeWeights, description: "Bauchrad für Fortgeschrittene", instructions: ["Kniend mit Rad", "Nach vorn rollen", "Kraft aus Bauch zurück"]),
            Exercise(name: "Flutter Kicks", muscleGroups: [.abs], equipmentType: .bodyweight, description: "Flatterkicks für unteren Bauch", instructions: ["Rückenlage", "Beine abwechselnd heben", "Schnelle kleine Bewegungen"]),
            Exercise(name: "Leg Raises", muscleGroups: [.abs], equipmentType: .bodyweight, description: "Beinheben liegend", instructions: ["Auf Rücken", "Beine gerade nach oben", "Langsam senken ohne abzulegen"]),
            Exercise(name: "V-Ups", muscleGroups: [.abs], equipmentType: .bodyweight, description: "V-förmige Sit-ups", instructions: ["Gleichzeitig Oberkörper und Beine heben", "V-Form bilden", "Kurz halten"]),
            Exercise(name: "Wood Choppers", muscleGroups: [.abs], equipmentType: .cable, description: "Holzhacker-Übung mit Rotation", instructions: ["Diagonale Bewegung", "Von einer Seite zur anderen", "Rumpfrotation"]),
            Exercise(name: "Captain's Chair Knee Raises", muscleGroups: [.abs], equipmentType: .machine, description: "Knieheben am Captain's Chair", instructions: ["Rücken an Polster", "Knie zur Brust ziehen", "Nicht schwingen"]),
            
            // === WEITERE MASCHINENÜBUNGEN FÜR BAUCH ===
            Exercise(name: "Ab Crunch Maschine", muscleGroups: [.abs], equipmentType: .machine, description: "Bauchpresse an der Maschine", instructions: ["Sitzend am Gerät", "Oberkörper nach vorn beugen", "Bauchmuskeln anspannen"]),
            Exercise(name: "Torso Rotation Maschine", muscleGroups: [.abs], equipmentType: .machine, description: "Rumpfdrehung an der Maschine", instructions: ["Sitzend rotieren", "Langsame kontrollierte Bewegung", "Beide Seiten gleich"]),
            
            // === WEITERE FUNKTIONELLE ÜBUNGEN ===
            Exercise(name: "Burpees", muscleGroups: [.legs, .chest, .abs], equipmentType: .bodyweight, description: "Ganzkörper-Konditionsübung", instructions: ["Stehen-Hocken-Liegestütz", "Zurück in Hocke", "Strecksprung"]),
            Exercise(name: "Turkish Get-up", muscleGroups: [.abs, .shoulders, .legs], equipmentType: .freeWeights, description: "Komplexe Ganzkörperübung", instructions: ["Vom Liegen zum Stehen", "Gewicht über Kopf", "Umkehr-Bewegung"]),
            Exercise(name: "Kettlebell Swings", muscleGroups: [.glutes, .legs, .back], equipmentType: .freeWeights, description: "Dynamische Kettlebell Übung", instructions: ["Kettlebell zwischen Beine", "Hüftexplosion nach oben", "Bis Schulterhöhe schwingen"]),
            Exercise(name: "Kettlebell Goblet Squats", muscleGroups: [.legs, .glutes, .abs], equipmentType: .freeWeights, description: "Kniebeugen mit Kettlebell", instructions: ["Kettlebell vor Brust", "Tiefe Kniebeuge", "Rücken gerade"]),
            Exercise(name: "Box Jumps", muscleGroups: [.legs, .glutes], equipmentType: .bodyweight, description: "Explosivkraft für Beine", instructions: ["Auf Box springen", "Vollständig aufrichten", "Kontrolliert runter"]),
            Exercise(name: "Battle Ropes", muscleGroups: [.shoulders, .abs, .legs], equipmentType: .freeWeights, description: "Kondition und Kraft mit Seilen", instructions: ["Seile greifen", "Wellenförmige Bewegungen", "Hohe Intensität"]),
            Exercise(name: "Farmer's Walk", muscleGroups: [.back, .legs, .abs], equipmentType: .freeWeights, description: "Laden und Gehen", instructions: ["Schwere Gewichte greifen", "Aufrecht gehen", "Rumpf stabil"]),
            Exercise(name: "Bear Crawl", muscleGroups: [.shoulders, .abs, .legs], equipmentType: .bodyweight, description: "Vierfüßler-Gang", instructions: ["Hände und Füße am Boden", "Vorwärts krabbeln", "Knie schweben"]),
            Exercise(name: "Wall Sit", muscleGroups: [.legs, .glutes], equipmentType: .bodyweight, description: "Statische Beinübung", instructions: ["Rücken an Wand", "In Sitzposition", "Position halten"]),
            Exercise(name: "Jump Squats", muscleGroups: [.legs, .glutes], equipmentType: .bodyweight, description: "Explosive Kniebeugen", instructions: ["Normale Kniebeuge", "Explosiv nach oben springen", "Weich landen"]),
            Exercise(name: "Single Leg Deadlift", muscleGroups: [.legs, .glutes, .back], equipmentType: .freeWeights, description: "Einbeiniges Kreuzheben", instructions: ["Auf einem Bein", "Oberkörper nach vorn", "Anderes Bein nach hinten"]),
            Exercise(name: "Thrusters", muscleGroups: [.shoulders, .legs, .triceps], equipmentType: .freeWeights, description: "Kniebeuge mit Überkopfdrücken", instructions: ["Kniebeuge mit Kurzhanteln", "Beim Aufstehen über Kopf drücken", "Flüssige Bewegung"]),
            Exercise(name: "Man Makers", muscleGroups: [.chest, .shoulders, .legs, .abs], equipmentType: .freeWeights, description: "Burpee mit Rudern", instructions: ["Liegestütz mit Kurzhanteln", "Rudern rechts und links", "Aufstehen und Überkopfdrücken"]),
            Exercise(name: "Renegade Rows", muscleGroups: [.back, .abs, .chest], equipmentType: .freeWeights, description: "Plank mit Rudern", instructions: ["Plank auf Kurzhanteln", "Abwechselnd rudern", "Hüfte stabil halten"]),
            Exercise(name: "Hindu Push-ups", muscleGroups: [.chest, .shoulders, .triceps, .back], equipmentType: .bodyweight, description: "Fließende Liegestütz-Bewegung", instructions: ["Herabschauender Hund", "Durch nach Cobra", "Zurück zur Startposition"]),
            Exercise(name: "Pistol Squats", muscleGroups: [.legs, .glutes], equipmentType: .bodyweight, description: "Einbeinige Kniebeuge", instructions: ["Ein Bein nach vorn strecken", "Auf einem Bein in Hocke", "Explosiv aufstehen"]),
            Exercise(name: "Archer Push-ups", muscleGroups: [.chest, .triceps, .shoulders], equipmentType: .bodyweight, description: "Einseitige Liegestütze", instructions: ["Breite Armhaltung", "Gewicht auf einen Arm", "Andere Seite"]),
            Exercise(name: "Clean and Press", muscleGroups: [.shoulders, .legs, .back], equipmentType: .freeWeights, description: "Olympische Bewegung", instructions: ["Stange vom Boden", "Zur Schulter reißen", "Über Kopf drücken"]),
            Exercise(name: "Sled Push", muscleGroups: [.legs, .glutes, .shoulders], equipmentType: .freeWeights, description: "Schlitten schieben", instructions: ["Hände am Schlitten", "Vorwärts schieben", "Kurze explosive Schritte"]),
            Exercise(name: "Sled Pull", muscleGroups: [.back, .legs, .biceps], equipmentType: .freeWeights, description: "Schlitten ziehen", instructions: ["Seil oder Griff", "Rückwärts gehen und ziehen", "Körper aufrecht"]),
        ]
    }
}

