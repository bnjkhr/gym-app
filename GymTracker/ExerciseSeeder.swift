import Foundation
import SwiftData

struct ExerciseSeeder {
    
    static func seedExercises(context: ModelContext) {
        let sampleExercises = createRealisticExercises()

        for exercise in sampleExercises {
            let entity = ExerciseEntity.make(from: exercise)
            context.insert(entity)
        }

        try? context.save()
    }
    static func createRealisticExercises() -> [Exercise] {
        guard let csvPath = Bundle.main.path(forResource: "exercises", ofType: "csv") else {
            print("⚠️ CSV file not found")
            return []
        }

        do {
            let csvContent = try String(contentsOfFile: csvPath, encoding: .utf8)
            return parseCSV(csvContent)
        } catch {
            print("❌ Error reading CSV: \(error)")
            return []
        }
    }

    private static func parseCSV(_ content: String) -> [Exercise] {
        let lines = content.components(separatedBy: .newlines)
        var exercises: [Exercise] = []

        // Skip header (line 0) and empty lines
        for (index, line) in lines.enumerated() {
            guard index > 0, !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let columns = line.components(separatedBy: ",")
            guard columns.count >= 5 else { continue }

            let name = columns[0].trimmingCharacters(in: .whitespaces)
            let muscleGroupsStr = columns[1].trimmingCharacters(in: .whitespaces)
            let equipmentTypeStr = columns[2].trimmingCharacters(in: .whitespaces)
            let difficultyLevelStr = columns[3].trimmingCharacters(in: .whitespaces)
            let description = columns[4].trimmingCharacters(in: .whitespaces)

            // Parse muscle groups (separated by ;)
            let muscleGroups = muscleGroupsStr.components(separatedBy: ";")
                .compactMap { parseMuscleGroup($0.trimmingCharacters(in: .whitespaces)) }

            // Parse equipment type
            guard let equipmentType = parseEquipmentType(equipmentTypeStr) else { continue }

            // Parse difficulty level
            guard let difficultyLevel = parseDifficultyLevel(difficultyLevelStr) else { continue }

            // Parse instructions (columns 5-8)
            var instructions: [String] = []
            for i in 5..<min(columns.count, 9) {
                let instruction = columns[i].trimmingCharacters(in: .whitespaces)
                if !instruction.isEmpty {
                    instructions.append(instruction)
                }
            }

            let exercise = Exercise(
                name: name,
                muscleGroups: muscleGroups,
                equipmentType: equipmentType,
                difficultyLevel: difficultyLevel,
                description: description,
                instructions: instructions
            )

            exercises.append(exercise)
        }

        return exercises
    }

    private static func parseMuscleGroup(_ value: String) -> MuscleGroup? {
        switch value.lowercased() {
        case "chest": return .chest
        case "back": return .back
        case "shoulders": return .shoulders
        case "biceps": return .biceps
        case "triceps": return .triceps
        case "legs": return .legs
        case "glutes": return .glutes
        case "abs": return .abs
        case "cardio": return .cardio
        case "forearms": return .forearms
        case "calves": return .calves
        case "trapezius": return .trapezius
        case "lowerback": return .lowerBack
        case "upperback": return .upperBack
        case "fullbody": return .fullBody
        case "hips": return .hips
        case "core": return .core
        case "hamstrings": return .hamstrings
        case "lats": return .lats
        case "grip": return .grip
        case "arms": return .arms
        case "adductors": return .adductors
        case "obliques": return .obliques
        case "hipflexors": return .hipFlexors
        case "traps": return .traps
        case "coordination": return .coordination
        default:
            print("⚠️ Unknown muscle group: \(value)")
            return nil
        }
    }

    private static func parseEquipmentType(_ value: String) -> EquipmentType? {
        switch value.lowercased() {
        case "freeweights": return .freeWeights
        case "machine": return .machine
        case "bodyweight": return .bodyweight
        case "cable": return .cable
        case "mixed": return .mixed
        default:
            print("⚠️ Unknown equipment type: \(value)")
            return nil
        }
    }

    private static func parseDifficultyLevel(_ value: String) -> DifficultyLevel? {
        switch value.lowercased() {
        case "beginner": return .anfänger
        case "intermediate": return .fortgeschritten
        case "advanced": return .profi
        default:
            print("⚠️ Unknown difficulty level: \(value)")
            return nil
        }
    }
}

