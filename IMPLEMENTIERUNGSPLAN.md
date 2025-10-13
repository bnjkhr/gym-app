# GymBo - Detaillierter Implementierungsplan

**Version:** 1.0  
**Datum:** 2025-10-13  
**Basis:** APP_VERBESSERUNGS_KONZEPT.md  
**Status:** Planung - Keine Code-Änderungen

---

## 📋 Übersicht

Dieser Plan strukturiert die Umsetzung der im Verbesserungskonzept identifizierten Features in **3 Phasen** über **7 Wochen**. Jede Phase enthält detaillierte Implementierungsschritte, Dateipfade, und konkrete Code-Tasks.

### Gesamtzeitplan

```
Phase 1: Quick Wins              ██████░░░░░░░░░░ (Woche 1-2)
Phase 2: Architektur-Refactoring ░░░░░░██████████░ (Woche 3-5)
Phase 3: Data Intelligence       ░░░░░░░░░░░░████ (Woche 6-7)
```

### Erfolgskriterien

- ✅ Alle bestehenden Tests bleiben grün
- ✅ Keine Breaking Changes für User
- ✅ Neue Features hinter Feature Flags
- ✅ 70%+ Test Coverage für neue Features
- ✅ Code Review vor jedem Merge

---

## Phase 1: Quick Wins (Woche 1-2)

**Ziel:** Maximaler User-Impact bei minimalem Risiko  
**Dauer:** 10 Arbeitstage  
**Priorität:** ⭐⭐⭐⭐⭐

---

### Sprint 1.1: "Nächster Satz"-UI (4 Tage)

#### Tag 1: Datenstrukturen & View Models

**Neue Dateien erstellen:**

1. **`Models/SetSuggestion.swift`**
   ```swift
   struct SetSuggestion: Identifiable {
       let id = UUID()
       let weight: Double
       let reps: ClosedRange<Int>
       let confidence: Double  // 0.0 bis 1.0
       let reasoning: String
       let isIncrease: Bool
       let isWarmup: Bool
       
       var confidenceLevel: ConfidenceLevel {
           switch confidence {
           case 0.8...: return .high
           case 0.6..<0.8: return .medium
           default: return .low
           }
       }
   }
   
   enum ConfidenceLevel {
       case high, medium, low
       
       var color: Color {
           switch self {
           case .high: return .green
           case .medium: return .orange
           case .low: return .red
           }
       }
       
       var description: String {
           switch self {
           case .high: return "Sicher"
           case .medium: return "Moderat"
           case .low: return "Unsicher"
           }
       }
   }
   ```

2. **`Models/LastPerformance.swift`**
   ```swift
   struct LastPerformance {
       let reps: Int
       let weight: Double
       let date: Date
       
       var daysAgo: String {
           let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
           switch days {
           case 0: return "Heute"
           case 1: return "Gestern"
           default: return "vor \(days) Tagen"
           }
       }
       
       var formattedDate: String {
           let formatter = RelativeDateTimeFormatter()
           formatter.unitsStyle = .full
           return formatter.localizedString(for: date, relativeTo: .now)
       }
   }
   ```

**Aufgaben:**
- [ ] Neue Dateien erstellen und zu Xcode-Projekt hinzufügen
- [ ] In `Models/` Ordner organisieren
- [ ] Import in benötigten Views prüfen
- [ ] Build-Check durchführen

---

#### Tag 2-3: UI-Komponenten implementieren

**Neue Dateien erstellen:**

3. **`Views/Workout/Components/NextSetCardView.swift`**
   ```swift
   struct NextSetCardView: View {
       let currentExercise: WorkoutExercise
       let setNumber: Int
       let suggestion: SetSuggestion
       let lastPerformance: LastPerformance?
       
       @State private var weight: Double
       @State private var reps: Int
       
       let onComplete: (Double, Int) -> Void
       
       init(
           currentExercise: WorkoutExercise,
           setNumber: Int,
           suggestion: SetSuggestion,
           lastPerformance: LastPerformance?,
           onComplete: @escaping (Double, Int) -> Void
       ) {
           self.currentExercise = currentExercise
           self.setNumber = setNumber
           self.suggestion = suggestion
           self.lastPerformance = lastPerformance
           self.onComplete = onComplete
           
           // Initialisiere State mit Vorschlag
           _weight = State(initialValue: suggestion.weight)
           _reps = State(initialValue: suggestion.reps.lowerBound)
       }
       
       var body: some View {
           VStack(spacing: 20) {
               // Header
               headerSection
               
               Divider()
               
               // Suggestion Section
               suggestionSection
               
               Divider()
               
               // Last Performance (optional)
               if let last = lastPerformance {
                   lastPerformanceSection(last)
                   Divider()
               }
               
               // Input Fields
               inputSection
               
               // Complete Button
               completeButton
           }
           .padding(24)
           .background(.ultraThinMaterial)
           .clipShape(RoundedRectangle(cornerRadius: 20))
           .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
       }
       
       // MARK: - View Components
       
       private var headerSection: some View {
           VStack(spacing: 8) {
               Text(currentExercise.exercise.name)
                   .font(.title3.bold())
               
               Text("Satz \(setNumber) von \(currentExercise.sets.count)")
                   .font(.subheadline)
                   .foregroundStyle(.secondary)
           }
       }
       
       private var suggestionSection: some View {
           VStack(alignment: .leading, spacing: 12) {
               HStack {
                   Text("Empfehlung")
                       .font(.caption.uppercased())
                       .foregroundStyle(.secondary)
                   
                   Spacer()
                   
                   if suggestion.isIncrease {
                       Label("Progressive Overload", systemImage: "arrow.up.circle.fill")
                           .font(.caption2)
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(Color.green.opacity(0.2))
                           .foregroundStyle(.green)
                           .clipShape(Capsule())
                   }
                   
                   if suggestion.isWarmup {
                       Label("Aufwärmsatz", systemImage: "flame.fill")
                           .font(.caption2)
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(Color.orange.opacity(0.2))
                           .foregroundStyle(.orange)
                           .clipShape(Capsule())
                   }
               }
               
               HStack(alignment: .lastTextBaseline, spacing: 12) {
                   Text("\(suggestion.weight, specifier: "%.1f")")
                       .font(.system(size: 36, weight: .bold, design: .rounded))
                   
                   Text("kg")
                       .font(.title3)
                       .foregroundStyle(.secondary)
                   
                   Text("×")
                       .font(.title2)
                       .foregroundStyle(.tertiary)
                   
                   Text("\(suggestion.reps.lowerBound)–\(suggestion.reps.upperBound)")
                       .font(.system(size: 36, weight: .bold, design: .rounded))
                   
                   Text("Wdh.")
                       .font(.title3)
                       .foregroundStyle(.secondary)
               }
               
               // Reasoning
               Text(suggestion.reasoning)
                   .font(.subheadline)
                   .foregroundStyle(.secondary)
               
               // Confidence Badge
               HStack {
                   Circle()
                       .fill(suggestion.confidenceLevel.color)
                       .frame(width: 8, height: 8)
                   
                   Text("Sicherheit: \(suggestion.confidenceLevel.description)")
                       .font(.caption)
                       .foregroundStyle(.secondary)
                   
                   Text("\(Int(suggestion.confidence * 100))%")
                       .font(.caption.bold())
                       .foregroundStyle(suggestion.confidenceLevel.color)
               }
           }
       }
       
       private func lastPerformanceSection(_ last: LastPerformance) -> some View {
           HStack(spacing: 12) {
               Image(systemName: "clock.arrow.circlepath")
                   .foregroundStyle(.secondary)
               
               VStack(alignment: .leading, spacing: 4) {
                   Text("Letzte Leistung")
                       .font(.caption.uppercased())
                       .foregroundStyle(.secondary)
                   
                   Text("\(last.reps) × \(last.weight, specifier: "%.1f") kg")
                       .font(.subheadline.bold())
               }
               
               Spacer()
               
               Text(last.daysAgo)
                   .font(.caption)
                   .foregroundStyle(.tertiary)
           }
       }
       
       private var inputSection: some View {
           HStack(spacing: 20) {
               // Weight Stepper
               VStack(alignment: .leading, spacing: 8) {
                   Text("Gewicht")
                       .font(.caption.uppercased())
                       .foregroundStyle(.secondary)
                   
                   HStack {
                       Button {
                           weight = max(0, weight - 2.5)
                       } label: {
                           Image(systemName: "minus.circle.fill")
                               .font(.title2)
                       }
                       .buttonStyle(.plain)
                       
                       Text("\(weight, specifier: "%.1f") kg")
                           .font(.title3.bold())
                           .frame(minWidth: 80)
                           .multilineTextAlignment(.center)
                       
                       Button {
                           weight += 2.5
                       } label: {
                           Image(systemName: "plus.circle.fill")
                               .font(.title2)
                       }
                       .buttonStyle(.plain)
                   }
               }
               
               Divider()
               
               // Reps Stepper
               VStack(alignment: .leading, spacing: 8) {
                   Text("Wiederholungen")
                       .font(.caption.uppercased())
                       .foregroundStyle(.secondary)
                   
                   HStack {
                       Button {
                           reps = max(1, reps - 1)
                       } label: {
                           Image(systemName: "minus.circle.fill")
                               .font(.title2)
                       }
                       .buttonStyle(.plain)
                       
                       Text("\(reps)")
                           .font(.title3.bold())
                           .frame(minWidth: 50)
                           .multilineTextAlignment(.center)
                       
                       Button {
                           reps += 1
                       } label: {
                           Image(systemName: "plus.circle.fill")
                               .font(.title2)
                       }
                       .buttonStyle(.plain)
                   }
               }
           }
       }
       
       private var completeButton: some View {
           Button {
               onComplete(weight, reps)
           } label: {
               Label("Satz abschließen", systemImage: "checkmark.circle.fill")
                   .font(.headline)
                   .frame(maxWidth: .infinity)
                   .padding()
                   .background(Color.accentColor)
                   .foregroundStyle(.white)
                   .clipShape(RoundedRectangle(cornerRadius: 12))
           }
           .buttonStyle(.plain)
       }
   }
   ```

