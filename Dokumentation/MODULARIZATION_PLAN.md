# 🏗️ GymBo Modularization Plan

**Project:** GymBo (GymTracker) - iOS Fitness App  
**Start Date:** 2025-10-15  
**Estimated Duration:** 7-8 Wochen  
**Status:** 🟡 In Planning

---

## 📋 Executive Summary

### Current State
- **Total LOC:** 34,518 Zeilen
- **Kritische Dateien:** 4 Dateien mit >2000 Zeilen (10,948 LOC)
- **WorkoutStore:** 2,595 Zeilen (God Object)
- **View Coupling:** 29 Views abhängig von WorkoutStore
- **Test Coverage:** ~5%

### Target State
- **WorkoutStore → 9 Feature Coordinators** (je ~200 Zeilen)
- **Große Views aufgeteilt** (max 1000 Zeilen pro View)
- **Alle Services extrahiert** (klare Verantwortlichkeiten)
- **Test Coverage:** 80%+
- **Modular, wartbar, testbar**

---

## 🎯 Refactoring-Ziele

### Primäre Ziele
1. ✅ **Modularität:** Jede Komponente hat eine klare, einzige Verantwortlichkeit
2. ✅ **Wartbarkeit:** Dateien <1000 Zeilen, klare Struktur
3. ✅ **Testbarkeit:** Alle Business Logic unit-testbar
4. ✅ **Entkopplung:** Views nur von benötigten Coordinators abhängig
5. ✅ **Performance:** Kleinere View-Hierarchien, optimierte Speichernutzung

### Sekundäre Ziele
- Konsistente Architektur-Patterns
- Verbesserte Code-Dokumentation
- Einfacheres Onboarding für neue Entwickler
- Schnellere Kompilierungszeiten

---

## 📊 Phasen-Übersicht

| Phase | Dauer | Priorität | Fokus | LOC Reduktion |
|-------|-------|-----------|-------|---------------|
| **Phase 1** | Woche 1-2 | 🔴 Kritisch | Services extrahieren | -800 Zeilen |
| **Phase 2** | Woche 3-4 | 🔴 Kritisch | Coordinators erstellen | -1000 Zeilen |
| **Phase 3** | Woche 5-7 | 🟠 Hoch | Views aufteilen | -5800 Zeilen |
| **Phase 4** | Woche 8-10 | 🟠 Hoch | View Migration | -500 Zeilen |
| **Phase 5** | Woche 11-12 | 🟡 Mittel | Technical Debt | -600 Zeilen |
| **Phase 6** | Woche 13-14 | 🟡 Mittel | Testing & Docs | - |

**Gesamte LOC-Reduktion:** ~8,700 Zeilen (25% des Codes)

---

## 🔴 Phase 1: Services Extrahieren (Woche 1-2)

### Ziel
WorkoutStore von 2,595 auf ~1,800 Zeilen reduzieren durch Extraktion von Business Logic in Services.

### Status: 🟡 In Progress
- ✅ WorkoutAnalyticsService erstellt
- ✅ WorkoutDataService erstellt
- ✅ ProfileService erstellt
- ⬜ SessionManagementService fehlt
- ⬜ WorkoutSessionService fehlt (KRITISCH!)
- ⬜ ExerciseRecordService fehlt
- ⬜ HealthKitSyncService fehlt
- ⬜ WorkoutGenerationService fehlt

---

### Task 1.1: WorkoutSessionService erstellen/finden ⚠️ KRITISCH

**Problem:**
```swift
// WorkoutStore.swift:78
private let sessionService = WorkoutSessionService()
// ❌ WorkoutSessionService existiert nicht!
```

**Verwendung im Code:**
- L145: `sessionService.prepareSessionStart(for: workoutId)`
- L322: `sessionService.recordSession(session)`
- L403: `sessionService.removeSession(with: id)`

**Lösungsansatz:**
1. Suche nach inline/nested Definition in WorkoutStore
2. Falls nicht gefunden: Rekonstruiere aus Verwendung
3. Erstelle dedizierte Datei

**Datei:** `GymTracker/Services/WorkoutSessionService.swift`

**Geschätzte Größe:** ~200-250 Zeilen

**Interface (rekonstruiert):**
```swift
@MainActor
final class WorkoutSessionService {
    enum SessionError: Error {
        case missingModelContext
        case sessionNotFound
        case invalidWorkoutId
    }
    
    private var modelContext: ModelContext?
    
    func setContext(_ context: ModelContext?)
    
    func prepareSessionStart(for workoutId: UUID) throws -> WorkoutEntity?
    
    func recordSession(_ session: WorkoutSession) throws -> WorkoutSessionEntity
    
    func removeSession(with id: UUID) throws
    
    func getSession(with id: UUID) throws -> WorkoutSession?
    
    func getAllSessions(limit: Int) -> [WorkoutSession]
}
```

**Zeitaufwand:** 3-4 Stunden

---

### Task 1.2: SessionManagementService erstellen

**Verantwortlichkeit:**
- Active Session Lifecycle
- Session State Management
- Live Activity Integration
- Heart Rate Tracking Coordination

**Datei:** `GymTracker/Services/SessionManagementService.swift`

**Zu extrahierender Code aus WorkoutStore:**
- `startSession(for:)` (L144-159)
- `endCurrentSession()` (L161-175)
- `startHeartRateTracking(...)` (L2180-2219)
- `stopHeartRateTracking()` (L2221-2228)
- `activeSessionID` Property
- `heartRateTracker` Property

**Interface:**
```swift
@MainActor
final class SessionManagementService: ObservableObject {
    @Published var activeSessionID: UUID?
    
    private var heartRateTracker: HealthKitWorkoutTracker?
    private let dataService: WorkoutDataService
    private let healthKitManager: HealthKitManager
    private let liveActivityController: WorkoutLiveActivityController
    
    func startSession(for workoutId: UUID)
    func endSession()
    func pauseSession()
    func resumeSession()
    
    private func startHeartRateTracking(workoutId: UUID, workoutName: String)
    private func stopHeartRateTracking()
}
```

**Geschätzte Größe:** ~250-300 Zeilen

**Zeitaufwand:** 4-6 Stunden

---

### Task 1.3: ExerciseRecordService erstellen

**Verantwortlichkeit:**
- Personal Records (PRs) Management
- Record Tracking & Validation
- New Record Detection
- 1RM Calculations

**Datei:** `GymTracker/Services/ExerciseRecordService.swift`

**Zu extrahierender Code aus WorkoutStore:**
- `getExerciseRecord(for:)` (L674-702)
- `getAllExerciseRecords()` (L705-733)
- `checkForNewRecord(...)` (L736-746)

**Interface:**
```swift
@MainActor
final class ExerciseRecordService {
    private var modelContext: ModelContext?
    
    func setContext(_ context: ModelContext?)
    
    func getRecord(for exercise: Exercise) -> ExerciseRecord?
    func getAllRecords() -> [ExerciseRecord]
    func checkForNewRecord(exercise: Exercise, weight: Double, reps: Int) -> RecordType?
    func updateRecord(for exercise: Exercise, weight: Double, reps: Int, date: Date) throws
    func estimateOneRepMax(weight: Double, reps: Int) -> Double
}
```

**Geschätzte Größe:** ~200-250 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 1.4: HealthKitSyncService erstellen

**Verantwortlichkeit:**
- HealthKit Authorization
- Data Import/Export
- Profile Sync
- Workout Sync

**Datei:** `GymTracker/Services/HealthKitSyncService.swift`

**Zu extrahierender Code aus WorkoutStore:**
- `requestHealthKitAuthorization()` (L487-495)
- `importFromHealthKit()` (L497-563)
- `saveWorkoutToHealthKit(_:)` (L565-575)
- `readHeartRateData(...)` (L577-585)
- `readWeightData(...)` (L587-594)
- `readBodyFatData(...)` (L596-602)

