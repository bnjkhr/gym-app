import Foundation
import SwiftData

// MARK: - MigrationManager
enum MigrationManager {
    static func migrateIfNeeded(modelContext: ModelContext) throws {
        // If we already have SwiftData workouts, assume migration done
        let existing = try modelContext.fetch(FetchDescriptor<WorkoutEntity>(predicate: nil))
        guard existing.isEmpty else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // MARK: Exercises
        var exerciseById: [UUID: ExerciseEntity] = [:]
        // Try legacy array first
        var migratedExerciseCount = 0
        let legacyExercises: [LegacyExercise] = loadJSONArray("exercises.json", decoder: decoder)
        if !legacyExercises.isEmpty {
            for le in legacyExercises {
                let exercise = ExerciseEntity(
                    id: le.id,
                    name: le.name,
                    muscleGroupsRaw: le.muscleGroups,
                    descriptionText: le.descriptionText,
                    instructions: le.instructions,
                    createdAt: le.createdAt ?? Date()
                )
                exerciseById[exercise.id] = exercise
                modelContext.insert(exercise)
                migratedExerciseCount += 1
            }
        } else {
            // Fallback to app model [Exercise]
            let appExercises: [Exercise] = loadJSONArray("exercises.json", decoder: decoder)
            for ae in appExercises {
                let exercise = ExerciseEntity(
                    id: ae.id,
                    name: ae.name,
                    muscleGroupsRaw: ae.muscleGroups.map { $0.rawValue },
                    descriptionText: ae.description,
                    instructions: ae.instructions,
                    createdAt: ae.createdAt
                )
                exerciseById[exercise.id] = exercise
                modelContext.insert(exercise)
                migratedExerciseCount += 1
            }
        }

        // MARK: Workouts (templates)
        var migratedWorkoutCount = 0
        let legacyWorkouts: [LegacyWorkout] = loadJSONArray("workouts.json", decoder: decoder)
        if !legacyWorkouts.isEmpty {
            for lw in legacyWorkouts {
                let workout = WorkoutEntity(
                    id: lw.id,
                    name: lw.name,
                    date: lw.date,
                    exercises: [],
                    defaultRestTime: lw.defaultRestTime ?? 90,
                    duration: lw.duration,
                    notes: lw.notes ?? "",
                    isFavorite: lw.isFavorite ?? false
                )

                for lwe in lw.exercises {
                    // Resolve exercise (create placeholder if missing)
                    let exercise = exerciseById[lwe.exerciseId] ?? {
                        let e = ExerciseEntity(id: lwe.exerciseId, name: "Unknown Exercise")
                        exerciseById[e.id] = e
                        modelContext.insert(e)
                        return e
                    }()

                    let we = WorkoutExerciseEntity(exercise: exercise)
                    for ls in lwe.sets {
                        let set = ExerciseSetEntity(
                            id: ls.id,
                            reps: ls.reps,
                            weight: ls.weight,
                            restTime: ls.restTime ?? workout.defaultRestTime,
                            completed: ls.completed ?? false
                        )
                        we.sets.append(set)
                    }
                    workout.exercises.append(we)
                }

                modelContext.insert(workout)
                migratedWorkoutCount += 1
            }
        } else {
            // Fallback to app model [Workout]
            let appWorkouts: [Workout] = loadJSONArray("workouts.json", decoder: decoder)
            for aw in appWorkouts {
                let workout = WorkoutEntity(
                    id: aw.id,
                    name: aw.name,
                    date: aw.date,
                    exercises: [],
                    defaultRestTime: aw.defaultRestTime,
                    duration: aw.duration,
                    notes: aw.notes,
                    isFavorite: aw.isFavorite
                )

                for awe in aw.exercises {
                    // Resolve exercise by id or create from embedded
                    let ex = exerciseById[awe.exercise.id] ?? {
                        let e = ExerciseEntity(
                            id: awe.exercise.id,
                            name: awe.exercise.name,
                            muscleGroupsRaw: awe.exercise.muscleGroups.map { $0.rawValue },
                            descriptionText: awe.exercise.description,
                            instructions: awe.exercise.instructions,
                            createdAt: awe.exercise.createdAt
                        )
                        exerciseById[e.id] = e
                        modelContext.insert(e)
                        return e
                    }()

                    let we = WorkoutExerciseEntity(exercise: ex)
                    for s in awe.sets {
                        let set = ExerciseSetEntity(
                            // Generate a stable-ish id by combining workout/ex indices is not available here; use random UUID
                            id: UUID(),
                            reps: s.reps,
                            weight: s.weight,
                            restTime: s.restTime,
                            completed: s.completed
                        )
                        we.sets.append(set)
                    }
                    workout.exercises.append(we)
                }

                modelContext.insert(workout)
                migratedWorkoutCount += 1
            }
        }

        // MARK: Sessions (history)
        var migratedSessionCount = 0
        let legacySessions: [LegacyWorkoutSession] = loadJSONArray("sessions.json", decoder: decoder)
        if !legacySessions.isEmpty {
            for ls in legacySessions {
                let session = WorkoutSessionEntity(
                    id: ls.id,
                    templateId: ls.templateId,
                    name: ls.name,
                    date: ls.date,
                    exercises: [],
                    defaultRestTime: ls.defaultRestTime ?? 90,
                    duration: ls.duration,
                    notes: ls.notes ?? ""
                )

                for lwe in ls.exercises {
                    let exercise = exerciseById[lwe.exerciseId] ?? {
                        let e = ExerciseEntity(id: lwe.exerciseId, name: "Unknown Exercise")
                        exerciseById[e.id] = e
                        modelContext.insert(e)
                        return e
                    }()

                    let we = WorkoutExerciseEntity(exercise: exercise)
                    for lset in lwe.sets {
                        let set = ExerciseSetEntity(
                            id: lset.id,
                            reps: lset.reps,
                            weight: lset.weight,
                            restTime: lset.restTime ?? session.defaultRestTime,
                            completed: lset.completed ?? false
                        )
                        we.sets.append(set)
                    }
                    session.exercises.append(we)
                }

                modelContext.insert(session)
                migratedSessionCount += 1
            }
        } else {
            // Fallback to app model [WorkoutSession]
            let appSessions: [WorkoutSession] = loadJSONArray("sessions.json", decoder: decoder)
            for asess in appSessions {
                let session = WorkoutSessionEntity(
                    id: asess.id,
                    templateId: asess.templateId,
                    name: asess.name,
                    date: asess.date,
                    exercises: [],
                    defaultRestTime: asess.defaultRestTime,
                    duration: asess.duration,
                    notes: asess.notes
                )

                for awe in asess.exercises {
                    let ex = exerciseById[awe.exercise.id] ?? {
                        let e = ExerciseEntity(
                            id: awe.exercise.id,
                            name: awe.exercise.name,
                            muscleGroupsRaw: awe.exercise.muscleGroups.map { $0.rawValue },
                            descriptionText: awe.exercise.description,
                            instructions: awe.exercise.instructions,
                            createdAt: awe.exercise.createdAt
                        )
                        exerciseById[e.id] = e
                        modelContext.insert(e)
                        return e
                    }()

                    let we = WorkoutExerciseEntity(exercise: ex)
                    for s in awe.sets {
                        let set = ExerciseSetEntity(
                            id: UUID(),
                            reps: s.reps,
                            weight: s.weight,
                            restTime: s.restTime,
                            completed: s.completed
                        )
                        we.sets.append(set)
                    }
                    session.exercises.append(we)
                }

                modelContext.insert(session)
                migratedSessionCount += 1
            }
        }

        // MARK: User profile (optional)
        var migratedProfile = false
        if let legacyProfile: LegacyUserProfile = loadJSON("profile.json", decoder: decoder) {
            let data: Data?
            if let base64 = legacyProfile.profileImageBase64 { data = Data(base64Encoded: base64) } else { data = nil }

            let profile = UserProfileEntity(
                id: legacyProfile.id,
                name: legacyProfile.name,
                birthDate: legacyProfile.birthDate,
                weight: legacyProfile.weight,
                goalRaw: legacyProfile.goal ?? "general",
                experienceRaw: legacyProfile.experience ?? "intermediate",
                equipmentRaw: legacyProfile.equipment ?? "mixed",
                preferredDurationRaw: legacyProfile.preferredDuration ?? 45,
                profileImageData: data,
                createdAt: legacyProfile.createdAt ?? Date(),
                updatedAt: legacyProfile.updatedAt ?? Date()
            )
            modelContext.insert(profile)
            migratedProfile = true
        } else if let appProfile: UserProfile = loadJSON("profile.json", decoder: decoder) {
            let profile = UserProfileEntity(
                id: appProfile.id,
                name: appProfile.name,
                birthDate: appProfile.birthDate,
                weight: appProfile.weight,
                goalRaw: appProfile.goal.rawValue,
                experienceRaw: appProfile.experience.rawValue,
                equipmentRaw: appProfile.equipment.rawValue,
                preferredDurationRaw: appProfile.preferredDuration.rawValue,
                profileImageData: appProfile.profileImageData,
                createdAt: appProfile.createdAt,
                updatedAt: appProfile.updatedAt
            )
            modelContext.insert(profile)
            migratedProfile = true
        }

        try modelContext.save()
    }
}

// MARK: - JSON Loading Helpers
private func loadJSONArray<T: Decodable>(_ filename: String, decoder: JSONDecoder) -> [T] {
    if let url = documentsURL(filename), let data = try? Data(contentsOf: url) {
        if let arr = try? decoder.decode([T].self, from: data) { return arr }
    }
    if let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".json", with: ""), withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let arr = try? decoder.decode([T].self, from: data) {
        return arr
    }
    return []
}

private func loadJSON<T: Decodable>(_ filename: String, decoder: JSONDecoder) -> T? {
    if let url = documentsURL(filename), let data = try? Data(contentsOf: url) {
        if let obj = try? decoder.decode(T.self, from: data) { return obj }
    }
    if let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".json", with: ""), withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let obj = try? decoder.decode(T.self, from: data) {
        return obj
    }
    return nil
}

private func documentsURL(_ filename: String) -> URL? {
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    guard let base = urls.first else { return nil }
    return base.appendingPathComponent(filename)
}