**Aufgaben:**
- [ ] `NextSetCardView.swift` erstellen
- [ ] Preview mit Sample-Daten hinzufügen
- [ ] Dark Mode testen
- [ ] Accessibility Labels hinzufügen (VoiceOver)
- [ ] iPad-Layout prüfen

---

#### Tag 4: Integration in WorkoutDetailView

**Dateien modifizieren:**

4. **`Views/WorkoutDetailView.swift`** (Ergänzung)

**Schritte:**
- [ ] Import neuer Models
- [ ] Methode `generateSetSuggestion()` hinzufügen (temporär statisch)
- [ ] Methode `getLastPerformance()` hinzufügen
- [ ] `NextSetCardView` in Active Session einbinden
- [ ] Bestehende Set-Liste unter Card verschieben (scrollbar)
- [ ] Feature Flag `showNextSetCard` hinzufügen

**Code-Snippets für WorkoutDetailView:**

```swift
// MARK: - Set Suggestions (Temporär statisch)

private func generateSetSuggestion(
    for exercise: WorkoutExercise,
    setNumber: Int
) -> SetSuggestion {
    // TODO: Phase 1.2 - Durch AdaptiveProgressionEngine ersetzen
    
    // Hole letzte Werte
    let lastWeight = exercise.sets.last?.weight ?? 20.0
    let lastReps = exercise.sets.last?.reps ?? 10
    
    // Einfache Logik
    if setNumber == 1 {
        // Warmup-Satz
        return SetSuggestion(
            weight: lastWeight * 0.8,
            reps: lastReps...lastReps,
            confidence: 0.9,
            reasoning: "Aufwärmsatz mit 80% des letzten Gewichts",
            isIncrease: false,
            isWarmup: true
        )
    } else {
        // Arbeitsgewicht
        return SetSuggestion(
            weight: lastWeight,
            reps: (lastReps-2)...(lastReps+2),
            confidence: 0.7,
            reasoning: "Letzte Session: \(lastReps)×\(lastWeight, specifier: "%.1f") kg",
            isIncrease: false,
            isWarmup: false
        )
    }
}

private func getLastPerformance(
    for exercise: WorkoutExercise
) -> LastPerformance? {
    // TODO: Aus WorkoutStore Historie holen
    
    // Temporär: Mock Data
    guard let lastSet = exercise.sets.last else { return nil }
    
    return LastPerformance(
        reps: lastSet.reps,
        weight: lastSet.weight,
        date: Date().addingTimeInterval(-7*24*3600) // Vor 7 Tagen
    )
}
```

**Integration in Body:**

```swift
var body: some View {
    ScrollView {
        VStack(spacing: 16) {
            if workoutStore.isActiveSession && workoutStore.activeSessionID == workout.id {
                // FEATURE FLAG CHECK
                if FeatureFlags.showNextSetCard {
                    // Finde aktuelles Exercise
                    if let currentExercise = getCurrentExercise() {
                        let setNumber = currentExercise.sets.filter(\.completed).count + 1
                        let suggestion = generateSetSuggestion(
                            for: currentExercise,
                            setNumber: setNumber
                        )
                        let lastPerformance = getLastPerformance(for: currentExercise)
                        
                        NextSetCardView(
                            currentExercise: currentExercise,
                            setNumber: setNumber,
                            suggestion: suggestion,
                            lastPerformance: lastPerformance
                        ) { weight, reps in
                            completeSet(exercise: currentExercise, weight: weight, reps: reps)
                        }
                        .padding()
                    }
                }
                
                // Bestehende Set-Liste (scrollbar darunter)
                // ...
            }
        }
    }
}
```

**Feature Flag hinzufügen:**

5. **`Utils/FeatureFlags.swift`** (neu erstellen)
   ```swift
   enum FeatureFlags {
       static var showNextSetCard: Bool {
           #if DEBUG
           return true
           #else
           return UserDefaults.standard.bool(forKey: "feature_next_set_card")
           #endif
       }
       
       // Für zukünftige Flags
       static var useAdaptiveProgression: Bool {
           #if DEBUG
           return false  // Noch nicht implementiert
           #else
           return UserDefaults.standard.bool(forKey: "feature_adaptive_progression")
           #endif
       }
   }
   ```

**Testing:**
- [ ] Manuelles Testing: Workout starten, Next Set Card erscheint
- [ ] Verschiedene Szenarien testen (erster Satz, mittlerer Satz, letzter Satz)
- [ ] Stepper-Funktionalität prüfen
- [ ] Complete Button führt zu nächstem Satz
- [ ] Screenshot für Dokumentation

---

### Sprint 1.2: Adaptive Progression Engine MVP (5 Tage)

#### Tag 5-6: Engine Core Logic

**Neue Dateien erstellen:**