**Interface:**
```swift
@MainActor
final class HealthKitSyncService {
    private let healthKitManager: HealthKitManager
    private let profileService: ProfileService
    private var modelContext: ModelContext?
    
    func setContext(_ context: ModelContext?)
    
    func requestAuthorization() async throws
    func importProfile() async throws
    func saveWorkout(_ session: WorkoutSession) async throws
    func readHeartRateData(from: Date, to: Date) async throws -> [HeartRateReading]
    func readWeightData(from: Date, to: Date) async throws -> [BodyWeightReading]
    func readBodyFatData(from: Date, to: Date) async throws -> [BodyFatReading]
}
```

**Geschätzte Größe:** ~200-250 Zeilen

**Zeitaufwand:** 4-5 Stunden

---

### Task 1.5: WorkoutGenerationService erstellen

**Verantwortlichkeit:**
- Workout Wizard Logic
- Exercise Selection Algorithm
- Set/Rep Calculations
- Workout Naming & Notes

**Datei:** `GymTracker/Services/WorkoutGenerationService.swift`

**Zu extrahierender Code aus WorkoutStore:**
- `generateWorkout(from:)` (L1872-1886)
- `selectMuscleGroups(for:)` (L1888-1903)
- `selectExercises(...)` (L1905-1994)
- `filterExercisesByDifficulty(...)` (L1998-2014)
- `filterExercisesByEquipment(...)` (L2016-2033)
- `matchesDifficultyLevel(...)` (L2040-2054)
- `calculateExerciseCount(for:)` (L2056-2074)
- `createWorkoutExercises(...)` (L2076-2090)
- `calculateSetCount(...)` (L2092-2102)
- `calculateReps(...)` (L2104-2117)
- `calculateRestTime(for:)` (L2119-2132)
- `generateWorkoutName(for:)` (L2134-2152)
- `generateWorkoutNotes(for:)` (L2154-2176)

**Interface:**
```swift
@MainActor
final class WorkoutGenerationService {
    private let dataService: WorkoutDataService
    
    func generateWorkout(from preferences: WorkoutPreferences) -> Workout
    
    // Private helper methods
    private func selectMuscleGroups(for preferences: WorkoutPreferences) -> [MuscleGroup]
    private func selectExercises(for preferences: WorkoutPreferences, 
                                 targeting: [MuscleGroup], 
                                 from: [Exercise]) -> [Exercise]
    private func filterByDifficulty(_ exercises: [Exercise], 
                                    for level: ExperienceLevel) -> [Exercise]
    private func filterByEquipment(_ preference: EquipmentPreference, 
                                   from: [Exercise]) -> [Exercise]
    private func calculateExerciseCount(for preferences: WorkoutPreferences) -> Int
    private func calculateSetCount(for exercise: Exercise, 
                                   preferences: WorkoutPreferences) -> Int
    private func calculateReps(for exercise: Exercise, 
                              preferences: WorkoutPreferences) -> Int
    private func calculateRestTime(for preferences: WorkoutPreferences) -> Double
    private func generateWorkoutName(for preferences: WorkoutPreferences) -> String
    private func generateWorkoutNotes(for preferences: WorkoutPreferences) -> String
}
```

**Geschätzte Größe:** ~350-400 Zeilen

**Zeitaufwand:** 5-6 Stunden

---

### Task 1.6: LastUsedMetricsService erstellen

**Verantwortlichkeit:**
- Last-Used Exercise Metrics
- Metric Caching
- Legacy Fallback Logic

**Datei:** `GymTracker/Services/LastUsedMetricsService.swift`

**Zu extrahierender Code aus WorkoutStore:**
- `lastMetrics(for:)` (L238-254)
- `completeLastMetrics(for:)` (L257-273)
- `legacyLastMetrics(for:)` (L276-291)
- `updateLastUsedMetrics(from:)` (L362-403)
- `ExerciseLastUsedMetrics` struct (L14-53)

**Interface:**
```swift
struct ExerciseLastUsedMetrics {
    let weight: Double?
    let reps: Int?
    let setCount: Int?
    let lastUsedDate: Date?
    let restTime: TimeInterval?
    
    var hasData: Bool
    var displayText: String
    var detailedDisplayText: String
}

@MainActor
final class LastUsedMetricsService {
    private var modelContext: ModelContext?
    
    func setContext(_ context: ModelContext?)
    
    func getLastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)?
    func getCompleteMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics?
    func updateMetrics(from session: WorkoutSession)
    
    private func legacyFallback(for exercise: Exercise) -> (weight: Double, setCount: Int)?
}
```

**Geschätzte Größe:** ~150-200 Zeilen

**Zeitaufwand:** 2-3 Stunden

---

### Task 1.7: WorkoutStore aufräumen

**Nach Extraktion aller Services:**

**Entfernen aus WorkoutStore:**
- Session Management Code (~300 Zeilen)
- HealthKit Integration (~150 Zeilen)
- Workout Generation (~350 Zeilen)
- Exercise Records (~100 Zeilen)
- Last-Used Metrics (~150 Zeilen)

**Verbleibend in WorkoutStore:**
- Service Koordination
- Published Properties
- Context Management
- Backward Compatibility Layer

**Ziel-Größe:** ~1,800 Zeilen (von 2,595)

**Zeitaufwand:** 4-6 Stunden

---

### Phase 1: Deliverables

✅ **Neue Dateien:**
1. `Services/WorkoutSessionService.swift` (~250 Zeilen)
2. `Services/SessionManagementService.swift` (~300 Zeilen)
3. `Services/ExerciseRecordService.swift` (~200 Zeilen)
4. `Services/HealthKitSyncService.swift` (~250 Zeilen)
5. `Services/WorkoutGenerationService.swift` (~400 Zeilen)
6. `Services/LastUsedMetricsService.swift` (~200 Zeilen)

✅ **Aktualisierte Dateien:**
- `ViewModels/WorkoutStore.swift` (2,595 → ~1,800 Zeilen)

✅ **Tests:**
- Unit Tests für alle 6 neuen Services
- Integration Tests für Service-Zusammenspiel

✅ **Dokumentation:**
- Service-Dokumentation in CLAUDE.md
- API-Dokumentation mit SwiftDoc

**Zeitaufwand Phase 1:** 25-35 Stunden (2 Wochen)

---

## 🔴 Phase 2: Feature Coordinators (Woche 3-4)

### Ziel
Ersetze WorkoutStore God Object durch 9 spezialisierte Feature Coordinators.

### Architektur-Konzept

**Aktuell:**
```
Views → WorkoutStore (2,595 Zeilen)
          └── Services
```

**Ziel:**
```
Views → Specific Coordinator (~200 Zeilen each)
          └── Services
```

### Status: ⬜ Not Started

---

### Task 2.1: SessionCoordinator erstellen

**Verantwortlichkeit:**
- Active Session State
- Session Lifecycle Management
- View Integration für Session Views

**Datei:** `GymTracker/Coordinators/SessionCoordinator.swift`

**Interface:**
```swift
@MainActor
final class SessionCoordinator: ObservableObject {
    // Published State
    @Published var activeSessionID: UUID?
    @Published var isShowingWorkoutDetail: Bool = false
    
    // Dependencies
    private let sessionManagementService: SessionManagementService
    private let sessionService: WorkoutSessionService
    private let dataService: WorkoutDataService
    private let liveActivityController: WorkoutLiveActivityController
    
    // Public API
    func startSession(for workoutId: UUID)
    func endSession()
    func pauseSession()
    func resumeSession()
    
    // Computed Properties
    var activeWorkout: Workout? { get }
    var isSessionActive: Bool { get }
}
```

**Verwendende Views:**
- WorkoutDetailView
- WorkoutsHomeView
- ContentView

**Geschätzte Größe:** ~200-250 Zeilen

**Zeitaufwand:** 4-5 Stunden

---

### Task 2.2: ProfileCoordinator erstellen

**Verantwortlichkeit:**
- User Profile State
- Profile Updates
- Onboarding State
- HealthKit Profile Sync

**Datei:** `GymTracker/Coordinators/ProfileCoordinator.swift`

