# GymBo V2.0 - Clean Architecture Implementation Roadmap

**Erstellt:** 2025-10-21
**Branch:** `feature/v2-clean-architecture`
**Dauer:** 8 Wochen (40 Arbeitstage)
**Ziel:** Ground-Up Redesign mit Clean Architecture

---

## 📋 Inhaltsverzeichnis

1. [Roadmap Overview](#roadmap-overview)
2. [Sprint 1-2: Foundation](#sprint-1-2-foundation-woche-1-2)
3. [Sprint 3-4: Session Management](#sprint-3-4-session-management-woche-3-4)
4. [Sprint 5-6: Workout & Exercise Management](#sprint-5-6-workout--exercise-management-woche-5-6)
5. [Sprint 7-8: Statistics, Testing, Polish](#sprint-7-8-statistics-testing-polish-woche-7-8)
6. [Daily Task Lists](#daily-task-lists)
7. [Success Criteria](#success-criteria)
8. [Risk Management](#risk-management)

---

## Roadmap Overview

### 🎯 Vision
Eine hochperformante, wartbare und testbare iOS-App nach Clean Architecture Prinzipien.

### 📊 Sprint-Übersicht

| Sprint | Woche | Ziel | Status |
|--------|-------|------|--------|
| **Sprint 1-2** | 1-2 | Foundation (DI, Entities, Repos) | ⏳ NEXT |
| **Sprint 3-4** | 3-4 | Session Management (Active Workout) | ⏳ GEPLANT |
| **Sprint 5-6** | 5-6 | Workout & Exercise Management | ⏳ GEPLANT |
| **Sprint 7-8** | 7-8 | Statistics, Tests, Polish | ⏳ GEPLANT |

### 🎓 Architektur-Referenz
Alle Implementierungen folgen: [`TECHNICAL_CONCEPT_V2.md`](TECHNICAL_CONCEPT_V2.md)

---

## Sprint 1-2: Foundation (Woche 1-2)

**Dauer:** 10 Arbeitstage
**Ziel:** Neue Architektur aufsetzen, DI funktionsfähig
**Status:** 🟡 BEREIT ZUM START (2025-10-22)

### 📦 Deliverables

- ✅ 4-Layer Projektstruktur angelegt
- ✅ DI Container implementiert
- ✅ Repository Protocols definiert
- ✅ Domain Entities erstellt (Workout, Exercise, Session)
- ✅ Test Infrastructure aufgesetzt
- ✅ App läuft mit neuer Architektur (parallel zur alten)

### 📅 Tag-für-Tag Plan

#### **Tag 1-2: Projektstruktur & DI Container**

**Tag 1 Morgen (3h)**
- [ ] Ordnerstruktur anlegen:
  ```
  GymTracker/
  ├── Domain/
  │   ├── Entities/
  │   ├── UseCases/
  │   └── RepositoryProtocols/
  ├── Data/
  │   ├── Repositories/
  │   ├── Mappers/
  │   └── Cache/
  ├── Presentation/
  │   ├── Stores/
  │   └── Views/
  └── Infrastructure/
      ├── SwiftData/
      ├── HealthKit/
      └── DI/
  ```
- [ ] Xcode Groups anlegen (spiegelt Ordner)
- [ ] `.gitkeep` Files für leere Ordner

**Tag 1 Nachmittag (3h)**
- [ ] `DependencyContainer.swift` implementieren
  - Service Locator Pattern
  - `register<T>()` für Factories
  - `registerSingleton<T>()` für Singletons
  - `resolve<T>()` für Dependency Resolution
- [ ] Unit Tests für DI Container

**Tag 2 (6h)**
- [ ] `GymTrackerApp.swift` anpassen
  - DI Container initialisieren
  - AppState mit Container verdrahten
- [ ] `AppState.swift` refactoren
  - Stores über DI Container injizieren
  - Tab Navigation beibehalten
- [ ] Build & Run Test - App startet

**Referenz:** `TECHNICAL_CONCEPT_V2.md` Zeile 880-999

---

#### **Tag 3-4: Domain Layer - Entities**

**Tag 3 (6h)**
- [ ] `Domain/Entities/Workout.swift` erstellen
  ```swift
  struct Workout: Identifiable, Equatable {
      let id: UUID
      var name: String
      var exercises: [WorkoutExercise]
      var defaultRestTime: TimeInterval
      var isFavorite: Bool
      var folder: WorkoutFolder?

      // Computed Properties
      var totalVolume: Double { ... }
      var estimatedDuration: TimeInterval { ... }

      // Business Logic
      func canAddExercise(_ exercise: Exercise) -> Result<Void, WorkoutError>
  }
  ```
- [ ] `Domain/Entities/Exercise.swift` erstellen
- [ ] `Domain/Entities/WorkoutExercise.swift` erstellen
- [ ] Unit Tests für Domain Entities

**Tag 4 (6h)**
- [ ] `Domain/Entities/WorkoutSession.swift` erstellen
- [ ] `Domain/Entities/Set.swift` erstellen
- [ ] `Domain/Entities/WorkoutFolder.swift` erstellen
- [ ] Errors definieren:
  - `WorkoutError.swift`
  - `SessionError.swift`
- [ ] Unit Tests für Session Entities

**Referenz:** `TECHNICAL_CONCEPT_V2.md` Zeile 138-180

---

#### **Tag 5-6: Repository Protocols**

**Tag 5 (6h)**
- [ ] `Domain/RepositoryProtocols/WorkoutRepositoryProtocol.swift`
  ```swift
  protocol WorkoutRepositoryProtocol {
      func fetch(id: UUID) async -> Result<Workout, RepositoryError>
      func fetchAll() async -> Result<[Workout], RepositoryError>
      func save(_ workout: Workout) async -> Result<Void, RepositoryError>
      func delete(id: UUID) async -> Result<Void, RepositoryError>
      func observe() -> AsyncStream<[Workout]>
  }
  ```
- [ ] `Domain/RepositoryProtocols/SessionRepositoryProtocol.swift`
- [ ] `Domain/RepositoryProtocols/ExerciseRepositoryProtocol.swift`
- [ ] `RepositoryError.swift` definieren

**Tag 6 (6h)**
- [ ] Mock Repositories erstellen:
  - `MockWorkoutRepository.swift` (in Tests/)
  - `MockSessionRepository.swift`
  - `MockExerciseRepository.swift`
- [ ] Tests für Mock Repositories

**Referenz:** `TECHNICAL_CONCEPT_V2.md` Zeile 248-267

---

#### **Tag 7-8: Erste Use Cases**

**Tag 7 (6h)**
- [ ] `Domain/UseCases/Workout/FetchWorkoutsUseCase.swift`
  ```swift
  class FetchWorkoutsUseCase {
      let repository: WorkoutRepositoryProtocol

      func execute() async -> Result<[Workout], WorkoutError> {
          // Business Logic hier
      }
  }
  ```
- [ ] `Domain/UseCases/Workout/FetchWorkoutByIdUseCase.swift`
- [ ] Unit Tests für Use Cases (mit Mock Repos)

**Tag 8 (6h)**
- [ ] `Domain/UseCases/Workout/SaveWorkoutUseCase.swift`
- [ ] `Domain/UseCases/Workout/DeleteWorkoutUseCase.swift`
- [ ] Unit Tests erweitern
- [ ] Test Coverage Check (sollte >90% für Domain sein)

**Referenz:** `TECHNICAL_CONCEPT_V2.md` Zeile 183-245

---

#### **Tag 9-10: Data Layer - Repositories**

**Tag 9 (6h)**
- [ ] `Data/Repositories/SwiftDataWorkoutRepository.swift`
  ```swift
  class SwiftDataWorkoutRepository: WorkoutRepositoryProtocol {
      let context: ModelContext
      let mapper: WorkoutMapper

      func fetch(id: UUID) async -> Result<Workout, RepositoryError> {
          // SwiftData fetch + mapping
      }
  }
  ```
- [ ] `Data/Mappers/WorkoutMapper.swift`
  ```swift
  struct WorkoutMapper {
      func toDomain(_ entity: WorkoutEntity) -> Workout
      func toEntity(_ workout: Workout, context: ModelContext) -> WorkoutEntity
  }
  ```

**Tag 10 (6h)**
- [ ] DI Container verdrahten:
  - Repositories registrieren
  - Use Cases registrieren
  - Singletons für Repositories
- [ ] Integration Test: Use Case → Repository → SwiftData
- [ ] App Build & Run mit echter Datenbank
- [ ] **Sprint 1-2 Retrospective**

**Referenz:** `TECHNICAL_CONCEPT_V2.md` Zeile 272-362

---

### ✅ Sprint 1-2 Success Criteria

**MUSS (Blocker für Sprint 3):**
- [ ] Alle 4 Layer Ordner existieren
- [ ] DI Container funktioniert (registriert & resolved)
- [ ] Workout, Exercise, Session Entities erstellt
- [ ] Mindestens 3 Repository Protocols definiert
- [ ] Mindestens 2 Use Cases implementiert
- [ ] 1 Repository Implementation (SwiftData)
- [ ] Test Coverage Domain Layer: >80%
- [ ] App startet ohne Crashes

**SOLL (Nice-to-have):**
- [ ] Cache Service implementiert
- [ ] Retry Logic für Repository
- [ ] Performance Baseline gemessen

---

## Sprint 3-4: Session Management (Woche 3-4)

**Dauer:** 10 Arbeitstage
**Ziel:** Active Workout Flow komplett neu implementiert
**Status:** ⏳ GEPLANT (startet nach Sprint 1-2)

### 📦 Deliverables

- ✅ SessionStore (Feature Store Pattern)
- ✅ Session Use Cases (Start, End, Update)
- ✅ SessionRepository Implementation
- ✅ Active Workout Views (neu mit Clean Architecture)
- ✅ Unit Tests (>80% Coverage)
- ✅ Integration Tests (Store → Use Case → Repository)

### 📅 Tag-für-Tag Plan

#### **Tag 11-12: Session Use Cases**

**Tag 11 (6h)**
- [ ] `Domain/UseCases/Session/StartWorkoutSessionUseCase.swift`
  ```swift
  class StartWorkoutSessionUseCase: StartWorkoutSessionUseCaseProtocol {
      let workoutRepository: WorkoutRepositoryProtocol
      let sessionRepository: SessionRepositoryProtocol
      let healthKitService: HealthKitServiceProtocol

      func execute(workoutId: UUID) async -> Result<WorkoutSession, SessionError>
  }
  ```
- [ ] Business Logic:
  - Workout laden
  - Session erstellen
  - HealthKit starten
  - Session speichern
- [ ] Unit Tests (Mocks)

**Tag 12 (6h)**
- [ ] `EndWorkoutSessionUseCase.swift`
- [ ] `UpdateWorkoutSessionUseCase.swift`
- [ ] `CompleteSetUseCase.swift`
- [ ] Unit Tests erweitern
- [ ] Edge Cases testen (z.B. Session already active)

**Referenz:** `TECHNICAL_CONCEPT_V2.md` Zeile 189-245

---

#### **Tag 13-14: SessionStore (Presentation Layer)**

**Tag 13 (6h)**
- [ ] `Presentation/Stores/SessionStore.swift`
  ```swift
  @MainActor
  class SessionStore: ObservableObject {
      @Published var state: State
      @Published var activeSession: WorkoutSession?
      @Published var error: SessionError?

      let startSessionUseCase: StartWorkoutSessionUseCaseProtocol
      let endSessionUseCase: EndWorkoutSessionUseCaseProtocol

      func startSession(workoutId: UUID) async
      func completeSet(_ setIndex: Int, for exerciseIndex: Int) async
  }
  ```
- [ ] State Machine implementieren (idle, loading, active, error)

**Tag 14 (6h)**
- [ ] SessionStore Integration Tests
  - Mit Mock Use Cases
  - State Transitions testen
  - Error Handling testen
- [ ] DI Container Registrierung

---

#### **Tag 15-16: SessionRepository**

**Tag 15 (6h)**
- [ ] `Data/Repositories/SwiftDataSessionRepository.swift`
- [ ] `Data/Mappers/SessionMapper.swift`
- [ ] CRUD Operations für Session
- [ ] Observer Pattern für aktive Session

**Tag 16 (6h)**
- [ ] Repository Tests
- [ ] Performance Tests (große Sessions)
- [ ] Integration Test: Store → Use Case → Repository

---

#### **Tag 17-19: Active Workout Views (Neu)**

**Tag 17 (6h)**
- [ ] `Presentation/Views/ActiveWorkout/ActiveWorkoutView.swift`
  - Dumb View (keine Business Logic)
  - Bindet an SessionStore
  - Nutzt alte UI-Komponenten als Referenz
- [ ] `ExerciseListView.swift`
- [ ] `SetRowView.swift`

**Tag 18 (6h)**
- [ ] `TimerSectionView.swift`
- [ ] `CompletionButtonView.swift`
- [ ] Navigation verdrahten (von Home → Active Workout)
- [ ] Preview States (Empty, Loading, Active, Completed)

**Tag 19 (6h)**
- [ ] UI Tests (Critical Flows):
  - Start Workout
  - Complete Set
  - End Workout
- [ ] Haptic Feedback Integration
- [ ] Dark Mode Testing

**UI Referenz:** `archive/v2-ui-experiments` Branch - ActiveWorkoutV2 Components

---

#### **Tag 20: Sprint 3-4 Wrap-Up**

- [ ] Code Review (selbst oder Pair)
- [ ] Performance Profiling (Instruments)
- [ ] Test Coverage Check (Ziel: >80%)
- [ ] Bug Fixes
- [ ] **Sprint 3-4 Retrospective**
- [ ] Documentation Update

---

### ✅ Sprint 3-4 Success Criteria

**MUSS:**
- [ ] Session kann gestartet werden
- [ ] Sets können completed werden
- [ ] Session kann beendet werden
- [ ] Daten persistent in SwiftData
- [ ] HealthKit Integration funktioniert
- [ ] Test Coverage: >80%
- [ ] Keine Memory Leaks

**SOLL:**
- [ ] Rest Timer funktioniert
- [ ] Exercise Reordering funktioniert
- [ ] Offline-fähig (kein Crash bei Netzwerk-Loss)

---

## Sprint 5-6: Workout & Exercise Management (Woche 5-6)

**Dauer:** 10 Arbeitstage
**Ziel:** CRUD für Workouts & Exercises
**Status:** ⏳ GEPLANT

### 📦 Deliverables

- ✅ WorkoutStore (Feature Store Pattern)
- ✅ ExerciseStore (Feature Store Pattern)
- ✅ Workout/Exercise Use Cases (CRUD)
- ✅ Home View neu (mit WorkoutStore)
- ✅ Workout Builder View neu
- ✅ Exercise Library View neu

### 📅 High-Level Tasks

#### **Tag 21-23: Workout Use Cases & Store**
- [ ] CRUD Use Cases (Create, Update, Delete, Reorder)
- [ ] WorkoutStore implementieren
- [ ] Unit Tests

#### **Tag 24-26: Exercise Use Cases & Store**
- [ ] Exercise CRUD Use Cases
- [ ] ExerciseStore implementieren
- [ ] Translation Service Migration
- [ ] Unit Tests

#### **Tag 27-29: Views (Home, Workout Builder)**
- [ ] Home View neu (Liste, Kalender, Stats)
- [ ] Workout Builder View
- [ ] Exercise Picker View
- [ ] UI Tests

**UI Referenz:** `archive/v2-ui-experiments` - HomeV2 Components

#### **Tag 30: Sprint 5-6 Wrap-Up**
- [ ] Integration Tests
- [ ] Performance Testing
- [ ] Retrospective

---

### ✅ Sprint 5-6 Success Criteria

**MUSS:**
- [ ] Workout erstellen/bearbeiten/löschen
- [ ] Exercise erstellen/bearbeiten/löschen
- [ ] Workout Reordering funktioniert
- [ ] Favoriten funktionieren
- [ ] Folder System funktioniert
- [ ] Test Coverage: >70%

---

## Sprint 7-8: Statistics, Testing, Polish (Woche 7-8)

**Dauer:** 10 Arbeitstage
**Ziel:** Feature-Completion, Performance, Cleanup
**Status:** ⏳ GEPLANT

### 📦 Deliverables

- ✅ StatisticsStore implementiert
- ✅ Analytics Views neu
- ✅ Profile/Settings Views neu
- ✅ Caching optimiert
- ✅ Performance Profiling
- ✅ Integration Tests vollständig
- ✅ UI Tests (Critical Flows)
- ✅ Alte WorkoutStore gelöscht (130KB)
- ✅ Code Cleanup
- ✅ Documentation Update
- ✅ **v2.0 Release Candidate**

### 📅 High-Level Tasks

#### **Tag 31-33: Statistics & Analytics**
- [ ] StatisticsStore
- [ ] Analytics Use Cases (Weekly Stats, Progress, etc.)
- [ ] Analytics Views
- [ ] Charts Integration

#### **Tag 34-36: Profile & Settings**
- [ ] ProfileStore
- [ ] Settings Migration (UserDefaults → SwiftData)
- [ ] Profile Views
- [ ] Onboarding Flow

#### **Tag 37-38: Performance & Optimization**
- [ ] Caching Layer optimieren
- [ ] Prefetching implementieren
- [ ] Lazy Loading überall
- [ ] Memory Profiling (Instruments)
- [ ] App Launch Time optimieren

#### **Tag 39: Testing & Quality**
- [ ] Integration Tests (End-to-End Flows)
- [ ] UI Tests (Alle Critical Flows)
- [ ] Test Coverage: >70% gesamt
- [ ] Bug Bash (alle gefundenen Bugs fixen)

#### **Tag 40: Cleanup & Release**
- [ ] Alte WorkoutStore löschen (130KB File)
- [ ] Alte Services löschen
- [ ] Code Cleanup (unused imports, TODOs)
- [ ] Documentation Update
- [ ] Release Notes schreiben
- [ ] **v2.0 RC erstellen**

---

### ✅ Sprint 7-8 Success Criteria

**MUSS:**
- [ ] Alle Features funktionieren
- [ ] Test Coverage: >70%
- [ ] Performance Targets erreicht
- [ ] Keine kritischen Bugs
- [ ] Alte Architektur komplett entfernt
- [ ] App Launch: <1.5s
- [ ] Größte Datei: <30KB

---

## Daily Task Lists

### Template für jeden Arbeitstag:

```markdown
## Tag X - [Datum] - [Sprint X] - [Thema]

### 🎯 Ziel des Tages
[Ein Satz: Was soll am Ende erreicht sein?]

### ✅ Tasks
- [ ] Task 1 (Zeitschätzung)
- [ ] Task 2
- [ ] Task 3

### 📝 Notes & Learnings
[Am Ende des Tages: Was lief gut? Was lief schlecht? Learnings?]

### 🐛 Bugs gefunden
[Bugs dokumentieren mit Status]

### ⏭️ Nächster Tag
[Was ist morgen als erstes zu tun?]
```

---

## Success Criteria

### 🎯 Gesamt-Ziele (8 Wochen)

**Architektur:**
- ✅ Clean Architecture 4-Layer Pattern vollständig implementiert
- ✅ Dependency Injection überall
- ✅ Alle Business Logic in Use Cases
- ✅ Views sind dumb (nur Presentation)

**Testing:**
- ✅ Test Coverage: >70% gesamt
- ✅ Domain Layer: >90%
- ✅ Unit Tests für alle Use Cases
- ✅ Integration Tests für kritische Flows
- ✅ UI Tests für Happy Paths

**Performance:**
- ✅ App Launch: <1.5s (down from 3-5s)
- ✅ Compile Time: <20s (down from 45s)
- ✅ Größte Datei: <30KB (down from 130KB)
- ✅ Keine Memory Leaks
- ✅ Smooth 60fps UI

**Code Quality:**
- ✅ Keine SOLID Violations
- ✅ Keine Circular Dependencies
- ✅ Keine Force Unwraps (außer Tests)
- ✅ SwiftLint Clean (0 Warnings)

**Features:**
- ✅ Alle V1 Features funktionieren
- ✅ Keine Regressions
- ✅ HealthKit funktioniert
- ✅ SwiftData Migration erfolgreich

---

## Risk Management

### 🚨 Risiken & Mitigation

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| **SwiftData Migration schlägt fehl** | Medium | Hoch | Backup-Strategie, Incremental Migration, Rollback-Plan |
| **Performance schlechter als V1** | Low | Hoch | Frühzeitig profilen, Benchmarks definieren |
| **Test Coverage Ziel nicht erreicht** | Medium | Medium | Test-First Development, Pair Programming |
| **8 Wochen reichen nicht** | Medium | Medium | MVP definieren, Features priorisieren, Timeboxing |
| **HealthKit Integration bricht** | Low | Hoch | Früh testen, Fallback ohne HealthKit |
| **DI Container Overhead** | Low | Low | Performance Tests, Lazy Loading |

### 🛡️ Mitigation Strategies

**Daily:**
- [ ] Mindestens 1x Build & Run
- [ ] Tests ausführen vor jedem Commit
- [ ] Code Review (selbst oder Pair)

**Weekly:**
- [ ] Sprint Review (Freitag)
- [ ] Performance Check (Instruments)
- [ ] Test Coverage Check

**Bi-Weekly:**
- [ ] Sprint Retrospective
- [ ] Roadmap Update
- [ ] Risk Assessment

---

## Tools & Resources

### 📚 Dokumentation (Referenz)
- `TECHNICAL_CONCEPT_V2.md` - Architektur Bible
- `DATAFLOW_KONZEPT_V2.md` - State Management
- `archive/v2-ui-experiments` - UI Reference

### 🧪 Testing
- XCTest (Unit Tests)
- XCUITest (UI Tests)
- Mocks & Fixtures selbst gebaut

### 📊 Performance
- Instruments (Time Profiler, Allocations)
- SwiftLint (Code Quality)
- xcodebuild -showBuildTimings

### 🔧 Development
- Xcode 15+
- iOS 17+ Target
- Swift 5.9+

---

## Lessons Learned (laufend aktualisieren)

### Was gut läuft
[TBD - während Implementation]

### Was verbessert werden muss
[TBD - während Implementation]

### Architektur-Entscheidungen
[TBD - ADRs dokumentieren]

---

## Changelog

### 2025-10-21
- ✅ Roadmap erstellt
- ✅ Sprint 1-2 detailliert geplant (Tag 1-10)
- ✅ Sprint 3-4 high-level geplant
- ✅ Sprint 5-6 Outline
- ✅ Sprint 7-8 Outline
- ✅ Success Criteria definiert
- ✅ Risk Management hinzugefügt

---

**Nächster Meilenstein:** Sprint 1 - Tag 1 (2025-10-22)
**Erste Task:** Projektstruktur anlegen (4 Layer Ordner)

**Status:** 🟢 READY TO START