6. **`Services/AdaptiveProgressionEngine.swift`**
   ```swift
   import Foundation
   
   /// Engine für intelligente Satz-Vorschläge basierend auf Trainingshistorie
   class AdaptiveProgressionEngine {
       
       // MARK: - Configuration
       
       private let config: ProgressionConfig
       
       struct ProgressionConfig {
           let weightIncrement: Double = 2.5        // kg
           let minRepRange: Int = 8
           let maxRepRange: Int = 12
           let warmupPercentage: Double = 0.8      // 80% des Arbeitsgewichts
           let deloadPercentage: Double = 0.9      // 90% bei Plateau
           let plateauThreshold: Int = 3           // 3 Sessions ohne Fortschritt
       }
       
       init(config: ProgressionConfig = ProgressionConfig()) {
           self.config = config
       }
       
       // MARK: - Public API
       
       /// Generiert intelligenten Vorschlag für nächsten Satz
       func suggestNextSet(
           exercise: Exercise,
           setNumber: Int,
           currentSession: [ExerciseSet],
           history: [WorkoutSession]
       ) -> SetSuggestion {
           
           // 1. Warmup-Check
           if setNumber == 1 && shouldSuggestWarmup(exercise, history) {
               return suggestWarmupSet(exercise, history)
           }
           
           // 2. Analysiere Historie
           let analysis = analyzeHistory(exercise, history)
           
           // 3. Progressive Overload Check
           if analysis.shouldIncrease {
               return suggestProgressiveOverload(exercise, analysis)
           }
           
           // 4. Plateau Check
           if analysis.plateauDetected {
               return suggestDeload(exercise, analysis)
           }
           
           // 5. Maintain
           return suggestMaintain(exercise, analysis, setNumber)
       }
       
       // MARK: - Analysis
       
       private func analyzeHistory(
           _ exercise: Exercise,
           _ history: [WorkoutSession]
       ) -> HistoryAnalysis {
           
           // Filter relevante Sessions (letzten 8 Wochen)
           let cutoffDate = Calendar.current.date(byAdding: .weekOfYear, value: -8, to: .now)!
           let recentSessions = history
               .filter { $0.date >= cutoffDate }
               .filter { session in
                   session.exercises.contains { $0.exercise.id == exercise.id }
               }
               .sorted { $0.date > $1.date }
           
           guard !recentSessions.isEmpty else {
               return HistoryAnalysis(
                   lastWeight: 20.0,
                   lastReps: 10,
                   averageReps: 10,
                   sessionsAnalyzed: 0,
                   plateauDetected: false,
                   shouldIncrease: false,
                   confidence: 0.3
               )
           }
           
           // Extrahiere Sätze dieser Übung
           let recentSets = recentSessions.prefix(5).flatMap { session -> [ExerciseSet] in
               session.exercises
                   .first { $0.exercise.id == exercise.id }?
                   .sets ?? []
           }
           
           guard let lastSet = recentSets.first else {
               return HistoryAnalysis(
                   lastWeight: 20.0,
                   lastReps: 10,
                   averageReps: 10,
                   sessionsAnalyzed: 0,
                   plateauDetected: false,
                   shouldIncrease: false,
                   confidence: 0.3
               )
           }
           
           // Berechne Metriken
           let weights = recentSets.map { $0.weight }
           let reps = recentSets.map { $0.reps }
           
           let lastWeight = lastSet.weight
           let lastReps = lastSet.reps
           let averageReps = Double(reps.reduce(0, +)) / Double(reps.count)
           
           // Progressive Overload Detection
           let completedAllReps = lastReps >= config.maxRepRange
           let consistentPerformance = reps.prefix(3).allSatisfy { $0 >= config.minRepRange }
           
           // Plateau Detection (3 Sessions gleiche Gewicht, keine Progression)
           let lastThreeWeights = Array(weights.prefix(config.plateauThreshold))
           let plateauDetected = lastThreeWeights.count == config.plateauThreshold &&
                                 Set(lastThreeWeights).count == 1 &&
                                 !completedAllReps
           
           return HistoryAnalysis(
               lastWeight: lastWeight,
               lastReps: lastReps,
               averageReps: averageReps,
               sessionsAnalyzed: recentSessions.count,
               plateauDetected: plateauDetected,
               shouldIncrease: completedAllReps && consistentPerformance,
               confidence: calculateConfidence(recentSessions.count)
           )
       }
       
       private func calculateConfidence(_ sessionsCount: Int) -> Double {
           switch sessionsCount {
           case 0: return 0.3
           case 1: return 0.5
           case 2: return 0.7
           case 3...: return 0.9
           default: return 0.5
           }
       }
       
       // MARK: - Suggestion Strategies
       
       private func shouldSuggestWarmup(_ exercise: Exercise, _ history: [WorkoutSession]) -> Bool {
           // Nur bei Compound Movements (mehrere Muskelgruppen)
           return exercise.muscleGroups.count >= 2
       }
       
       private func suggestWarmupSet(
           _ exercise: Exercise,
           _ history: [WorkoutSession]
       ) -> SetSuggestion {
           let analysis = analyzeHistory(exercise, history)
           let warmupWeight = analysis.lastWeight * config.warmupPercentage
           
           return SetSuggestion(
               weight: warmupWeight,
               reps: config.minRepRange...config.maxRepRange,
               confidence: 0.95,
               reasoning: "Aufwärmsatz mit 80% des Arbeitsgewichts (\(analysis.lastWeight, specifier: "%.1f") kg)",
               isIncrease: false,
               isWarmup: true
           )
       }
       
       private func suggestProgressiveOverload(
           _ exercise: Exercise,
           _ analysis: HistoryAnalysis
       ) -> SetSuggestion {
           let newWeight = analysis.lastWeight + config.weightIncrement
           
           return SetSuggestion(
               weight: newWeight,
               reps: config.minRepRange...config.maxRepRange,
               confidence: analysis.confidence,
               reasoning: "Progressive Overload: Du hast letzte Session \(analysis.lastReps) Wiederholungen geschafft → +\(config.weightIncrement) kg",
               isIncrease: true,
               isWarmup: false
           )
       }
       
       private func suggestDeload(
           _ exercise: Exercise,
           _ analysis: HistoryAnalysis
       ) -> SetSuggestion {
           let deloadWeight = analysis.lastWeight * config.deloadPercentage
           
           return SetSuggestion(
               weight: deloadWeight,
               reps: config.minRepRange...config.maxRepRange,
               confidence: 0.8,
               reasoning: "Plateau erkannt: \(config.plateauThreshold)× gleiche Leistung → 10% Deload für Regeneration",
               isIncrease: false,
               isWarmup: false
           )
       }
       
       private func suggestMaintain(
           _ exercise: Exercise,
           _ analysis: HistoryAnalysis,
           _ setNumber: Int
       ) -> SetSuggestion {
           // Bei späteren Sätzen: leicht reduzierte Reps
           let repsAdjustment = max(0, setNumber - 2)
           let adjustedMinReps = max(config.minRepRange - repsAdjustment, 6)
           let adjustedMaxReps = max(config.maxRepRange - repsAdjustment, 8)
           
           return SetSuggestion(
               weight: analysis.lastWeight,
               reps: adjustedMinReps...adjustedMaxReps,
               confidence: analysis.confidence,
               reasoning: "Letzte Session: \(analysis.lastReps)×\(analysis.lastWeight, specifier: "%.1f") kg",
               isIncrease: false,
               isWarmup: false
           )
       }
   }
   
   // MARK: - Supporting Types
   
   struct HistoryAnalysis {
       let lastWeight: Double
       let lastReps: Int
       let averageReps: Double
       let sessionsAnalyzed: Int
       let plateauDetected: Bool
       let shouldIncrease: Bool
       let confidence: Double
   }
   ```

**Aufgaben:**
- [ ] `AdaptiveProgressionEngine.swift` erstellen
- [ ] Inline-Dokumentation hinzufügen
- [ ] Build-Fehler beheben (imports prüfen)
- [ ] Code Review (Logic-Checks)

---

#### Tag 7: Unit Tests schreiben

