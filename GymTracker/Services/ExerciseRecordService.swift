import Foundation
import SwiftData

/// Service für Personal Records (PRs) Management
/// Verantwortlich für:
/// - Abrufen von Exercise Records
/// - Erkennung neuer Personal Records
/// - 1RM (One-Rep Max) Berechnungen
/// - Record Updates
@MainActor
final class ExerciseRecordService {

    // MARK: - Properties

    private var modelContext: ModelContext?

    // MARK: - Context Management

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    // MARK: - Record Queries

    /// Holt den ExerciseRecord für eine bestimmte Übung
    /// - Parameter exercise: Die Übung
    /// - Returns: Der ExerciseRecord oder nil wenn nicht vorhanden
    func getRecord(for exercise: Exercise) -> ExerciseRecord? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExerciseRecordEntity>(
            predicate: #Predicate { record in
                record.exerciseId == exercise.id
            }
        )

        guard let entity = try? context.fetch(descriptor).first else { return nil }

        return mapEntityToRecord(entity)
    }

    /// Holt alle ExerciseRecords sortiert nach Übungsname
    /// - Returns: Array aller ExerciseRecords
    func getAllRecords() -> [ExerciseRecord] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<ExerciseRecordEntity>(
            sortBy: [SortDescriptor(\.exerciseName)]
        )

        let entities = (try? context.fetch(descriptor)) ?? []

        return entities.map(mapEntityToRecord)
    }

    /// Holt die Top N Records nach verschiedenen Kriterien
    /// - Parameters:
    ///   - limit: Anzahl der Records
    ///   - sortBy: Sortierkriterium
    /// - Returns: Array der Top Records
    func getTopRecords(limit: Int = 10, sortBy: RecordSortCriteria = .maxWeight) -> [ExerciseRecord]
    {
        guard let context = modelContext else { return [] }

        var descriptor: FetchDescriptor<ExerciseRecordEntity>

        switch sortBy {
        case .maxWeight:
            descriptor = FetchDescriptor<ExerciseRecordEntity>(
                sortBy: [SortDescriptor(\.maxWeight, order: .reverse)]
            )
        case .maxReps:
            descriptor = FetchDescriptor<ExerciseRecordEntity>(
                sortBy: [SortDescriptor(\.maxReps, order: .reverse)]
            )
        case .oneRepMax:
            descriptor = FetchDescriptor<ExerciseRecordEntity>(
                sortBy: [SortDescriptor(\.bestEstimatedOneRepMax, order: .reverse)]
            )
        case .recentlyBroken:
            descriptor = FetchDescriptor<ExerciseRecordEntity>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        }

        descriptor.fetchLimit = limit

        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map(mapEntityToRecord)
    }

    // MARK: - Record Detection

    /// Prüft ob ein Satz einen neuen Personal Record darstellt
    /// - Parameters:
    ///   - exercise: Die Übung
    ///   - weight: Das Gewicht
    ///   - reps: Die Wiederholungen
    /// - Returns: Der Record-Typ oder nil wenn kein neuer Record
    func checkForNewRecord(exercise: Exercise, weight: Double, reps: Int) -> RecordType? {
        guard let record = getRecord(for: exercise) else {
            // Wenn noch kein Record existiert, ist jeder abgeschlossene Satz ein neuer Record
            if weight > 0 && reps > 0 {
                return .maxWeight  // Default zu Weight-Record für erste Errungenschaft
            }
            return nil
        }

        return record.hasNewRecord(weight: weight, reps: reps)
    }

    /// Prüft mehrere Records gleichzeitig
    /// - Parameter sets: Array von (exercise, weight, reps) Tupeln
    /// - Returns: Dictionary mit Exercise ID als Key und RecordType als Value
    func checkMultipleForNewRecords(sets: [(exercise: Exercise, weight: Double, reps: Int)])
        -> [UUID: RecordType]
    {
        var newRecords: [UUID: RecordType] = [:]

        for set in sets {
            if let recordType = checkForNewRecord(
                exercise: set.exercise, weight: set.weight, reps: set.reps)
            {
                newRecords[set.exercise.id] = recordType
            }
        }

        return newRecords
    }

    // MARK: - Record Updates

    /// Aktualisiert einen Record mit neuen Werten
    /// - Parameters:
    ///   - exercise: Die Übung
    ///   - weight: Das neue Gewicht
    ///   - reps: Die neuen Wiederholungen
    ///   - date: Das Datum des neuen Records
    /// - Throws: Fehler bei Speicherproblemen
    func updateRecord(for exercise: Exercise, weight: Double, reps: Int, date: Date) throws {
        guard let context = modelContext else {
            throw RecordServiceError.missingModelContext
        }

        let descriptor = FetchDescriptor<ExerciseRecordEntity>(
            predicate: #Predicate { record in
                record.exerciseId == exercise.id
            }
        )

        let entity: ExerciseRecordEntity

        if let existing = try? context.fetch(descriptor).first {
            entity = existing
        } else {
            // Create new record
            entity = ExerciseRecordEntity(
                id: UUID(),
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                maxWeight: weight,
                maxWeightReps: reps,
                maxWeightDate: date,
                maxReps: reps,
                maxRepsWeight: weight,
                maxRepsDate: date,
                bestEstimatedOneRepMax: estimateOneRepMax(weight: weight, reps: reps),
                bestOneRepMaxWeight: weight,
                bestOneRepMaxReps: reps,
                bestOneRepMaxDate: date,
                createdAt: date,
                updatedAt: date
            )
            context.insert(entity)
        }

        // Update max weight if applicable
        if weight > entity.maxWeight {
            entity.maxWeight = weight
            entity.maxWeightReps = reps
            entity.maxWeightDate = date
        }

        // Update max reps if applicable
        if reps > entity.maxReps {
            entity.maxReps = reps
            entity.maxRepsWeight = weight
            entity.maxRepsDate = date
        }

        // Update 1RM if applicable
        let estimatedOneRepMax = estimateOneRepMax(weight: weight, reps: reps)
        if estimatedOneRepMax > entity.bestEstimatedOneRepMax {
            entity.bestEstimatedOneRepMax = estimatedOneRepMax
            entity.bestOneRepMaxWeight = weight
            entity.bestOneRepMaxReps = reps
            entity.bestOneRepMaxDate = date
        }

        entity.updatedAt = date

        try context.save()

        print("✅ Record aktualisiert für \(exercise.name): \(weight)kg × \(reps)")
    }

    /// Löscht einen Record
    /// - Parameter exercise: Die Übung deren Record gelöscht werden soll
    /// - Throws: Fehler bei Speicherproblemen
    func deleteRecord(for exercise: Exercise) throws {
        guard let context = modelContext else {
            throw RecordServiceError.missingModelContext
        }

        let descriptor = FetchDescriptor<ExerciseRecordEntity>(
            predicate: #Predicate { record in
                record.exerciseId == exercise.id
            }
        )

        guard let entity = try? context.fetch(descriptor).first else {
            throw RecordServiceError.recordNotFound
        }

        context.delete(entity)
        try context.save()

        print("✅ Record gelöscht für \(exercise.name)")
    }

    // MARK: - 1RM Calculations

    /// Berechnet das geschätzte One-Rep Max (1RM) nach der Brzycki-Formel
    /// - Parameters:
    ///   - weight: Das verwendete Gewicht
    ///   - reps: Die Anzahl der Wiederholungen
    /// - Returns: Das geschätzte 1RM
    func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }

        // Brzycki Formula: 1RM = weight × (36 / (37 - reps))
        // Alternative simplified: 1RM = weight × (1 + reps/30)

        if reps == 1 {
            return weight
        }

        // Use simplified formula for better approximation at higher reps
        return weight * (1 + Double(reps) / 30.0)
    }

    /// Berechnet die empfohlenen Gewichte für verschiedene Rep-Ranges basierend auf 1RM
    /// - Parameter oneRepMax: Das One-Rep Max
    /// - Returns: Dictionary mit Rep-Range als Key und empfohlenem Gewicht als Value
    func calculateTrainingWeights(oneRepMax: Double) -> [String: Double] {
        [
            "1-3 Reps (Kraft)": oneRepMax * 0.90,  // 90% 1RM
            "4-6 Reps (Kraft)": oneRepMax * 0.85,  // 85% 1RM
            "6-8 Reps (Hypertrophie)": oneRepMax * 0.80,  // 80% 1RM
            "8-12 Reps (Hypertrophie)": oneRepMax * 0.75,  // 75% 1RM
            "12-15 Reps (Ausdauer)": oneRepMax * 0.65,  // 65% 1RM
            "15+ Reps (Ausdauer)": oneRepMax * 0.50,  // 50% 1RM
        ]
    }

    // MARK: - Statistics

    /// Berechnet Statistiken über alle Records
    /// - Returns: RecordStatistics Objekt
    func getRecordStatistics() -> RecordStatistics {
        let allRecords = getAllRecords()

        let totalRecords = allRecords.count
        let avgMaxWeight =
            allRecords.isEmpty
            ? 0 : allRecords.reduce(0.0) { $0 + $1.maxWeight } / Double(allRecords.count)
        let avgMaxReps =
            allRecords.isEmpty ? 0 : allRecords.reduce(0) { $0 + $1.maxReps } / allRecords.count
        let avgOneRepMax =
            allRecords.isEmpty
            ? 0
            : allRecords.reduce(0.0) { $0 + $1.bestEstimatedOneRepMax } / Double(allRecords.count)

        let recentRecords =
            allRecords
            .filter { $0.updatedAt > Date().addingTimeInterval(-30 * 24 * 60 * 60) }  // Last 30 days
            .count

        return RecordStatistics(
            totalRecords: totalRecords,
            averageMaxWeight: avgMaxWeight,
            averageMaxReps: avgMaxReps,
            averageOneRepMax: avgOneRepMax,
            recentRecords: recentRecords
        )
    }

    // MARK: - Private Helpers

    /// Mapped ein ExerciseRecordEntity zu einem ExerciseRecord
    private func mapEntityToRecord(_ entity: ExerciseRecordEntity) -> ExerciseRecord {
        ExerciseRecord(
            id: entity.id,
            exerciseId: entity.exerciseId,
            exerciseName: entity.exerciseName,
            maxWeight: entity.maxWeight,
            maxWeightReps: entity.maxWeightReps,
            maxWeightDate: entity.maxWeightDate,
            maxReps: entity.maxReps,
            maxRepsWeight: entity.maxRepsWeight,
            maxRepsDate: entity.maxRepsDate,
            bestEstimatedOneRepMax: entity.bestEstimatedOneRepMax,
            bestOneRepMaxWeight: entity.bestOneRepMaxWeight,
            bestOneRepMaxReps: entity.bestOneRepMaxReps,
            bestOneRepMaxDate: entity.bestOneRepMaxDate,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }
}

// MARK: - Supporting Types

extension ExerciseRecordService {
    enum RecordServiceError: Error, LocalizedError {
        case missingModelContext
        case recordNotFound
        case invalidData

        var errorDescription: String? {
            switch self {
            case .missingModelContext:
                return "ModelContext ist nicht verfügbar"
            case .recordNotFound:
                return "Exercise Record nicht gefunden"
            case .invalidData:
                return "Ungültige Daten für Record"
            }
        }
    }

    enum RecordSortCriteria {
        case maxWeight
        case maxReps
        case oneRepMax
        case recentlyBroken
    }
}

struct RecordStatistics {
    let totalRecords: Int
    let averageMaxWeight: Double
    let averageMaxReps: Int
    let averageOneRepMax: Double
    let recentRecords: Int
}