**Interface:**
```swift
@MainActor
final class ProfileCoordinator: ObservableObject {
    // Published State
    @Published var profile: UserProfile
    @Published var profileUpdateTrigger: UUID = UUID()
    
    // Dependencies
    private let profileService: ProfileService
    private let healthKitSyncService: HealthKitSyncService
    
    // Public API
    func updateProfile(name: String, birthDate: Date?, weight: Double?, 
                      height: Double?, biologicalSex: HKBiologicalSex?,
                      goal: FitnessGoal, experience: ExperienceLevel,
                      equipment: EquipmentPreference, 
                      preferredDuration: WorkoutDuration,
                      healthKitSyncEnabled: Bool, profileImageData: Data?)
    
    func updateProfileImage(_ image: UIImage?)
    func updateLockerNumber(_ lockerNumber: String)
    func markOnboardingStep(hasExploredWorkouts: Bool?, 
                           hasCreatedFirstWorkout: Bool?,
                           hasSetupProfile: Bool?)
    
    func requestHealthKitAuthorization() async throws
    func importFromHealthKit() async throws
}
```

**Verwendende Views:**
- ProfileView
- ProfileEditView
- SettingsView
- WorkoutWizardView

**Geschätzte Größe:** ~200-250 Zeilen

**Zeitaufwand:** 4-5 Stunden

---

### Task 2.3: WorkoutCoordinator erstellen

**Verantwortlichkeit:**
- Workout CRUD Operations
- Workout Favorites
- Workout Generation
- Session Recording

**Datei:** `GymTracker/Coordinators/WorkoutCoordinator.swift`

**Interface:**
```swift
@MainActor
final class WorkoutCoordinator: ObservableObject {
    // Published State
    @Published var workouts: [Workout] = []
    @Published var homeWorkouts: [Workout] = []
    
    // Dependencies
    private let dataService: WorkoutDataService
    private let generationService: WorkoutGenerationService
    private let sessionService: WorkoutSessionService
    private let analyticsService: WorkoutAnalyticsService
    
    var modelContext: ModelContext? {
        didSet {
            dataService.setContext(modelContext)
            sessionService.setContext(modelContext)
            analyticsService.setContext(modelContext)
        }
    }
    
    // Public API - CRUD
    func addWorkout(_ workout: Workout)
    func updateWorkout(_ workout: Workout)
    func deleteWorkout(at indexSet: IndexSet)
    
    // Favorites
    func toggleFavorite(for workoutID: UUID)
    func toggleHomeFavorite(workoutID: UUID) -> Bool
    
    // Generation
    func generateWorkout(from preferences: WorkoutPreferences) -> Workout
    
    // Session Recording
    func recordSession(from workout: Workout)
    func removeSession(with id: UUID)
    
    // Queries
    func previousWorkout(before workout: Workout) -> Workout?
    func getSessionHistory(limit: Int) -> [WorkoutSession]
}
```

**Verwendende Views:**
- WorkoutsView
- WorkoutsHomeView
- WorkoutDetailView
- EditWorkoutView
- AddWorkoutView
- WorkoutWizardView

**Geschätzte Größe:** ~300-350 Zeilen

**Zeitaufwand:** 5-6 Stunden

---

### Task 2.4: ExerciseCoordinator erstellen

**Verantwortlichkeit:**
- Exercise CRUD Operations
- Exercise Search & Filtering
- Similar Exercise Matching
- Last-Used Metrics

**Datei:** `GymTracker/Coordinators/ExerciseCoordinator.swift`

**Interface:**
```swift
@MainActor
final class ExerciseCoordinator: ObservableObject {
    // Published State
    @Published var exercises: [Exercise] = []
    
    // Dependencies
    private let dataService: WorkoutDataService
    private let metricsService: LastUsedMetricsService
    
    var modelContext: ModelContext? {
        didSet {
            dataService.setContext(modelContext)
            metricsService.setContext(modelContext)
        }
    }
    
    // Public API - CRUD
    func addExercise(_ exercise: Exercise)
    func updateExercise(_ exercise: Exercise)
    func deleteExercise(at indexSet: IndexSet)
    
    // Search & Filtering
    func exercise(named name: String) -> Exercise
    func getSimilarExercises(to exercise: Exercise, 
                            count: Int, 
                            userLevel: ExperienceLevel?) -> [Exercise]
    
    // Metrics
    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)?
    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics?
}
```

**Verwendende Views:**
- ExercisesView
- AddExerciseView
- ExerciseSwapView
- EditWorkoutView
- WorkoutDetailView

**Geschätzte Größe:** ~200-250 Zeilen

**Zeitaufwand:** 4-5 Stunden

---

### Task 2.5: RecordCoordinator erstellen

**Verantwortlichkeit:**
- Personal Records Management
- New Record Detection
- Record Display & Formatting

**Datei:** `GymTracker/Coordinators/RecordCoordinator.swift`

**Interface:**
```swift
@MainActor
final class RecordCoordinator: ObservableObject {
    // Published State
    @Published var recentRecords: [ExerciseRecord] = []
    
    // Dependencies
    private let recordService: ExerciseRecordService
    
    var modelContext: ModelContext? {
        didSet {
            recordService.setContext(modelContext)
        }
    }
    
    // Public API
    func getRecord(for exercise: Exercise) -> ExerciseRecord?
    func getAllRecords() -> [ExerciseRecord]
    func checkForNewRecord(exercise: Exercise, weight: Double, reps: Int) -> RecordType?
    func updateRecord(for exercise: Exercise, weight: Double, reps: Int, date: Date) throws
    
    // Formatting
    func formattedRecord(_ record: ExerciseRecord) -> String
    func recordBadge(_ recordType: RecordType) -> String
}
```

**Verwendende Views:**
- StatisticsView
- TopPRsCard
- WorkoutDetailView

**Geschätzte Größe:** ~150-200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 2.6: AnalyticsCoordinator erstellen

**Verantwortlichkeit:**
- Analytics Data Aggregation
- Statistics Calculations
- Performance Metrics
- Charts Data

**Datei:** `GymTracker/Coordinators/AnalyticsCoordinator.swift`

**Interface:**
```swift
@MainActor
final class AnalyticsCoordinator: ObservableObject {
    // Published State
    @Published var weeklyStats: WeeklyStats?
    @Published var progressionScore: ProgressionScore?
    
    // Dependencies
    private let analyticsService: WorkoutAnalyticsService
    private let analyzer: WorkoutAnalyzer
    
    typealias ExerciseStats = WorkoutAnalyticsService.ExerciseStats
    
    var modelContext: ModelContext? {
        didSet {
            analyticsService.setContext(modelContext)
        }
    }
    
    // Public API
    var totalWorkoutCount: Int { get }
    var averageWorkoutsPerWeek: Double { get }
    var currentWeekStreak: Int { get }
    var averageDurationMinutes: Int { get }
    
    func muscleVolume(byGroupInLastWeeks weeks: Int) -> [(MuscleGroup, Double)]
    func exerciseStats(for exercise: Exercise) -> ExerciseStats?
    func workoutsByDay(in range: ClosedRange<Date>) -> [Date: [WorkoutSession]]
    
    // Cache Management
    func invalidateCaches()
}
```

**Verwendende Views:**
- StatisticsView
- All Statistics Cards
- WorkoutsHomeView

**Geschätzte Größe:** ~200-250 Zeilen

**Zeitaufwand:** 4-5 Stunden

---

### Task 2.7: HealthKitCoordinator erstellen

**Verantwortlichkeit:**
- HealthKit Authorization State
- HealthKit Sync Orchestration
- Profile Import/Export

**Datei:** `GymTracker/Coordinators/HealthKitCoordinator.swift`

**Interface:**
```swift
@MainActor
final class HealthKitCoordinator: ObservableObject {
    // Published State
    @Published var isAuthorized: Bool = false
    @Published var syncInProgress: Bool = false
    
    // Dependencies
    private let healthKitManager: HealthKitManager
    private let syncService: HealthKitSyncService
    private let profileCoordinator: ProfileCoordinator
    
    // Public API
    func requestAuthorization() async throws
    func importProfile() async throws
    func exportWorkout(_ session: WorkoutSession) async throws
    
    func readHeartRateData(from: Date, to: Date) async throws -> [HeartRateReading]
    func readWeightData(from: Date, to: Date) async throws -> [BodyWeightReading]
    func readBodyFatData(from: Date, to: Date) async throws -> [BodyFatReading]
}
```

