# 🎯 Phase 2: Feature Coordinators - Detaillierter Implementierungsplan

**Start:** Nach Phase 1 Abschluss (2025-10-15)  
**Geschätzte Dauer:** 2-3 Wochen (35-45 Stunden)  
**Status:** 🟡 Bereit zum Start

---

## 📋 Übersicht

### Ziel
Ersetze WorkoutStore God Object (2,177 Zeilen) durch 9 spezialisierte Feature Coordinators (~200 Zeilen je).

### Architektur-Transformation

**Vorher (Phase 1):**
```
Views (29 Files)
    ↓
WorkoutStore (2,177 Zeilen - God Object)
    ↓
Services (9 Files - 1,900 LOC)
    ↓
SwiftData
```

**Nachher (Phase 2):**
```
Views (29 Files)
    ↓
Feature Coordinators (9 Files - ~1,800 LOC total)
    ↓
Services (9 Files - 1,900 LOC)
    ↓
SwiftData
```

### Vorteile
✅ **Modularität:** Jeder Coordinator hat eine klar definierte Verantwortlichkeit  
✅ **Testbarkeit:** Coordinators können isoliert getestet werden  
✅ **Wartbarkeit:** Kleinere, fokussierte Dateien (~200 LOC)  
✅ **Performance:** Views laden nur benötigte Coordinators  
✅ **Skalierbarkeit:** Neue Features = neue Coordinators

---

## 🎯 Die 9 Feature Coordinators

| # | Coordinator | LOC | Priorität | Abhängigkeiten | Zeit |
|---|-------------|-----|-----------|----------------|------|
| 1 | ProfileCoordinator | 200 | 🔴 P0 | Keine | 4-5h |
| 2 | ExerciseCoordinator | 220 | 🔴 P0 | Keine | 4-5h |
| 3 | WorkoutCoordinator | 300 | 🟠 P1 | Exercise | 5-6h |
| 4 | SessionCoordinator | 250 | 🟠 P1 | Workout | 5h |
| 5 | RecordsCoordinator | 180 | 🟡 P2 | Exercise | 3-4h |
| 6 | AnalyticsCoordinator | 200 | 🟡 P2 | Session | 4h |
| 7 | HealthKitCoordinator | 200 | 🟡 P2 | Profile | 4h |
| 8 | RestTimerCoordinator | 150 | 🟢 P3 | Session | 3h |
| 9 | WorkoutStoreCoordinator | 100 | 🟢 P3 | Alle | 3-4h |

**Gesamt:** ~1,800 LOC, 35-45 Stunden

---

## 📅 Wochenplan

### Woche 1: Foundation Coordinators (P0)
**Ziel:** Kern-Coordinators ohne Dependencies

**Tag 1-2: ProfileCoordinator** (4-5h)
- User profile management
- Onboarding state
- HealthKit profile sync
- Settings integration

**Tag 3-4: ExerciseCoordinator** (4-5h)
- Exercise CRUD
- Search & filtering
- Similar exercises
- Last-used metrics

**Tag 5: Testing & Integration** (2-3h)
- Unit tests
- View integration
- Bug fixes

**Wochenziel:** 2 Coordinators, ~420 LOC

---

### Woche 2: Core Feature Coordinators (P1)
**Ziel:** Haupt-Features mit Dependencies

**Tag 1-2: WorkoutCoordinator** (5-6h)
- Workout CRUD
- Favorites management
- Workout generation
- Session recording

**Tag 3-4: SessionCoordinator** (5h)
- Active session state
- Session lifecycle
- Live Activity integration
- Heart rate tracking

**Tag 5: Testing & Integration** (3h)
- Integration tests
- View updates
- Bug fixes

**Wochenziel:** 2 Coordinators, ~550 LOC

---

### Woche 3: Specialized Coordinators (P2-P3)
**Ziel:** Spezial-Features und Facade

**Tag 1: RecordsCoordinator** (3-4h)
- Personal records
- 1RM calculations
- Record statistics

**Tag 2: AnalyticsCoordinator** (4h)
- Workout analytics
- Statistics
- Progress tracking

**Tag 3: HealthKitCoordinator** (4h)
- HealthKit authorization
- Data sync
- Health queries