7. **`Tests/AdaptiveProgressionEngineTests.swift`** (neu)
   ```swift
   import XCTest
   @testable import GymBo
   
   class AdaptiveProgressionEngineTests: XCTestCase {
       
       var sut: AdaptiveProgressionEngine!
       
       override func setUp() {
           super.setUp()
           sut = AdaptiveProgressionEngine()
       }
       
       override func tearDown() {
           sut = nil
           super.tearDown()
       }
       
       // MARK: - Warmup Tests
       
       func testSuggestNextSet_FirstSet_CompoundExercise_SuggestsWarmup() {
           // Arrange
           let exercise = createExercise(
               name: "Bench Press",
               muscleGroups: [.chest, .triceps, .shoulders]  // Compound
           )
           
           let history = [
               createSession(exercise: exercise, weight: 80.0, reps: 10, daysAgo: 7)
           ]
           
           // Act
           let suggestion = sut.suggestNextSet(
               exercise: exercise,
               setNumber: 1,
               currentSession: [],
               history: history
           )
           
           // Assert
           XCTAssertTrue(suggestion.isWarmup)
           XCTAssertEqual(suggestion.weight, 64.0, accuracy: 0.1)  // 80% von 80kg
           XCTAssertTrue(suggestion.reasoning.contains("Aufwärmsatz"))
           XCTAssertGreaterThan(suggestion.confidence, 0.9)
       }
       
       func testSuggestNextSet_FirstSet_IsolationExercise_NoWarmup() {
           // Arrange
           let exercise = createExercise(
               name: "Bicep Curl",
               muscleGroups: [.biceps]  // Isolation
           )
           
           let history = [
               createSession(exercise: exercise, weight: 15.0, reps: 12, daysAgo: 3)
           ]
           
           // Act
           let suggestion = sut.suggestNextSet(
               exercise: exercise,
               setNumber: 1,
               currentSession: [],
               history: history
           )
           
           // Assert
           XCTAssertFalse(suggestion.isWarmup)
       }
       
       // MARK: - Progressive Overload Tests
       
       func testSuggestNextSet_CompletedAllRepsLastSession_SuggestsWeightIncrease() {
           // Arrange
           let exercise = createExercise(name: "Squat", muscleGroups: [.quads])
           
           let history = [
               createSession(exercise: exercise, weight: 100.0, reps: 12, daysAgo: 7),
               createSession(exercise: exercise, weight: 100.0, reps: 11, daysAgo: 14),
               createSession(exercise: exercise, weight: 100.0, reps: 10, daysAgo: 21)
           ]
           
           // Act
           let suggestion = sut.suggestNextSet(
               exercise: exercise,
               setNumber: 2,  // Nicht erster Satz
               currentSession: [],
               history: history
           )
           
           // Assert
           XCTAssertTrue(suggestion.isIncrease)
           XCTAssertEqual(suggestion.weight, 102.5, accuracy: 0.1)
           XCTAssertTrue(suggestion.reasoning.contains("Progressive Overload"))
       }
       
       // MARK: - Plateau Tests
       
       func testSuggestNextSet_PlateauDetected_SuggestsDeload() {
           // Arrange
           let exercise = createExercise(name: "Bench Press", muscleGroups: [.chest])
           
           // 3 Sessions mit gleichem Gewicht und niedriger Rep-Count (Plateau)
           let history = [
               createSession(exercise: exercise, weight: 80.0, reps: 7, daysAgo: 7),
               createSession(exercise: exercise, weight: 80.0, reps: 8, daysAgo: 14),
               createSession(exercise: exercise, weight: 80.0, reps: 7, daysAgo: 21)
           ]
           
           // Act
           let suggestion = sut.suggestNextSet(
               exercise: exercise,
               setNumber: 1,
               currentSession: [],
               history: history
           )
           
           // Assert
           XCTAssertFalse(suggestion.isIncrease)
           XCTAssertEqual(suggestion.weight, 72.0, accuracy: 0.1)  // 90% Deload
           XCTAssertTrue(suggestion.reasoning.contains("Plateau"))
       }
       
       // MARK: - Maintain Tests
       
       func testSuggestNextSet_NormalProgress_SuggestsMaintain() {
           // Arrange
           let exercise = createExercise(name: "Overhead Press", muscleGroups: [.shoulders])
           
           let history = [
               createSession(exercise: exercise, weight: 50.0, reps: 10, daysAgo: 7)
           ]
           
           // Act
           let suggestion = sut.suggestNextSet(
               exercise: exercise,
               setNumber: 2,
               currentSession: [],
               history: history
           )
           
           // Assert
           XCTAssertFalse(suggestion.isIncrease)
           XCTAssertFalse(suggestion.isWarmup)
           XCTAssertEqual(suggestion.weight, 50.0, accuracy: 0.1)
           XCTAssertEqual(suggestion.reps.lowerBound, 8)
           XCTAssertEqual(suggestion.reps.upperBound, 12)
       }
       
       // MARK: - Confidence Tests
       
       func testSuggestNextSet_NoHistory_LowConfidence() {
           // Arrange
           let exercise = createExercise(name: "New Exercise", muscleGroups: [.back])
           let history: [WorkoutSession] = []
           
           // Act
           let suggestion = sut.suggestNextSet(
               exercise: exercise,
               setNumber: 1,
               currentSession: [],
               history: history
           )
           
           // Assert
           XCTAssertLessThan(suggestion.confidence, 0.5)
       }
       
       func testSuggestNextSet_ManySessionsInHistory_HighConfidence() {
           // Arrange
           let exercise = createExercise(name: "Deadlift", muscleGroups: [.back])
           
           let history = (1...10).map { dayOffset in
               createSession(exercise: exercise, weight: 120.0, reps: 10, daysAgo: dayOffset * 7)
           }
           
           // Act
           let suggestion = sut.suggestNextSet(
               exercise: exercise,
               setNumber: 1,
               currentSession: [],
               history: history
           )
           
           // Assert
           XCTAssertGreaterThan(suggestion.confidence, 0.8)
       }
       
       // MARK: - Set Number Adjustment Tests
       
       func testSuggestNextSet_LaterSets_ReducedRepRange() {
           // Arrange
           let exercise = createExercise(name: "Leg Press", muscleGroups: [.quads])
           let history = [
               createSession(exercise: exercise, weight: 150.0, reps: 10, daysAgo: 7)
           ]
           
           // Act (Satz 4)
           let suggestion = sut.suggestNextSet(
               exercise: exercise,
               setNumber: 4,
               currentSession: [],
               history: history
           )
           
           // Assert
           // Rep-Range sollte reduziert sein (z.B. 6-10 statt 8-12)
           XCTAssertLessThanOrEqual(suggestion.reps.lowerBound, 8)
       }
       
       // MARK: - Helper Methods
       
       private func createExercise(
           name: String,
           muscleGroups: [MuscleGroup]
       ) -> Exercise {
           Exercise(
               id: UUID(),
               name: name,
               muscleGroups: muscleGroups,
               equipment: .barbell,
               difficulty: .intermediate,
               instructions: ["Test instruction"]
           )
       }
       
       private func createSession(
           exercise: Exercise,
           weight: Double,
           reps: Int,
           daysAgo: Int
       ) -> WorkoutSession {
           let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
           
           return WorkoutSession(
               id: UUID(),
               templateId: nil,
               name: "Test Workout",
               date: date,
               exercises: [
                   WorkoutExercise(
                       exercise: exercise,
                       sets: [
                           ExerciseSet(reps: reps, weight: weight, completed: true)
                       ]
                   )
               ],
               defaultRestTime: 90,
               duration: 3600,
               notes: ""
           )
       }
   }
   ```

**Aufgaben:**
- [ ] Test-Target einrichten (falls nicht vorhanden)
- [ ] Alle 10+ Tests ausführen
- [ ] Alle Tests müssen grün sein
- [ ] Code Coverage prüfen (Ziel: 85%+)
- [ ] Edge Cases identifizieren und Tests hinzufügen

---

#### Tag 8-9: Integration in WorkoutDetailView

**Dateien modifizieren:**

8. **`Views/WorkoutDetailView.swift`** (Update)

**Änderungen:**
- [ ] AdaptiveProgressionEngine initialisieren
- [ ] `generateSetSuggestion()` Methode ersetzen durch Engine-Call
- [ ] `getLastPerformance()` mit echten Daten aus WorkoutStore
- [ ] Feature Flag `useAdaptiveProgression` aktivieren

**Code-Änderungen:**

```swift
// MARK: - Properties

@StateObject private var progressionEngine = AdaptiveProgressionEngine()

// MARK: - Set Suggestions (Update)

private func generateSetSuggestion(
    for exercise: WorkoutExercise,
    setNumber: Int
) -> SetSuggestion {
    
    guard FeatureFlags.useAdaptiveProgression else {
        // Fallback auf statische Logik
        return generateStaticSuggestion(exercise, setNumber)
    }
    
    // Hole Historie aus WorkoutStore
    let history = workoutStore.getAllSessions()
    
    // Aktuell abgeschlossene Sätze dieser Übung
    let currentSession = exercise.sets.filter(\.completed)
    
    // Engine-Call
    return progressionEngine.suggestNextSet(
        exercise: exercise.exercise,
        setNumber: setNumber,
        currentSession: currentSession,
        history: history
    )
}

private func getLastPerformance(
    for exercise: WorkoutExercise
) -> LastPerformance? {
    
    // Hole alle Sessions mit dieser Übung
    let sessions = workoutStore.getAllSessions()
        .filter { session in
            session.exercises.contains { $0.exercise.id == exercise.exercise.id }
        }
        .sorted { $0.date > $1.date }
    
    guard let lastSession = sessions.first,
          let lastExercise = lastSession.exercises.first(where: { $0.exercise.id == exercise.exercise.id }),
          let lastSet = lastExercise.sets.first else {
        return nil
    }
    
    return LastPerformance(
        reps: lastSet.reps,
        weight: lastSet.weight,
        date: lastSession.date
    )
}
```

**WorkoutStore Erweiterung:**

9. **`Services/WorkoutStore.swift`** (Ergänzung)

```swift
// MARK: - History Access (für AdaptiveProgressionEngine)

/// Gibt alle abgeschlossenen WorkoutSessions zurück (sortiert nach Datum)
func getAllSessions() -> [WorkoutSession] {
    let descriptor = FetchDescriptor<WorkoutSessionEntity>(
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    
    do {
        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { mapWorkoutSessionEntity($0) }
    } catch {
        print("❌ Fehler beim Laden der Sessions: \(error)")
        return []
    }
}

/// Gibt Sessions für eine bestimmte Übung zurück
func getSessions(for exerciseId: UUID, limit: Int = 10) -> [WorkoutSession] {
    return getAllSessions()
        .filter { session in
            session.exercises.contains { $0.exercise.id == exerciseId }
        }
        .prefix(limit)
        .map { $0 }
}
```

**Testing:**
- [ ] Manuelles Testing mit echter Historie
- [ ] Progressive Overload Szenario testen (12 Reps letztes Mal → +2.5kg)
- [ ] Plateau Szenario testen (3× gleiches Gewicht → Deload)
- [ ] Warmup Szenario testen (erster Satz → 80%)
- [ ] Keine Historie Szenario testen (neue Übung)
- [ ] Screenshot-Dokumentation

---

### Sprint 1.3: Smart Workout Suggestions Basic (3 Tage)

#### Tag 10: Muscle Group Balance Logic

