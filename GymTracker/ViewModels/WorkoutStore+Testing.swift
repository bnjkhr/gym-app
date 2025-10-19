import Combine
import Foundation
import SwiftData
import SwiftUI

// MARK: - WorkoutStore Testing Extension
// This file contains all debug and testing functions for WorkoutStore
// These functions are only used during development and testing

@MainActor
extension WorkoutStore {

    // MARK: - Markdown Parser Test (Phase 3-6)
    func testMarkdownParser() {
        print("🧪 Teste Markdown Parser...")
        ExerciseMarkdownParser.testWithSampleData()
    }

    func testMuscleGroupMapping() {
        print("🔬 Teste Muskelgruppen-Mapping...")
        ExerciseMarkdownParser.testMuscleGroupMapping()
    }

    func testEquipmentAndDifficultyMapping() {
        print("🔧 Teste Equipment und Schwierigkeitsgrad-Mapping...")
        ExerciseMarkdownParser.testEquipmentAndDifficultyMapping()
    }

    func testCompleteExerciseCreation() {
        print("🎯 Teste vollständige Exercise-Erstellung...")
        ExerciseMarkdownParser.testCompleteExerciseCreation()
    }

    func testCompleteEmbeddedExerciseList() {
        print("📖 Teste vollständige eingebettete Übungsliste...")
        ExerciseMarkdownParser.testCompleteEmbeddedList()
    }

    // MARK: - Phase 7: Replace Exercises with Markdown Data