**Tag 4: RestTimerCoordinator** (3h)
- Rest timer state
- Timer controls
- Notifications

**Tag 5: WorkoutStoreCoordinator + Final** (3-4h)
- Backward compatibility facade
- Final integration
- Complete testing
- Documentation

**Wochenziel:** 5 Coordinators, ~830 LOC

---

## 🏗️ Implementierungs-Reihenfolge (Detailliert)

### ✅ Phase 2.1: ProfileCoordinator (P0 - 4-5h)

**Warum zuerst?**
- ✅ Keine Dependencies zu anderen Coordinators
- ✅ Klar abgegrenzte Verantwortlichkeit
- ✅ Verwendet von vielen Views
- ✅ Perfektes Template für andere Coordinators

**Was wird extrahiert:**
```swift
// Aus WorkoutStore.swift (~150 Zeilen)
- userProfile: UserProfile
- profileUpdateTrigger: UUID
- updateProfile(...)
- updateProfileImage(...)
- updateLockerNumber(...)
- markOnboardingStep(...)
- requestHealthKitAuthorization()
- importFromHealthKit()
```

**Dependencies:**
- ProfileService ✅ (existiert)
- HealthKitManager ✅ (existiert)

**Verwendende Views:**
- ProfileView
- ProfileEditView
- SettingsView
- WorkoutWizardView
- OnboardingView

**Datei:** `GymTracker/Coordinators/ProfileCoordinator.swift`

**Template:**
```swift
import Foundation
import SwiftUI
import Combine
import HealthKit

@MainActor
final class ProfileCoordinator: ObservableObject {
    // MARK: - Published State
    @Published var profile: UserProfile
    @Published var profileUpdateTrigger: UUID = UUID()
    
    // MARK: - Dependencies
    private let profileService: ProfileService
    private let healthKitManager = HealthKitManager.shared
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    init(profileService: ProfileService = ProfileService()) {
        self.profileService = profileService
        self.profile = profileService.loadProfile(context: nil)
    }
    
    // MARK: - Context Management
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        self.profile = profileService.loadProfile(context: context)
    }
    
    // MARK: - Profile Management
    func updateProfile(...) { }
    func updateProfileImage(_ image: UIImage?) { }
    func updateLockerNumber(_ lockerNumber: String) { }
    
    // MARK: - Onboarding
    func markOnboardingStep(...) { }
    
    // MARK: - HealthKit Integration
    func requestHealthKitAuthorization() async throws { }
    func importFromHealthKit() async throws { }
}
```

**Testing Checklist:**
- [ ] Profile updates trigger UI refresh
- [ ] HealthKit authorization works
- [ ] Profile image upload/delete
- [ ] Onboarding state persistence
- [ ] Context switching

**Completion Criteria:**
- ✅ Coordinator kompiliert ohne Fehler
- ✅ Alle Tests grün
- ✅ ProfileView verwendet Coordinator statt WorkoutStore
- ✅ Keine Regression in anderen Views

---

### ✅ Phase 2.2: ExerciseCoordinator (P0 - 4-5h)

**Warum als zweites?**
- ✅ Keine Dependencies (außer Services)
- ✅ Wird von WorkoutCoordinator benötigt
- ✅ Klare Abgrenzung
- ✅ Viele Views betroffen

**Was wird extrahiert:**
```swift
// Aus WorkoutStore.swift (~120 Zeilen)
- exercises: [Exercise] (via DataService)
- addExercise(...)
- updateExercise(...)
- deleteExercise(...)
- exercise(named:)
- getSimilarExercises(...)
- lastMetrics(for:)
- completeLastMetrics(for:)
```

**Dependencies:**
- WorkoutDataService ✅
- LastUsedMetricsService ✅

**Verwendende Views:**
- ExercisesView
- AddExerciseView
- EditExerciseView
- ExerciseSelectionView
- WorkoutDetailView

**Datei:** `GymTracker/Coordinators/ExerciseCoordinator.swift`