10. **`Services/WorkoutSuggestionEngine.swift`** (neu)
    ```swift
    import Foundation
    
    /// Engine für intelligente Workout-Vorschläge basierend auf Trainingshistorie
    class WorkoutSuggestionEngine {
        
        // MARK: - Configuration
        
        private let config: SuggestionConfig
        
        struct SuggestionConfig {
            let analysisWindowDays: Int = 28  // 4 Wochen
            let neglectedThreshold: Int = 5   // Tage ohne Training
            let maxSuggestions: Int = 3
        }
        
        init(config: SuggestionConfig = SuggestionConfig()) {
            self.config = config
        }
        
        // MARK: - Public API
        
        /// Generiert Workout-Vorschläge basierend auf Historie
        func suggestWorkouts(
            templates: [Workout],
            history: [WorkoutSession]
        ) -> [SmartWorkoutSuggestion] {
            
            var suggestions: [SmartWorkoutSuggestion] = []
            
            // Analysiere Muskelgruppen-Balance
            let muscleAnalysis = analyzeMuscleGroupBalance(history)
            
            for template in templates {
                var reasons: [SuggestionReason] = []
                var confidence: Double = 0.0
                
                // 1. Muskelgruppen-Gap-Check
                let templateMuscles = extractMuscleGroups(from: template)
                
                for muscle in templateMuscles {
                    if let daysSince = muscleAnalysis.daysSinceLastTrained[muscle],
                       daysSince >= config.neglectedThreshold {
                        
                        reasons.append(.muscleGroupRested(muscle, days: daysSince))
                        confidence += 0.4
                    }
                }
                
                // 2. Favoriten-Match
                let favoriteExercises = identifyFavoriteExercises(history)
                let matchingFavorites = template.exercises.filter { workoutEx in
                    favoriteExercises.contains { $0.id == workoutEx.exercise.id }
                }.count
                
                if matchingFavorites > 0 {
                    reasons.append(.containsFavorites(count: matchingFavorites))
                    confidence += Double(matchingFavorites) * 0.1
                }
                
                // 3. Training-Frequenz-Match
                let avgDaysBetweenWorkouts = calculateAverageDaysBetween(history)
                let daysSinceLastWorkout = daysSinceLastSession(history)
                
                if let avgDays = avgDaysBetweenWorkouts,
                   let daysSince = daysSinceLastWorkout,
                   daysSince >= avgDays {
                    
                    reasons.append(.followsPattern("Dein übliches \(avgDays)-Tage-Muster"))
                    confidence += 0.2
                }
                
                // Nur Vorschläge mit min. 1 Grund
                if !reasons.isEmpty {
                    suggestions.append(SmartWorkoutSuggestion(
                        workout: template,
                        confidence: min(confidence, 1.0),
                        reasons: reasons
                    ))
                }
            }
            
            // Sortiere nach Confidence, nehme Top N
            return suggestions
                .sorted { $0.confidence > $1.confidence }
                .prefix(config.maxSuggestions)
                .map { $0 }
        }
        
        // MARK: - Analysis Helpers
        
        private func analyzeMuscleGroupBalance(_ history: [WorkoutSession]) -> MuscleGroupAnalysis {
            
            let cutoffDate = Calendar.current.date(
                byAdding: .day,
                value: -config.analysisWindowDays,
                to: .now
            )!
            
            let recentSessions = history.filter { $0.date >= cutoffDate }
            
            var daysSinceLastTrained: [MuscleGroup: Int] = [:]
            
            for muscleGroup in MuscleGroup.allCases {
                // Finde letzte Session mit dieser Muskelgruppe
                if let lastSession = recentSessions.first(where: { session in
                    session.exercises.contains { exercise in
                        exercise.exercise.muscleGroups.contains(muscleGroup)
                    }
                }) {
                    let days = Calendar.current.dateComponents(
                        [.day],
                        from: lastSession.date,
                        to: .now
                    ).day ?? 0
                    
                    daysSinceLastTrained[muscleGroup] = days
                }
            }
            
            return MuscleGroupAnalysis(
                daysSinceLastTrained: daysSinceLastTrained
            )
        }
        
        private func identifyFavoriteExercises(_ history: [WorkoutSession]) -> [Exercise] {
            var exerciseFrequency: [UUID: (Exercise, Int)] = [:]
            
            for session in history {
                for workoutExercise in session.exercises {
                    let exercise = workoutExercise.exercise
                    if var entry = exerciseFrequency[exercise.id] {
                        entry.1 += 1
                        exerciseFrequency[exercise.id] = entry
                    } else {
                        exerciseFrequency[exercise.id] = (exercise, 1)
                    }
                }
            }
            
            // Top 10 favoriten
            return exerciseFrequency
                .sorted { $0.value.1 > $1.value.1 }
                .prefix(10)
                .map { $0.value.0 }
        }
        
        private func extractMuscleGroups(from workout: Workout) -> Set<MuscleGroup> {
            var muscles = Set<MuscleGroup>()
            
            for workoutExercise in workout.exercises {
                for muscle in workoutExercise.exercise.muscleGroups {
                    muscles.insert(muscle)
                }
            }
            
            return muscles
        }
        
        private func calculateAverageDaysBetween(_ history: [WorkoutSession]) -> Int? {
            guard history.count >= 2 else { return nil }
            
            let sorted = history.sorted { $0.date < $1.date }
            var totalDays = 0
            
            for i in 1..<sorted.count {
                let days = Calendar.current.dateComponents(
                    [.day],
                    from: sorted[i-1].date,
                    to: sorted[i].date
                ).day ?? 0
                
                totalDays += days
            }
            
            return totalDays / (sorted.count - 1)
        }
        
        private func daysSinceLastSession(_ history: [WorkoutSession]) -> Int? {
            guard let lastSession = history.max(by: { $0.date < $1.date }) else {
                return nil
            }
            
            return Calendar.current.dateComponents(
                [.day],
                from: lastSession.date,
                to: .now
            ).day
        }
    }
    
    // MARK: - Supporting Types
    
    struct SmartWorkoutSuggestion: Identifiable {
        let id = UUID()
        let workout: Workout
        let confidence: Double
        let reasons: [SuggestionReason]
        
        var confidenceLevel: ConfidenceLevel {
            switch confidence {
            case 0.7...: return .high
            case 0.4..<0.7: return .medium
            default: return .low
            }
        }
    }
    
    enum SuggestionReason: Identifiable {
        case muscleGroupRested(MuscleGroup, days: Int)
        case containsFavorites(count: Int)
        case followsPattern(String)
        
        var id: String {
            switch self {
            case .muscleGroupRested(let muscle, _): return "muscle_\(muscle.rawValue)"
            case .containsFavorites: return "favorites"
            case .followsPattern: return "pattern"
            }
        }
        
        var displayText: String {
            switch self {
            case .muscleGroupRested(let muscle, let days):
                return "\(muscle.rawValue) seit \(days) Tagen nicht trainiert"
            case .containsFavorites(let count):
                return "\(count) deiner Lieblingsübungen"
            case .followsPattern(let pattern):
                return pattern
            }
        }
        
        var icon: String {
            switch self {
            case .muscleGroupRested: return "clock.fill"
            case .containsFavorites: return "star.fill"
            case .followsPattern: return "chart.line.uptrend.xyaxis"
            }
        }
        
        var color: Color {
            switch self {
            case .muscleGroupRested: return .orange
            case .containsFavorites: return .yellow
            case .followsPattern: return .blue
            }
        }
    }
    
    struct MuscleGroupAnalysis {
        let daysSinceLastTrained: [MuscleGroup: Int]
    }
    
    enum ConfidenceLevel {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .green
            case .medium: return .orange
            case .low: return .gray
            }
        }
    }
    ```

**Aufgaben:**
- [ ] Datei erstellen und zu Services-Ordner hinzufügen
- [ ] MuscleGroup-Enum prüfen (existiert bereits?)
- [ ] Build testen

---

#### Tag 11: Home-Screen Integration

