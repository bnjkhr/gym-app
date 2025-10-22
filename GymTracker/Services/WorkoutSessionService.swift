import Foundation
import SwiftData

/// Service für Workout Session CRUD-Operationen
/// Verantwortlich für:
/// - Session-Vorbereitung und Validierung
/// - Session-Persistierung
/// - Session-Löschung
@MainActor
final class WorkoutSessionService {

    // MARK: - Error Handling

    enum SessionError: Error, LocalizedError {
        case missingModelContext
        case sessionNotFound
        case invalidWorkoutId
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .missingModelContext:
                return "ModelContext ist nicht verfügbar"
            case .sessionNotFound:
                return "Workout-Session nicht gefunden"
            case .invalidWorkoutId:
                return "Ungültige Workout-ID"
            case .saveFailed(let error):
                return "Fehler beim Speichern: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private var modelContext: ModelContext?

    // MARK: - Context Management

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    // MARK: - Session Preparation

    /// Bereitet eine Session für ein Workout vor
    /// - Parameter workoutId: Die ID des Workouts
    /// - Returns: Das WorkoutEntity oder nil wenn nicht gefunden
    /// - Throws: SessionError wenn ModelContext fehlt
    func prepareSessionStart(for workoutId: UUID) throws -> WorkoutEntity? {
        guard let context = modelContext else {
            throw SessionError.missingModelContext
        }

        // Fetch das Workout
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate<WorkoutEntity> { workout in
                workout.id == workoutId
            }
        )

        guard let workoutEntity = try? context.fetch(descriptor).first else {
            return nil
        }

        print("✅ Workout vorbereitet: \(workoutEntity.name)")
        return workoutEntity
    }

    // MARK: - Session Recording

    /// Speichert eine abgeschlossene Workout-Session
    /// - Parameter session: Die WorkoutSessionV1 zum Speichern
    /// - Returns: Das gespeicherte WorkoutSessionEntityV1
    /// - Throws: SessionError bei Fehlern
    func recordSession(_ session: WorkoutSessionV1) throws -> WorkoutSessionEntityV1 {
        guard let context = modelContext else {
            throw SessionError.missingModelContext
        }

        // Erstelle zuerst alle WorkoutExerciseEntities
        var workoutExerciseEntities: [WorkoutExerciseEntity] = []

        for (index, workoutExercise) in session.exercises.enumerated() {
            // Finde die ExerciseEntity
            let exerciseDescriptor = FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate<ExerciseEntity> { entity in
                    entity.id == workoutExercise.exercise.id
                }
            )

            guard let exerciseEntity = try? context.fetch(exerciseDescriptor).first else {
                print("⚠️ ExerciseEntity nicht gefunden für: \(workoutExercise.exercise.name)")
                continue
            }

            let workoutExerciseEntity = WorkoutExerciseEntity(
                exercise: exerciseEntity,
                order: index
            )

            // Erstelle ExerciseSetEntities für jeden Satz
            for set in workoutExercise.sets {
                let setEntity = ExerciseSetEntity(
                    reps: set.reps,
                    weight: set.weight,
                    restTime: set.restTime,
                    completed: set.completed
                )
                workoutExerciseEntity.sets.append(setEntity)
            }

            workoutExerciseEntities.append(workoutExerciseEntity)
        }

        // Erstelle WorkoutSessionEntityV1 mit allen erforderlichen Parametern
        let sessionEntity = WorkoutSessionEntityV1(
            id: session.id,
            templateId: session.templateId,
            name: session.name,
            date: session.date,
            exercises: workoutExerciseEntities,
            defaultRestTime: session.defaultRestTime,
            duration: session.duration,
            notes: session.notes,
            minHeartRate: session.minHeartRate,
            maxHeartRate: session.maxHeartRate,
            avgHeartRate: session.avgHeartRate
        )

        // Insert und Save
        context.insert(sessionEntity)

        do {
            try context.save()
            print("✅ Session gespeichert: \(session.name)")
            return sessionEntity
        } catch {
            throw SessionError.saveFailed(error)
        }
    }

    // MARK: - Session Deletion

    /// Entfernt eine Session
    /// - Parameter id: Die Session-ID
    /// - Throws: SessionError bei Fehlern
    func removeSession(with id: UUID) throws {
        guard let context = modelContext else {
            throw SessionError.missingModelContext
        }

        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate<WorkoutSessionEntity> { entity in
                entity.id == id
            }
        )

        guard let sessionEntity = try? context.fetch(descriptor).first else {
            throw SessionError.sessionNotFound
        }

        context.delete(sessionEntity)

        do {
            try context.save()
            print("✅ Session gelöscht: \(id.uuidString.prefix(8))")
        } catch {
            throw SessionError.saveFailed(error)
        }
    }

    // MARK: - Session Queries

    /// Holt eine Session anhand der ID
    /// - Parameter id: Die Session-ID
    /// - Returns: Die WorkoutSessionV1 oder nil
    func getSession(with id: UUID) -> WorkoutSessionV1? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate<WorkoutSessionEntity> { entity in
                entity.id == id
            }
        )

        guard let entity = try? context.fetch(descriptor).first else {
            return nil
        }

        return WorkoutSessionV1(entity: entity)
    }

    /// Holt alle Sessions mit optionalem Limit
    /// - Parameter limit: Maximale Anzahl an Sessions (default: 100)
    /// - Returns: Array von WorkoutSessions
    func getAllSessions(limit: Int = 100) -> [WorkoutSessionV1] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { WorkoutSessionV1(entity: $0) }
    }

    /// Holt Sessions für ein bestimmtes Template
    /// - Parameters:
    ///   - templateId: Die Template-ID
    ///   - limit: Maximale Anzahl (default: 50)
    /// - Returns: Array von WorkoutSessions
    func getSessions(for templateId: UUID, limit: Int = 50) -> [WorkoutSessionV1] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate<WorkoutSessionEntity> { entity in
                entity.templateId == templateId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { WorkoutSessionV1(entity: $0) }
    }
}