**Verwendende Views:**
- ProfileEditView
- HealthKitSetupView
- SettingsView

**Geschätzte Größe:** ~150-200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 2.8: RestTimerCoordinator erstellen

**Verantwortlichkeit:**
- Rest Timer State Orchestration
- Notification Coordination
- Live Activity Updates
- In-App Overlay Management

**Datei:** `GymTracker/Coordinators/RestTimerCoordinator.swift`

**Interface:**
```swift
@MainActor
final class RestTimerCoordinator: ObservableObject {
    // Published State (delegiert von RestTimerStateManager)
    var currentState: RestTimerState? { stateManager.currentState }
    
    // Dependencies
    private let stateManager: RestTimerStateManager
    private let notificationManager: NotificationManager
    private let overlayManager: InAppOverlayManager?
    
    // Public API
    func startRest(for workout: Workout, 
                   exerciseIndex: Int, 
                   setIndex: Int, 
                   totalSeconds: Int)
    
    func pauseRest()
    func resumeRest()
    func addRest(seconds: Int)
    func setRest(remaining: Int, total: Int?)
    func stopRest()
    func acknowledgeExpired()
    
    func updateHeartRate(_ heartRate: Int)
}
```

**Verwendende Views:**
- WorkoutDetailView
- RestTimerExpiredOverlay
- ContentView (Deep Links)

**Geschätzte Größe:** ~200-250 Zeilen

**Zeitaufwand:** 4-5 Stunden

---

### Task 2.9: CacheCoordinator erstellen

**Verantwortlichkeit:**
- Unified Cache Management
- Cache Invalidation Strategy
- Memory Management

**Datei:** `GymTracker/Coordinators/CacheCoordinator.swift`

**Interface:**
```swift
@MainActor
final class CacheCoordinator: ObservableObject {
    // Dependencies
    private let analyticsService: WorkoutAnalyticsService
    private let metricsService: LastUsedMetricsService
    private let statisticsCache: StatisticsCache
    
    // Public API
    func invalidateAll()
    func invalidateExerciseCache(for exerciseId: UUID)
    func invalidateAnalytics()
    func invalidateMetrics()
    
    func performMemoryCleanup()
    
    // Cache Statistics
    var cacheHitRate: Double { get }
    var cachedItemsCount: Int { get }
}
```

**Verwendende Views:**
- Alle Views (indirekt)
- DebugMenuView (Cache-Statistiken)

**Geschätzte Größe:** ~100-150 Zeilen

**Zeitaufwand:** 2-3 Stunden

---

### Task 2.10: CoordinatorFactory erstellen

**Verantwortlichkeit:**
- Coordinator Lifecycle Management
- Dependency Injection
- Singleton Pattern für Coordinators

**Datei:** `GymTracker/Coordinators/CoordinatorFactory.swift`

**Interface:**
```swift
@MainActor
final class CoordinatorFactory {
    static let shared = CoordinatorFactory()
    
    // Coordinators
    lazy var sessionCoordinator: SessionCoordinator = makeSessionCoordinator()
    lazy var profileCoordinator: ProfileCoordinator = makeProfileCoordinator()
    lazy var workoutCoordinator: WorkoutCoordinator = makeWorkoutCoordinator()
    lazy var exerciseCoordinator: ExerciseCoordinator = makeExerciseCoordinator()
    lazy var recordCoordinator: RecordCoordinator = makeRecordCoordinator()
    lazy var analyticsCoordinator: AnalyticsCoordinator = makeAnalyticsCoordinator()
    lazy var healthKitCoordinator: HealthKitCoordinator = makeHealthKitCoordinator()
    lazy var restTimerCoordinator: RestTimerCoordinator = makeRestTimerCoordinator()
    lazy var cacheCoordinator: CacheCoordinator = makeCacheCoordinator()
    
    // Context Management
    func setModelContext(_ context: ModelContext?)
    
    // Factory Methods (private)
    private func makeSessionCoordinator() -> SessionCoordinator
    private func makeProfileCoordinator() -> ProfileCoordinator
    // ... etc
}
```

**Geschätzte Größe:** ~150-200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 2.11: WorkoutStoreCoordinator migrieren

**Aktueller Status:**
- WorkoutStoreCoordinator ist Wrapper um WorkoutStore
- Verwendet für Backward Compatibility

**Neue Implementierung:**
- Coordinator orchestriert alle Feature Coordinators
- Delegiert an spezifische Coordinators
- Erhält Published Properties von Coordinators

**Aktualisierte Datei:** `GymTracker/ViewModels/WorkoutStore.swift`

**Interface:**
```swift
@MainActor
class WorkoutStoreCoordinator: ObservableObject {
    // Feature Coordinators
    private let sessionCoordinator: SessionCoordinator
    private let profileCoordinator: ProfileCoordinator
    private let workoutCoordinator: WorkoutCoordinator
    private let exerciseCoordinator: ExerciseCoordinator
    private let recordCoordinator: RecordCoordinator
    private let analyticsCoordinator: AnalyticsCoordinator
    private let healthKitCoordinator: HealthKitCoordinator
    private let restTimerCoordinator: RestTimerCoordinator
    private let cacheCoordinator: CacheCoordinator
    
    // Published Properties (synced from coordinators)
    @Published var activeSessionID: UUID?
    @Published var profile: UserProfile
    @Published var workouts: [Workout]
    // ... etc
    
    init() {
        // Initialize coordinators via factory
        // Setup Combine subscriptions to sync state
    }
    
    // Facade Methods (delegate to coordinators)
    func startSession(for workoutId: UUID) {
        sessionCoordinator.startSession(for: workoutId)
    }
    // ... etc
}
```

**Zeitaufwand:** 6-8 Stunden

---

### Phase 2: Deliverables

✅ **Neue Dateien:**
1. `Coordinators/SessionCoordinator.swift` (~250 Zeilen)
2. `Coordinators/ProfileCoordinator.swift` (~250 Zeilen)
3. `Coordinators/WorkoutCoordinator.swift` (~350 Zeilen)
4. `Coordinators/ExerciseCoordinator.swift` (~250 Zeilen)
5. `Coordinators/RecordCoordinator.swift` (~200 Zeilen)
6. `Coordinators/AnalyticsCoordinator.swift` (~250 Zeilen)
7. `Coordinators/HealthKitCoordinator.swift` (~200 Zeilen)
8. `Coordinators/RestTimerCoordinator.swift` (~250 Zeilen)
9. `Coordinators/CacheCoordinator.swift` (~150 Zeilen)
10. `Coordinators/CoordinatorFactory.swift` (~200 Zeilen)

**Total:** 2,350 Zeilen (organisiert in 10 Dateien)

✅ **Aktualisierte Dateien:**
- `ViewModels/WorkoutStore.swift` (1,800 → ~500 Zeilen)
- CLAUDE.md (Architektur-Update)

✅ **Tests:**
- Unit Tests für alle 9 Coordinators
- Integration Tests für Coordinator-Zusammenspiel
- Mock-Implementierungen für Testing

**Zeitaufwand Phase 2:** 38-48 Stunden (2 Wochen)

---

## 🟠 Phase 3: Views Aufteilen (Woche 5-7)

### Ziel
Alle großen Views (<1000 Zeilen) durch Extraktion von Komponenten modularisieren.

### Status: ⬜ Not Started

---

## Woche 5: StatisticsView (3,159 → ~1,000 Zeilen)

### Task 3.1: FloatingInsightsHeader extrahieren

**Datei:** `GymTracker/Views/Statistics/FloatingInsightsHeader.swift`

**Komponente:**
- Floating Header mit Glassmorphism
- Workout Count, PRs, Streak
- Animations

**Geschätzte Größe:** ~150 Zeilen

**Zeitaufwand:** 2-3 Stunden

---

### Task 3.2: HeroStreakCard extrahieren

**Datei:** `GymTracker/Views/Statistics/HeroStreakCard.swift`

**Komponente:**
- Hero Card mit Streak-Animation
- Streak-Berechnung
- Motivations-Texte

**Geschätzte Größe:** ~200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 3.3: QuickStatsGrid extrahieren

**Datei:** `GymTracker/Views/Statistics/QuickStatsGrid.swift`