11. **`Views/Home/Components/SmartSuggestionsSection.swift`** (neu)
    ```swift
    import SwiftUI
    
    struct SmartSuggestionsSection: View {
        let suggestions: [SmartWorkoutSuggestion]
        let onStartWorkout: (Workout) -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)
                    
                    Text("Empfohlene Workouts")
                        .font(.title3.bold())
                    
                    Spacer()
                }
                
                if suggestions.isEmpty {
                    emptyState
                } else {
                    suggestionsList
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        
        private var emptyState: some View {
            VStack(spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("Trainiere regelmäßig, um personalisierte Empfehlungen zu erhalten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        
        private var suggestionsList: some View {
            VStack(spacing: 12) {
                ForEach(suggestions.prefix(2)) { suggestion in
                    WorkoutSuggestionCard(
                        suggestion: suggestion,
                        onStart: { onStartWorkout(suggestion.workout) }
                    )
                }
            }
        }
    }
    
    struct WorkoutSuggestionCard: View {
        let suggestion: SmartWorkoutSuggestion
        let onStart: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(suggestion.workout.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    ConfidenceBadge(level: suggestion.confidenceLevel)
                }
                
                // Reasons
                FlowLayout(spacing: 8) {
                    ForEach(suggestion.reasons) { reason in
                        ReasonTag(reason: reason)
                    }
                }
                
                // Actions
                HStack {
                    Button(action: onStart) {
                        Label("Jetzt starten", systemImage: "play.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    struct ReasonTag: View {
        let reason: SuggestionReason
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: reason.icon)
                    .font(.caption2)
                
                Text(reason.displayText)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(reason.color.opacity(0.2))
            .foregroundStyle(reason.color)
            .clipShape(Capsule())
        }
    }
    
    struct ConfidenceBadge: View {
        let level: ConfidenceLevel
        
        var body: some View {
            HStack(spacing: 4) {
                Circle()
                    .fill(level.color)
                    .frame(width: 6, height: 6)
                
                Text(confidenceText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        
        private var confidenceText: String {
            switch level {
            case .high: return "Hohe Passung"
            case .medium: return "Mittlere Passung"
            case .low: return "Geringe Passung"
            }
        }
    }
    
    // MARK: - FlowLayout Helper (Horizontales Wrapping)
    
    struct FlowLayout: Layout {
        var spacing: CGFloat = 8
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = FlowResult(
                in: proposal.replacingUnspecifiedDimensions().width,
                subviews: subviews,
                spacing: spacing
            )
            return result.size
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let result = FlowResult(
                in: bounds.width,
                subviews: subviews,
                spacing: spacing
            )
            for (index, subview) in subviews.enumerated() {
                subview.place(at: result.positions[index], proposal: .unspecified)
            }
        }
        
        struct FlowResult {
            var size: CGSize = .zero
            var positions: [CGPoint] = []
            
            init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
                var currentX: CGFloat = 0
                var currentY: CGFloat = 0
                var lineHeight: CGFloat = 0
                
                for subview in subviews {
                    let size = subview.sizeThatFits(.unspecified)
                    
                    if currentX + size.width > maxWidth && currentX > 0 {
                        currentX = 0
                        currentY += lineHeight + spacing
                        lineHeight = 0
                    }
                    
                    positions.append(CGPoint(x: currentX, y: currentY))
                    currentX += size.width + spacing
                    lineHeight = max(lineHeight, size.height)
                }
                
                self.size = CGSize(
                    width: maxWidth,
                    height: currentY + lineHeight
                )
            }
        }
    }
    ```

**Aufgaben:**
- [ ] Komponenten erstellen
- [ ] FlowLayout testen (Tags wrappen korrekt?)
- [ ] Dark Mode Check
- [ ] Preview mit Sample-Daten

---

#### Tag 12: HomeView Integration & Testing

12. **`Views/HomeView.swift`** (Update)

**Schritte:**
- [ ] WorkoutSuggestionEngine initialisieren
- [ ] Suggestions berechnen (onAppear + Refresh)
- [ ] SmartSuggestionsSection einbinden
- [ ] Feature Flag hinzufügen

**Code-Änderungen:**

```swift
// MARK: - Properties

@StateObject private var suggestionEngine = WorkoutSuggestionEngine()
@State private var smartSuggestions: [SmartWorkoutSuggestion] = []

// MARK: - Body

var body: some View {
    ScrollView {
        VStack(spacing: 20) {
            
            // ... bestehende Sections (Header, Active Session, etc.)
            
            // Smart Suggestions Section
            if FeatureFlags.showSmartSuggestions && !smartSuggestions.isEmpty {
                SmartSuggestionsSection(
                    suggestions: smartSuggestions,
                    onStartWorkout: { workout in
                        startWorkout(workout)
                    }
                )
                .padding(.horizontal)
            }
            
            // ... restliche Sections
        }
    }
    .onAppear {
        refreshSuggestions()
    }
    .refreshable {
        refreshSuggestions()
    }
}

// MARK: - Helper Methods

private func refreshSuggestions() {
    let templates = workoutStore.getAllWorkouts()
    let history = workoutStore.getAllSessions()
    
    smartSuggestions = suggestionEngine.suggestWorkouts(
        templates: templates,
        history: history
    )
}

private func startWorkout(_ workout: Workout) {
    workoutStore.startSession(for: workout.id)
    // Navigation...
}
```

**Feature Flag Update:**

```swift
// Utils/FeatureFlags.swift

static var showSmartSuggestions: Bool {
    #if DEBUG
    return true
    #else
    return UserDefaults.standard.bool(forKey: "feature_smart_suggestions")
    #endif
}
```

**Testing:**
- [ ] HomeView zeigt Suggestions (mit genügend Historie)
- [ ] Leerer State bei keine/wenig Historie
- [ ] Tap auf "Jetzt starten" startet Workout
- [ ] Reasons werden korrekt angezeigt
- [ ] Confidence-Badge stimmt
- [ ] Pull-to-Refresh funktioniert
- [ ] Screenshot-Dokumentation

---

### Phase 1 Abschluss-Checkliste

**Code Quality:**
- [ ] Alle neuen Dateien dokumentiert
- [ ] Code Conventions befolgt
- [ ] Keine Compiler Warnings
- [ ] SwiftLint-Checks grün (falls vorhanden)

**Testing:**
- [ ] Unit Tests: 10+ Tests grün
- [ ] Manual Testing: Alle User-Flows getestet
- [ ] Accessibility: VoiceOver funktioniert
- [ ] Performance: Keine Lags bei Historie-Queries

**Dokumentation:**
- [ ] README mit neuen Features aktualisiert
- [ ] Screenshots für App Store vorbereitet
- [ ] Changelog-Einträge geschrieben

**Rollout:**
- [ ] Feature Flags in Production auf `false` (staged rollout)
- [ ] Analytics-Events eingebaut (Feature-Usage-Tracking)
- [ ] Beta-Tester informiert

---

## Phase 2: Architektur-Refactoring (Woche 3-5)

**Ziel:** Langfristige Wartbarkeit, Testbarkeit, Skalierbarkeit  
**Dauer:** 15 Arbeitstage  
**Priorität:** ⭐⭐⭐⭐

⚠️ **WARNUNG:** Diese Phase enthält Breaking Changes in der Architektur. Vorsicht und umfangreiches Testing erforderlich.

---

### Sprint 2.1: Repository Pattern (Woche 3, Tag 1-5)

#### Ziel
Entkopplung von Business Logic und Datenschicht durch Einführung des Repository Patterns.

#### Tag 13-14: Repository Interfaces erstellen

13. **`Data/Repositories/WorkoutRepository.swift`** (neu)
    ```swift
    import Foundation
    
    /// Repository-Interface für Workout-Datenzugriff
    protocol WorkoutRepository {
        // Workouts
        func fetchAllWorkouts() async throws -> [Workout]
        func fetchWorkout(by id: UUID) async throws -> Workout?
        func saveWorkout(_ workout: Workout) async throws
        func deleteWorkout(id: UUID) async throws
        
        // Sessions
        func fetchAllSessions() async throws -> [WorkoutSession]
        func fetchSessions(for workoutId: UUID) async throws -> [WorkoutSession]
        func saveSession(_ session: WorkoutSession) async throws
        func deleteSession(id: UUID) async throws
        
        // Exercise Records
        func fetchRecords(for exerciseId: UUID) async throws -> [ExerciseRecord]
        func saveRecord(_ record: ExerciseRecord) async throws
    }
    ```