**Template:**
```swift
@MainActor
final class ExerciseCoordinator: ObservableObject {
    // MARK: - Published State
    @Published var exercises: [Exercise] = []
    
    // MARK: - Dependencies
    private let dataService: WorkoutDataService
    private let metricsService: LastUsedMetricsService
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    init(dataService: WorkoutDataService = WorkoutDataService(),
         metricsService: LastUsedMetricsService = LastUsedMetricsService()) {
        self.dataService = dataService
        self.metricsService = metricsService
    }
    
    // MARK: - Context Management
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        dataService.setContext(context)
        metricsService.setContext(context)
        loadExercises()
    }
    
    // MARK: - CRUD Operations
    func addExercise(_ exercise: Exercise) { }
    func updateExercise(_ exercise: Exercise) { }
    func deleteExercise(at indexSet: IndexSet) { }
    
    // MARK: - Queries
    func exercise(named name: String) -> Exercise { }
    func getSimilarExercises(to exercise: Exercise, ...) -> [Exercise] { }
    
    // MARK: - Metrics
    func lastMetrics(for exercise: Exercise) -> (weight: Double, setCount: Int)? { }
    func completeLastMetrics(for exercise: Exercise) -> ExerciseLastUsedMetrics? { }
    
    // MARK: - Private Helpers
    private func loadExercises() { }
}
```

**Testing Checklist:**
- [ ] Exercise CRUD operations
- [ ] Similar exercise matching
- [ ] Last-used metrics retrieval
- [ ] Search functionality
- [ ] Context switching

---

### ✅ Phase 2.3: WorkoutCoordinator (P1 - 5-6h)

**Abhängigkeiten:** ExerciseCoordinator muss fertig sein

**Was wird extrahiert:**
```swift
// Aus WorkoutStore.swift (~200 Zeilen)
- workouts: [Workout]
- homeWorkouts: [Workout]
- addWorkout(...)
- updateWorkout(...)
- deleteWorkout(...)
- toggleFavorite(...)
- toggleHomeFavorite(...)
- generateWorkout(...)
- recordSession(...)
- removeSession(...)
- previousWorkout(...)
- getSessionHistory()
```

**Dependencies:**
- WorkoutDataService ✅
- WorkoutGenerationService ✅
- WorkoutSessionService ✅
- WorkoutAnalyticsService ✅

**Verwendende Views:**
- WorkoutsView
- WorkoutsHomeView
- WorkoutDetailView
- EditWorkoutView
- AddWorkoutView
- WorkoutWizardView

**Datei:** `GymTracker/Coordinators/WorkoutCoordinator.swift`

**Besonderheiten:**
- ⚠️ Größter Coordinator (~300 LOC)
- ⚠️ Viele Views betroffen
- ⚠️ Favorites-Logik komplex (max 4 home favorites)

---

### ✅ Phase 2.4: SessionCoordinator (P1 - 5h)

**Abhängigkeiten:** WorkoutCoordinator

**Was wird extrahiert:**
```swift
// Aus WorkoutStore.swift (~180 Zeilen)
- activeSessionID: UUID?
- isShowingWorkoutDetail: Bool
- activeWorkout: Workout?
- startSession(...)
- endSession()
- pauseSession()
- resumeSession()
- startHeartRateTracking(...)
- stopHeartRateTracking()
```

**Dependencies:**
- SessionManagementService ✅
- WorkoutSessionService ✅
- WorkoutLiveActivityController ✅
- HealthKitWorkoutTracker ✅

**Verwendende Views:**
- WorkoutDetailView
- WorkoutsHomeView
- ContentView

---

### ✅ Phase 2.5: RecordsCoordinator (P2 - 3-4h)

**Was wird extrahiert:**
```swift
// Aus WorkoutStore.swift (~80 Zeilen)
- getExerciseRecord(...)
- getAllExerciseRecords()
- checkForNewRecord(...)
```

**Dependencies:**
- ExerciseRecordService ✅

**Verwendende Views:**
- StatisticsView
- ExerciseDetailView
- RecordsView

---

### ✅ Phase 2.6: AnalyticsCoordinator (P2 - 4h)

**Was wird extrahiert:**
```swift
// Aus WorkoutStore.swift (~120 Zeilen)
- totalWorkouts: Int
- totalDuration: TimeInterval
- currentStreak: Int
- averageDurationMinutes: Int
- muscleVolume(...)
- exerciseStats(...)
- workoutsByDay(...)
```