**Komponente:**
- 2x2 Grid mit Quick Stats
- Verschiedene Stat-Types
- Animationen

**Geschätzte Größe:** ~250 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 3.4: VolumeChartCard extrahieren

**Datei:** `GymTracker/Views/Statistics/VolumeChartCard.swift`

**Komponente:**
- Volume Chart mit Zeitreihen
- Chart Interactions
- Zeitraum-Selektor

**Geschätzte Größe:** ~300 Zeilen

**Zeitaufwand:** 4-5 Stunden

---

### Task 3.5: PersonalRecordsCard extrahieren

**Datei:** `GymTracker/Views/Statistics/PersonalRecordsCard.swift`

**Komponente:**
- Liste aller PRs
- Sortierung & Filterung
- Record-Details

**Geschätzte Größe:** ~200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 3.6: StatisticsCalendarOverlay extrahieren

**Datei:** `GymTracker/Views/Statistics/StatisticsCalendarOverlay.swift`

**Komponente:**
- Kalender-Overlay
- Workout-Historie
- Date Selection

**Geschätzte Größe:** ~150 Zeilen

**Zeitaufwand:** 2-3 Stunden

---

### Task 3.7: StatisticsView aufräumen

**Nach Extraktion:**

**Verbleibend in StatisticsView:**
- ScrollView Container
- Coordinator-Binding
- Tab-Logik
- Navigation

**Ziel-Größe:** ~1,000 Zeilen (von 3,159)

**Zeitaufwand:** 3-4 Stunden

---

## Woche 6: ContentView (2,650 → ~800 Zeilen)

### Task 3.8: HomeTabView extrahieren

**Datei:** `GymTracker/Views/Home/HomeTabView.swift`

**Komponente:**
- Komplettes Home-Tab
- Active Workout Card
- Favorites Grid
- Weekly Progress
- Quick Actions

**Geschätzte Größe:** ~600 Zeilen

**Zeitaufwand:** 6-8 Stunden

---

### Task 3.9: ActiveWorkoutCard extrahieren

**Datei:** `GymTracker/Views/Home/ActiveWorkoutCard.swift`

**Komponente:**
- Active Workout Display
- Resume/Continue Button
- Progress Indicator

**Geschätzte Größe:** ~200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 3.10: FavoriteWorkoutsGrid extrahieren

**Datei:** `GymTracker/Views/Home/FavoriteWorkoutsGrid.swift`

**Komponente:**
- 2x2 Grid mit Favoriten
- Add Button (wenn <4)
- Limit-Logik

**Geschätzte Größe:** ~300 Zeilen

**Zeitaufwand:** 4-5 Stunden

---

### Task 3.11: WeeklyProgressCard extrahieren

**Datei:** `GymTracker/Views/Home/WeeklyProgressCard.swift`

**Komponente:**
- Weekly Progress Anzeige
- Goal Tracking
- Mini-Chart

**Geschätzte Größe:** ~200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 3.12: QuickActionsBar extrahieren

**Datei:** `GymTracker/Views/Home/QuickActionsBar.swift`

**Komponente:**
- Quick Action Buttons
- Shortcuts
- Icons

**Geschätzte Größe:** ~150 Zeilen

**Zeitaufwand:** 2-3 Stunden

---

### Task 3.13: ContentView aufräumen

**Nach Extraktion:**

**Verbleibend in ContentView:**
- TabView Container
- Tab Selection State
- Coordinator Injection
- Deep Link Handling
- Notification Handling

**Ziel-Größe:** ~800 Zeilen (von 2,650)

**Zeitaufwand:** 4-5 Stunden

---

## Woche 7: WorkoutDetailView (2,544 → ~800 Zeilen)

### Task 3.14: WorkoutSessionHeader extrahieren

**Datei:** `GymTracker/Views/WorkoutDetail/WorkoutSessionHeader.swift`

**Komponente:**
- Workout Name & Info
- Timer Display
- Action Buttons
- Navigation

**Geschätzte Größe:** ~200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 3.15: ExerciseListSection extrahieren

**Datei:** `GymTracker/Views/WorkoutDetail/ExerciseListSection.swift`

**Komponente:**
- Liste aller Exercises
- Drag & Drop
- Add/Remove
- ExerciseCard Integration

**Geschätzte Größe:** ~800 Zeilen

**Zeitaufwand:** 8-10 Stunden

**Sub-Komponenten (bereits vorhanden):**
- ExerciseCard.swift (~300 Zeilen)
- SetRow.swift (~150 Zeilen)

---

### Task 3.16: WorkoutProgressTab extrahieren

**Datei:** `GymTracker/Views/WorkoutDetail/WorkoutProgressTab.swift`

**Komponente:**
- Progress Tab Content
- Charts
- Statistics
- Comparisons

**Geschätzte Größe:** ~400 Zeilen

**Zeitaufwand:** 5-6 Stunden

---

### Task 3.17: WorkoutCompletionSheet extrahieren

**Datei:** `GymTracker/Views/WorkoutDetail/WorkoutCompletionSheet.swift`

**Komponente:**
- Completion Sheet
- Summary
- Celebration
- Actions

**Geschätzte Größe:** ~200 Zeilen

**Zeitaufwand:** 3-4 Stunden

---

### Task 3.18: WorkoutDetailView aufräumen

**Nach Extraktion:**

**Verbleibend in WorkoutDetailView:**
- Main Container
- Tab Navigation
- State Management
- Coordinator Binding

**Ziel-Größe:** ~800 Zeilen (von 2,544)

**Zeitaufwand:** 4-5 Stunden

---

### Phase 3: Deliverables

✅ **Neue Komponenten (20 Dateien):**

**Statistics Components (6 Dateien):**
1. `Views/Statistics/FloatingInsightsHeader.swift` (~150 Zeilen)
2. `Views/Statistics/HeroStreakCard.swift` (~200 Zeilen)
3. `Views/Statistics/QuickStatsGrid.swift` (~250 Zeilen)
4. `Views/Statistics/VolumeChartCard.swift` (~300 Zeilen)
5. `Views/Statistics/PersonalRecordsCard.swift` (~200 Zeilen)
6. `Views/Statistics/StatisticsCalendarOverlay.swift` (~150 Zeilen)

**Home Components (5 Dateien):**
7. `Views/Home/HomeTabView.swift` (~600 Zeilen)
8. `Views/Home/ActiveWorkoutCard.swift` (~200 Zeilen)
9. `Views/Home/FavoriteWorkoutsGrid.swift` (~300 Zeilen)
10. `Views/Home/WeeklyProgressCard.swift` (~200 Zeilen)
11. `Views/Home/QuickActionsBar.swift` (~150 Zeilen)

**WorkoutDetail Components (4 Dateien):**
12. `Views/WorkoutDetail/WorkoutSessionHeader.swift` (~200 Zeilen)
13. `Views/WorkoutDetail/ExerciseListSection.swift` (~800 Zeilen)
14. `Views/WorkoutDetail/WorkoutProgressTab.swift` (~400 Zeilen)
15. `Views/WorkoutDetail/WorkoutCompletionSheet.swift` (~200 Zeilen)

**ExerciseListSection Sub-Components (bereits vorhanden):**
16. `Views/WorkoutDetail/ExerciseCard.swift` (~300 Zeilen)
17. `Views/WorkoutDetail/SetRow.swift` (~150 Zeilen)

**Additional Components (aus anderen Views):**
18. `Views/Settings/ProfileSection.swift` (~300 Zeilen)
19. `Views/Settings/DataManagementSection.swift` (~200 Zeilen)
20. `Views/Settings/AboutSection.swift` (~100 Zeilen)

**Total:** 5,250 Zeilen in 20 Dateien

✅ **Aktualisierte Container-Views (3 Dateien):**
- `Views/StatisticsView.swift` (3,159 → ~1,000 Zeilen)
- `ContentView.swift` (2,650 → ~800 Zeilen)
- `Views/WorkoutDetailView.swift` (2,544 → ~800 Zeilen)

**Reduktion:** 8,353 → 2,600 Zeilen (5,753 Zeilen extrahiert)

✅ **Tests:**
- UI Tests für neue Komponenten
- Preview Tests für alle Komponenten
- Integration Tests für Container-Views