14. **`Data/Repositories/SwiftDataWorkoutRepository.swift`** (neu - SwiftData-Implementierung)
    ```swift
    import Foundation
    import SwiftData
    
    /// SwiftData-Implementierung des WorkoutRepository
    @MainActor
    class SwiftDataWorkoutRepository: WorkoutRepository {
        
        private let modelContext: ModelContext
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }
        
        // MARK: - Workouts
        
        func fetchAllWorkouts() async throws -> [Workout] {
            let descriptor = FetchDescriptor<WorkoutEntity>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            return entities.compactMap { mapWorkoutEntity($0) }
        }
        
        func fetchWorkout(by id: UUID) async throws -> Workout? {
            let descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == id }
            )
            
            guard let entity = try modelContext.fetch(descriptor).first else {
                return nil
            }
            
            return mapWorkoutEntity(entity)
        }
        
        func saveWorkout(_ workout: Workout) async throws {
            // Prüfe ob Update oder Insert
            let existingDescriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == workout.id }
            )
            
            if let existing = try modelContext.fetch(existingDescriptor).first {
                // Update
                updateWorkoutEntity(existing, from: workout)
            } else {
                // Insert
                let entity = WorkoutEntity.from(workout)
                modelContext.insert(entity)
            }
            
            try modelContext.save()
        }
        
        func deleteWorkout(id: UUID) async throws {
            let descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == id }
            )
            
            if let entity = try modelContext.fetch(descriptor).first {
                modelContext.delete(entity)
                try modelContext.save()
            }
        }
        
        // MARK: - Sessions
        
        func fetchAllSessions() async throws -> [WorkoutSession] {
            let descriptor = FetchDescriptor<WorkoutSessionEntity>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            return entities.compactMap { mapWorkoutSessionEntity($0) }
        }
        
        func fetchSessions(for workoutId: UUID) async throws -> [WorkoutSession] {
            let descriptor = FetchDescriptor<WorkoutSessionEntity>(
                predicate: #Predicate { $0.templateId == workoutId },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            return entities.compactMap { mapWorkoutSessionEntity($0) }
        }
        
        func saveSession(_ session: WorkoutSession) async throws {
            let entity = WorkoutSessionEntity.from(session)
            modelContext.insert(entity)
            try modelContext.save()
        }
        
        func deleteSession(id: UUID) async throws {
            let descriptor = FetchDescriptor<WorkoutSessionEntity>(
                predicate: #Predicate { $0.id == id }
            )
            
            if let entity = try modelContext.fetch(descriptor).first {
                modelContext.delete(entity)
                try modelContext.save()
            }
        }
        
        // MARK: - Records
        
        func fetchRecords(for exerciseId: UUID) async throws -> [ExerciseRecord] {
            let descriptor = FetchDescriptor<ExerciseRecordEntity>(
                predicate: #Predicate { $0.exerciseId == exerciseId },
                sortBy: [SortDescriptor(\.achievedDate, order: .reverse)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            return entities.map { ExerciseRecord(from: $0) }
        }
        
        func saveRecord(_ record: ExerciseRecord) async throws {
            let entity = ExerciseRecordEntity.from(record)
            modelContext.insert(entity)
            try modelContext.save()
        }
        
        // MARK: - Mapping Helpers
        
        private func mapWorkoutEntity(_ entity: WorkoutEntity) -> Workout? {
            // Nutze bestehende Mapping-Logik
            // (aus WorkoutStore extrahieren)
            return Workout(from: entity)
        }
        
        private func mapWorkoutSessionEntity(_ entity: WorkoutSessionEntity) -> WorkoutSession? {
            return WorkoutSession(from: entity)
        }
        
        private func updateWorkoutEntity(_ entity: WorkoutEntity, from workout: Workout) {
            entity.name = workout.name
            entity.notes = workout.notes
            // ... weitere Properties
        }
    }
    ```

15. **`Data/Repositories/MockWorkoutRepository.swift`** (neu - für Tests)
    ```swift
    import Foundation
    
    /// Mock-Implementierung für Unit Tests
    class MockWorkoutRepository: WorkoutRepository {
        
        // In-Memory Storage
        var workouts: [Workout] = []
        var sessions: [WorkoutSession] = []
        var records: [ExerciseRecord] = []
        
        // Error Injection (für Fehlerfall-Tests)
        var shouldThrowError: Bool = false
        var errorToThrow: Error = NSError(domain: "Mock", code: -1)
        
        // MARK: - Workouts
        
        func fetchAllWorkouts() async throws -> [Workout] {
            if shouldThrowError { throw errorToThrow }
            return workouts
        }
        
        func fetchWorkout(by id: UUID) async throws -> Workout? {
            if shouldThrowError { throw errorToThrow }
            return workouts.first { $0.id == id }
        }
        
        func saveWorkout(_ workout: Workout) async throws {
            if shouldThrowError { throw errorToThrow }
            
            if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
                workouts[index] = workout
            } else {
                workouts.append(workout)
            }
        }
        
        func deleteWorkout(id: UUID) async throws {
            if shouldThrowError { throw errorToThrow }
            workouts.removeAll { $0.id == id }
        }
        
        // MARK: - Sessions
        
        func fetchAllSessions() async throws -> [WorkoutSession] {
            if shouldThrowError { throw errorToThrow }
            return sessions.sorted { $0.date > $1.date }
        }
        
        func fetchSessions(for workoutId: UUID) async throws -> [WorkoutSession] {
            if shouldThrowError { throw errorToThrow }
            return sessions.filter { $0.templateId == workoutId }
        }
        
        func saveSession(_ session: WorkoutSession) async throws {
            if shouldThrowError { throw errorToThrow }
            sessions.append(session)
        }
        
        func deleteSession(id: UUID) async throws {
            if shouldThrowError { throw errorToThrow }
            sessions.removeAll { $0.id == id }
        }
        
        // MARK: - Records
        
        func fetchRecords(for exerciseId: UUID) async throws -> [ExerciseRecord] {
            if shouldThrowError { throw errorToThrow }
            return records.filter { $0.exerciseId == exerciseId }
        }
        
        func saveRecord(_ record: ExerciseRecord) async throws {
            if shouldThrowError { throw errorToThrow }
            records.append(record)
        }
        
        // MARK: - Test Helpers
        
        func reset() {
            workouts = []
            sessions = []
            records = []
            shouldThrowError = false
        }
    }
    ```

**Aufgaben Tag 13-14:**
- [ ] Neue Ordnerstruktur `Data/Repositories/` erstellen
- [ ] Alle 3 Dateien erstellen
- [ ] Bestehende Mapping-Methoden aus WorkoutStore extrahieren
- [ ] Build-Fehler beheben
- [ ] Code Review

---

#### Tag 15-17: WorkoutStore Refactoring Teil 1

**Strategie:** Graduelles Refactoring mit Adapter-Pattern (Breaking Changes minimieren)

16. **`Services/Session/WorkoutSessionManager.swift`** (neu - extrahiert aus WorkoutStore)
    ```swift
    import Foundation
    import SwiftUI
    
    /// Verwaltet aktive Workout-Sessions
    @MainActor
    class WorkoutSessionManager: ObservableObject {
        
        // MARK: - Published State
        
        @Published private(set) var activeSessionID: UUID?
        @Published private(set) var sessionStartTime: Date?
        @Published private(set) var currentExerciseIndex: Int = 0
        
        // MARK: - Dependencies
        
        private let repository: WorkoutRepository
        private let heartRateTracker: HeartRateTracker
        
        // MARK: - Initialization
        
        init(
            repository: WorkoutRepository,
            heartRateTracker: HeartRateTracker = HealthKitHeartRateTracker.shared
        ) {
            self.repository = repository
            self.heartRateTracker = heartRateTracker
        }
        
        // MARK: - Session Lifecycle
        
        func startSession(for workoutId: UUID) async throws {
            guard activeSessionID == nil else {
                throw SessionError.sessionAlreadyActive
            }
            
            // Lade Workout
            guard let workout = try await repository.fetchWorkout(by: workoutId) else {
                throw SessionError.workoutNotFound
            }
            
            activeSessionID = workoutId
            sessionStartTime = Date()
            currentExerciseIndex = 0
            
            // Starte HeartRate-Tracking
            await heartRateTracker.startTracking()
            
            print("✅ Session gestartet: \(workout.name)")
        }
        
        func endSession(session: WorkoutSession) async throws {
            guard activeSessionID != nil else {
                throw SessionError.noActiveSession
            }
            
            // Speichere Session
            try await repository.saveSession(session)
            
            // Stoppe HeartRate-Tracking
            await heartRateTracker.stopTracking()
            
            // Reset State
            activeSessionID = nil
            sessionStartTime = nil
            currentExerciseIndex = 0
            
            print("✅ Session beendet und gespeichert")
        }
        
        func pauseSession() {
            // TODO: Implementieren
        }
        
        func resumeSession() {
            // TODO: Implementieren
        }
        
        // MARK: - Exercise Navigation
        
        func moveToNextExercise() {
            currentExerciseIndex += 1
        }
        
        func moveToPreviousExercise() {
            currentExerciseIndex = max(0, currentExerciseIndex - 1)
        }
        
        // MARK: - Computed Properties
        
        var isSessionActive: Bool {
            activeSessionID != nil
        }
        
        var sessionDuration: TimeInterval {
            guard let startTime = sessionStartTime else { return 0 }
            return Date().timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Errors
    
    enum SessionError: LocalizedError {
        case sessionAlreadyActive
        case noActiveSession
        case workoutNotFound
        
        var errorDescription: String? {
            switch self {
            case .sessionAlreadyActive:
                return "Es läuft bereits eine aktive Session"
            case .noActiveSession:
                return "Keine aktive Session vorhanden"
            case .workoutNotFound:
                return "Workout nicht gefunden"
            }
        }
    }
    ```