**Dependencies:**
- WorkoutAnalyticsService ✅

**Verwendende Views:**
- StatisticsView
- InsightsView
- HomeView

---

### ✅ Phase 2.7: HealthKitCoordinator (P2 - 4h)

**Was wird extrahiert:**
```swift
// Aus WorkoutStore.swift (~100 Zeilen)
- healthKitManager: HealthKitManager
- requestHealthKitAuthorization()
- importFromHealthKit()
- saveWorkoutToHealthKit(...)
- readHeartRateData(...)
- readWeightData(...)
- readBodyFatData(...)
```

**Dependencies:**
- HealthKitSyncService ✅
- HealthKitManager ✅

**Verwendende Views:**
- ProfileView
- SettingsView
- HealthKitSyncView

---

### ✅ Phase 2.8: RestTimerCoordinator (P3 - 3h)

**Was wird extrahiert:**
```swift
// Aus WorkoutStore.swift (~80 Zeilen)
- restTimerStateManager: RestTimerStateManager
- overlayManager: InAppOverlayManager?
- startRest(...)
- pauseRest()
- resumeRest()
- cancelRest()
```

**Dependencies:**
- RestTimerStateManager ✅
- InAppOverlayManager ✅

**Verwendende Views:**
- WorkoutDetailView
- RestTimerView

---

### ✅ Phase 2.9: WorkoutStoreCoordinator (P3 - 3-4h)

**Zweck:** Backward Compatibility Facade

**Was macht er:**
- Hält Referenzen zu allen anderen Coordinators
- Delegiert Aufrufe an entsprechende Coordinators
- Ermöglicht schrittweise Migration von Views
- Verhindert Breaking Changes

**Datei:** `GymTracker/Coordinators/WorkoutStoreCoordinator.swift`

**Template:**
```swift
@MainActor
final class WorkoutStoreCoordinator: ObservableObject {
    // MARK: - Sub-Coordinators
    let profileCoordinator: ProfileCoordinator
    let exerciseCoordinator: ExerciseCoordinator
    let workoutCoordinator: WorkoutCoordinator
    let sessionCoordinator: SessionCoordinator
    let recordsCoordinator: RecordsCoordinator
    let analyticsCoordinator: AnalyticsCoordinator
    let healthKitCoordinator: HealthKitCoordinator
    let restTimerCoordinator: RestTimerCoordinator
    
    // MARK: - Context Management
    var modelContext: ModelContext? {
        didSet {
            profileCoordinator.setContext(modelContext)
            exerciseCoordinator.setContext(modelContext)
            workoutCoordinator.setContext(modelContext)
            // ... etc
        }
    }
    
    // MARK: - Backward Compatibility
    // Delegate all old WorkoutStore methods to appropriate coordinators
    var userProfile: UserProfile { profileCoordinator.profile }
    func updateProfile(...) { profileCoordinator.updateProfile(...) }
    // ... etc for all methods
}
```

**Verwendung:**
- Ermöglicht Views, WorkoutStore schrittweise durch Coordinators zu ersetzen
- Views können entweder WorkoutStoreCoordinator ODER spezifische Coordinators verwenden
- Sobald alle Views migriert sind, kann WorkoutStoreCoordinator entfernt werden

---

## 🛠️ Implementierungs-Workflow (für jeden Coordinator)

### Schritt 1: Vorbereitung (15 Min)
1. Lese relevante Sections aus WorkoutStore
2. Identifiziere alle zu extrahierenden Methoden
3. Liste alle Dependencies
4. Liste alle verwendenden Views

### Schritt 2: Coordinator erstellen (60-90 Min)
1. Erstelle neue Datei: `Coordinators/[Name]Coordinator.swift`
2. Kopiere Template-Struktur
3. Implementiere `@Published` Properties
4. Implementiere Dependencies Injection
5. Implementiere Context Management
6. Kopiere Methoden aus WorkoutStore
7. Passe an Coordinator-Kontext an

### Schritt 3: Services Integration (30 Min)
1. Ersetze direkte SwiftData-Calls durch Service-Calls
2. Implementiere Error Handling
3. Füge Logging hinzu
4. Teste Service-Integration

