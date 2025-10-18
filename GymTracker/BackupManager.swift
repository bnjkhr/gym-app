import Foundation
import SwiftData
import SwiftUI

@MainActor
class BackupManager: ObservableObject {
    static let shared = BackupManager()
    private init() {}
    
    // MARK: - Backup Creation
    
    func createBackup(from context: ModelContext) throws -> BackupData {
        print("📦 Erstelle Backup...")
        
        // Fetch all data
        let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
        let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
        let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
        let profiles = try context.fetch(FetchDescriptor<UserProfileEntity>())
        
        // Convert to backup format
        let backupWorkouts = workouts.map(convertWorkoutToBackup)
        let backupExercises = exercises.map(convertExerciseToBackup)
        let backupSessions = sessions.map(convertSessionToBackup)
        let backupProfiles = profiles.map(convertProfileToBackup)
        
        let backup = BackupData(
            version: "1.0",
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            workouts: backupWorkouts,
            exercises: backupExercises,
            sessions: backupSessions,
            profiles: backupProfiles,
            metadata: BackupMetadata(
                workoutCount: workouts.count,
                exerciseCount: exercises.count,
                sessionCount: sessions.count,
                profileCount: profiles.count
            )
        )
        
        print("✅ Backup erstellt: \(backup.metadata.workoutCount) Workouts, \(backup.metadata.exerciseCount) Übungen, \(backup.metadata.sessionCount) Sessions")
        return backup
    }
    
    func exportBackupToFile(_ backup: BackupData) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(backup)

        // Create filename with timestamp
        let timestamp = DateFormatters.backupFilename.string(from: Date())
        let filename = "workout_backup_\(timestamp).json"

        // Security: Use Documents directory with file protection instead of temp
        // Temp directory is not encrypted and can be lost
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDir.appendingPathComponent(filename)

        // Security: Write with file protection enabled
        // .complete = File encrypted and inaccessible when device is locked
        try data.write(to: fileURL, options: [.completeFileProtection, .atomic])

        // Security: Exclude from iCloud backup (optional - user decides via share sheet)
        // This keeps backups local-only until user explicitly shares them
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = fileURL
        try? mutableURL.setResourceValues(resourceValues)