17. **`Services/Timer/RestTimerManager.swift`** (neu - extrahiert aus WorkoutStore)
    ```swift
    import Foundation
    import SwiftUI
    import UserNotifications
    
    /// Verwaltet Rest-Timer zwischen Sätzen
    @MainActor
    class RestTimerManager: ObservableObject {
        
        // MARK: - Published State
        
        @Published private(set) var activeRestState: RestState?
        @Published private(set) var remainingTime: TimeInterval = 0
        
        // MARK: - Dependencies
        
        private let notificationManager: NotificationManager
        private let liveActivityController: WorkoutLiveActivityController
        
        // MARK: - Timer
        
        private var timer: Timer?
        private var restEndDate: Date?
        
        // MARK: - Initialization
        
        init(
            notificationManager: NotificationManager = .shared,
            liveActivityController: WorkoutLiveActivityController = .shared
        ) {
            self.notificationManager = notificationManager
            self.liveActivityController = liveActivityController
            
            // Restore State bei App-Start
            restoreStateIfNeeded()
        }
        
        // MARK: - Public API
        
        func startRest(duration: TimeInterval, for exercise: Exercise) {
            stopRest()  // Stop existing timer
            
            let endDate = Date().addingTimeInterval(duration)
            
            activeRestState = RestState(
                duration: duration,
                startDate: Date(),
                endDate: endDate,
                exerciseName: exercise.name
            )
            
            restEndDate = endDate
            remainingTime = duration
            
            // Persistiere State (für Force Quit Recovery)
            saveState()
            
            // Starte Timer
            startTimer()
            
            // Schedule Notification
            scheduleNotification(at: endDate, exercise: exercise)
            
            // Update Live Activity
            liveActivityController.updateRestTimer(duration: duration, exercise: exercise.name)
            
            print("⏱️ Rest Timer gestartet: \(Int(duration))s")
        }
        
        func stopRest() {
            timer?.invalidate()
            timer = nil
            
            activeRestState = nil
            restEndDate = nil
            remainingTime = 0
            
            clearState()
            cancelNotification()
            liveActivityController.clearRestTimer()
            
            print("⏱️ Rest Timer gestoppt")
        }
        
        func pauseRest() {
            timer?.invalidate()
            timer = nil
            
            // State bleibt erhalten
            print("⏸️ Rest Timer pausiert")
        }
        
        func resumeRest() {
            guard activeRestState != nil, restEndDate != nil else { return }
            startTimer()
            print("▶️ Rest Timer fortgesetzt")
        }
        
        // MARK: - Private Helpers
        
        private func startTimer() {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateTimer()
            }
            RunLoop.current.add(timer!, forMode: .common)
        }
        
        private func updateTimer() {
            guard let endDate = restEndDate else {
                stopRest()
                return
            }
            
            let remaining = endDate.timeIntervalSinceNow
            
            if remaining <= 0 {
                // Timer abgelaufen
                stopRest()
                onTimerCompleted()
            } else {
                remainingTime = remaining
            }
        }
        
        private func onTimerCompleted() {
            print("✅ Rest Timer abgelaufen")
            // Haptic Feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        
        // MARK: - Persistence (Force Quit Recovery)
        
        private func saveState() {
            guard let state = activeRestState else { return }
            
            UserDefaults.standard.set(state.endDate.timeIntervalSince1970, forKey: "restTimer_endDate")
            UserDefaults.standard.set(state.exerciseName, forKey: "restTimer_exercise")
            UserDefaults.standard.set(state.duration, forKey: "restTimer_duration")
        }
        
        private func clearState() {
            UserDefaults.standard.removeObject(forKey: "restTimer_endDate")
            UserDefaults.standard.removeObject(forKey: "restTimer_exercise")
            UserDefaults.standard.removeObject(forKey: "restTimer_duration")
        }
        
        private func restoreStateIfNeeded() {
            guard let endTimestamp = UserDefaults.standard.object(forKey: "restTimer_endDate") as? TimeInterval,
                  let exerciseName = UserDefaults.standard.string(forKey: "restTimer_exercise"),
                  let duration = UserDefaults.standard.object(forKey: "restTimer_duration") as? TimeInterval else {
                return
            }
            
            let endDate = Date(timeIntervalSince1970: endTimestamp)
            
            // Prüfe ob Timer noch läuft
            if endDate > Date() {
                activeRestState = RestState(
                    duration: duration,
                    startDate: endDate.addingTimeInterval(-duration),
                    endDate: endDate,
                    exerciseName: exerciseName
                )
                
                restEndDate = endDate
                startTimer()
                
                print("♻️ Rest Timer wiederhergestellt")
            } else {
                clearState()
            }
        }
        
        // MARK: - Notifications
        
        private func scheduleNotification(at date: Date, exercise: Exercise) {
            let content = UNMutableNotificationContent()
            content.title = "Pause vorbei!"
            content.body = "Zeit für den nächsten Satz \(exercise.name)"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: date.timeIntervalSinceNow,
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "restTimer",
                content: content,
                trigger: trigger
            )
            
            notificationManager.schedule(request)
        }
        
        private func cancelNotification() {
            notificationManager.cancel(identifier: "restTimer")
        }
    }
    
    // MARK: - Supporting Types
    
    struct RestState {
        let duration: TimeInterval
        let startDate: Date
        let endDate: Date
        let exerciseName: String
        
        var progress: Double {
            let elapsed = Date().timeIntervalSince(startDate)
            return min(elapsed / duration, 1.0)
        }
    }
    ```

**Aufgaben Tag 15-17:**
- [ ] Neue Ordner `Services/Session/` und `Services/Timer/` erstellen
- [ ] Manager-Klassen implementieren
- [ ] Bestehende Logik aus WorkoutStore migrieren
- [ ] HeartRateTracker-Protocol erstellen (falls nicht vorhanden)
- [ ] Build testen
- [ ] Mock-Versionen für Tests erstellen

---

#### Fortsetzung folgt im nächsten Teil...

---

## Anhang

### Dateistruktur (Nach Phase 1)

```
GymBo/
├── Models/
│   ├── Domain/
│   │   ├── Workout.swift
│   │   ├── Exercise.swift
│   │   ├── WorkoutSession.swift
│   │   ├── SetSuggestion.swift         # NEU
│   │   └── LastPerformance.swift       # NEU
│   └── Persistence/
│       ├── WorkoutEntity.swift
│       └── ...
├── Services/
│   ├── WorkoutStore.swift              # Bestehend (wird in Phase 2 refactored)
│   ├── AdaptiveProgressionEngine.swift # NEU
│   └── WorkoutSuggestionEngine.swift   # NEU
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── Components/
│   │       └── SmartSuggestionsSection.swift  # NEU
│   └── Workout/
│       ├── WorkoutDetailView.swift     # Modifiziert
│       └── Components/
│           └── NextSetCardView.swift   # NEU
├── Utils/
│   └── FeatureFlags.swift              # NEU
└── Tests/
    └── AdaptiveProgressionEngineTests.swift  # NEU
```

### Git Commit-Strategie

**Phase 1 - Commits:**
```bash
# Tag 1
git commit -m "feat: Add SetSuggestion and LastPerformance models"

# Tag 2-3
git commit -m "feat: Implement NextSetCardView component"
git commit -m "test: Add manual testing screenshots for NextSetCard"

# Tag 4
git commit -m "feat: Integrate NextSetCard into WorkoutDetailView"
git commit -m "feat: Add FeatureFlags utility"

# Tag 5-6
git commit -m "feat: Implement AdaptiveProgressionEngine core logic"

# Tag 7
git commit -m "test: Add comprehensive unit tests for AdaptiveProgressionEngine"

# Tag 8-9
git commit -m "feat: Integrate AdaptiveProgressionEngine into WorkoutDetailView"
git commit -m "refactor: Extract history access methods in WorkoutStore"

# Tag 10
git commit -m "feat: Implement WorkoutSuggestionEngine"

# Tag 11
git commit -m "feat: Add SmartSuggestionsSection UI components"

# Tag 12
git commit -m "feat: Integrate smart suggestions into HomeView"
git commit -m "docs: Update README with Phase 1 features"
```

### Nächste Schritte nach Phase 1

1. **User Feedback sammeln:**
   - Beta-Tester um Feedback bitten
   - Analytics auswerten (Feature-Adoption)
   - A/B-Test-Ergebnisse analysieren

2. **Iterieren:**
   - Progression-Regeln anpassen basierend auf Daten
   - UI-Tweaks basierend auf Feedback

3. **Phase 2 vorbereiten:**
   - Architektur-Review mit Team
   - Migration-Plan für WorkoutStore finalisieren
   - Testing-Strategie definieren

---

**Ende des Implementierungsplans - Teil 1**

*Die Phasen 2 und 3 werden in separaten Dokumenten detailliert ausgearbeitet.*