**Zeitaufwand Phase 3:** 60-75 Stunden (3 Wochen)

---

## 🟠 Phase 4: View Migration (Woche 8-10)

### Ziel
Alle Views von WorkoutStore auf spezifische Coordinators migrieren.

### Status: ⬜ Not Started

---

### Task 4.1: Migration-Strategie definieren

**View-Kategorien:**
1. Session-bezogene Views → SessionCoordinator
2. Profile-bezogene Views → ProfileCoordinator
3. Workout-bezogene Views → WorkoutCoordinator
4. Exercise-bezogene Views → ExerciseCoordinator
5. Statistics-bezogene Views → AnalyticsCoordinator
6. Settings-bezogene Views → Mehrere Coordinators

**Migration-Pattern:**
```swift
// Vorher:
struct MyView: View {
    @EnvironmentObject var store: WorkoutStore
    
    var body: some View {
        Text(store.userProfile.name)
        Button("Start") {
            store.startSession(for: workoutId)
        }
    }
}

// Nachher:
struct MyView: View {
    @EnvironmentObject var profileCoordinator: ProfileCoordinator
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    
    var body: some View {
        Text(profileCoordinator.profile.name)
        Button("Start") {
            sessionCoordinator.startSession(for: workoutId)
        }
    }
}
```

**Zeitaufwand:** 2-3 Stunden (Planung)

---

### Task 4.2: ContentView & App-Level migrieren

**Dateien:**
- ContentView.swift
- GymTrackerApp.swift

**Änderungen:**
```swift
// GymTrackerApp.swift
@main
struct GymTrackerApp: App {
    @StateObject private var coordinatorFactory = CoordinatorFactory.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinatorFactory.sessionCoordinator)
                .environmentObject(coordinatorFactory.profileCoordinator)
                .environmentObject(coordinatorFactory.workoutCoordinator)
                .environmentObject(coordinatorFactory.exerciseCoordinator)
                .environmentObject(coordinatorFactory.recordCoordinator)
                .environmentObject(coordinatorFactory.analyticsCoordinator)
                .environmentObject(coordinatorFactory.healthKitCoordinator)
                .environmentObject(coordinatorFactory.restTimerCoordinator)
                .onAppear {
                    coordinatorFactory.setModelContext(modelContext)
                }
        }
    }
}
```

**Zeitaufwand:** 3-4 Stunden

---

### Task 4.3: Session-Views migrieren (6 Views)

**Views:**
1. WorkoutDetailView
2. WorkoutsHomeView
3. SessionDetailView
4. WorkoutSessionHeader
5. ExerciseListSection
6. WorkoutCompletionSheet

**Coordinator:** SessionCoordinator + WorkoutCoordinator

**Pattern:**
```swift
@EnvironmentObject var sessionCoordinator: SessionCoordinator
@EnvironmentObject var workoutCoordinator: WorkoutCoordinator
```

**Zeitaufwand:** 6-8 Stunden

---

### Task 4.4: Profile-Views migrieren (4 Views)

**Views:**
1. ProfileView
2. ProfileEditView
3. HealthKitSetupView
4. ProfileSection

**Coordinator:** ProfileCoordinator + HealthKitCoordinator

**Zeitaufwand:** 4-5 Stunden

---

### Task 4.5: Workout-Views migrieren (7 Views)

**Views:**
1. WorkoutsView
2. EditWorkoutView
3. AddWorkoutView
4. WorkoutWizardView
5. GeneratedWorkoutPreviewView
6. FavoriteWorkoutsGrid
7. BackupView

**Coordinator:** WorkoutCoordinator + ExerciseCoordinator

**Zeitaufwand:** 7-9 Stunden

---

### Task 4.6: Exercise-Views migrieren (3 Views)

**Views:**
1. ExercisesView
2. AddExerciseView
3. ExerciseSwapView

**Coordinator:** ExerciseCoordinator

**Zeitaufwand:** 3-4 Stunden

---

### Task 4.7: Statistics-Views migrieren (10 Views)

**Views:**
1. StatisticsView
2. ProgressionScoreCard
3. SmartTipsCard
4. WeekComparisonCard
5. TopPRsCard
6. MuscleDistributionCard
7. WeeklySetsCard
8. RecoveryCard
9. VolumeChartCard
10. PersonalRecordsCard

**Coordinator:** AnalyticsCoordinator + RecordCoordinator

**Zeitaufwand:** 8-10 Stunden

---

### Task 4.8: Settings-Views migrieren (4 Views)

**Views:**
1. SettingsView
2. NotificationSettingsView
3. DebugMenuView
4. DataManagementSection

**Coordinator:** ProfileCoordinator + HealthKitCoordinator + CacheCoordinator

**Zeitaufwand:** 4-5 Stunden

---

### Task 4.9: Remaining Views migrieren (5 Views)

**Views:**
1. HeartRateView
2. RestTimerExpiredOverlay
3. ExercisePicker
4. EditWorkoutComponents
5. SessionDetailComponents

**Coordinator:** Abhängig von Kontext

**Zeitaufwand:** 4-5 Stunden

---

### Task 4.10: WorkoutStore deprecaten

**Nach erfolgreicher Migration:**

1. Markiere WorkoutStore als deprecated
2. Füge Deprecation-Warnings hinzu
3. Update CLAUDE.md
4. Code-Review

```swift
@available(*, deprecated, message: "Use specific coordinators instead")
@MainActor
class WorkoutStore: ObservableObject {
    // Legacy implementation for backward compatibility
}
```

**Zeitaufwand:** 2-3 Stunden

---

### Phase 4: Deliverables

✅ **Migrierte Views:** 29 Views

✅ **Aktualisierte Dateien:**
- Alle 29 View-Dateien
- GymTrackerApp.swift
- ContentView.swift

✅ **Tests:**
- UI Tests für alle migrierten Views
- Integration Tests für Coordinator-Interaction
- Regression Tests

✅ **Dokumentation:**
- Migration Guide
- Coordinator Usage Guide
- Updated CLAUDE.md

**Zeitaufwand Phase 4:** 40-50 Stunden (2-3 Wochen)

---

## 🟡 Phase 5: Technical Debt (Woche 11-12)

### Ziel
Alle bekannten Technical Debt Items beheben.

### Status: ⬜ Not Started

---

### Task 5.1: Profile zu SwiftData migrieren

**Problem:**
- Profile aktuell in UserDefaults gespeichert
- Sollte vollständig in SwiftData sein
- UserProfileEntity existiert, wird aber als Backup verwendet

**Lösung:**
1. Entferne UserDefaults-Backup aus ProfileService
2. Migration: UserDefaults → SwiftData (einmalig)
3. Update ProfileCoordinator
4. Teste Daten-Persistenz

**Dateien:**
- `Services/ProfileService.swift`
- `Coordinators/ProfileCoordinator.swift`

**Zeitaufwand:** 6-8 Stunden

---

### Task 5.2: DataManager.swift entfernen

**Problem:**
- Legacy-Code aus früher Entwicklung
- Überschneidet sich mit WorkoutDataService
- Verwirrung über Verantwortlichkeiten

**Lösung:**
1. Audit: Wo wird DataManager verwendet?
2. Migriere Funktionalität zu WorkoutDataService
3. Update alle referenzierenden Stellen
4. Lösche DataManager.swift

**Dateien:**
- `GymTracker/DataManager.swift` (532 Zeilen - LÖSCHEN)
- Alle Views/Services die DataManager verwenden

**Zeitaufwand:** 6-8 Stunden

---

### Task 5.3: Migration-Code auslagern

**Problem:**
- WorkoutStore enthält 568 Zeilen Migration/Debug-Code (L1267-1835)
- Nicht produktionsrelevant
- Bläht WorkoutStore auf

**Lösung:**
1. Erstelle `Database/Migrations/ExerciseMigrationManager.swift`
2. Verschiebe alle Migration-Methoden
3. Verschiebe Debug-Methoden in `#if DEBUG` Blöcke
4. Cleanup WorkoutStore

**Neue Datei:** `Database/Migrations/ExerciseMigrationManager.swift`