### Schritt 4: Testing (30-45 Min)
1. Schreibe Unit Tests für Coordinator
2. Teste alle Public Methods
3. Teste Context Switching
4. Teste Error Cases

### Schritt 5: View Integration (45-60 Min)
1. Update 1-2 Views zum Testen
2. Ersetze `@EnvironmentObject var store: WorkoutStore`
   durch `@EnvironmentObject var coordinator: [Name]Coordinator`
3. Update Method Calls
4. Teste UI Funktionalität
5. Fix Bugs

### Schritt 6: Documentation (15 Min)
1. SwiftDoc Comments für alle Public Methods
2. Update CLAUDE.md
3. Update PROGRESS.md

---

## 📝 Code Templates

### Template 1: Basic Coordinator Structure

```swift
import Foundation
import SwiftUI
import Combine
import SwiftData

/// [Beschreibung was dieser Coordinator macht]
///
/// **Verantwortlichkeiten:**
/// - [Verantwortlichkeit 1]
/// - [Verantwortlichkeit 2]
///
/// **Dependencies:**
/// - [Service 1]
/// - [Service 2]
@MainActor
final class [Name]Coordinator: ObservableObject {
    
    // MARK: - Published State
    
    @Published var someState: SomeType
    
    // MARK: - Dependencies
    
    private let someService: SomeService
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init(someService: SomeService = SomeService()) {
        self.someService = someService
        // Initialize state
    }
    
    // MARK: - Context Management
    
    /// Sets the SwiftData model context for database operations
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        someService.setContext(context)
        // Reload data if needed
    }
    
    // MARK: - Public API
    
    /// [Method description]
    func someMethod() {
        // Implementation
    }
    
    // MARK: - Private Helpers
    
    private func helperMethod() {
        // Implementation
    }
}
```

### Template 2: Coordinator mit Async Operations

```swift
@MainActor
final class [Name]Coordinator: ObservableObject {
    
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    func performAsyncOperation() async {
        isLoading = true
        error = nil
        
        do {
            try await someService.asyncMethod()
            // Success handling
        } catch {
            self.error = error
            print("❌ Error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}
```

### Template 3: Coordinator mit ObservableObject Dependencies

```swift
@MainActor
final class [Name]Coordinator: ObservableObject {
    
    // MARK: - Dependencies (ObservableObject)
    
    @ObservedObject private var subCoordinator: SubCoordinator
    
    // MARK: - Initialization
    
    init(subCoordinator: SubCoordinator) {
        self.subCoordinator = subCoordinator
    }
    
    // MARK: - Computed Properties
    
    var someComputedValue: Int {
        return subCoordinator.someValue * 2
    }
}
```

---

## ✅ Testing Strategy

### Unit Tests (für jeden Coordinator)

```swift
@MainActor
final class ProfileCoordinatorTests: XCTestCase {
    
    var sut: ProfileCoordinator!
    var mockProfileService: MockProfileService!
    var mockContext: MockModelContext!
    
    override func setUp() {
        super.setUp()
        mockProfileService = MockProfileService()
        mockContext = MockModelContext()
        sut = ProfileCoordinator(profileService: mockProfileService)
        sut.setContext(mockContext)
    }
    
    override func tearDown() {
        sut = nil
        mockProfileService = nil
        mockContext = nil
        super.tearDown()
    }
    
    func testUpdateProfile_Success() {
        // Given
        let newName = "Test User"
        
        // When
        sut.updateProfile(name: newName, ...)
        
        // Then
        XCTAssertEqual(sut.profile.name, newName)
        XCTAssertTrue(mockProfileService.updateCalled)
    }
    
    func testUpdateProfile_TriggersUIUpdate() {
        // Given
        let oldTrigger = sut.profileUpdateTrigger
        
        // When
        sut.updateProfile(name: "Test", ...)
        
        // Then
        XCTAssertNotEqual(sut.profileUpdateTrigger, oldTrigger)
    }
}
```

### Integration Tests

```swift
@MainActor
final class CoordinatorIntegrationTests: XCTestCase {
    
    func testWorkoutCoordinator_WithExerciseCoordinator() {
        // Given
        let exerciseCoordinator = ExerciseCoordinator()
        let workoutCoordinator = WorkoutCoordinator()
        
        // When
        let exercise = exerciseCoordinator.exercise(named: "Squats")
        workoutCoordinator.addExercise(exercise, to: workout)
        
        // Then
        XCTAssertTrue(workout.exercises.contains(where: { $0.exercise.id == exercise.id }))
    }
}
```