        print("📄 Backup-Datei erstellt (verschlüsselt, lokal): \(filename)")
        return fileURL
    }
    
    // MARK: - Backup Restoration
    
    func restoreBackup(from url: URL, to context: ModelContext, mergeStrategy: BackupMergeStrategy = .replace) async throws {
        print("📥 Stelle Backup wieder her...")
        
        // Access security-scoped resource
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Read and parse backup file
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backup = try decoder.decode(BackupData.self, from: data)
        
        // Validate backup
        try validateBackup(backup)
        
        // Apply merge strategy
        switch mergeStrategy {
        case .replace:
            try await replaceAllData(with: backup, in: context)
        case .merge:
            try await mergeData(with: backup, in: context)
        case .addOnly:
            try await addNewData(from: backup, to: context)
        }
        
        print("✅ Backup erfolgreich wiederhergestellt")
    }
    
    private func validateBackup(_ backup: BackupData) throws {
        guard backup.version == "1.0" else {
            throw BackupError.incompatibleVersion(backup.version)
        }
        
        // Basic validation
        if backup.workouts.isEmpty && backup.exercises.isEmpty && backup.sessions.isEmpty {
            throw BackupError.emptyBackup
        }
        
        // Check if backup is too large (safety check)
        let totalItems = backup.workouts.count + backup.exercises.count + backup.sessions.count
        if totalItems > 10000 {
            throw BackupError.backupTooLarge(totalItems)
        }
    }
    
    // MARK: - Merge Strategies
    
    private func replaceAllData(with backup: BackupData, in context: ModelContext) async throws {
        // Delete all existing data
        let existingWorkouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
        let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
        let existingSessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
        let existingProfiles = try context.fetch(FetchDescriptor<UserProfileEntity>())
        
        for workout in existingWorkouts { context.delete(workout) }
        for exercise in existingExercises { context.delete(exercise) }
        for session in existingSessions { context.delete(session) }
        for profile in existingProfiles { context.delete(profile) }
        
        try context.save()
        
        // Restore from backup
        try await addNewData(from: backup, to: context)
    }
    
    private func mergeData(with backup: BackupData, in context: ModelContext) async throws {
        // Merge exercises first (they are referenced by workouts/sessions)
        for backupExercise in backup.exercises {
            let existing = try context.fetch(FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { exercise in exercise.id == backupExercise.id }
            )).first
            
            if let existing = existing {
                // Update existing exercise
                updateExerciseEntity(existing, with: backupExercise)
            } else {
                // Create new exercise
                let newExercise = createExerciseEntity(from: backupExercise)
                context.insert(newExercise)
            }
        }
        try context.save()
        
        // Merge workouts
        for backupWorkout in backup.workouts {
            let existing = try context.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate<WorkoutEntity> { workout in workout.id == backupWorkout.id }
            )).first
            
            if let existing = existing {
                // Update existing workout
                try updateWorkoutEntity(existing, with: backupWorkout, in: context)
            } else {
                // Create new workout
                try createWorkoutEntity(from: backupWorkout, in: context)
            }
        }
        try context.save()
        
        // Merge sessions
        for backupSession in backup.sessions {
            let existing = try context.fetch(FetchDescriptor<WorkoutSessionEntity>(
                predicate: #Predicate<WorkoutSessionEntity> { session in session.id == backupSession.id }
            )).first
            
            if existing == nil {
                // Only create new sessions, don't update existing ones
                try createSessionEntity(from: backupSession, in: context)
            }
        }
        try context.save()
        
        // Merge profiles
        for backupProfile in backup.profiles {
            let existing = try context.fetch(FetchDescriptor<UserProfileEntity>(
                predicate: #Predicate<UserProfileEntity> { profile in profile.id == backupProfile.id }
            )).first
            
            if let existing = existing {
                updateProfileEntity(existing, with: backupProfile)
            } else {
                let newProfile = createProfileEntity(from: backupProfile)
                context.insert(newProfile)
            }
        }
        try context.save()
    }
    
    private func addNewData(from backup: BackupData, to context: ModelContext) async throws {
        // Create exercises first
        for backupExercise in backup.exercises {
            let newExercise = createExerciseEntity(from: backupExercise)
            context.insert(newExercise)
        }
        try context.save()
        
        // Create workouts
        for backupWorkout in backup.workouts {
            try createWorkoutEntity(from: backupWorkout, in: context)
        }
        try context.save()
        
        // Create sessions
        for backupSession in backup.sessions {
            try createSessionEntity(from: backupSession, in: context)
        }
        try context.save()
        
        // Create profiles
        for backupProfile in backup.profiles {
            let newProfile = createProfileEntity(from: backupProfile)
            context.insert(newProfile)
        }
        try context.save()
    }
    
    // MARK: - Entity Conversion (To Backup)
    
    private func convertWorkoutToBackup(_ entity: WorkoutEntity) -> BackupWorkout {
        BackupWorkout(
            id: entity.id,
            name: entity.name,
            date: entity.date,
            exercises: entity.exercises.map(convertWorkoutExerciseToBackup),
            defaultRestTime: Int(entity.defaultRestTime),
            duration: entity.duration ?? 0,
            notes: entity.notes,
            isFavorite: entity.isFavorite,
            level: nil,
            workoutType: nil,
            estimatedDuration: nil,
            frequency: nil
        )
    }
    
    private func convertExerciseToBackup(_ entity: ExerciseEntity) -> BackupExercise {
        BackupExercise(
            id: entity.id,
            name: entity.name,
            category: entity.equipmentTypeRaw, // Map equipment to category
            muscleGroups: entity.muscleGroupsRaw,
            equipment: entity.equipmentTypeRaw,
            instructions: entity.instructions.joined(separator: "\n"),
            tips: entity.descriptionText
        )
    }
    
    private func convertSessionToBackup(_ entity: WorkoutSessionEntity) -> BackupSession {
        BackupSession(
            id: entity.id,
            templateId: entity.templateId,
            name: entity.name,
            date: entity.date,
            exercises: entity.exercises.map(convertWorkoutExerciseToBackup),
            defaultRestTime: Int(entity.defaultRestTime),
            duration: entity.duration ?? 0,
            notes: entity.notes
        )
    }
    
    private func convertProfileToBackup(_ entity: UserProfileEntity) -> BackupProfile {
        BackupProfile(
            id: entity.id,
            name: entity.name,
            weight: entity.weight,
            height: entity.height,
            birthDate: entity.birthDate,
            fitnessLevel: entity.experienceRaw,
            goals: entity.goalRaw,
            notes: "" // UserProfileEntity doesn't have notes field
        )
    }
    
    private func convertWorkoutExerciseToBackup(_ entity: WorkoutExerciseEntity) -> BackupWorkoutExercise {
        BackupWorkoutExercise(
            exerciseId: entity.exercise?.id ?? UUID(),
            sets: entity.sets.map(convertSetToBackup),
            notes: "" // WorkoutExerciseEntity doesn't have notes field
        )
    }
    
    private func convertSetToBackup(_ entity: ExerciseSetEntity) -> BackupSet {
        BackupSet(
            reps: entity.reps,
            weight: entity.weight,
            restTime: Int(entity.restTime),
            completed: entity.completed,
            notes: "" // ExerciseSetEntity doesn't have notes field
        )
    }
    
    // MARK: - Entity Creation (From Backup)
    
    private func createExerciseEntity(from backup: BackupExercise) -> ExerciseEntity {
        let entity = ExerciseEntity(
            id: backup.id,
            name: backup.name,
            muscleGroupsRaw: backup.muscleGroups,
            equipmentTypeRaw: backup.equipment,
            descriptionText: backup.tips,
            instructions: backup.instructions.components(separatedBy: "\n").filter { !$0.isEmpty }
        )
        return entity
    }
    
    private func createWorkoutEntity(from backup: BackupWorkout, in context: ModelContext) throws -> WorkoutEntity {
        // Note: level, workoutType, estimatedDuration, frequency sind in notes gespeichert
        // da WorkoutEntity diese Felder nicht direkt hat
        let entity = WorkoutEntity(
            id: backup.id,
            name: backup.name,
            date: backup.date,
            exercises: [],
            defaultRestTime: TimeInterval(backup.defaultRestTime),
            duration: backup.duration,
            notes: backup.notes,
            isFavorite: backup.isFavorite
        )
        
        // Create exercises
        for backupExercise in backup.exercises {
            if let exerciseEntity = try context.fetch(FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { exercise in exercise.id == backupExercise.exerciseId }
            )).first {
                let workoutExercise = WorkoutExerciseEntity(
                    exercise: exerciseEntity,
                    sets: backupExercise.sets.map { createSetEntity(from: $0) }
                )
                entity.exercises.append(workoutExercise)
            }
        }
        
        context.insert(entity)
        return entity
    }
    
    private func createSessionEntity(from backup: BackupSession, in context: ModelContext) throws -> WorkoutSessionEntity {
        let entity = WorkoutSessionEntity(
            id: backup.id,
            templateId: backup.templateId,
            name: backup.name,
            date: backup.date,
            exercises: [],
            defaultRestTime: TimeInterval(backup.defaultRestTime),
            duration: backup.duration,
            notes: backup.notes
        )
        
        // Create exercises
        for backupExercise in backup.exercises {
            if let exerciseEntity = try context.fetch(FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { exercise in exercise.id == backupExercise.exerciseId }
            )).first {
                let workoutExercise = WorkoutExerciseEntity(
                    exercise: exerciseEntity,
                    sets: backupExercise.sets.map { createSetEntity(from: $0) }
                )
                entity.exercises.append(workoutExercise)
            }
        }
        
        context.insert(entity)
        return entity
    }
    
    private func createProfileEntity(from backup: BackupProfile) -> UserProfileEntity {
        let entity = UserProfileEntity(
            id: backup.id,
            name: backup.name,
            birthDate: backup.birthDate,
            weight: backup.weight,
            height: backup.height,
            goalRaw: backup.goals,
            experienceRaw: backup.fitnessLevel
        )
        return entity
    }
    
    private func createSetEntity(from backup: BackupSet) -> ExerciseSetEntity {
        ExerciseSetEntity(
            reps: backup.reps,
            weight: backup.weight,
            restTime: TimeInterval(backup.restTime),
            completed: backup.completed
        )
    }
    
    // MARK: - Entity Updates
    
    private func updateExerciseEntity(_ entity: ExerciseEntity, with backup: BackupExercise) {
        entity.name = backup.name
        entity.muscleGroupsRaw = backup.muscleGroups
        entity.equipmentTypeRaw = backup.equipment
        entity.descriptionText = backup.tips
        entity.instructions = backup.instructions.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    private func updateWorkoutEntity(_ entity: WorkoutEntity, with backup: BackupWorkout, in context: ModelContext) throws {
        entity.name = backup.name
        entity.date = backup.date
        entity.defaultRestTime = TimeInterval(backup.defaultRestTime)
        entity.duration = backup.duration
        entity.notes = backup.notes
        entity.isFavorite = backup.isFavorite
        
        // Clear and recreate exercises
        entity.exercises.removeAll()
        
        for backupExercise in backup.exercises {
            if let exerciseEntity = try context.fetch(FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { exercise in exercise.id == backupExercise.exerciseId }
            )).first {
                let workoutExercise = WorkoutExerciseEntity(
                    exercise: exerciseEntity,
                    sets: backupExercise.sets.map { createSetEntity(from: $0) }
                )
                entity.exercises.append(workoutExercise)
            }
        }
    }
    
    private func updateProfileEntity(_ entity: UserProfileEntity, with backup: BackupProfile) {
        entity.name = backup.name
        entity.birthDate = backup.birthDate
        entity.weight = backup.weight
        entity.height = backup.height
        entity.goalRaw = backup.goals
        entity.experienceRaw = backup.fitnessLevel
        entity.updatedAt = Date()
    }

    // MARK: - Security: Backup Cleanup

    /// Security: Clean up old backup files to prevent storage bloat and reduce attack surface
    /// Keeps only the most recent N backup files
    func cleanupOldBackups(keepRecent: Int = 5) {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        do {
            // Find all backup files
            let backupFiles = try fileManager.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.lastPathComponent.hasPrefix("workout_backup_") && $0.pathExtension == "json" }
                .sorted { (url1, url2) -> Bool in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }

            // Delete old backups, keep only recent N
            let filesToDelete = backupFiles.dropFirst(keepRecent)
            for file in filesToDelete {
                try fileManager.removeItem(at: file)
                print("🗑️ Deleted old backup: \(file.lastPathComponent)")
            }

            if !filesToDelete.isEmpty {
                print("✅ Cleaned up \(filesToDelete.count) old backup files")
            }
        } catch {
            print("⚠️ Failed to cleanup old backups: \(error.localizedDescription)")
        }
    }
}

