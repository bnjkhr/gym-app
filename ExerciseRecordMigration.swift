import Foundation
import SwiftData

/// Migration utility for generating ExerciseRecords from existing workout sessions
@MainActor
class ExerciseRecordMigration {
    
    /// Check if migration is needed by looking for any ExerciseRecords
    static func isMigrationNeeded(context: ModelContext) async -> Bool {
        do {
            // Try to fetch ExerciseRecordEntity - use simple descriptor without predicate
            let recordDescriptor = FetchDescriptor<ExerciseRecordEntity>()
            let existingRecords = try context.fetch(recordDescriptor)

            // Try to fetch WorkoutSessionEntity - use simple descriptor without predicate
            let sessionDescriptor = FetchDescriptor<WorkoutSessionEntity>()
            let existingSessions = try context.fetch(sessionDescriptor)

            // Migration needed if we have sessions but no records
            let migrationNeeded = existingRecords.isEmpty && !existingSessions.isEmpty

            if migrationNeeded {
                print("🔄 ExerciseRecord Migration benötigt: \(existingSessions.count) Sessions gefunden, aber keine Records")
            } else {
                print("✅ ExerciseRecord Migration nicht benötigt: \(existingRecords.count) Records vorhanden")
            }

            return migrationNeeded
        } catch {
            print("❌ Fehler beim Prüfen der Migration: \(error)")
            // Bei einem Fehler (z.B. Schema-Problem) keine Migration durchführen
            return false
        }
    }
    
    /// Migrate existing workout sessions to generate ExerciseRecords
    static func migrateExistingData(context: ModelContext) async {
        print("🔄 Starte ExerciseRecord Migration...")

        do {
            var sessionDescriptor = FetchDescriptor<WorkoutSessionEntity>()
            sessionDescriptor.sortBy = [SortDescriptor(\WorkoutSessionEntity.date, order: .forward)]
            let sessions = try context.fetch(sessionDescriptor)
            
            print("📊 Analysiere \(sessions.count) Sessions für Personal Records...")
            
            var exerciseRecords: [UUID: ExerciseRecordEntity] = [:]
            var processedSets = 0
            
            for session in sessions {
                for workoutExercise in session.exercises {
                    guard let exercise = workoutExercise.exercise else { continue }
                    
                    // Find or create record for this exercise
                    let record = exerciseRecords[exercise.id] ?? {
                        let newRecord = ExerciseRecordEntity(
                            exerciseId: exercise.id,
                            exerciseName: exercise.name
                        )
                        exerciseRecords[exercise.id] = newRecord
                        return newRecord
                    }()
                    
                    // Process each set for records
                    for set in workoutExercise.sets {
                        guard set.completed else { continue }
                        
                        let weight = set.weight
                        let reps = set.reps
                        let date = session.date
                        
                        processedSets += 1
                        
                        // Check for max weight record
                        if weight > record.maxWeight {
                            record.maxWeight = weight
                            record.maxWeightReps = reps
                            record.maxWeightDate = date
                        }
                        
                        // Check for max reps record
                        if reps > record.maxReps {
                            record.maxReps = reps
                            record.maxRepsWeight = weight
                            record.maxRepsDate = date
                        }
                        
                        // Calculate estimated 1RM using ExerciseRecord helper
                        let estimatedOneRepMax = ExerciseRecord.estimateOneRepMax(weight: weight, reps: reps)
                        if estimatedOneRepMax > record.bestEstimatedOneRepMax {
                            record.bestEstimatedOneRepMax = estimatedOneRepMax
                            record.bestOneRepMaxWeight = weight
                            record.bestOneRepMaxReps = reps
                            record.bestOneRepMaxDate = date
                        }
                        
                        // Update timestamps
                        record.updatedAt = date
                    }
                }
            }
            
            // Insert all records into context
            for record in exerciseRecords.values {
                context.insert(record)
            }
            
            try context.save()
            
            print("✅ ExerciseRecord Migration abgeschlossen:")
            print("   • \(exerciseRecords.count) ExerciseRecords erstellt")
            print("   • \(processedSets) Sätze analysiert")
            print("   • Records für \(exerciseRecords.keys.count) verschiedene Übungen")
            
        } catch {
            print("❌ Fehler bei ExerciseRecord Migration: \(error)")
        }
    }
    
    /// Update records for a single workout session
    static func updateRecords(from session: WorkoutSessionEntity, context: ModelContext) async {
        do {
            for workoutExercise in session.exercises {
                guard let exercise = workoutExercise.exercise else { continue }
                
                // Find existing record or create new one
                let exerciseId = exercise.id
                var descriptor = FetchDescriptor<ExerciseRecordEntity>(
                    predicate: #Predicate<ExerciseRecordEntity> { record in
                        record.exerciseId == exerciseId
                    }
                )
                descriptor.fetchLimit = 1

                let existingRecord = try context.fetch(descriptor).first
                let record = existingRecord ?? {
                    let newRecord = ExerciseRecordEntity(
                        exerciseId: exercise.id,
                        exerciseName: exercise.name
                    )
                    context.insert(newRecord)
                    return newRecord
                }()
                
                // Process each completed set
                for set in workoutExercise.sets {
                    guard set.completed else { continue }
                    
                    let weight = set.weight
                    let reps = set.reps
                    let date = session.date
                    
                    // Check for new records
                    var hasNewRecord = false
                    
                    if weight > record.maxWeight {
                        record.maxWeight = weight
                        record.maxWeightReps = reps
                        record.maxWeightDate = date
                        hasNewRecord = true
                        print("🏆 Neuer Gewichts-Rekord für \(exercise.name): \(weight) kg x \(reps)")
                    }
                    
                    if reps > record.maxReps {
                        record.maxReps = reps
                        record.maxRepsWeight = weight
                        record.maxRepsDate = date
                        hasNewRecord = true
                        print("🏆 Neuer Wiederholungs-Rekord für \(exercise.name): \(reps) x \(weight) kg")
                    }
                    
                    let estimatedOneRepMax = ExerciseRecord.estimateOneRepMax(weight: weight, reps: reps)
                    if estimatedOneRepMax > record.bestEstimatedOneRepMax {
                        record.bestEstimatedOneRepMax = estimatedOneRepMax
                        record.bestOneRepMaxWeight = weight
                        record.bestOneRepMaxReps = reps
                        record.bestOneRepMaxDate = date
                        hasNewRecord = true
                        print("🏆 Neuer 1RM-Rekord für \(exercise.name): \(String(format: "%.1f", estimatedOneRepMax)) kg (\(weight) kg x \(reps))")
                    }
                    
                    if hasNewRecord {
                        record.updatedAt = date
                    }
                }
            }
            
            try context.save()
            
        } catch {
            print("❌ Fehler beim Aktualisieren der ExerciseRecords: \(error)")
        }
    }
}