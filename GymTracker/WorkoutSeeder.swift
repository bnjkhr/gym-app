import Foundation
import SwiftData

struct WorkoutSeeder {

    static func seedWorkouts(context: ModelContext) {
        let sampleWorkouts = createWorkoutsFromCSV(context: context)

        for workout in sampleWorkouts {
            // Explizit alle WorkoutExerciseEntity und ihre Sets in den Context einfügen
            for exercise in workout.exercises {
                context.insert(exercise)
                for set in exercise.sets {
                    context.insert(set)
                }
            }
            context.insert(workout)
        }

        do {
            try context.save()
            print("✅ Seeded \(sampleWorkouts.count) sample workouts")
        } catch {
            print("❌ Fehler beim Speichern der Workouts: \(error)")
        }
    }

    static func createWorkoutsFromCSV(context: ModelContext) -> [WorkoutEntity] {
        guard let csvPath = Bundle.main.path(forResource: "workouts_with_ids", ofType: "csv") else {
            print("⚠️ workouts_with_ids.csv file not found")
            return []
        }

        do {
            let csvContent = try String(contentsOfFile: csvPath, encoding: .utf8)
            return parseWorkoutsCSV(csvContent, context: context)
        } catch {
            print("❌ Error reading workouts CSV: \(error)")
            return []
        }
    }

    private static func parseWorkoutsCSV(_ content: String, context: ModelContext) -> [WorkoutEntity] {
        let lines = content.components(separatedBy: .newlines)
        var workouts: [WorkoutEntity] = []
        var currentWorkoutData: [String: Any] = [:]
        var currentExercises: [WorkoutExerciseEntity] = []

        // Fetch all existing exercises from the database
        let exerciseDescriptor = FetchDescriptor<ExerciseEntity>()
        let allExercises = (try? context.fetch(exerciseDescriptor)) ?? []

        // Create a lookup dictionary for faster ID-based search
        var exercisesByUUID: [UUID: ExerciseEntity] = [:]
        for exercise in allExercises {
            exercisesByUUID[exercise.id] = exercise
        }

        // Skip header (line 0)
        for (index, line) in lines.enumerated() {
            guard index > 0, !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let columns = line.components(separatedBy: ",")
            guard columns.count >= 13 else { continue }

            let workoutIdStr = columns[0].trimmingCharacters(in: .whitespaces)
            let workoutName = columns[1].trimmingCharacters(in: .whitespaces)
            let niveau = columns[3].trimmingCharacters(in: .whitespaces)
            let typ = columns[4].trimmingCharacters(in: .whitespaces)
            let dauer = columns[5].trimmingCharacters(in: .whitespaces)
            let frequenz = columns[6].trimmingCharacters(in: .whitespaces)

            let exerciseIdStr = columns[8].trimmingCharacters(in: .whitespaces)
            let setsStr = columns[9].trimmingCharacters(in: .whitespaces)
            let repsStr = columns[10].trimmingCharacters(in: .whitespaces)
            let restStr = columns[11].trimmingCharacters(in: .whitespaces)

            // Check if we're starting a new workout (by workout ID)
            if let currentWorkoutId = currentWorkoutData["id"] as? String, currentWorkoutId != workoutIdStr {
                // Save previous workout if exists
                if !currentWorkoutData.isEmpty {
                    let workout = createWorkoutEntity(
                        from: currentWorkoutData,
                        exercises: currentExercises
                    )
                    workouts.append(workout)
                }

                // Start new workout
                currentWorkoutData = [
                    "id": workoutIdStr,
                    "name": workoutName,
                    "niveau": niveau,
                    "typ": typ,
                    "dauer": dauer,
                    "frequenz": frequenz
                ]
                currentExercises = []
            } else if currentWorkoutData.isEmpty {
                // First workout
                currentWorkoutData = [
                    "id": workoutIdStr,
                    "name": workoutName,
                    "niveau": niveau,
                    "typ": typ,
                    "dauer": dauer,
                    "frequenz": frequenz
                ]
            }

            // Find exercise in database by ID
            if let exerciseId = Int(exerciseIdStr) {
                // Create deterministic UUID from exercise ID (same logic as ExerciseSeeder)
                let uuidString = NSString(format: "00000000-0000-0000-0000-%012d", exerciseId) as String

                if let exerciseUUID = UUID(uuidString: uuidString),
                   let exerciseEntity = exercisesByUUID[exerciseUUID] {
                    let sets = parseSets(setsStr: setsStr, repsStr: repsStr, restStr: restStr)
                    let workoutExercise = WorkoutExerciseEntity(
                        exercise: exerciseEntity,
                        sets: sets
                    )
                    currentExercises.append(workoutExercise)
                }
            }
        }

        // Add last workout
        if !currentWorkoutData.isEmpty {
            let workout = createWorkoutEntity(
                from: currentWorkoutData,
                exercises: currentExercises
            )
            workouts.append(workout)
        }

        return workouts
    }