// MARK: - Backup Data Models

struct BackupData: Codable {
    let version: String
    let createdAt: Date
    let appVersion: String
    let workouts: [BackupWorkout]
    let exercises: [BackupExercise]
    let sessions: [BackupSession]
    let profiles: [BackupProfile]
    let metadata: BackupMetadata
}

struct BackupMetadata: Codable {
    let workoutCount: Int
    let exerciseCount: Int
    let sessionCount: Int
    let profileCount: Int
}

struct BackupWorkout: Codable {
    let id: UUID
    let name: String
    let date: Date
    let exercises: [BackupWorkoutExercise]
    let defaultRestTime: Int
    let duration: TimeInterval
    let notes: String
    let isFavorite: Bool
    let level: String?
    let workoutType: String?
    let estimatedDuration: String?
    let frequency: String?
}

struct BackupExercise: Codable {
    let id: UUID
    let name: String
    let category: String
    let muscleGroups: [String]
    let equipment: String
    let instructions: String
    let tips: String
}

struct BackupSession: Codable {
    let id: UUID
    let templateId: UUID?
    let name: String
    let date: Date
    let exercises: [BackupWorkoutExercise]
    let defaultRestTime: Int
    let duration: TimeInterval
    let notes: String
}

struct BackupProfile: Codable {
    let id: UUID
    let name: String
    let weight: Double?
    let height: Double?
    let birthDate: Date?
    let fitnessLevel: String
    let goals: String
    let notes: String
}