---

## 🎯 Migration Strategy für Views

### Schritt-für-Schritt View Migration

**Beispiel: ProfileView**

**Vorher:**
```swift
struct ProfileView: View {
    @EnvironmentObject var store: WorkoutStore
    
    var body: some View {
        Text(store.userProfile.name)
        Button("Update") {
            store.updateProfile(...)
        }
    }
}
```

**Nachher:**
```swift
struct ProfileView: View {
    @EnvironmentObject var profileCoordinator: ProfileCoordinator
    
    var body: some View {
        Text(profileCoordinator.profile.name)
        Button("Update") {
            profileCoordinator.updateProfile(...)
        }
    }
}
```

**Environment Injection (in App oder ContentView):**
```swift
@StateObject private var profileCoordinator = ProfileCoordinator()
@StateObject private var exerciseCoordinator = ExerciseCoordinator()
// ...

var body: some View {
    ContentView()
        .environmentObject(profileCoordinator)
        .environmentObject(exerciseCoordinator)
        // ...
        .onAppear {
            profileCoordinator.setContext(modelContext)
            exerciseCoordinator.setContext(modelContext)
            // ...
        }
}
```

### Views Migration Priority

**Week 1 (mit ProfileCoordinator):**
1. ProfileView ✅ (einfach, isoliert)
2. ProfileEditView ✅ (einfach)
3. SettingsView ⚠️ (komplex, viele Dependencies)

**Week 1 (mit ExerciseCoordinator):**
1. ExercisesView ✅ (einfach)
2. AddExerciseView ✅ (einfach)
3. ExerciseSelectionView ⚠️ (mittel)

**Week 2 (mit WorkoutCoordinator):**
1. WorkoutsView ✅
2. WorkoutDetailView ⚠️ (sehr komplex!)
3. EditWorkoutView ✅

**Week 2 (mit SessionCoordinator):**
1. WorkoutDetailView (Session-Teil) ⚠️
2. WorkoutsHomeView ⚠️

**Week 3 (Rest):**
1. StatisticsView (Analytics + Records)
2. Kleinere Views nach Bedarf

---

## 📊 Success Metrics

### Code Metrics

**Ziel nach Phase 2:**
| Metrik | Vorher | Ziel | Messung |
|--------|--------|------|---------|
| WorkoutStore LOC | 2,177 | **~300** | wc -l |
| Coordinator LOC | 0 | **~1,800** | Total aller Coordinators |
| Durchschn. File Size | 2,177 | **~200** | Pro Coordinator |
| Services LOC | 1,900 | 1,900 | Unverändert |

### Architecture Metrics

- ✅ **Separation of Concerns:** Jeder Coordinator hat eine klare Verantwortlichkeit
- ✅ **Dependency Direction:** Views → Coordinators → Services → Data
- ✅ **Testability:** Alle Coordinators unit-testbar
- ✅ **Modularity:** Coordinators können einzeln ersetzt werden

### Quality Metrics

- ✅ **Test Coverage:** Mind. 80% für alle Coordinators
- ✅ **Documentation:** 100% SwiftDoc für Public APIs
- ✅ **Build Time:** Keine signifikante Verschlechterung
- ✅ **Performance:** Keine Regression in UI-Performance

---

## 🚨 Risiken und Mitigation

### Risiko 1: Breaking Changes in Views (HOCH)
**Problem:** 29 Views müssen potentiell angepasst werden

**Mitigation:**
- ✅ Verwende WorkoutStoreCoordinator als Facade
- ✅ Migriere Views schrittweise (1-2 pro Coordinator)
- ✅ Teste jede View nach Migration
- ✅ Behalte alte WorkoutStore parallel (Deprecated)

### Risiko 2: Komplexe Dependencies (MITTEL)
**Problem:** Manche Coordinators hängen voneinander ab

**Mitigation:**
- ✅ Erstelle Dependency Graph
- ✅ Implementiere in richtiger Reihenfolge
- ✅ Verwende Protocols für lose Kopplung
- ✅ Dependency Injection für Testbarkeit