**Zu verschiebender Code:**
- Markdown Parser Tests (L1267-1290)
- Exercise Database Migration (L755-1174)
- Automatic Migration (L1456-1634)
- Test & Debug Methods (L1639-1835)

**Zeitaufwand:** 6-8 Stunden

---

### Task 5.4: Duplicate ProfileService entfernen

**Problem:**
```swift
// WorkoutStore.swift
let profileService = ProfileService()  // L77
let sessionService = WorkoutSessionService()  // L78
let profileService = ProfileService()  // L79 ❌ DUPLIKAT!
```

**Lösung:**
- Entferne Zeile 79

**Zeitaufwand:** 5 Minuten

---

### Task 5.5: Legacy Rest Timer Comment entfernen

**Problem:**
```swift
// MARK: - Legacy Rest Timer State (DEPRECATED - Phase 5)
// Aber kein Legacy-Code darunter!
```

**Lösung:**
- Entferne obsoletes Comment (L68-69)

**Zeitaufwand:** 5 Minuten

---

### Task 5.6: exercisesTranslatedToGerman entfernen

**Problem:**
- Überschneidet sich mit Markdown-Migration (Phase 8)
- Nach erfolgreicher Migration obsolet

**Lösung:**
1. Prüfe ob Markdown-Migration erfolgreich
2. Entferne `@AppStorage("exercisesTranslatedToGerman")`
3. Entferne `checkAndPerformAutomaticGermanTranslation(...)` (L950-1174)

**Zeitaufwand:** 2-3 Stunden

---

### Task 5.7: Cache-Management konsolidieren

**Problem:**
- Cache-Logik über mehrere Stellen verteilt
- WorkoutStore, StatisticsCache, Services
- Keine zentrale Cache-Strategie

**Lösung:**
1. Zentralisiere in CacheCoordinator
2. Einheitliche Cache-Invalidierung
3. Cache-Monitoring

**Zeitaufwand:** 4-5 Stunden

---

### Task 5.8: SettingsView aufteilen

**Problem:**
- SettingsView.swift: 1,446 Zeilen

**Lösung (bereits teilweise gemacht):**
1. ✅ NotificationSettingsView extrahiert (356 Zeilen)
2. ✅ DebugMenuView extrahiert (406 Zeilen)
3. ⬜ ProfileSection extrahieren (~300 Zeilen)
4. ⬜ DataManagementSection extrahieren (~200 Zeilen)
5. ⬜ AboutSection extrahieren (~100 Zeilen)

**Ziel-Größe:** ~500 Zeilen (von 1,446)

**Zeitaufwand:** 5-6 Stunden

---

### Task 5.9: EditWorkoutView aufteilen

**Problem:**
- EditWorkoutView.swift: 1,244 Zeilen

**Lösung (teilweise gemacht):**
1. ✅ ExercisePicker extrahiert (164 Zeilen)
2. ⬜ ExerciseManager extrahieren (~400 Zeilen)
3. ⬜ SetEditor extrahieren (~300 Zeilen)
4. ⬜ ReorderSheet extrahieren (~200 Zeilen)

**Ziel-Größe:** ~600 Zeilen (von 1,244)

**Zeitaufwand:** 6-7 Stunden

---

### Phase 5: Deliverables

✅ **Gelöste Technical Debt Items:**
1. Profile vollständig in SwiftData
2. DataManager.swift entfernt
3. Migration-Code ausgelagert
4. Duplikate entfernt
5. Cache konsolidiert
6. Alle großen Views <1000 Zeilen

✅ **Neue Dateien:**
- `Database/Migrations/ExerciseMigrationManager.swift` (~600 Zeilen)
- `Views/Settings/ProfileSection.swift` (~300 Zeilen)
- `Views/Settings/DataManagementSection.swift` (~200 Zeilen)
- `Views/Settings/AboutSection.swift` (~100 Zeilen)
- `Views/EditWorkout/ExerciseManager.swift` (~400 Zeilen)
- `Views/EditWorkout/SetEditor.swift` (~300 Zeilen)
- `Views/EditWorkout/ReorderSheet.swift` (~200 Zeilen)

✅ **Gelöschte Dateien:**
- `GymTracker/DataManager.swift` (532 Zeilen)

✅ **Aktualisierte Dateien:**
- `ViewModels/WorkoutStore.swift` (weitere Reduktion)
- `Services/ProfileService.swift` (UserDefaults entfernt)
- `Views/SettingsView.swift` (1,446 → ~500 Zeilen)
- `Views/EditWorkoutView.swift` (1,244 → ~600 Zeilen)

**Zeitaufwand Phase 5:** 35-45 Stunden (2 Wochen)

---

## 🟡 Phase 6: Testing & Dokumentation (Woche 13-14)

### Ziel
80%+ Test Coverage und vollständige Dokumentation.

### Status: ⬜ Not Started

---

### Task 6.1: Service Unit Tests

**Zu testende Services (9 + 6 neue):**
1. WorkoutAnalyticsService
2. WorkoutDataService
3. ProfileService
4. TipEngine
5. WorkoutAnalyzer
6. TimerEngine
7. TipFeedbackManager
8. WorkoutActionService
9. HapticManager
10. WorkoutSessionService (neu)
11. SessionManagementService (neu)
12. ExerciseRecordService (neu)
13. HealthKitSyncService (neu)
14. WorkoutGenerationService (neu)
15. LastUsedMetricsService (neu)

**Test-Strategie:**
- Unit Tests für jede öffentliche Methode
- Edge Cases & Error Handling
- Mock Dependencies (ModelContext, HealthKit)
- Performance Tests für teure Operationen

**Zeitaufwand:** 20-25 Stunden

---

### Task 6.2: Coordinator Unit Tests

**Zu testende Coordinators (9):**
1. SessionCoordinator
2. ProfileCoordinator
3. WorkoutCoordinator
4. ExerciseCoordinator
5. RecordCoordinator
6. AnalyticsCoordinator
7. HealthKitCoordinator
8. RestTimerCoordinator
9. CacheCoordinator

**Test-Strategie:**
- Mock Services
- Test State Management (@Published)
- Test Coordinator Orchestration
- Integration Tests zwischen Coordinators

**Zeitaufwand:** 15-20 Stunden

---

### Task 6.3: View Component Tests

**Test-Typen:**
- Preview Tests (alle Komponenten)
- Snapshot Tests (visuelle Regression)
- Accessibility Tests
- Dark Mode Tests

**Priorität:**
1. Kritische Views (WorkoutDetailView, StatisticsView)
2. Alle extrahierten Komponenten (20+)
3. Container Views

**Zeitaufwand:** 10-15 Stunden

---

### Task 6.4: Integration Tests

**Test-Szenarien:**
1. **Session Flow:**
   - Start Session → Complete Sets → End Session
   - Rest Timer Integration
   - HealthKit Sync

2. **Workout Creation:**
   - Create Workout → Add Exercises → Save
   - Workout Wizard Flow
   - Template vs Active Session

3. **Profile Management:**
   - Update Profile → HealthKit Sync
   - Onboarding Flow

4. **Statistics:**
   - Data Aggregation
   - Chart Generation
   - Cache Management

**Zeitaufwand:** 12-15 Stunden

---

### Task 6.5: Performance Tests

**Metriken:**
- App Launch Time
- View Load Time
- Data Fetch Performance
- Memory Usage
- Battery Impact

**Tools:**
- Xcode Instruments
- Memory Graph Debugger
- Time Profiler

**Zeitaufwand:** 6-8 Stunden

---

### Task 6.6: Dokumentation aktualisieren

**Zu aktualisierende Dokumente:**

1. **CLAUDE.md:**
   - Neue Architektur beschreiben
   - Coordinator-Pattern dokumentieren
   - Service-Layer Update
   - Beispiele für View-Integration

2. **DOCUMENTATION.md:**
   - Vollständige API-Dokumentation
   - Coordinator-Guide
   - Service-Guide
   - Migration-Guide (für zukünftige Entwickler)

3. **README.md:**
   - Architektur-Übersicht
   - Getting Started Guide
   - Testing Guide

4. **CODE_STYLE.md (neu):**
   - Swift Style Guide
   - Naming Conventions
   - Architecture Patterns
   - Best Practices

