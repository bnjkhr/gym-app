# DataFlow-Konzept für GymBo v2.0

**Erstellt:** 2025-10-21
**Autor:** Claude Code Analysis
**Version:** 2.0 Planning Document

---

## Inhaltsverzeichnis

1. [Executive Summary](#executive-summary)
2. [Aktuelle Architektur (v1.x)](#aktuelle-architektur-v1x)
3. [Datenmodell-Übersicht](#datenmodell-übersicht)
4. [Datenfluss-Analyse](#datenfluss-analyse)
5. [State Management](#state-management)
6. [Persistierung & Speicherung](#persistierung--speicherung)
7. [Schwachstellen & Technical Debt](#schwachstellen--technical-debt)
8. [Empfehlungen für v2.0](#empfehlungen-für-v20)
9. [Migrationsplan](#migrationsplan)

---

## Executive Summary

GymBo ist eine **native iOS Fitness-App** mit hochmoderner Architektur basierend auf:
- **SwiftUI** (deklaratives UI)
- **SwiftData** (iOS 17+ Persistierung)
- **MVVM + Repository Pattern**
- **HealthKit Integration**
- **Live Activities & Dynamic Island**

### Kernmetriken

| Metrik | Wert |
|--------|------|
| Swift-Dateien | 130+ |
| Services | 14 (4.067 LOC) |
| Views | 30+ (10.738 LOC) |
| Entities | 8 SwiftData Models |
| Domain Models | 9 Structs |
| Coordinators | 9 Feature-Koordinatoren |
| Test-Abdeckung | ~15% (Ziel: 60-70%) |

### Stärken der aktuellen Architektur

✅ **Klare Separation of Concerns** - Domain Models ↔ Persistence Layer
✅ **Reaktive UI** - SwiftUI @Query für automatische Updates
✅ **Performance-optimiert** - Caching, LazyStacks, DB-Level Filtering
✅ **Robuste Persistierung** - Multi-Fallback-Strategie, Migrations-System
✅ **Modulare Services** - Feature-basierte Organisation
✅ **AI-Integration** - 15-Regel Tip-Engine

### Hauptprobleme (Technical Debt)

❌ **WorkoutStore zu groß** - 130KB Datei, sollte aufgeteilt werden
❌ **UserDefaults für Profile** - Sollte zu SwiftData migriert werden
❌ **Inkonsistente Datenhaltung** - Mix aus SwiftData + UserDefaults
❌ **Fehlende Transaktionen** - Keine Atomicity bei komplexen Operationen
❌ **Cache-Invalidierung** - Manuell, fehleranfällig
❌ **Unidirektionale Sync** - HealthKit nur teilweise bidirektional

---

## Aktuelle Architektur (v1.x)

### Schichtenmodell

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│                                                              │
│  SwiftUI Views (30+ Components)                             │
│  - WorkoutsHomeView, StatisticsView, ProfileView           │
│  - @State, @Binding, @Query, @EnvironmentObject            │
│  - LazyVStack/Grid für Performance                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   VIEW MODEL LAYER                           │
│                                                              │
│  WorkoutStore (Singleton, @MainActor)                       │
│  - activeSessionID: UUID?                                   │
│  - restTimerStateManager: RestTimerStateManager             │
│  - healthKitManager: HealthKitManager                       │
│  - Exercise Stats Caching                                   │
│  - Profile Management                                        │
│                                                              │
│  RestTimerStateManager (@MainActor, @Published)             │
│  - currentState: RestTimerState?                            │
│  - Koordiniert: Timer, LiveActivity, Push, Overlay          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    BUSINESS LOGIC LAYER                      │
│                                                              │
│  Services (14 Klassen, 4.067 LOC)                           │
│  ├─ WorkoutDataService         - CRUD Operationen           │
│  ├─ WorkoutAnalyticsService    - Statistiken & Caching      │
│  ├─ WorkoutAnalyzer            - AI-Analyse                 │
│  ├─ TipEngine                  - 15 Regeln, 6 Kategorien    │
│  ├─ SessionManagementService   - Session Lifecycle          │
│  ├─ HealthKitManager           - Bidirektionale Sync        │
│  ├─ NotificationManager        - Push Notifications         │
│  ├─ ExerciseRecordService      - Personal Records           │
│  ├─ LastUsedMetricsService     - Letzte Werte               │
│  ├─ ProfileService             - Profil (UserDefaults!)     │
│  ├─ WorkoutGenerationService   - Wizard                     │
│  ├─ BackupManager              - Export/Import              │
│  └─ InAppOverlayManager        - In-App Overlays            │
│                                                              │
│  Coordinators (9 Feature-Koordinatoren)                     │
│  - WorkoutCoordinator, SessionCoordinator, etc.             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                              │
│                                                              │
│  Domain Models (Value Types - Structs)                      │
│  ├─ Exercise (mit Similarity-Algorithmus)                   │
│  ├─ Workout                                                  │
│  ├─ WorkoutExercise                                          │
│  ├─ ExerciseSet                                              │
│  ├─ WorkoutSession                                           │
│  ├─ TrainingTip                                              │
│  ├─ UserProfile                                              │
│  └─ RestTimerState                                           │
│                                                              │
│  SwiftData Entities (@Model classes)                        │
│  ├─ ExerciseEntity                                           │
│  ├─ WorkoutEntity                                            │
│  ├─ WorkoutExerciseEntity                                    │
│  ├─ ExerciseSetEntity                                        │
│  ├─ WorkoutSessionEntity                                     │
│  ├─ ExerciseRecordEntity                                     │
│  ├─ UserProfileEntity                                        │
│  └─ WorkoutFolderEntity                                      │
│                                                              │
│  Mapping Layer (Bidirektional)                              │
│  - mapExerciseEntity() -> Exercise                           │
│  - mapWorkoutEntity() -> Workout                             │
│  - ExerciseEntity.make(from: Exercise)                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   PERSISTENCE LAYER                          │
│                                                              │
│  SwiftData ModelContainer (SQLite Backend)                  │
│  - Automatic Schema Migration                               │
│  - Fallback Chain: AppSupport → Documents → Temp → Memory  │
│  - @Query für reaktive Updates                              │
│                                                              │
│  UserDefaults (Legacy & Preferences)                        │
│  - Rest Timer State (Force Quit Recovery)                   │
│  - App Preferences (weeklyGoal, notifications)              │
│  - Profile Data (TECHNICAL DEBT!)                           │
│  - Migration Versions                                        │
│                                                              │
│  HealthKit Store (External)                                 │
│  - HKWorkoutSession Export                                   │
│  - Body Metrics Import (Weight, Height)                     │
│  - Live Heart Rate (HKQuantityTypeIdentifier)               │
└─────────────────────────────────────────────────────────────┘
```

---

## Datenmodell-Übersicht

### Entity-Relationship-Diagramm (SwiftData)

```
┌─────────────────────┐
│  ExerciseEntity     │
│  (161 vordefiniert) │
├─────────────────────┤
│ • id: UUID          │
│ • name: String      │
│ • muscleGroupsRaw   │◄──────────┐
│ • equipmentTypeRaw  │           │ @Relationship
│ • difficultyLevel   │           │ (deleteRule: .nullify)
│ • instructions      │           │
│ • lastUsedWeight    │           │
│ • lastUsedReps      │           │
│ • lastUsedDate      │           │
└─────────────────────┘           │
                                  │
                                  │
┌─────────────────────┐           │
│ WorkoutFolderEntity │           │
├─────────────────────┤           │
│ • id: UUID          │◄──┐       │
│ • name: String      │   │       │
│ • color: String     │   │       │
│ • order: Int        │   │       │
└─────────────────────┘   │       │
                          │       │
                          │       │
┌─────────────────────┐   │       │
│   WorkoutEntity     │   │       │
│   (Templates)       │   │       │
├─────────────────────┤   │       │
│ • id: UUID          │   │       │
│ • name: String      │   │       │
│ • defaultRestTime   │   │       │
│ • isFavorite        │   │       │
│ • exerciseCount     │   │       │
│ • folder            │───┘       │
│ • orderInFolder     │           │
└─────────┬───────────┘           │
          │ @Relationship         │
          │ (cascade delete)      │
          ▼                       │
┌─────────────────────┐           │
│WorkoutExerciseEntity│           │
├─────────────────────┤           │
│ • id: UUID          │           │
│ • exercise          │───────────┘
│ • sets: [Set]       │───┐
│ • order: Int        │   │ @Relationship
│ • workout           │   │ (cascade delete)
│ • session           │   │
└─────────────────────┘   │
                          ▼
                    ┌─────────────────┐
                    │ExerciseSetEntity│
                    ├─────────────────┤
                    │ • id: UUID      │
                    │ • reps: Int     │
                    │ • weight: Double│
                    │ • restTime      │
                    │ • completed     │
                    └─────────────────┘

┌─────────────────────┐
│WorkoutSessionEntity │
│  (History)          │
├─────────────────────┤
│ • id: UUID          │
│ • templateId: UUID? │──┐ (optional link)
│ • name: String      │  │
│ • date: Date        │  │
│ • exercises         │  │
│ • duration          │  │
│ • minHeartRate      │  │
│ • maxHeartRate      │  │
│ • avgHeartRate      │  │
└─────────────────────┘  │
         │               │
         └───────────────┘

┌─────────────────────┐
│ExerciseRecordEntity │
│ (Personal Records)  │
├─────────────────────┤
│ • id: UUID          │
│ • exerciseId: UUID  │
│ • maxWeight         │
│ • maxWeightReps     │
│ • maxReps           │
│ • bestEstimated1RM  │
└─────────────────────┘

┌─────────────────────┐
│ UserProfileEntity   │
├─────────────────────┤
│ • id: UUID          │
│ • name: String      │
│ • birthDate         │
│ • weight, height    │
│ • goalRaw           │
│ • experienceRaw     │
│ • equipmentRaw      │
│ • lockerNumber      │
│ • onboarding flags  │
└─────────────────────┘
```

### Kardinalitäten

| Beziehung | Typ | Delete Rule |
|-----------|-----|-------------|
| Workout → WorkoutExercise | 1:N | cascade |
| WorkoutExercise → ExerciseSet | 1:N | cascade |
| WorkoutExercise → Exercise | N:1 | nullify |
| WorkoutFolder → Workout | 1:N | nullify |
| Session → WorkoutExercise | 1:N | cascade |
| Session → Template | N:1 | keine (UUID-Referenz) |

---

## Datenfluss-Analyse

### 1. Workout-Session Lifecycle (Hauptfluss)

```
USER ACTION: "Workout starten"
         │
         ▼
┌─────────────────────────────────┐
│  WorkoutsHomeView.swift         │
│  - Button: "Start Workout"      │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  WorkoutStore.startSession()    │
│  1. Validate workout exists     │
│  2. Set activeSessionID         │
│  3. Persist to UserDefaults     │
│  4. Start HealthKit tracking    │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  SessionManagementService       │
│  - prepareSessionStart()        │
│  - Fetch WorkoutEntity          │
│  - Validate exercises           │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  SwiftData ModelContext         │
│  - FetchDescriptor<WorkoutEntity>│
│  - Predicate: id == workoutId   │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  HealthKitManager               │
│  - startWorkoutSession()        │
│  - Request HKWorkoutSession     │
│  - Start HeartRate monitoring   │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Live Activity                  │
│  - WorkoutLiveActivityController│
│  - Start Dynamic Island         │
│  - Display workout info         │
└─────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  ActiveWorkoutView              │
│  - @Query activeWorkout         │
│  - Horizontal Exercise Swipe    │
│  - Set-by-Set Tracking          │
└─────────────────────────────────┘
```

### 2. Rest Timer Datenfluss (Kritischer Pfad)

```
USER ACTION: "Satz abgeschlossen"
         │
         ▼
┌──────────────────────────────────────┐
│  ExerciseSetRow.swift                │
│  - Toggle set.completed              │
│  - Trigger rest timer                │
└────────────┬─────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│  WorkoutStore.startRest()            │
│  - Delegate to RestTimerStateManager │
└────────────┬─────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│  RestTimerStateManager               │
│  SINGLE SOURCE OF TRUTH              │
│                                      │
│  1. Create RestTimerState            │
│     - workoutId, exerciseIndex       │
│     - startDate, endDate (wall-clock)│
│     - totalSeconds, phase: .running  │
│                                      │
│  2. Persist to UserDefaults          │
│     Key: "restTimerState_v2"         │
│     (Force Quit Recovery!)           │
│                                      │
│  3. Publish state change             │
│     @Published currentState          │
└────────────┬─────────────────────────┘
             │
             ├────────────┬────────────┬────────────┐
             ▼            ▼            ▼            ▼
    ┌───────────┐ ┌──────────┐ ┌────────────┐ ┌─────────┐
    │TimerEngine│ │LiveActiv.│ │ NotifMgr   │ │Overlay  │
    │           │ │          │ │            │ │Manager  │
    │Wall-Clock │ │Dynamic   │ │Push Notif. │ │In-App   │
    │Precise    │ │Island    │ │Background  │ │Foreground│
    │Timer      │ │Updates   │ │Deep Link   │ │Display  │
    └─────┬─────┘ └────┬─────┘ └──────┬─────┘ └────┬────┘
          │            │               │            │
          └────────────┴───────────────┴────────────┘
                       │
                       ▼
          ┌───────────────────────────┐
          │  UI Updates (Reactive)    │
          │  - RestTimerOverlay       │
          │  - Dynamic Island         │
          │  - Push Notification      │
          │  - Haptic Feedback        │
          └───────────────────────────┘
```

**Wichtig:** RestTimerStateManager koordiniert ALLE Subsysteme:
- ✅ TimerEngine (Wall-Clock basiert, überlebt App-Backgrounding)
- ✅ Live Activity (nur iOS 16.1+, Physical Device)
- ✅ Push Notifications (nur wenn App im Hintergrund)
- ✅ In-App Overlay (nur wenn App im Vordergrund)
- ✅ Haptics & Sound (Phase 6)

### 3. Statistik-Berechnung (Read-Heavy)

```
USER: "Statistik-Tab öffnen"
         │
         ▼
┌─────────────────────────────────┐
│  StatisticsView.swift           │
│  - @Query WorkoutSessionEntity  │
│  - Predicate: last 30 days      │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  WorkoutAnalyticsService        │
│  CACHING LAYER!                 │
│                                 │
│  - exerciseStatsCache: [UUID:  │
│    ExerciseStats]               │
│  - Cache hit: Return cached     │
│  - Cache miss: Compute & cache  │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  SwiftData Fetch (Batch)        │
│  - FetchDescriptor<Session>     │
│  - SortBy: date DESC            │
│  - Limit: 100                   │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Compute Metrics                │
│  - Total Volume (kg)            │
│  - Exercise Count               │
│  - Week Comparison              │
│  - Personal Records             │
│  - Muscle Group Distribution    │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Cache Result                   │
│  exerciseStatsCache[id] = stats │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Return to View                 │
│  - Charts (native Charts fw)    │
│  - LazyVStack (performance)     │
└─────────────────────────────────┘
```

**Cache Invalidierung:**
- ❌ **Problem:** Manuell via `invalidateExerciseCache()`
- ❌ **Fehleranfällig:** Wird oft vergessen
- ✅ **v2.0:** Automatisch via Observers

### 4. HealthKit Synchronisation (Bidirektional)

```
┌─────────────────────────────────────────────────┐
│              HEALTHKIT INTEGRATION               │
└─────────────────────────────────────────────────┘

READ (Import zu GymBo):
─────────────────────────
HealthKit Store
    │ HKQuantityType
    ├─ Weight (HKBodyMass)
    ├─ Height (HKHeight)
    ├─ BirthDate (HKCharacteristicType)
    └─ BiologicalSex (HKCharacteristicType)
    │
    ▼
HealthKitManager.requestHealthKitData()
    │
    ├─ Query HKQuantityType
    ├─ Get most recent sample
    └─ Timeout: 30 seconds
    │
    ▼
ProfileService.updateProfile()
    │
    ▼
UserDefaults (TECHNICAL DEBT!)
    Key: "userProfile"
    │
    ▼
UI Update (@Published profileUpdateTrigger)


WRITE (Export von GymBo):
─────────────────────────
WorkoutSession Complete
    │
    ▼
HealthKitManager.saveWorkoutToHealthKit()
    │
    ├─ Create HKWorkoutConfiguration
    ├─ Calculate active energy burn
    ├─ Set start/end dates
    └─ Add metadata (exercises, volume)
    │
    ▼
HKHealthStore.save(HKWorkout)
    │
    ▼
HealthKit Store (persistent)


LIVE DATA (Während Workout):
────────────────────────────
HKWorkoutSession (active)
    │
    ▼
HealthKitWorkoutTracker.startTracking()
    │
    ├─ Start HKLiveWorkoutBuilder
    ├─ Subscribe to Heart Rate
    └─ Query interval: 5 seconds
    │
    ▼
Heart Rate Updates (streaming)
    │ @Published currentHeartRate
    ├─ Update RestTimerState
    ├─ Update Live Activity
    └─ Display in ActiveWorkoutView
    │
    ▼
Session End → Save min/max/avg HR
```

**HealthKit Probleme:**
- ⚠️ **Unidirektionale Profile-Sync:** Weight/Height nur Import, kein Export
- ⚠️ **Timeout-Probleme:** 30s für Queries kann zu lang sein
- ⚠️ **Fehlende Fehlerbehandlung:** Berechtigungen werden nicht persistent gecheckt

---

## State Management

### 1. State-Container-Hierarchie

```
┌───────────────────────────────────────────────┐
│           APP-WIDE STATE                      │
│                                               │
│  WorkoutStore (@EnvironmentObject)            │
│  ├─ @Published activeSessionID: UUID?         │
│  ├─ @Published profileUpdateTrigger: UUID     │
│  ├─ restTimerStateManager                     │
│  ├─ healthKitManager                          │
│  └─ modelContext: ModelContext?               │
└───────────────┬───────────────────────────────┘
                │
                ├──────────────────────────────┐
                │                              │
        ┌───────▼───────┐          ┌──────────▼──────────┐
        │ RestTimer     │          │  HealthKit          │
        │ StateManager  │          │  Manager            │
        ├───────────────┤          ├─────────────────────┤
        │ @Published    │          │ @Published          │
        │ currentState  │          │ currentHeartRate    │
        └───────────────┘          └─────────────────────┘
```

### 2. State-Persistierung-Matrix

| State | Storage | Grund | Problem |
|-------|---------|-------|---------|
| `activeSessionID` | UserDefaults | Session überlebt App-Restart | ⚠️ Kann veraltet sein |
| `RestTimerState` | UserDefaults | Force Quit Recovery | ✅ Gut |
| `UserProfile` | UserDefaults | Legacy-Kompatibilität | ❌ Sollte SwiftData sein |
| `weeklyGoal` | @AppStorage | User Preference | ✅ Gut |
| `restNotificationsEnabled` | @AppStorage | User Preference | ✅ Gut |
| `exerciseStatsCache` | In-Memory | Performance | ⚠️ Verloren bei Restart |
| `Workouts/Sessions` | SwiftData | Primäre Daten | ✅ Gut |
| `Exercise Catalog` | SwiftData | 161 vordefiniert | ✅ Gut |
| `Personal Records` | SwiftData | Berechnete Daten | ✅ Gut |

### 3. Reaktive Updates (SwiftUI)

```swift
// Pattern 1: @Query (Automatische Updates)
@Query(filter: #Predicate<WorkoutEntity> { $0.isFavorite == true })
var favoriteWorkouts: [WorkoutEntity]
// ✅ Updates automatisch wenn SwiftData sich ändert

// Pattern 2: @Published (Manuelles Publishing)
class WorkoutStore: ObservableObject {
    @Published var activeSessionID: UUID?
    // ✅ Views reagieren auf Änderungen
}

// Pattern 3: @AppStorage (UserDefaults Binding)
@AppStorage("weeklyGoal") var weeklyGoal: Int = 5
// ✅ Automatische Sync mit UserDefaults

// Pattern 4: @State + @Binding (Lokaler State)
@State private var selectedExercise: Exercise?
// ✅ View-lokaler State
```

---

## Persistierung & Speicherung

### 1. SwiftData Container-Setup

```swift
// GymTrackerApp.swift

static let containerResult: (ModelContainer, StorageLocation) = {
    let schema = Schema([
        ExerciseEntity.self,
        WorkoutEntity.self,
        WorkoutSessionEntity.self,
        // ... 8 Entities total
    ])

    // Fallback-Kette (Robustheit!)
    let result = ModelContainerFactory.createContainer(schema: schema)

    switch result {
    case .success(container, location):
        // Locations:
        // 1. Application Support (preferred)
        // 2. Documents (fallback 1)
        // 3. Temporary (fallback 2)
        // 4. In-Memory (fallback 3)
        return (container, location)

    case .failure(error):
        // Emergency in-memory container
        fatalError("Container creation failed")
    }
}()
```

**Storage Locations (Priorität):**

1. **Application Support** (bevorzugt)
   - Persistent, backed up via iCloud
   - Pfad: `~/Library/Application Support/`

2. **Documents** (Fallback 1)
   - User-visible, iTunes sync
   - Pfad: `~/Documents/`

3. **Temporary** (Fallback 2)
   - ⚠️ Kann von OS gelöscht werden!
   - Pfad: `~/tmp/`

4. **In-Memory** (Fallback 3)
   - ❌ Alle Daten verloren bei App-Neustart
   - Nur für Testing

### 2. Migration-System

```swift
// Versionskontrolle
struct DataVersions {
    static let EXERCISE_DATABASE_VERSION = 1
    static let SAMPLE_WORKOUT_VERSION = 2
    static let FORCE_FULL_RESET_VERSION = 2
}

// Migration-Pipeline (GymTrackerApp.swift)
func performMigrations() async {
    1. Schema-Validierung
    2. Force Reset (wenn FORCE_FULL_RESET_VERSION erhöht)
    3. Exercise-Datenbank-Update (CSV → SwiftData)
    4. Sample-Workout-Versionierung
    5. Exercise Records Generation
    6. Last-Used Metrics Population
    7. Live Activity Sync
}
```

**Migration-Typen:**

| Typ | Wann | Wie |
|-----|------|-----|
| **Lightweight** | Neue Properties mit Default | Automatisch (SwiftData) |
| **CSV Update** | 161 Exercises ändern | CSV reimport |
| **Force Reset** | Breaking Schema Change | Alle Daten löschen |
| **Versioned Update** | Sample Workouts | Version-Check |

### 3. Backup & Export

```swift
// BackupManager.swift

func exportWorkout(_ workout: Workout) -> Data? {
    // JSON Serialization (Codable)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    return try? encoder.encode(workout)
}

func importWorkout(from data: Data) -> Workout? {
    let decoder = JSONDecoder()
    return try? decoder.decode(Workout.self, from: data)
}
```

**Export-Format:** `.gymtracker` (JSON)

**Was wird exportiert:**
- ✅ Workout-Name, Notizen
- ✅ Exercise-Liste (über deterministische UUIDs)
- ✅ Sets (Reps, Weight, Rest Time)
- ❌ Session-History (nicht exportiert)
- ❌ Personal Records (nicht exportiert)

---

## Schwachstellen & Technical Debt

### 🔴 Kritisch (Must Fix für v2.0)

#### 1. WorkoutStore Monster-Datei (130KB)

**Problem:**
```swift
// WorkoutStore.swift - 130KB, 2000+ Zeilen
class WorkoutStore: ObservableObject {
    // Session Management
    // Rest Timer
    // Profile Management
    // HealthKit
    // Analytics Caching
    // Home Favorites
    // Exercise Operations
    // Workout CRUD
    // ... viel zu viel!
}
```

**Impact:**
- ❌ Schwer zu testen
- ❌ Merge Conflicts
- ❌ Langsame Compile-Zeit
- ❌ Violation of Single Responsibility

**Lösung v2.0:**
```swift
// Aufteilen in spezifische Stores:
SessionStore          // Session Lifecycle
ProfileStore          // User Profile
ExerciseStore         // Exercise Operations
StatisticsStore       // Analytics & Caching
HealthKitStore        // HealthKit Integration
```

#### 2. Profile in UserDefaults statt SwiftData

**Problem:**
```swift
// ProfileService.swift
func saveProfile(_ profile: UserProfile) {
    // ❌ UserDefaults statt SwiftData!
    if let data = try? encoder.encode(profile) {
        UserDefaults.standard.set(data, forKey: "userProfile")
    }
}
```

**Impact:**
- ❌ Inkonsistent mit restlicher Architektur
- ❌ Keine Relationship zu anderen Entities
- ❌ Schwer zu migrieren
- ❌ Keine automatische Backup-Integration

**Lösung v2.0:**
```swift
// Verwende existierende UserProfileEntity
@Query var userProfile: [UserProfileEntity]

// Service nur für Business Logic
class ProfileService {
    func updateProfile(in context: ModelContext) {
        // Update SwiftData Entity direkt
    }
}
```

#### 3. Manuelles Cache-Management

**Problem:**
```swift
// WorkoutAnalyticsService.swift
private var exerciseStatsCache: [UUID: ExerciseStats] = [:]

func invalidateExerciseCache(for exerciseId: UUID) {
    exerciseStatsCache.removeValue(forKey: exerciseId)
}

// ❌ Muss manuell aufgerufen werden!
// ❌ Wird oft vergessen
// ❌ Cache kann veralten
```

**Impact:**
- ❌ Stale Data in UI
- ❌ Fehleranfällig
- ❌ Performance-Regression wenn Cache fehlt

**Lösung v2.0:**
```swift
// Automatische Invalidierung via Combine
class StatisticsStore {
    @Published var sessionHistory: [WorkoutSession] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Auto-invalidate on session changes
        $sessionHistory
            .sink { [weak self] _ in
                self?.invalidateAllCaches()
            }
            .store(in: &cancellables)
    }
}
```

### 🟡 Mittel (Should Fix)

#### 4. Fehlende Transaktionen

**Problem:**
```swift
// Kein atomares Update
func updateWorkoutAndRecords(workout: Workout) {
    dataService.updateWorkout(workout)  // ✅ Erfolgreich
    // ... App crasht hier ...
    recordService.updateRecords()       // ❌ Nie ausgeführt
    // → Inkonsistenter State!
}
```

**Lösung v2.0:**
```swift
func updateWorkoutAndRecords(workout: Workout) throws {
    guard let context = modelContext else { throw Error.noContext }

    context.transaction {
        updateWorkout(workout, in: context)
        updateRecords(for: workout, in: context)
        // Entweder BEIDE erfolgreich oder ROLLBACK
    }
}
```

#### 5. Unvollständige HealthKit-Sync

**Problem:**
- ✅ Read: Weight, Height, BirthDate
- ❌ Write: Weight-Updates werden NICHT zurück geschrieben
- ❌ Keine automatische Sync bei HealthKit-Änderungen

**Lösung v2.0:**
```swift
// Observer für HealthKit Updates
class HealthKitSyncService {
    func startObserving() {
        // HKObserverQuery für Weight/Height
        // Bei Änderung: Update UserProfileEntity
    }
}
```

#### 6. Session-Recovery-Logik fragil

**Problem:**
```swift
// ContentView.swift - Session Recovery
if let storedID = UserDefaults.standard.string(forKey: "activeWorkoutID"),
   let uuid = UUID(uuidString: storedID) {

    // ⚠️ Was wenn Workout gelöscht wurde?
    // ⚠️ Was wenn Session zu alt ist?
    // ⚠️ Kein Timeout-Check

    workoutStore.activeSessionID = uuid
}
```

**Lösung v2.0:**
```swift
func recoverSession() {
    guard let storedID = UserDefaults.standard.string(...),
          let uuid = UUID(uuidString: storedID),
          let timestamp = UserDefaults.standard.object(forKey: "sessionStartTime") as? Date,
          Date().timeIntervalSince(timestamp) < 86400, // Max 24h alt
          workoutExists(uuid) else {
        clearStaleSession()
        return
    }

    workoutStore.activeSessionID = uuid
}
```

### 🟢 Nice to Have

#### 7. Fehlende Analytics Events

Keine Tracking-Events für:
- User Engagement (Workouts/Woche)
- Feature Usage (Wizard, Swap, etc.)
- Performance Metrics (Startup Zeit)
- Crash Reporting

#### 8. Keine Offline-First Strategie

Aktuell:
- ✅ Funktioniert offline
- ❌ Aber keine explizite Offline-Queue
- ❌ HealthKit Sync wartet nicht auf Network

#### 9. Fehlende Data Validation

```swift
// Kein Input Validation
func addExerciseSet(reps: Int, weight: Double) {
    // ❌ Was wenn reps < 0?
    // ❌ Was wenn weight > 1000kg?
    // ❌ Keine Business Rules
}
```

---

## Empfehlungen für v2.0

### 🎯 Architektur-Ziele

1. **Klare State-Ownership** - Jeder State hat genau einen Owner
2. **Automatische Invalidierung** - Keine manuellen Cache-Clears
3. **Transaktionale Operationen** - Atomicity garantiert
4. **Vollständige SwiftData-Migration** - Keine UserDefaults für Domain-Daten
5. **Testbare Services** - Dependency Injection everywhere
6. **Performance Monitoring** - Metrics für kritische Pfade

### 🏗️ Neue Architektur v2.0

```
┌──────────────────────────────────────────────────┐
│                  PRESENTATION                     │
│  SwiftUI Views (unverändert, nur kleinere Fixes) │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│              FEATURE STORES (NEU!)                │
│                                                   │
│  SessionStore         - Active Session           │
│  ProfileStore         - User Profile             │
│  ExerciseStore        - Exercise Catalog         │
│  StatisticsStore      - Analytics & Caching      │
│  HealthKitStore       - HealthKit Sync           │
│  RestTimerStore       - Rest Timer (migriert)    │
│                                                   │
│  ✅ Jeder Store hat genau eine Verantwortung     │
│  ✅ Testbar via Protocol Injection               │
│  ✅ Combine Publishers für reaktive Updates      │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│              BUSINESS LOGIC LAYER                 │
│                                                   │
│  Services (umgebaut):                             │
│  ├─ WorkoutService    - CRUD + Validation        │
│  ├─ AnalyticsService  - Auto-Invalidating Cache  │
│  ├─ SyncService       - HealthKit Bidirektional  │
│  ├─ BackupService     - Export/Import            │
│  └─ ValidationService - Input Validation (NEU!)  │
│                                                   │
│  Coordinators (behalten):                        │
│  - 9 Feature Coordinators unverändert            │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│              REPOSITORY LAYER (NEU!)              │
│                                                   │
│  Protocol-basierte Repositories:                 │
│                                                   │
│  protocol WorkoutRepository {                    │
│    func fetch(id: UUID) async throws -> Workout │
│    func save(_ workout: Workout) async throws   │
│    func delete(_ workout: Workout) async throws │
│  }                                               │
│                                                   │
│  SwiftDataWorkoutRepository (Implementierung)    │
│  ├─ Production: SwiftData                        │
│  └─ Testing: InMemoryRepository                  │
│                                                   │
│  ✅ Testbar ohne SwiftData-Container             │
│  ✅ Austauschbare Implementierungen              │
└─────────────────────┬────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────┐
│                  DATA LAYER                       │
│                                                   │
│  SwiftData (Primary Storage)                     │
│  ├─ All Domain Entities                          │
│  ├─ UserProfileEntity (migriert!)                │
│  └─ Automatic Schema Migration                   │
│                                                   │
│  UserDefaults (nur für Preferences)              │
│  ├─ App Settings (weeklyGoal, etc.)              │
│  ├─ RestTimerState (Recovery Only)               │
│  └─ Migration Versions                           │
│                                                   │
│  HealthKit (External Sync)                       │
│  ├─ Bidirektionale Sync (NEU!)                   │
│  └─ Background Observer (NEU!)                   │
└──────────────────────────────────────────────────┘
```

### 📋 Konkrete Änderungen

#### 1. WorkoutStore auflösen

```swift
// VORHER (v1.x)
class WorkoutStore: ObservableObject {
    // 2000+ Zeilen, alles gemischt
}

// NACHHER (v2.0)
class SessionStore: ObservableObject {
    @Published private(set) var activeSession: WorkoutSession?

    private let repository: WorkoutRepository
    private let healthKit: HealthKitStore

    init(repository: WorkoutRepository, healthKit: HealthKitStore) {
        self.repository = repository
        self.healthKit = healthKit
    }

    func startSession(workoutId: UUID) async throws {
        let workout = try await repository.fetch(id: workoutId)
        activeSession = WorkoutSession(from: workout)
        healthKit.startTracking(for: activeSession)
    }
}

class ProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile?

    private let repository: ProfileRepository

    func updateProfile(_ profile: UserProfile) async throws {
        try await repository.save(profile)
        self.profile = profile
    }
}
```

#### 2. Profile zu SwiftData migrieren

```swift
// Migration Script
func migrateProfileToSwiftData(context: ModelContext) {
    // 1. Lade aus UserDefaults
    guard let data = UserDefaults.standard.data(forKey: "userProfile"),
          let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
        return
    }

    // 2. Erstelle SwiftData Entity
    let entity = UserProfileEntity(
        name: profile.name,
        birthDate: profile.birthDate,
        // ... alle Properties
    )

    // 3. Speichere in SwiftData
    context.insert(entity)
    try? context.save()

    // 4. Lösche aus UserDefaults
    UserDefaults.standard.removeObject(forKey: "userProfile")

    print("✅ Profile migrated to SwiftData")
}
```

#### 3. Automatisches Cache-Management

```swift
class StatisticsStore: ObservableObject {
    @Published private(set) var statistics: SessionStatistics?

    private var cache: [CacheKey: CachedValue] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(sessionStore: SessionStore) {
        // Auto-invalidate on session changes
        sessionStore.$activeSession
            .dropFirst()
            .sink { [weak self] _ in
                self?.invalidateCache()
            }
            .store(in: &cancellables)
    }

    func fetchStatistics() async throws -> SessionStatistics {
        let key = CacheKey.statistics

        // Check cache
        if let cached = cache[key], !cached.isExpired {
            return cached.value
        }

        // Compute & cache
        let stats = try await computeStatistics()
        cache[key] = CachedValue(value: stats, ttl: 300) // 5min TTL
        return stats
    }
}
```

#### 4. Repository Pattern

```swift
protocol WorkoutRepository {
    func fetch(id: UUID) async throws -> Workout
    func fetchAll() async throws -> [Workout]
    func save(_ workout: Workout) async throws
    func delete(id: UUID) async throws
}

// Production Implementation
class SwiftDataWorkoutRepository: WorkoutRepository {
    private let context: ModelContext

    func fetch(id: UUID) async throws -> Workout {
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        return mapToWorkout(entity)
    }
}

// Test Implementation
class InMemoryWorkoutRepository: WorkoutRepository {
    private var storage: [UUID: Workout] = [:]

    func fetch(id: UUID) async throws -> Workout {
        guard let workout = storage[id] else {
            throw RepositoryError.notFound
        }
        return workout
    }
}
```

#### 5. Transaktionale Updates

```swift
class WorkoutService {
    private let repository: WorkoutRepository
    private let recordService: ExerciseRecordService

    func completeWorkout(_ workout: Workout) async throws {
        try await repository.transaction { context in
            // 1. Speichere Session
            let session = WorkoutSession(from: workout)
            try await repository.save(session)

            // 2. Update Personal Records
            try await recordService.updateRecords(for: workout)

            // 3. Sync zu HealthKit
            try await healthKitStore.exportSession(session)

            // Entweder ALLES erfolgreich oder ROLLBACK
        }
    }
}
```

#### 6. Input Validation

```swift
class ValidationService {
    enum ValidationError: Error {
        case invalidReps(Int)
        case invalidWeight(Double)
        case invalidDuration(TimeInterval)
    }

    func validate(exerciseSet: ExerciseSet) throws {
        // Reps: 1-100
        guard (1...100).contains(exerciseSet.reps) else {
            throw ValidationError.invalidReps(exerciseSet.reps)
        }

        // Weight: 0-500kg
        guard (0...500).contains(exerciseSet.weight) else {
            throw ValidationError.invalidWeight(exerciseSet.weight)
        }

        // Rest Time: 0-600s
        guard (0...600).contains(exerciseSet.restTime) else {
            throw ValidationError.invalidDuration(exerciseSet.restTime)
        }
    }
}
```

---

## Migrationsplan

### Phase 1: Refactoring (2-3 Wochen)

**Woche 1: WorkoutStore Split**
- [ ] Erstelle `SessionStore`
- [ ] Erstelle `ProfileStore`
- [ ] Erstelle `ExerciseStore`
- [ ] Erstelle `StatisticsStore`
- [ ] Migriere alle Funktionen
- [ ] Update Views zu neuen Stores

**Woche 2: Repository Pattern**
- [ ] Definiere Repository Protocols
- [ ] Implementiere SwiftData Repositories
- [ ] Implementiere InMemory Test Repositories
- [ ] Migriere Services zu Repositories
- [ ] Schreibe Unit Tests (Ziel: 60% Coverage)

**Woche 3: Profile Migration**
- [ ] Schreibe Migration Script
- [ ] Teste Migration auf Testgerät
- [ ] Deploy Migration in App
- [ ] Validiere UserDefaults leer
- [ ] Update ProfileStore zu SwiftData

### Phase 2: Improvements (2 Wochen)

**Woche 4: Cache & Validation**
- [ ] Implementiere Auto-Invalidating Cache
- [ ] Erstelle ValidationService
- [ ] Migriere Analytics zu neuem Cache
- [ ] Integration Testing

**Woche 5: HealthKit Sync**
- [ ] Implementiere Bidirektionale Sync
- [ ] HKObserverQuery für Background Updates
- [ ] Error Handling verbessern
- [ ] Timeout-Logik optimieren

### Phase 3: Testing & Deployment (1 Woche)

**Woche 6: QA & Release**
- [ ] Integration Tests (alle kritischen Pfade)
- [ ] Performance Testing (Startup < 2s)
- [ ] Migration Testing (alte → neue Daten)
- [ ] TestFlight Beta (100 User)
- [ ] Production Release v2.0

---

## Metriken & KPIs

### Performance-Ziele v2.0

| Metrik | v1.x | v2.0 Ziel |
|--------|------|-----------|
| App Startup | 3-5s | < 2s |
| Workout Start | 1-2s | < 500ms |
| Statistics Load | 2-3s | < 1s (cached) |
| SwiftData Fetch | Variable | < 100ms |
| Test Coverage | 15% | 60-70% |
| Compile Time | 45s | < 30s |

### Code-Qualität-Ziele

| Metrik | v1.x | v2.0 Ziel |
|--------|------|-----------|
| Größte Datei | 130KB | < 50KB |
| Durchschn. Datei | 15KB | < 10KB |
| Funktionen/Klasse | 30+ | < 15 |
| Zeilen/Funktion | 50+ | < 30 |
| Zyklomatische Komplexität | Hoch | Mittel |

---

## Zusammenfassung

### ✅ Was funktioniert gut

1. **SwiftData Integration** - Moderne Persistierung
2. **Rest Timer System** - Wall-Clock basiert, robust
3. **Live Activities** - Moderne iOS-Features
4. **Service-Architektur** - Gute Trennung
5. **Exercise Similarity** - Intelligenter Algorithmus
6. **Migration System** - Versionskontrolle vorhanden

### ❌ Was muss verbessert werden

1. **WorkoutStore** - Zu groß, aufteilen
2. **Profile Storage** - UserDefaults → SwiftData
3. **Cache Management** - Automatisch statt manuell
4. **Transaktionen** - Atomicity fehlt
5. **HealthKit Sync** - Unidirektional → Bidirektional
6. **Testing** - 15% → 60%+ Coverage

### 🎯 v2.0 Vision

Eine **saubere, testbare, performante** iOS-App mit:
- Feature-spezifischen Stores statt Monolith
- Repository Pattern für austauschbare Backends
- Automatischem Cache-Management
- Vollständiger SwiftData-Migration
- 60%+ Test-Coverage
- < 2s Startup-Zeit

**Geschätzte Entwicklungszeit:** 6 Wochen
**Breaking Changes:** Keine (Migration transparent)
**User Impact:** Bessere Performance, stabilere App

---

**Nächste Schritte:** Diskutiere Prioritäten und starte Phase 1 (WorkoutStore Split)