### Risiko 3: State Synchronisation (MITTEL)
**Problem:** State muss zwischen Coordinators synchron bleiben

**Mitigation:**
- ✅ Verwende Combine Publishers
- ✅ Single Source of Truth Pattern
- ✅ Event-driven Communication
- ✅ Dokumentiere State Flow

### Risiko 4: Performance Degradation (NIEDRIG)
**Problem:** Mehr Objects = mehr Memory/CPU?

**Mitigation:**
- ✅ Profile mit Instruments
- ✅ Lazy Initialization wo möglich
- ✅ Weak References wo sinnvoll
- ✅ Benchmark vor/nach

### Risiko 5: Zeitüberschreitung (MITTEL)
**Problem:** 35-45h ist viel Arbeit

**Mitigation:**
- ✅ Priorisiere P0 Coordinators
- ✅ P2/P3 können später kommen
- ✅ WorkoutStoreCoordinator erst am Ende
- ✅ Regelmäßige Commits für Rollback

---

## 📚 Hilfreiche Ressourcen

### Apple Documentation
- [Coordinator Pattern in SwiftUI](https://developer.apple.com/documentation/swiftui)
- [ObservableObject](https://developer.apple.com/documentation/combine/observableobject)
- [EnvironmentObject](https://developer.apple.com/documentation/swiftui/environmentobject)

### Project Documentation
- `CLAUDE.md` - Project overview
- `DOCUMENTATION.md` - Technical docs
- `VIEWS_DOCUMENTATION.md` - View catalog
- `MODULARIZATION_PLAN.md` - Original plan

### Code Locations
- WorkoutStore: `GymTracker/ViewModels/WorkoutStore.swift`
- Services: `GymTracker/Services/`
- Views: `GymTracker/Views/`
- Coordinators: `GymTracker/Coordinators/` (zu erstellen)

---

## 🎯 Quick Start Guide für nächste Session

### Vor dem Start
1. ✅ Lies diesen Plan komplett durch
2. ✅ Review WorkoutStore.swift (~2,177 Zeilen)
3. ✅ Schaue dir bestehende Services an
4. ✅ Verstehe die View-Hierarchie

### Session Start
1. **Erstelle Coordinator-Ordner:**
   ```bash
   mkdir -p /Users/benkohler/projekte/gym-app/GymTracker/Coordinators
   ```

2. **Starte mit ProfileCoordinator:**
   - Kopiere Template aus diesem Plan
   - Implementiere Schritt für Schritt
   - Teste kontinuierlich

3. **Update PROGRESS.md:**
   - Markiere Tasks als "In Progress"
   - Update nach jedem Coordinator

4. **Commit oft:**
   ```bash
   git add .
   git commit -m "Phase 2.1: Create ProfileCoordinator"
   git push
   ```

### Nach jedem Coordinator
1. ✅ Teste Coordinator isoliert
2. ✅ Migriere 1-2 Views
3. ✅ Teste Views
4. ✅ Commit & Push
5. ✅ Update PROGRESS.md

---

## 🎉 Completion Criteria

Phase 2 gilt als **abgeschlossen**, wenn:

✅ **Alle 9 Coordinators erstellt**
- Jeder Coordinator kompiliert ohne Fehler
- Jeder Coordinator hat vollständige Dokumentation
- Jeder Coordinator hat Unit Tests mit >80% Coverage

✅ **WorkoutStore reduziert**
- Von 2,177 auf ~300 Zeilen
- Nur noch Context Management und Backward Compatibility

✅ **Views migriert**
- Mindestens 50% der Views verwenden Coordinators direkt
- Alle kritischen Views getestet

✅ **Qualitätssicherung**
- Alle Tests grün
- Keine Performance-Regression
- Keine Breaking Changes in UI

✅ **Dokumentation**
- CLAUDE.md updated
- PROGRESS.md updated
- Alle Coordinators dokumentiert

---

**Version:** 1.0  
**Erstellt:** 2025-10-15  
**Autor:** Phase 2 Planning Session  
**Status:** ✅ Ready to Execute

---

**Nächster Schritt:** Starte mit ProfileCoordinator (Phase 2.1) 🚀