struct BackupWorkoutExercise: Codable {
    let exerciseId: UUID
    let sets: [BackupSet]
    let notes: String
}

struct BackupSet: Codable {
    let reps: Int
    let weight: Double
    let restTime: Int
    let completed: Bool
    let notes: String
}

// MARK: - Backup Options

enum BackupMergeStrategy: CaseIterable {
    case replace    // Replace all existing data
    case merge      // Update existing, add new
    case addOnly    // Only add new items, don't update existing
    
    var displayName: String {
        switch self {
        case .replace: return "Alle Daten ersetzen"
        case .merge: return "Zusammenführen"
        case .addOnly: return "Nur neue Daten hinzufügen"
        }
    }
    
    var description: String {
        switch self {
        case .replace: return "Löscht alle vorhandenen Daten und ersetzt sie durch das Backup"
        case .merge: return "Aktualisiert vorhandene Daten und fügt neue hinzu"
        case .addOnly: return "Fügt nur neue Daten hinzu, ohne vorhandene zu ändern"
        }
    }
}

// MARK: - Backup Errors

enum BackupError: LocalizedError {
    case incompatibleVersion(String)
    case emptyBackup
    case backupTooLarge(Int)
    case corruptedBackup
    case missingExercises([UUID])
    
    var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let version):
            return "Inkompatible Backup-Version: \(version). Diese App unterstützt nur Version 1.0."
        case .emptyBackup:
            return "Das Backup enthält keine Daten."
        case .backupTooLarge(let count):
            return "Das Backup ist zu groß (\(count) Einträge). Maximum sind 10.000 Einträge."
        case .corruptedBackup:
            return "Das Backup ist beschädigt und kann nicht gelesen werden."
        case .missingExercises(let ids):
            return "Fehlende Übungen im Backup (IDs: \(ids.map { $0.uuidString.prefix(8) }.joined(separator: ", ")))."
        }
    }
}
