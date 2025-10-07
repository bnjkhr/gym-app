import Foundation
import SwiftData

// MARK: - Shareable Workout Format (JSON)

struct ShareableWorkout: Codable {
    let version: String
    let workout: WorkoutData

    init(workout: WorkoutData) {
        self.version = "1.0"
        self.workout = workout
    }

    struct WorkoutData: Codable {
        let name: String
        let defaultRestTime: TimeInterval
        let notes: String
        let exercises: [ExerciseData]
    }

    struct ExerciseData: Codable {
        let exerciseId: String  // UUID als String
        let exerciseName: String // Für Anzeige & Fallback
        let sets: [SetData]
    }

    struct SetData: Codable {
        let reps: Int
        let weight: Double
        let restTime: TimeInterval
    }
}

// MARK: - Export Helper

extension ShareableWorkout {
    /// Erstellt ShareableWorkout aus WorkoutEntity
    static func from(entity: WorkoutEntity) -> ShareableWorkout {
        let exercises = entity.exercises.map { workoutExercise in
            ExerciseData(
                exerciseId: workoutExercise.exercise?.id.uuidString ?? "",
                exerciseName: workoutExercise.exercise?.name ?? "Unbekannte Übung",
                sets: workoutExercise.sets.map { set in
                    SetData(
                        reps: set.reps,
                        weight: set.weight,
                        restTime: set.restTime
                    )
                }
            )
        }

        let workoutData = WorkoutData(
            name: entity.name,
            defaultRestTime: entity.defaultRestTime,
            notes: entity.notes,
            exercises: exercises
        )

        return ShareableWorkout(workout: workoutData)
    }

    /// Exportiert als JSON-Datei
    func exportToFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(self)

        // Temporäre Datei erstellen
        let fileName = "\(workout.name.replacingOccurrences(of: " ", with: "_")).gymtracker"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        try jsonData.write(to: tempURL)

        print("✅ Workout exportiert nach: \(tempURL)")
        return tempURL
    }
}

// MARK: - Import Helper

extension ShareableWorkout {
    /// Importiert Workout aus JSON-Datei
    static func importFrom(url: URL) throws -> ShareableWorkout {
        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let shareable = try decoder.decode(ShareableWorkout.self, from: jsonData)

        print("✅ Workout '\(shareable.workout.name)' aus Datei geladen")
        return shareable
    }

    /// Erstellt WorkoutEntity aus ShareableWorkout
    func toWorkoutEntity(in context: ModelContext, exerciseEntities: [ExerciseEntity]) throws -> WorkoutEntity {
        // Erstelle neue WorkoutEntity
        let workoutEntity = WorkoutEntity(
            name: "\(workout.name) (Importiert)",
            date: Date(),
            exercises: [],
            defaultRestTime: workout.defaultRestTime,
            duration: nil,
            notes: workout.notes,
            isFavorite: false,
            isSampleWorkout: false
        )

        // Erstelle Übungen und Sets
        for (index, exerciseData) in workout.exercises.enumerated() {
            // Finde Exercise in DB
            guard let exerciseId = UUID(uuidString: exerciseData.exerciseId),
                  let exerciseEntity = exerciseEntities.first(where: { $0.id == exerciseId }) else {
                print("⚠️ Übung '\(exerciseData.exerciseName)' (ID: \(exerciseData.exerciseId)) nicht gefunden - überspringe")
                continue
            }

            // Erstelle WorkoutExerciseEntity with order
            let workoutExercise = WorkoutExerciseEntity(exercise: exerciseEntity, order: index)

            // Erstelle Sets
            for setData in exerciseData.sets {
                let setEntity = ExerciseSetEntity(
                    reps: setData.reps,
                    weight: setData.weight,
                    restTime: setData.restTime,
                    completed: false
                )
                workoutExercise.sets.append(setEntity)
                context.insert(setEntity)
            }

            workoutEntity.exercises.append(workoutExercise)
            context.insert(workoutExercise)
        }

        // Speichere in SwiftData
        context.insert(workoutEntity)
        try context.save()

        print("✅ Workout '\(workout.name)' erfolgreich importiert")
        return workoutEntity
    }
}