    private static func createWorkoutEntity(
        from data: [String: Any],
        exercises: [WorkoutExerciseEntity]
    ) -> WorkoutEntity {
        let name = data["name"] as? String ?? "Workout"
        let niveau = data["niveau"] as? String
        let typ = data["typ"] as? String
        let dauer = data["dauer"] as? String
        let frequenz = data["frequenz"] as? String

        // Create WorkoutEntity
        let workout = WorkoutEntity(
            name: name,
            date: Date(),
            exercises: exercises,
            defaultRestTime: 90,
            duration: nil,
            notes: [niveau, typ, dauer, frequenz]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " • "),
            isFavorite: false
        )

        // Setze bidirektionale Beziehung
        for exercise in exercises {
            exercise.workout = workout
        }

        return workout
    }

    private static func parseSets(setsStr: String, repsStr: String, restStr: String) -> [ExerciseSetEntity] {
        // Parse number of sets
        let numSets: Int
        if let sets = Int(setsStr) {
            numSets = sets
        } else {
            numSets = 3 // default
        }

        // Parse reps (can be like "12-15" or "30 Sek" or "10 pro Seite")
        let reps = parseReps(repsStr)

        // Parse rest time in seconds
        let restTime = parseRestTime(restStr)

        // Create sets
        var sets: [ExerciseSetEntity] = []
        for _ in 0..<numSets {
            let set = ExerciseSetEntity(
                reps: reps,
                weight: 0, // User will fill this in
                restTime: restTime,
                completed: false
            )
            sets.append(set)
        }

        return sets
    }

    private static func parseReps(_ repsStr: String) -> Int {
        // Handle formats like "12-15", "30 Sek", "10 pro Seite"
        if repsStr.contains("-") {
            // Take the lower value of range
            let components = repsStr.components(separatedBy: "-")
            if let first = components.first,
               let value = Int(first.trimmingCharacters(in: .whitespaces)) {
                return value
            }
        }

        if repsStr.lowercased().contains("sek") {
            // Convert seconds to reps (e.g., 30 Sek -> 30 reps for time-based exercises)
            if let value = Int(repsStr.components(separatedBy: .whitespaces).first ?? "") {
                return value
            }
        }

        if repsStr.lowercased().contains("pro seite") || repsStr.lowercased().contains("max") {
            // Extract number before "pro Seite"
            if let value = Int(repsStr.components(separatedBy: .whitespaces).first ?? "") {
                return value
            }
        }

        // Try to parse as plain integer
        if let value = Int(repsStr.trimmingCharacters(in: .whitespaces)) {
            return value
        }

        return 10 // default
    }

    private static func parseRestTime(_ restStr: String) -> TimeInterval {
        // Handle formats like "90", "120 nach Runde", "0 (90 nach Runde)"
        let cleanStr = restStr.components(separatedBy: "(").first ?? restStr

        if let value = Int(cleanStr.trimmingCharacters(in: .whitespaces)) {
            return TimeInterval(value)
        }

        // Try to extract number from string
        let numbers = cleanStr.components(separatedBy: .whitespaces)
            .compactMap { Int($0) }

        if let first = numbers.first {
            return TimeInterval(first)
        }

        return 90 // default
    }
}