5. **TESTING_GUIDE.md (neu):**
   - How to Write Tests
   - Mock Patterns
   - Test Strategies

**Zeitaufwand:** 8-10 Stunden

---

### Task 6.7: Code Review & Cleanup

**Review-Bereiche:**
1. Code-Qualität (SwiftLint)
2. Naming Consistency
3. Comment-Qualität
4. TODOs/FIXMEs entfernen
5. Debug-Code entfernen

**Zeitaufwand:** 6-8 Stunden

---

### Phase 6: Deliverables

✅ **Tests:**
- 15 Service Test Suites
- 9 Coordinator Test Suites
- 20+ View Component Tests
- 10+ Integration Tests
- Performance Benchmarks

✅ **Test Coverage:**
- Services: 90%+
- Coordinators: 85%+
- Views: 60%+
- Overall: 80%+

✅ **Dokumentation:**
- CLAUDE.md aktualisiert
- DOCUMENTATION.md aktualisiert
- README.md aktualisiert
- CODE_STYLE.md erstellt
- TESTING_GUIDE.md erstellt

✅ **Code Quality:**
- Alle SwiftLint Warnings behoben
- Konsistentes Naming
- Vollständige SwiftDoc-Kommentare
- Keine TODOs/FIXMEs

**Zeitaufwand Phase 6:** 75-95 Stunden (2 Wochen)

---

## 📊 Gesamtübersicht

### Zeit- & Aufwandsschätzung

| Phase | Dauer | Stunden | Priorität | Status |
|-------|-------|---------|-----------|--------|
| Phase 1: Services | 2 Wochen | 25-35h | 🔴 Kritisch | 🟡 In Progress |
| Phase 2: Coordinators | 2 Wochen | 38-48h | 🔴 Kritisch | ⬜ Not Started |
| Phase 3: Views | 3 Wochen | 60-75h | 🟠 Hoch | ⬜ Not Started |
| Phase 4: Migration | 2-3 Wochen | 40-50h | 🟠 Hoch | ⬜ Not Started |
| Phase 5: Tech Debt | 2 Wochen | 35-45h | 🟡 Mittel | ⬜ Not Started |
| Phase 6: Testing | 2 Wochen | 75-95h | 🟡 Mittel | ⬜ Not Started |
| **GESAMT** | **13-14 Wochen** | **273-348h** | | |

### Meilensteine

#### 🎯 Meilenstein 1: Services Complete (Ende Woche 2)
- ✅ Alle Services extrahiert
- ✅ WorkoutStore auf ~1,800 Zeilen reduziert
- ✅ Unit Tests für Services

#### 🎯 Meilenstein 2: Coordinators Complete (Ende Woche 4)
- ✅ Alle 9 Coordinators erstellt
- ✅ WorkoutStore auf ~500 Zeilen reduziert
- ✅ Unit Tests für Coordinators

#### 🎯 Meilenstein 3: Views Modular (Ende Woche 7)
- ✅ Alle großen Views aufgeteilt
- ✅ 20+ neue Komponenten
- ✅ Keine View >1000 Zeilen

#### 🎯 Meilenstein 4: Migration Complete (Ende Woche 10)
- ✅ Alle Views auf Coordinators migriert
- ✅ WorkoutStore deprecated
- ✅ Backward Compatibility erhalten

#### 🎯 Meilenstein 5: Tech Debt Resolved (Ende Woche 12)
- ✅ Alle Known Issues gelöst
- ✅ Profile in SwiftData
- ✅ DataManager entfernt

#### 🎯 Meilenstein 6: Production Ready (Ende Woche 14)
- ✅ 80%+ Test Coverage
- ✅ Vollständige Dokumentation
- ✅ Performance optimiert

---

## 🚀 Quick Start Guide

### Diese Woche starten (Woche 1)

**Sofort:**
1. ✅ Task 1.1: WorkoutSessionService erstellen (3-4h)
2. ✅ Task 5.4: Duplicate entfernen (5min)
3. ✅ Task 5.5: Legacy Comment entfernen (5min)

**Diese Woche:**
4. ✅ Task 1.2: SessionManagementService (4-6h)
5. ✅ Task 1.3: ExerciseRecordService (3-4h)
6. ✅ Task 1.4: HealthKitSyncService (4-5h)

**Nächste Woche (Woche 2):**
7. ✅ Task 1.5: WorkoutGenerationService (5-6h)
8. ✅ Task 1.6: LastUsedMetricsService (2-3h)
9. ✅ Task 1.7: WorkoutStore aufräumen (4-6h)

---

## 📝 Konventionen & Best Practices

### Naming Conventions

**Coordinators:**
```swift
<Feature>Coordinator
// Beispiele:
SessionCoordinator
ProfileCoordinator
WorkoutCoordinator
```

**Services:**
```swift
<Domain><Function>Service
// Beispiele:
WorkoutDataService
ExerciseRecordService
HealthKitSyncService
```

**Views:**
```swift
<Feature><Type>View / <Feature><Type>Card
// Beispiele:
WorkoutDetailView
FavoriteWorkoutsGrid
ProgressionScoreCard
```

### File Organization

```
GymTracker/
├── Coordinators/          # Feature Coordinators
│   ├── SessionCoordinator.swift
│   ├── ProfileCoordinator.swift
│   └── ...
├── Services/              # Business Logic Services
│   ├── WorkoutDataService.swift
│   ├── SessionManagementService.swift
│   └── ...
├── ViewModels/            # Legacy (zu deprecaten)
│   └── WorkoutStore.swift
├── Views/                 # SwiftUI Views
│   ├── Home/
│   │   ├── HomeTabView.swift
│   │   └── ...
│   ├── Statistics/
│   │   ├── StatisticsView.swift
│   │   └── ...
│   └── WorkoutDetail/
│       ├── WorkoutDetailView.swift
│       └── ...
├── Models/                # Domain Models
├── Managers/              # System Integration
└── Database/              # Persistence Layer
```

### Code Style

**SwiftUI Views:**
```swift
struct MyView: View {
    // MARK: - Dependencies
    @EnvironmentObject var coordinator: MyCoordinator
    
    // MARK: - State
    @State private var isEditing = false
    
    // MARK: - Body
    var body: some View {
        // ...
    }
    
    // MARK: - Private Methods
    private func handleAction() {
        // ...
    }
}
```

**Coordinators:**
```swift
@MainActor
final class MyCoordinator: ObservableObject {
    // MARK: - Published State
    @Published var myState: MyState
    
    // MARK: - Dependencies
    private let service: MyService
    
    // MARK: - Initialization
    init(service: MyService) {
        self.service = service
    }
    
    // MARK: - Public API
    func performAction() {
        // ...
    }
    
    // MARK: - Private Helpers
    private func helperMethod() {
        // ...
    }
}
```

---

## 🎯 Success Criteria

### Quantitative Metriken

- ✅ Keine Datei >1000 Zeilen
- ✅ WorkoutStore <500 Zeilen oder deprecated
- ✅ 80%+ Test Coverage
- ✅ <2s App Launch Time
- ✅ <100MB Memory Usage (typical)

### Qualitative Kriterien

- ✅ Jede Komponente hat Single Responsibility
- ✅ Views nur von benötigten Coordinators abhängig
- ✅ Alle Services unit-testbar
- ✅ Dokumentation vollständig und aktuell
- ✅ Neue Entwickler können in <1 Woche produktiv werden

---

## 📞 Support & Resources

### Dokumentation
- **CLAUDE.md** - Projekt-Kontext für Claude
- **DOCUMENTATION.md** - Technische Dokumentation
- **MODULARIZATION_PLAN.md** - Dieser Plan
- **PROGRESS.md** - Fortschritts-Tracking

### Tools
- Xcode 15+
- SwiftLint
- Instruments
- Git

### Kontakt
- Siehe CLAUDE.md für Projekt-Kontext
- GitHub Issues für Bug-Reports
- Pull Requests für Code-Reviews

---

**Version:** 1.0  
**Erstellt:** 2025-10-15  
**Letztes Update:** 2025-10-15  
**Status:** 🟡 Phase 1 In Progress

---