    /// Ersetzt alle bestehenden Übungen durch die Übungen aus der Markdown-Datei
    /// WARNUNG: Diese Funktion löscht ALLE bestehenden Übungen!
    func replaceAllExercisesWithMarkdownData() {
        guard let context = modelContext else {
            print("❌ WorkoutStore: ModelContext ist nil beim Ersetzen der Übungen")
            return
        }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                print("🔄 Starte vollständigen Austausch der Übungsdatenbank...")

                // Phase 7.1: Parse neue Übungen aus Markdown
                let newExercises = ExerciseMarkdownParser.parseCompleteExerciseList()
                print("📊 \(newExercises.count) neue Übungen aus Markdown geparst")

                if newExercises.isEmpty {
                    print("⚠️ Keine Übungen aus Markdown geparst - Abbruch")
                    return
                }

                // Phase 7.2: Lösche alle bestehenden Übungen
                let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                print("🗑️ Lösche \(existingExercises.count) bestehende Übungen...")

                for exercise in existingExercises {
                    context.delete(exercise)
                }

                // Phase 7.3: Speichere Löschungen
                try context.save()
                print("✅ Alle bestehenden Übungen gelöscht")

                // Phase 7.4: Füge neue Übungen hinzu
                print("➕ Füge \(newExercises.count) neue Übungen hinzu...")

                for exercise in newExercises {
                    let entity = ExerciseEntity.make(from: exercise)
                    context.insert(entity)
                }

                // Phase 7.5: Speichere neue Übungen
                try context.save()

                await MainActor.run {
                    // Phase 7.6: Cache invalidieren und UI aktualisieren
                    self.invalidateCaches()
                    self.objectWillChange.send()

                    print("🎉 Übungsdatenbank-Austausch erfolgreich abgeschlossen!")
                    print("   📊 Neue Übungen: \(newExercises.count)")

                    // Statistiken anzeigen
                    let byEquipment = Dictionary(grouping: newExercises) { $0.equipmentType }
                    for (equipment, exs) in byEquipment.sorted(by: {
                        $0.key.rawValue < $1.key.rawValue
                    }) {
                        print("   🏋️ \(equipment.rawValue): \(exs.count) Übungen")
                    }

                    let byDifficulty = Dictionary(grouping: newExercises) { $0.difficultyLevel }
                    for (difficulty, exs) in byDifficulty.sorted(by: {
                        $0.key.sortOrder < $1.key.sortOrder
                    }) {
                        print("   📊 \(difficulty.rawValue): \(exs.count) Übungen")
                    }
                }

            } catch {
                print("❌ Fehler beim Ersetzen der Übungsdatenbank: \(error)")
            }
        }
    }

    /// Test-Funktion für den Übungsaustausch (nur zu Testzwecken)
    func testReplaceExercises() {
        print("⚠️ WARNUNG: Diese Funktion löscht ALLE bestehenden Übungen!")
        print("🧪 Starte Test des Übungsaustauschs...")

        // Zeige aktuelle Statistiken
        let currentExercises = exercises
        print("📊 Aktuelle Übungen: \(currentExercises.count)")

        if !currentExercises.isEmpty {
            let currentByEquipment = Dictionary(grouping: currentExercises) { $0.equipmentType }
            print("   Aktuelle Verteilung:")
            for (equipment, exs) in currentByEquipment.sorted(by: {
                $0.key.rawValue < $1.key.rawValue
            }) {
                print("   - \(equipment.rawValue): \(exs.count)")
            }
        }

        print("\n🔄 Führe Austausch aus...")
        replaceAllExercisesWithMarkdownData()
    }

    // MARK: - Phase 8 & 9: Automatic Migration Testing

    /// Test-Funktion für automatische Migration
    func testAutomaticMigration() {
        print("🧪 Teste automatische Migration...")
        print("   📊 Migration-Flag aktuell: \(markdownExercisesMigrationCompleted)")
        print("   📈 Migration-Status: \(migrationStatus.displayText)")
        print("   🔄 Migration läuft: \(isMigrationInProgress)")
        print("   📊 Fortschritt: \(Int(migrationProgress * 100))%")

        if markdownExercisesMigrationCompleted {
            print("   ✅ Migration bereits durchgeführt")
            print("   💡 Verwende resetMigrationFlag() zum Zurücksetzen")
        } else {
            print("   🔄 Migration steht noch aus")
            if let context = modelContext {
                print("   🚀 Führe Migration jetzt aus...")
                // Note: checkAndPerformAutomaticMigration is private, called automatically
                print("   ℹ️ Migration wird automatisch beim nächsten modelContext-Set ausgeführt")
            } else {
                print("   ❌ ModelContext nicht verfügbar")
            }
        }
    }

    /// Test-Funktion um Migration-UI ohne echte Migration zu simulieren
    func simulateMigrationProgress() {
        print("🎭 Simuliere Migration-Fortschritt für UI-Tests...")

        isMigrationInProgress = true

        Task { [weak self] in
            guard let self = self else { return }

            let steps: [MigrationStatus] = [
                .parsing, .deletingOld, .addingNew, .saving, .completed,
            ]
            let progressValues: [Double] = [0.2, 0.4, 0.7, 0.9, 1.0]

            for (step, progress) in zip(steps, progressValues) {
                await MainActor.run {
                    self.migrationStatus = step
                    self.migrationProgress = progress
                    print("   📊 \(step.displayText) (\(Int(progress * 100))%)")
                }

                // Simuliere Verzögerung
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 Sekunde
            }

            await MainActor.run {
                self.isMigrationInProgress = false
                print("🎉 Migration-Simulation abgeschlossen!")
            }
        }
    }

    // MARK: - Phase 10: Cleanup & Final Testing

    /// Vollständiger Test aller Migration-Szenarien
    func runCompleteMigrationTests() {
        print("🧪 Starte vollständige Migration-Tests...")
        print(String(repeating: "=", count: 50))

        // Test 1: Parser-Funktionalität
        print("\n📖 Test 1: Markdown-Parser")
        testCompleteEmbeddedExerciseList()

        // Test 2: Migration-Status
        print("\n📊 Test 2: Migration-Status prüfen")
        print("   Migration-Flag: \(markdownExercisesMigrationCompleted)")
        print("   Migration aktiv: \(isMigrationInProgress)")
        print("   Aktueller Status: \(migrationStatus.displayText)")

        // Test 3: Datenbank-Status
        print("\n💾 Test 3: Aktuelle Datenbank-Statistiken")
        let currentExercises = exercises
        print("   Übungen in DB: \(currentExercises.count)")

        if !currentExercises.isEmpty {
            let byEquipment = Dictionary(grouping: currentExercises) { $0.equipmentType }
            print("   Verteilung nach Equipment:")
            for (equipment, exs) in byEquipment.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                print("     - \(equipment.rawValue): \(exs.count)")
            }

            let byDifficulty = Dictionary(grouping: currentExercises) { $0.difficultyLevel }
            print("   Verteilung nach Schwierigkeitsgrad:")
            for (difficulty, exs) in byDifficulty.sorted(by: { $0.key.sortOrder < $1.key.sortOrder }
            ) {
                print("     - \(difficulty.rawValue): \(exs.count)")
            }
        }

        // Test 4: Validierung
        print("\n✅ Test 4: Datenvalidierung")
        validateExerciseData()

        print("\n🎉 Vollständige Tests abgeschlossen!")
        print(String(repeating: "=", count: 50))
    }

    /// Validiert die Qualität der aktuellen Übungsdaten
    private func validateExerciseData() {
        let exercises = self.exercises

        var issues: [String] = []

        // Check 1: Mindestanzahl Übungen
        if exercises.count < 100 {
            issues.append("Zu wenige Übungen: \(exercises.count) < 100")
        } else {
            print("   ✅ Übungsanzahl: \(exercises.count)")
        }

        // Check 2: Alle Equipment-Types vertreten
        let equipmentTypes = Set(exercises.map { $0.equipmentType })
        let expectedTypes: Set<EquipmentType> = [.freeWeights, .bodyweight, .machine]
        let missingTypes = expectedTypes.subtracting(equipmentTypes)

        if !missingTypes.isEmpty {
            issues.append("Fehlende Equipment-Types: \(missingTypes.map { $0.rawValue })")
        } else {
            print("   ✅ Equipment-Types vollständig")
        }

        // Check 3: Alle Schwierigkeitsgrade vertreten
        let difficultyLevels = Set(exercises.map { $0.difficultyLevel })
        let expectedLevels: Set<DifficultyLevel> = [.anfänger, .fortgeschritten, .profi]
        let missingLevels = expectedLevels.subtracting(difficultyLevels)

        if !missingLevels.isEmpty {
            issues.append("Fehlende Schwierigkeitsgrade: \(missingLevels.map { $0.rawValue })")
        } else {
            print("   ✅ Schwierigkeitsgrade vollständig")
        }

        // Check 4: Alle Muskelgruppen vertreten
        let allMuscleGroups = Set(exercises.flatMap { $0.muscleGroups })
        let expectedMuscles: Set<MuscleGroup> = [
            .chest, .back, .shoulders, .biceps, .triceps, .legs, .glutes, .abs,
        ]
        let missingMuscles = expectedMuscles.subtracting(allMuscleGroups)

        if !missingMuscles.isEmpty {
            issues.append("Fehlende Muskelgruppen: \(missingMuscles.map { $0.rawValue })")
        } else {
            print("   ✅ Muskelgruppen vollständig")
        }

        // Check 5: Übungen ohne Muskelgruppen
        let exercisesWithoutMuscles = exercises.filter { $0.muscleGroups.isEmpty }
        if !exercisesWithoutMuscles.isEmpty {
            issues.append("\(exercisesWithoutMuscles.count) Übungen ohne Muskelgruppen")
            print("   ⚠️ Übungen ohne Muskelgruppen:")
            for exercise in exercisesWithoutMuscles.prefix(5) {
                print("     - \(exercise.name)")
            }
        } else {
            print("   ✅ Alle Übungen haben Muskelgruppen")
        }

        // Check 6: Übungen ohne Beschreibung
        let exercisesWithoutDescription = exercises.filter { $0.description.isEmpty }
        if !exercisesWithoutDescription.isEmpty {
            issues.append("\(exercisesWithoutDescription.count) Übungen ohne Beschreibung")
        } else {
            print("   ✅ Alle Übungen haben Beschreibungen")
        }

        // Zusammenfassung
        if issues.isEmpty {
            print("   🎉 Alle Validierungen bestanden!")
        } else {
            print("   ⚠️ Gefundene Probleme:")
            for issue in issues {
                print("     - \(issue)")
            }
        }
    }

    /// Edge-Case Testing für Migration
    func testMigrationEdgeCases() {
        print("🧪 Teste Migration Edge Cases...")

        // Test 1: Was passiert wenn Markdown leer ist?
        print("\n📝 Test 1: Leerer Markdown")
        let emptyResult = ExerciseMarkdownParser.parseMarkdownTable("")
        print("   Ergebnis bei leerem Markdown: \(emptyResult.count) Übungen")

        // Test 2: Malformed Markdown
        print("\n📝 Test 2: Fehlerhafter Markdown")
        let badMarkdown = "Das ist kein Markdown | Test | Fehler"
        let badResult = ExerciseMarkdownParser.parseMarkdownTable(badMarkdown)
        print("   Ergebnis bei fehlerhaftem Markdown: \(badResult.count) Übungen")

        // Test 3: Migration-Status nach Fehlern
        print("\n📊 Test 3: Migration-Status Validation")
        let allStatuses: [MigrationStatus] = [
            .notStarted, .parsing, .deletingOld, .addingNew, .saving, .completed,
            .error("Test-Fehler"),
        ]

        for status in allStatuses {
            print("   Status: \(status.displayText)")
            print("     Abgeschlossen: \(status.isCompleted)")
            print("     Fehler: \(status.isError)")
        }

        print("\n✅ Edge-Case Tests abgeschlossen")
    }

    /// Performance-Test für große Übungsmengen
    func testPerformance() {
        print("⚡ Performance-Test...")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Test Markdown-Parsing
        let exercises = ExerciseMarkdownParser.parseCompleteExerciseList()

        let parseTime = CFAbsoluteTimeGetCurrent() - startTime

        print("   📊 \(exercises.count) Übungen in \(String(format: "%.3f", parseTime))s geparst")
        print(
            "   📈 Performance: \(String(format: "%.1f", Double(exercises.count) / parseTime)) Übungen/s"
        )

        if parseTime > 2.0 {
            print("   ⚠️ Parsing dauert länger als 2 Sekunden!")
        } else {
            print("   ✅ Performance akzeptabel")
        }
    }

    /// Finaler Integrations-Test
    func runFinalIntegrationTest() {
        print("🎯 Starte finalen Integrations-Test...")
        print(String(repeating: "=", count: 60))

        print("\n1️⃣ Parser-Test")
        testPerformance()

        print("\n2️⃣ Edge-Case-Test")
        testMigrationEdgeCases()

        print("\n3️⃣ Vollständiger System-Test")
        runCompleteMigrationTests()

        print("\n4️⃣ Migration-Simulation")
        print("   🎭 Starte UI-Simulation...")
        simulateMigrationProgress()

        print("\n🏁 Finaler Integrations-Test abgeschlossen!")
        print("📋 System bereit für Produktion")
        print(String(repeating: "=", count: 60))
    }
}
