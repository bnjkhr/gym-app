# GymBo v2.0 - Technisches Konzept & Architektur
**Ground-Up Redesign für maximale Qualität**

**Version:** 2.0.0
**Erstellt:** 2025-10-21
**Status:** Design Phase

---

## Inhaltsverzeichnis

1. [Vision & Architektur-Prinzipien](#vision--architektur-prinzipien)
2. [Clean Architecture für iOS](#clean-architecture-für-ios)
3. [Layer-Architektur im Detail](#layer-architektur-im-detail)
4. [Datenfluss-Diagramme](#datenfluss-diagramme)
5. [State Management Strategy](#state-management-strategy)
6. [Dependency Injection Container](#dependency-injection-container)
7. [Error Handling & Resilience](#error-handling--resilience)
8. [Testing Strategy](#testing-strategy)
9. [Performance & Optimization](#performance--optimization)
10. [Migration von v1.x zu v2.0](#migration-von-v1x-zu-v20)
11. [Projektstruktur](#projektstruktur)
12. [Implementation Roadmap](#implementation-roadmap)

---

## Vision & Architektur-Prinzipien

### 🎯 Vision für v2.0

> **"Eine hochperformante, wartbare und testbare iOS-App, die moderne Swift-Patterns nutzt und für Skalierbarkeit gebaut ist."**

### 🏛️ Architektur-Prinzipien (The Sacred Five)

#### 1. **Separation of Concerns**
- Jede Schicht hat **genau eine Verantwortung**
- **Keine** Business Logic in Views
- **Keine** UI-Code in Services
- **Keine** SwiftData-Entities in Business Logic

#### 2. **Dependency Rule**
```
Domain (innerste Schicht) ← Data ← Presentation
     ↑ abhängig von NICHTS     ↑        ↑
     ↑                     abhängig    abhängig
     ↑                     von Domain  von Data+Domain
```

- Innere Schichten wissen **nichts** über äußere Schichten
- Dependencies zeigen **immer nach innen**
- Dependency Inversion via Protocols

#### 3. **Testability First**
- **100% der Business Logic testbar** ohne UI/DB
- Repository Pattern für austauschbare Backends
- Dependency Injection für alle Services
- Mock-freundliche Protokolle

#### 4. **Type Safety & Compile-Time Guarantees**
- Starke Typisierung über Enums statt Strings
- Result Types für fehlerhafte Operationen
- Phantom Types für State Machines
- SwiftUI PreviewProvider für alle Views

#### 5. **Performance by Design**
- Lazy Loading überall
- Async/Await für alle I/O-Operationen
- Structured Concurrency (Swift 5.5+)
- Caching als First-Class Citizen
- Actor Isolation für Thread Safety

---

## Clean Architecture für iOS

### 🏗️ 4-Layer Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                        │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   SwiftUI    │  │  ViewModels  │  │  Coordinators│       │
│  │    Views     │◄─┤   (Stores)   │◄─┤  (Navigation)│       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│         │                  │                                  │
│         └──────────────────┼──────────────────────────────────┤
│                            ▼                                  │
├──────────────────────────────────────────────────────────────┤
│                      DOMAIN LAYER                             │
│                   (Pure Swift, No Frameworks)                 │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Entities   │  │  Use Cases   │  │ Repository   │       │
│  │ (Models)     │  │ (Interactors)│  │  Protocols   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│         ▲                  ▲                  ▲              │
│         │                  │                  │              │
├─────────┼──────────────────┼──────────────────┼──────────────┤
│         │                  │                  │              │
│         ▼                  ▼                  ▼              │
│                       DATA LAYER                              │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Repositories │  │  SwiftData   │  │   Network    │       │
│  │(Implementat.)│  │   Entities   │  │     API      │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│         │                  │                  │              │
├─────────┼──────────────────┼──────────────────┼──────────────┤
│         │                  │                  │              │
│         ▼                  ▼                  ▼              │
│                   INFRASTRUCTURE LAYER                        │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   SwiftData  │  │   HealthKit  │  │  UserDefaults│       │
│  │   Container  │  │     Store    │  │   Keychain   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└──────────────────────────────────────────────────────────────┘
```

### Layer-Verantwortlichkeiten

| Layer | Verantwortung | Frameworks | Testbar |
|-------|---------------|------------|---------|
| **Presentation** | UI, User Interaction, Navigation | SwiftUI | ✅ (Preview) |
| **Domain** | Business Logic, Entities, Contracts | Pure Swift | ✅✅✅ (100%) |
| **Data** | Data Access, Mapping, Caching | SwiftData | ✅ (Mock) |
| **Infrastructure** | External Services, Frameworks | HealthKit, etc. | ✅ (Mock) |

---

## Layer-Architektur im Detail

### 1️⃣ Domain Layer (Core Business Logic)

**Ziel:** Kein Framework-Dependency, 100% testbar

#### 1.1 Entities (Domain Models)

```swift
// Domain/Entities/Workout.swift

/// Pure Swift struct - no SwiftData, no UIKit
struct Workout: Identifiable, Equatable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExercise]
    var defaultRestTime: TimeInterval
    var isFavorite: Bool
    var folder: WorkoutFolder?

    // Computed Properties (Business Logic)
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }

    var estimatedDuration: TimeInterval {
        // Business Logic hier
        let exerciseTime = exercises.count * 180 // 3min per exercise
        let restTime = exercises.count * Int(defaultRestTime)
        return TimeInterval(exerciseTime + restTime)
    }

    // Domain Logic
    func canAddExercise(_ exercise: Exercise) -> Result<Void, WorkoutError> {
        guard exercises.count < 15 else {
            return .failure(.exerciseLimitReached)
        }
        guard !exercises.contains(where: { $0.exercise.id == exercise.id }) else {
            return .failure(.duplicateExercise)
        }
        return .success(())
    }
}

enum WorkoutError: Error {
    case exerciseLimitReached
    case duplicateExercise
    case invalidConfiguration
}
```

#### 1.2 Use Cases (Business Operations)

```swift
// Domain/UseCases/StartWorkoutSessionUseCase.swift

/// Use Case = Single Business Operation
protocol StartWorkoutSessionUseCaseProtocol {
    func execute(workoutId: UUID) async -> Result<WorkoutSession, WorkoutSessionError>
}

final class StartWorkoutSessionUseCase: StartWorkoutSessionUseCaseProtocol {

    // Dependencies (injected via protocols)
    private let workoutRepository: WorkoutRepositoryProtocol
    private let sessionRepository: SessionRepositoryProtocol
    private let healthKitService: HealthKitServiceProtocol

    init(
        workoutRepository: WorkoutRepositoryProtocol,
        sessionRepository: SessionRepositoryProtocol,
        healthKitService: HealthKitServiceProtocol
    ) {
        self.workoutRepository = workoutRepository
        self.sessionRepository = sessionRepository
        self.healthKitService = healthKitService
    }

    func execute(workoutId: UUID) async -> Result<WorkoutSession, WorkoutSessionError> {
        // 1. Validate workout exists
        let workoutResult = await workoutRepository.fetch(id: workoutId)
        guard case .success(let workout) = workoutResult else {
            return .failure(.workoutNotFound)
        }

        // 2. Check prerequisites
        guard await sessionRepository.activeSession() == nil else {
            return .failure(.sessionAlreadyActive)
        }

        // 3. Create session
        let session = WorkoutSession.create(from: workout)

        // 4. Persist session
        let saveResult = await sessionRepository.save(session)
        guard case .success = saveResult else {
            return .failure(.persistenceFailed)
        }

        // 5. Start HealthKit tracking (fire-and-forget)
        Task {
            await healthKitService.startWorkoutSession(for: session)
        }

        return .success(session)
    }
}

enum WorkoutSessionError: Error {
    case workoutNotFound
    case sessionAlreadyActive
    case persistenceFailed
    case healthKitUnavailable
}
```

#### 1.3 Repository Protocols (Contracts)

```swift
// Domain/Repositories/WorkoutRepositoryProtocol.swift

/// Protocol in Domain Layer - Implementation in Data Layer
protocol WorkoutRepositoryProtocol {
    func fetch(id: UUID) async -> Result<Workout, RepositoryError>
    func fetchAll() async -> Result<[Workout], RepositoryError>
    func save(_ workout: Workout) async -> Result<Void, RepositoryError>
    func delete(id: UUID) async -> Result<Void, RepositoryError>
    func observe() -> AsyncStream<[Workout]>
}

enum RepositoryError: Error {
    case notFound
    case persistenceFailed
    case invalidData
    case permissionDenied
}
```

---

### 2️⃣ Data Layer (Data Access & Mapping)

**Ziel:** Framework-Isolation, testbar via Mocks

#### 2.1 Repository Implementation

```swift
// Data/Repositories/SwiftDataWorkoutRepository.swift

final class SwiftDataWorkoutRepository: WorkoutRepositoryProtocol {

    private let context: ModelContext
    private let mapper: WorkoutMapper

    init(context: ModelContext, mapper: WorkoutMapper = .init()) {
        self.context = context
        self.mapper = mapper
    }

    func fetch(id: UUID) async -> Result<Workout, RepositoryError> {
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            guard let entity = try context.fetch(descriptor).first else {
                return .failure(.notFound)
            }
            let workout = mapper.toDomain(entity)
            return .success(workout)
        } catch {
            return .failure(.persistenceFailed)
        }
    }

    func observe() -> AsyncStream<[Workout]> {
        AsyncStream { continuation in
            Task { @MainActor in
                // SwiftData observation
                for await _ in context.changes(for: WorkoutEntity.self) {
                    let result = await self.fetchAll()
                    if case .success(let workouts) = result {
                        continuation.yield(workouts)
                    }
                }
            }
        }
    }
}
```

#### 2.2 Mapper (Entity ↔ Domain)

```swift
// Data/Mappers/WorkoutMapper.swift

struct WorkoutMapper {

    /// SwiftData Entity → Domain Model
    func toDomain(_ entity: WorkoutEntity) -> Workout {
        Workout(
            id: entity.id,
            name: entity.name,
            exercises: entity.exercises
                .sorted(by: { $0.order < $1.order })
                .compactMap { exerciseMapper.toDomain($0) },
            defaultRestTime: entity.defaultRestTime,
            isFavorite: entity.isFavorite,
            folder: entity.folder.map { folderMapper.toDomain($0) }
        )
    }

    /// Domain Model → SwiftData Entity
    func toEntity(_ workout: Workout, context: ModelContext) -> WorkoutEntity {
        let entity = WorkoutEntity(
            id: workout.id,
            name: workout.name,
            defaultRestTime: workout.defaultRestTime,
            isFavorite: workout.isFavorite
        )

        // Map exercises
        for (index, workoutExercise) in workout.exercises.enumerated() {
            let exerciseEntity = exerciseMapper.toEntity(workoutExercise, context: context)
            exerciseEntity.order = index
            entity.exercises.append(exerciseEntity)
        }

        return entity
    }
}
```

#### 2.3 Caching Layer

```swift
// Data/Cache/CacheService.swift

actor CacheService<Key: Hashable, Value> {

    private var cache: [Key: CachedValue] = [:]

    struct CachedValue {
        let value: Value
        let timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    func get(_ key: Key) -> Value? {
        guard let cached = cache[key], !cached.isExpired else {
            cache.removeValue(forKey: key)
            return nil
        }
        return cached.value
    }

    func set(_ key: Key, value: Value, ttl: TimeInterval = 300) {
        cache[key] = CachedValue(value: value, timestamp: Date(), ttl: ttl)
    }

    func invalidate(_ key: Key) {
        cache.removeValue(forKey: key)
    }

    func invalidateAll() {
        cache.removeAll()
    }
}
```

---

### 3️⃣ Presentation Layer (UI & State)

**Ziel:** Dumb Views, Smart ViewModels

#### 3.1 Feature Store Pattern

```swift
// Presentation/Stores/SessionStore.swift

@MainActor
final class SessionStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var state: State = .idle
    @Published private(set) var activeSession: WorkoutSession?
    @Published private(set) var error: WorkoutSessionError?

    // MARK: - State Machine

    enum State {
        case idle
        case starting
        case active
        case paused
        case ending
        case error(WorkoutSessionError)
    }

    // MARK: - Dependencies (Injected)

    private let startSessionUseCase: StartWorkoutSessionUseCaseProtocol
    private let endSessionUseCase: EndWorkoutSessionUseCaseProtocol
    private let updateSessionUseCase: UpdateWorkoutSessionUseCaseProtocol

    init(
        startSessionUseCase: StartWorkoutSessionUseCaseProtocol,
        endSessionUseCase: EndWorkoutSessionUseCaseProtocol,
        updateSessionUseCase: UpdateWorkoutSessionUseCaseProtocol
    ) {
        self.startSessionUseCase = startSessionUseCase
        self.endSessionUseCase = endSessionUseCase
        self.updateSessionUseCase = updateSessionUseCase
    }

    // MARK: - Public Interface

    func startSession(workoutId: UUID) async {
        state = .starting

        let result = await startSessionUseCase.execute(workoutId: workoutId)

        switch result {
        case .success(let session):
            activeSession = session
            state = .active

        case .failure(let error):
            self.error = error
            state = .error(error)
        }
    }

    func completeSet(_ setIndex: Int, for exerciseIndex: Int) async {
        guard var session = activeSession else { return }

        // Update local state
        session.exercises[exerciseIndex].sets[setIndex].completed = true
        activeSession = session

        // Persist in background
        Task.detached(priority: .background) { [weak self] in
            await self?.updateSessionUseCase.execute(session: session)
        }
    }
}
```

#### 3.2 Dumb Views (Presentation Only)

```swift
// Presentation/Views/ActiveWorkoutView.swift

struct ActiveWorkoutView: View {

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var restTimerStore: RestTimerStore

    var body: some View {
        switch sessionStore.state {
        case .idle:
            EmptyStateView()

        case .starting:
            ProgressView("Starting workout...")

        case .active:
            if let session = sessionStore.activeSession {
                WorkoutSessionContent(session: session)
            }

        case .paused:
            PausedStateView()

        case .ending:
            ProgressView("Saving workout...")

        case .error(let error):
            ErrorView(error: error)
        }
    }
}

// Extracted Sub-View (testbar via PreviewProvider)
struct WorkoutSessionContent: View {
    let session: WorkoutSession

    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        TabView {
            ForEach(session.exercises.indices, id: \.self) { index in
                ExerciseView(
                    exercise: session.exercises[index],
                    onSetCompleted: { setIndex in
                        Task {
                            await sessionStore.completeSet(setIndex, for: index)
                        }
                    }
                )
            }
        }
        .tabViewStyle(.page)
    }
}
```

---

### 4️⃣ Infrastructure Layer (Framework Isolation)

#### 4.1 HealthKit Service

```swift
// Infrastructure/HealthKit/HealthKitService.swift

protocol HealthKitServiceProtocol {
    func requestPermissions() async -> Result<Void, HealthKitError>
    func startWorkoutSession(for session: WorkoutSession) async
    func endWorkoutSession() async
    func observeHeartRate() -> AsyncStream<Int>
}

final class HealthKitService: HealthKitServiceProtocol {

    private let healthStore = HKHealthStore()
    private var workoutBuilder: HKLiveWorkoutBuilder?

    func startWorkoutSession(for session: WorkoutSession) async {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        do {
            let workoutSession = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            workoutBuilder = workoutSession.associatedWorkoutBuilder()

            workoutSession.startActivity(with: Date())
            try await workoutBuilder?.beginCollection(at: Date())
        } catch {
            // Error handling
        }
    }

    func observeHeartRate() -> AsyncStream<Int> {
        AsyncStream { continuation in
            let heartRateType = HKQuantityType.quantityType(
                forIdentifier: .heartRate
            )!

            let query = HKAnchoredObjectQuery(
                type: heartRateType,
                predicate: nil,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { query, samples, deletedObjects, anchor, error in
                guard let samples = samples as? [HKQuantitySample] else { return }

                let heartRates = samples.compactMap { sample -> Int? in
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    return Int(sample.quantity.doubleValue(for: unit))
                }

                if let latest = heartRates.last {
                    continuation.yield(latest)
                }
            }

            healthStore.execute(query)
        }
    }
}
```

---

## Datenfluss-Diagramme

### 🔄 Unidirektionaler Datenfluss (Redux-Style)

```
┌─────────────────────────────────────────────────────────┐
│                      USER ACTION                         │
│                 (Button Tap, Gesture)                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  View dispatches      │
         │  Intent/Action        │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   Store receives      │
         │   action              │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   Store calls         │
         │   Use Case            │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Use Case executes    │
         │  business logic       │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Use Case calls       │
         │  Repository           │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Repository accesses  │
         │  SwiftData/HealthKit  │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Result returned      │
         │  up the chain         │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Store updates        │
         │  @Published state     │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  SwiftUI rerenders    │
         │  automatically        │
         └───────────────────────┘
```

### 📊 Beispiel: Session Start Flow

```
┌─────────────────────────────────────────────────────────────┐
│  USER: Taps "Start Workout" Button                          │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  WorkoutDetailView                                           │
│  ────────────────                                            │
│  Button("Start") {                                           │
│      Task {                                                  │
│          await sessionStore.startSession(workoutId: id)      │
│      }                                                       │
│  }                                                           │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  SessionStore (@MainActor)                                   │
│  ────────────────────────                                    │
│  func startSession(workoutId: UUID) async {                  │
│      state = .starting                                       │
│      let result = await startSessionUseCase.execute(id)      │
│      // ... handle result                                    │
│  }                                                           │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  StartWorkoutSessionUseCase                                  │
│  ───────────────────────────                                 │
│  1. Validate workout exists                                  │
│  2. Check no active session                                  │
│  3. Create WorkoutSession                                    │
│  4. Persist via repository                                   │
│  5. Start HealthKit tracking                                 │
│  6. Return Result<WorkoutSession, Error>                     │
└────────────┬────────────────────────────────────────────────┘
             │
             ├──────────────────┬──────────────────────────────┐
             ▼                  ▼                              ▼
┌──────────────────┐  ┌─────────────────┐  ┌──────────────────┐
│WorkoutRepository │  │SessionRepository│  │HealthKitService  │
│──────────────────│  │─────────────────│  │──────────────────│
│fetch(id)         │  │save(session)    │  │startSession()    │
└────────┬─────────┘  └────────┬────────┘  └────────┬─────────┘
         │                     │                     │
         ▼                     ▼                     ▼
┌──────────────────┐  ┌─────────────────┐  ┌──────────────────┐
│  SwiftData       │  │  SwiftData      │  │  HKHealthStore   │
│  ModelContext    │  │  ModelContext   │  │  (HealthKit)     │
└──────────────────┘  └─────────────────┘  └──────────────────┘
         │                     │                     │
         └─────────────────────┴─────────────────────┘
                               │
                               ▼
                     ┌──────────────────┐
                     │ Result returned  │
                     │ to Use Case      │
                     └─────────┬────────┘
                               │
                               ▼
                     ┌──────────────────┐
                     │ Use Case returns │
                     │ to Store         │
                     └─────────┬────────┘
                               │
                               ▼
                     ┌──────────────────┐
                     │ Store updates    │
                     │ @Published state │
                     └─────────┬────────┘
                               │
                               ▼
                     ┌──────────────────┐
                     │ View rerenders   │
                     │ automatically    │
                     └──────────────────┘
```

---

## State Management Strategy

### 🎭 Feature-Based State Stores

Jeder Store ist verantwortlich für **genau einen** Feature-Bereich:

| Store | Verantwortung | Published State |
|-------|---------------|-----------------|
| `SessionStore` | Active Workout Sessions | `activeSession`, `state` |
| `WorkoutStore` | Workout Library | `workouts`, `favorites` |
| `ExerciseStore` | Exercise Catalog | `exercises`, `filters` |
| `StatisticsStore` | Analytics & Stats | `statistics`, `charts` |
| `ProfileStore` | User Profile | `profile`, `preferences` |
| `RestTimerStore` | Rest Timer | `timerState`, `remaining` |

### 🔁 Reactive Updates via Combine

```swift
// Presentation/Stores/StatisticsStore.swift

@MainActor
final class StatisticsStore: ObservableObject {

    @Published private(set) var weeklyStats: WeeklyStatistics?
    @Published private(set) var isLoading = false

    private let sessionRepository: SessionRepositoryProtocol
    private let cacheService: CacheService<String, WeeklyStatistics>
    private var cancellables = Set<AnyCancellable>()

    init(
        sessionRepository: SessionRepositoryProtocol,
        cacheService: CacheService<String, WeeklyStatistics>
    ) {
        self.sessionRepository = sessionRepository
        self.cacheService = cacheService

        setupObservers()
    }

    private func setupObservers() {
        // Auto-refresh when sessions change
        sessionRepository
            .observe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadWeeklyStats()
                }
            }
            .store(in: &cancellables)
    }

    func loadWeeklyStats() async {
        isLoading = true
        defer { isLoading = false }

        // Check cache first
        if let cached = await cacheService.get("weeklyStats") {
            weeklyStats = cached
            return
        }

        // Compute fresh
        let result = await sessionRepository.fetchThisWeek()

        if case .success(let sessions) = result {
            let stats = WeeklyStatistics.compute(from: sessions)
            weeklyStats = stats

            // Cache for 5 minutes
            await cacheService.set("weeklyStats", value: stats, ttl: 300)
        }
    }
}
```

### 🏪 Global App State (Minimal)

```swift
// Presentation/AppState.swift

/// Minimal global state - most state is feature-scoped
@MainActor
final class AppState: ObservableObject {

    // Stores (injected)
    let sessionStore: SessionStore
    let workoutStore: WorkoutStore
    let exerciseStore: ExerciseStore
    let statisticsStore: StatisticsStore
    let profileStore: ProfileStore
    let restTimerStore: RestTimerStore

    // Global UI State
    @Published var selectedTab: Tab = .home
    @Published var isShowingOnboarding = false

    enum Tab {
        case home, workouts, statistics, profile
    }

    init(container: DependencyContainer) {
        self.sessionStore = container.resolve()
        self.workoutStore = container.resolve()
        self.exerciseStore = container.resolve()
        self.statisticsStore = container.resolve()
        self.profileStore = container.resolve()
        self.restTimerStore = container.resolve()
    }
}
```

---

## Dependency Injection Container

### 🏗️ Service Locator Pattern

```swift
// Infrastructure/DI/DependencyContainer.swift

final class DependencyContainer {

    // MARK: - Singletons

    private let modelContext: ModelContext
    private let healthKitService: HealthKitServiceProtocol

    // MARK: - Cache

    private var factories: [String: Any] = [:]
    private var singletons: [String: Any] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.healthKitService = HealthKitService()

        registerDependencies()
    }

    // MARK: - Registration

    private func registerDependencies() {
        // Repositories
        register(WorkoutRepositoryProtocol.self) { container in
            SwiftDataWorkoutRepository(context: container.modelContext)
        }

        register(SessionRepositoryProtocol.self) { container in
            SwiftDataSessionRepository(context: container.modelContext)
        }

        // Use Cases
        register(StartWorkoutSessionUseCaseProtocol.self) { container in
            StartWorkoutSessionUseCase(
                workoutRepository: container.resolve(),
                sessionRepository: container.resolve(),
                healthKitService: container.healthKitService
            )
        }

        // Stores (Singletons!)
        registerSingleton(SessionStore.self) { container in
            SessionStore(
                startSessionUseCase: container.resolve(),
                endSessionUseCase: container.resolve(),
                updateSessionUseCase: container.resolve()
            )
        }
    }

    // MARK: - Resolution

    func resolve<T>() -> T {
        let key = String(describing: T.self)

        // Check singletons first
        if let singleton = singletons[key] as? T {
            return singleton
        }

        // Create from factory
        guard let factory = factories[key] as? (DependencyContainer) -> T else {
            fatalError("No factory registered for \(key)")
        }

        return factory(self)
    }

    // MARK: - Helpers

    private func register<T>(_ type: T.Type, factory: @escaping (DependencyContainer) -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }

    private func registerSingleton<T>(_ type: T.Type, factory: @escaping (DependencyContainer) -> T) {
        let key = String(describing: type)
        factories[key] = factory

        // Create singleton immediately
        singletons[key] = factory(self)
    }
}
```

### 🎯 Usage in App

```swift
// GymTrackerApp.swift

@main
struct GymTrackerApp: App {

    @StateObject private var appState: AppState

    init() {
        // Create DI Container
        let container = DependencyContainer(modelContext: Self.modelContext)

        // Create AppState with injected dependencies
        _appState = StateObject(wrappedValue: AppState(container: container))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.sessionStore)
                .environmentObject(appState.workoutStore)
                // ... inject all stores
        }
    }
}
```

---

## Error Handling & Resilience

### 🎯 Type-Safe Errors

```swift
// Domain/Errors/DomainErrors.swift

/// Domain-level errors
enum WorkoutSessionError: LocalizedError {
    case workoutNotFound
    case sessionAlreadyActive
    case invalidConfiguration
    case persistenceFailed
    case healthKitUnavailable

    var errorDescription: String? {
        switch self {
        case .workoutNotFound:
            return "Das Workout konnte nicht gefunden werden"
        case .sessionAlreadyActive:
            return "Es läuft bereits eine aktive Session"
        case .invalidConfiguration:
            return "Workout-Konfiguration ist ungültig"
        case .persistenceFailed:
            return "Fehler beim Speichern der Session"
        case .healthKitUnavailable:
            return "HealthKit ist nicht verfügbar"
        }
    }
}

/// Repository errors
enum RepositoryError: Error {
    case notFound
    case persistenceFailed
    case invalidData
    case permissionDenied
    case networkUnavailable
}
```

### 🛡️ Resilience Patterns

#### 1. Retry with Exponential Backoff

```swift
// Infrastructure/Resilience/RetryPolicy.swift

struct RetryPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval

    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var attempt = 0
        var delay = baseDelay

        while attempt < maxAttempts {
            do {
                return try await operation()
            } catch {
                attempt += 1

                guard attempt < maxAttempts else {
                    throw error
                }

                // Exponential backoff: 1s, 2s, 4s, 8s
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2
            }
        }

        fatalError("Unreachable")
    }
}

// Usage
let result = try await RetryPolicy(maxAttempts: 3, baseDelay: 1.0)
    .execute {
        try await healthKitService.fetchHeartRate()
    }
```

#### 2. Circuit Breaker

```swift
// Infrastructure/Resilience/CircuitBreaker.swift

actor CircuitBreaker {

    enum State {
        case closed      // Normal operation
        case open        // Failing, reject calls
        case halfOpen    // Testing if recovered
    }

    private var state: State = .closed
    private var failureCount = 0
    private let failureThreshold = 5
    private let timeout: TimeInterval = 60
    private var lastFailureTime: Date?

    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        switch state {
        case .open:
            // Check if timeout passed
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout {
                state = .halfOpen
            } else {
                throw CircuitBreakerError.circuitOpen
            }

        case .halfOpen, .closed:
            break
        }

        do {
            let result = try await operation()

            // Success - reset or close
            if state == .halfOpen {
                state = .closed
                failureCount = 0
            }

            return result

        } catch {
            failureCount += 1
            lastFailureTime = Date()

            if failureCount >= failureThreshold {
                state = .open
            }

            throw error
        }
    }
}
```

---

## Testing Strategy

### 🧪 Test Pyramid

```
        ┌─────────────────┐
        │   UI Tests      │  5%   - Critical User Flows
        │   (SwiftUI)     │
        ├─────────────────┤
        │ Integration     │  25%  - Feature Tests
        │   Tests         │       (Store + UseCase + Repo)
        ├─────────────────┤
        │  Unit Tests     │  70%  - Business Logic
        │  (Use Cases,    │       (Use Cases, Entities)
        │   Domain)       │
        └─────────────────┘
```

### ✅ Testbare Architektur

#### 1. Use Case Testing (Pure Business Logic)

```swift
// DomainTests/UseCases/StartWorkoutSessionUseCaseTests.swift

final class StartWorkoutSessionUseCaseTests: XCTestCase {

    var sut: StartWorkoutSessionUseCase!
    var mockWorkoutRepo: MockWorkoutRepository!
    var mockSessionRepo: MockSessionRepository!
    var mockHealthKit: MockHealthKitService!

    override func setUp() {
        mockWorkoutRepo = MockWorkoutRepository()
        mockSessionRepo = MockSessionRepository()
        mockHealthKit = MockHealthKitService()

        sut = StartWorkoutSessionUseCase(
            workoutRepository: mockWorkoutRepo,
            sessionRepository: mockSessionRepo,
            healthKitService: mockHealthKit
        )
    }

    func test_startSession_withValidWorkout_succeeds() async {
        // Given
        let workout = Workout.fixture()
        mockWorkoutRepo.fetchResult = .success(workout)
        mockSessionRepo.activeSessionResult = nil
        mockSessionRepo.saveResult = .success(())

        // When
        let result = await sut.execute(workoutId: workout.id)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(mockSessionRepo.saveCallCount, 1)
        XCTAssertEqual(mockHealthKit.startSessionCallCount, 1)
    }

    func test_startSession_whenSessionActive_fails() async {
        // Given
        mockWorkoutRepo.fetchResult = .success(.fixture())
        mockSessionRepo.activeSessionResult = .fixture() // Active session exists!

        // When
        let result = await sut.execute(workoutId: UUID())

        // Then
        guard case .failure(let error) = result else {
            XCTFail("Expected failure")
            return
        }
        XCTAssertEqual(error, .sessionAlreadyActive)
    }
}

// Test Helpers
extension Workout {
    static func fixture(
        id: UUID = UUID(),
        name: String = "Test Workout",
        exercises: [WorkoutExercise] = []
    ) -> Workout {
        Workout(
            id: id,
            name: name,
            exercises: exercises,
            defaultRestTime: 90,
            isFavorite: false
        )
    }
}
```

#### 2. Mock Repositories

```swift
// DomainTests/Mocks/MockWorkoutRepository.swift

final class MockWorkoutRepository: WorkoutRepositoryProtocol {

    var fetchResult: Result<Workout, RepositoryError> = .failure(.notFound)
    var fetchAllResult: Result<[Workout], RepositoryError> = .success([])
    var saveResult: Result<Void, RepositoryError> = .success(())

    var fetchCallCount = 0
    var saveCallCount = 0

    func fetch(id: UUID) async -> Result<Workout, RepositoryError> {
        fetchCallCount += 1
        return fetchResult
    }

    func fetchAll() async -> Result<[Workout], RepositoryError> {
        return fetchAllResult
    }

    func save(_ workout: Workout) async -> Result<Void, RepositoryError> {
        saveCallCount += 1
        return saveResult
    }

    func delete(id: UUID) async -> Result<Void, RepositoryError> {
        return .success(())
    }

    func observe() -> AsyncStream<[Workout]> {
        AsyncStream { _ in }
    }
}
```

#### 3. Integration Testing (Store + Use Case)

```swift
// PresentationTests/Stores/SessionStoreTests.swift

@MainActor
final class SessionStoreTests: XCTestCase {

    var sut: SessionStore!
    var mockStartUseCase: MockStartSessionUseCase!

    override func setUp() async throws {
        mockStartUseCase = MockStartSessionUseCase()

        sut = SessionStore(
            startSessionUseCase: mockStartUseCase,
            endSessionUseCase: MockEndSessionUseCase(),
            updateSessionUseCase: MockUpdateSessionUseCase()
        )
    }

    func test_startSession_updatesStateToActive() async {
        // Given
        let session = WorkoutSession.fixture()
        mockStartUseCase.result = .success(session)

        // When
        await sut.startSession(workoutId: UUID())

        // Then
        XCTAssertEqual(sut.state, .active)
        XCTAssertEqual(sut.activeSession, session)
    }

    func test_startSession_onError_updatesStateToError() async {
        // Given
        mockStartUseCase.result = .failure(.workoutNotFound)

        // When
        await sut.startSession(workoutId: UUID())

        // Then
        if case .error(let error) = sut.state {
            XCTAssertEqual(error, .workoutNotFound)
        } else {
            XCTFail("Expected error state")
        }
    }
}
```

#### 4. UI Testing (Critical Flows)

```swift
// UITests/WorkoutSessionUITests.swift

final class WorkoutSessionUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func test_startWorkout_completesFullSession() {
        // Navigate to workout
        app.buttons["Workouts"].tap()
        app.buttons["Push Day"].tap()

        // Start session
        app.buttons["Start Workout"].tap()

        // Verify session started
        XCTAssertTrue(app.staticTexts["Push Day"].exists)
        XCTAssertTrue(app.buttons["Complete Set"].exists)

        // Complete first set
        app.buttons["Complete Set"].firstMatch.tap()

        // Verify rest timer started
        XCTAssertTrue(app.staticTexts["Rest Timer"].exists)

        // End session
        app.buttons["End Workout"].tap()
        app.buttons["Save"].tap()

        // Verify back to home
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
    }
}
```

---

## Performance & Optimization

### ⚡ Performance Targets

| Metrik | Target | Measurement |
|--------|--------|-------------|
| App Launch | < 1.5s | Time to first frame |
| Workout Start | < 300ms | Tap to view transition |
| Statistics Load | < 500ms | Data fetch + render |
| Rest Timer Start | < 100ms | Instant feedback |
| SwiftData Query | < 50ms | Average fetch time |
| Memory Usage | < 150MB | During active session |

### 🚀 Optimization Strategies

#### 1. Lazy Loading

```swift
// Presentation/Views/WorkoutListView.swift

struct WorkoutListView: View {

    @EnvironmentObject var workoutStore: WorkoutStore

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(workoutStore.workouts) { workout in
                WorkoutRow(workout: workout)
                    .onAppear {
                        // Pagination trigger
                        if workout.id == workoutStore.workouts.last?.id {
                            Task {
                                await workoutStore.loadMore()
                            }
                        }
                    }
            }
        }
    }
}
```

#### 2. Prefetching

```swift
// Data/Repositories/SwiftDataWorkoutRepository.swift

func prefetch(ids: [UUID]) async {
    let descriptor = FetchDescriptor<WorkoutEntity>(
        predicate: #Predicate { entity in
            ids.contains(entity.id)
        }
    )

    // Load into context cache
    _ = try? context.fetch(descriptor)
}
```

#### 3. Background Processing

```swift
// Domain/UseCases/CalculateStatisticsUseCase.swift

func execute() async -> Result<Statistics, Error> {
    // Heavy computation on background thread
    let statistics = await Task.detached(priority: .utility) {
        // CPU-intensive calculations
        self.computeVolumeCharts()
        self.analyzeMuscleBalance()
        self.detectPlateaus()

        return Statistics(/* ... */)
    }.value

    return .success(statistics)
}
```

#### 4. Debouncing

```swift
// Presentation/Stores/SearchStore.swift

@MainActor
final class SearchStore: ObservableObject {

    @Published var searchText = ""
    @Published var results: [Exercise] = []

    private var searchTask: Task<Void, Never>?

    init() {
        $searchText
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.performSearch(text)
            }
            .store(in: &cancellables)
    }

    private func performSearch(_ query: String) {
        // Cancel previous search
        searchTask?.cancel()

        searchTask = Task {
            let result = await searchUseCase.execute(query: query)

            if case .success(let exercises) = result {
                self.results = exercises
            }
        }
    }
}
```

---

## Migration von v1.x zu v2.0

### 🔄 Migrations-Strategie: **Strangler Fig Pattern**

**Idee:** Schrittweise Migration, nicht Big Bang Rewrite

```
v1.x Code (Legacy)          v2.0 Code (New)
┌─────────────────┐         ┌─────────────────┐
│  WorkoutStore   │───────→ │  SessionStore   │
│  (Monolith)     │         │  WorkoutStore   │
│                 │         │  ExerciseStore  │
│                 │         │  etc.           │
└─────────────────┘         └─────────────────┘

Phase 1: Extract SessionStore
Phase 2: Extract WorkoutStore
Phase 3: Extract remaining stores
Phase 4: Remove old WorkoutStore
```

### 📋 Migration Checklist

#### Phase 1: Foundation (Woche 1-2)

- [ ] **Setup neue Ordnerstruktur**
  ```
  GymTracker/
  ├── Domain/
  │   ├── Entities/
  │   ├── UseCases/
  │   └── Repositories/ (protocols)
  ├── Data/
  │   ├── Repositories/ (implementations)
  │   ├── Mappers/
  │   └── Cache/
  ├── Presentation/
  │   ├── Stores/
  │   └── Views/
  └── Infrastructure/
      ├── DI/
      ├── HealthKit/
      └── Persistence/
  ```

- [ ] **Create DI Container**
- [ ] **Setup Test Infrastructure**
- [ ] **Define Repository Protocols**

#### Phase 2: Core Migration (Woche 3-4)

- [ ] **Migrate Session Management**
  - Extract `SessionStore` from `WorkoutStore`
  - Implement `StartWorkoutSessionUseCase`
  - Implement `EndWorkoutSessionUseCase`
  - Migrate `ActiveWorkoutView` to new store

- [ ] **Migrate Workout Management**
  - Extract `WorkoutStore` (CRUD only)
  - Implement workout use cases
  - Migrate workout views

#### Phase 3: Data Layer (Woche 5-6)

- [ ] **Implement Repositories**
  - `SwiftDataWorkoutRepository`
  - `SwiftDataSessionRepository`
  - `SwiftDataExerciseRepository`

- [ ] **Profile Migration**
  - Migrate from UserDefaults to SwiftData
  - Write migration script
  - Test data preservation

#### Phase 4: Polish & Test (Woche 7-8)

- [ ] **Write Tests**
  - Unit tests for all use cases (70% coverage)
  - Integration tests for stores (25%)
  - UI tests for critical flows (5%)

- [ ] **Performance Testing**
  - Measure app launch time
  - Optimize slow queries
  - Profile memory usage

- [ ] **Code Cleanup**
  - Remove old `WorkoutStore`
  - Delete dead code
  - Update documentation

### 🔧 Migration Tools

#### Data Migration Script

```swift
// Infrastructure/Migration/V1toV2Migration.swift

struct V1toV2Migration {

    let oldContext: ModelContext
    let newContext: ModelContext

    func migrate() async throws {
        print("🔄 Starting migration v1.x → v2.0")

        // 1. Migrate UserProfile (UserDefaults → SwiftData)
        try await migrateUserProfile()

        // 2. Validate SwiftData integrity
        try await validateData()

        // 3. Cleanup old data
        cleanupLegacyData()

        print("✅ Migration complete")
    }

    private func migrateUserProfile() async throws {
        // Check if already migrated
        let descriptor = FetchDescriptor<UserProfileEntity>()
        if try newContext.fetch(descriptor).count > 0 {
            print("ℹ️ Profile already migrated, skipping")
            return
        }

        // Load from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "userProfile"),
              let legacyProfile = try? JSONDecoder().decode(LegacyUserProfile.self, from: data) else {
            print("⚠️ No legacy profile found")
            return
        }

        // Create new entity
        let entity = UserProfileEntity(
            name: legacyProfile.name,
            birthDate: legacyProfile.birthDate,
            weight: legacyProfile.weight,
            height: legacyProfile.height,
            // ... all fields
        )

        newContext.insert(entity)
        try newContext.save()

        // Archive old data (don't delete yet!)
        UserDefaults.standard.set(data, forKey: "userProfile_v1_backup")

        print("✅ User profile migrated")
    }
}
```

---

## Projektstruktur

```
GymTracker/
│
├── Domain/                          # Business Logic (Framework-free)
│   ├── Entities/
│   │   ├── Workout.swift
│   │   ├── Exercise.swift
│   │   ├── WorkoutSession.swift
│   │   └── UserProfile.swift
│   │
│   ├── UseCases/
│   │   ├── Workout/
│   │   │   ├── CreateWorkoutUseCase.swift
│   │   │   ├── UpdateWorkoutUseCase.swift
│   │   │   └── DeleteWorkoutUseCase.swift
│   │   ├── Session/
│   │   │   ├── StartWorkoutSessionUseCase.swift
│   │   │   ├── EndWorkoutSessionUseCase.swift
│   │   │   └── UpdateWorkoutSessionUseCase.swift
│   │   └── Statistics/
│   │       └── CalculateStatisticsUseCase.swift
│   │
│   └── Repositories/                # Protocols only!
│       ├── WorkoutRepositoryProtocol.swift
│       ├── SessionRepositoryProtocol.swift
│       └── ExerciseRepositoryProtocol.swift
│
├── Data/                            # Data Access Layer
│   ├── Repositories/                # Implementations
│   │   ├── SwiftDataWorkoutRepository.swift
│   │   ├── SwiftDataSessionRepository.swift
│   │   └── SwiftDataExerciseRepository.swift
│   │
│   ├── Entities/                    # SwiftData Models
│   │   ├── WorkoutEntity.swift
│   │   ├── ExerciseEntity.swift
│   │   └── WorkoutSessionEntity.swift
│   │
│   ├── Mappers/                     # Entity ↔ Domain
│   │   ├── WorkoutMapper.swift
│   │   ├── ExerciseMapper.swift
│   │   └── SessionMapper.swift
│   │
│   └── Cache/
│       └── CacheService.swift
│
├── Presentation/                    # UI Layer
│   ├── Stores/                      # ViewModels
│   │   ├── SessionStore.swift
│   │   ├── WorkoutStore.swift
│   │   ├── ExerciseStore.swift
│   │   ├── StatisticsStore.swift
│   │   ├── ProfileStore.swift
│   │   └── RestTimerStore.swift
│   │
│   ├── Views/
│   │   ├── Home/
│   │   │   └── WorkoutsHomeView.swift
│   │   ├── Workout/
│   │   │   ├── WorkoutListView.swift
│   │   │   ├── WorkoutDetailView.swift
│   │   │   └── CreateWorkoutView.swift
│   │   ├── Session/
│   │   │   ├── ActiveWorkoutView.swift
│   │   │   └── ExerciseView.swift
│   │   └── Statistics/
│   │       └── StatisticsView.swift
│   │
│   ├── Coordinators/                # Navigation
│   │   ├── AppCoordinator.swift
│   │   ├── WorkoutCoordinator.swift
│   │   └── SessionCoordinator.swift
│   │
│   └── AppState.swift               # Global state
│
├── Infrastructure/                  # Framework Integrations
│   ├── DI/
│   │   └── DependencyContainer.swift
│   │
│   ├── HealthKit/
│   │   └── HealthKitService.swift
│   │
│   ├── Persistence/
│   │   ├── ModelContainerFactory.swift
│   │   └── UserDefaultsService.swift
│   │
│   ├── Migration/
│   │   └── V1toV2Migration.swift
│   │
│   └── Resilience/
│       ├── RetryPolicy.swift
│       └── CircuitBreaker.swift
│
├── Tests/
│   ├── DomainTests/
│   │   ├── Entities/
│   │   ├── UseCases/
│   │   └── Mocks/
│   │
│   ├── PresentationTests/
│   │   └── Stores/
│   │
│   └── UITests/
│       └── WorkoutSessionUITests.swift
│
└── Resources/
    ├── Assets.xcassets
    └── exercises.csv
```

---

## Implementation Roadmap

### 🗓️ 8-Wochen-Plan

#### Sprint 1-2: Foundation (Woche 1-2)
**Ziel:** Neue Architektur aufsetzen, DI funktionsfähig

- [ ] Projektstruktur anlegen
- [ ] DI Container implementieren
- [ ] Repository Protocols definieren
- [ ] Test Infrastructure aufsetzen
- [ ] Domain Entities erstellen

**Deliverable:** Leere Architektur, lauffähige App

---

#### Sprint 3-4: Session Management (Woche 3-4)
**Ziel:** Session Flow komplett neu implementiert

- [ ] `SessionStore` extrahieren
- [ ] Use Cases implementieren:
  - `StartWorkoutSessionUseCase`
  - `EndWorkoutSessionUseCase`
  - `UpdateWorkoutSessionUseCase`
- [ ] `SessionRepository` implementieren
- [ ] Views migrieren:
  - `ActiveWorkoutView`
  - `ExerciseView`
- [ ] Unit Tests schreiben (>80% Coverage)

**Deliverable:** Funktionierendes Session Management

---

#### Sprint 5-6: Workout & Exercise Management (Woche 5-6)
**Ziel:** CRUD Operationen für Workouts & Exercises

- [ ] `WorkoutStore` extrahieren
- [ ] `ExerciseStore` extrahieren
- [ ] Use Cases implementieren
- [ ] Repositories implementieren
- [ ] Profile Migration (UserDefaults → SwiftData)
- [ ] Views migrieren

**Deliverable:** Workout-Library funktioniert

---

#### Sprint 7-8: Statistics, Testing, Polish (Woche 7-8)
**Ziel:** Feature-Completion, Performance, Tests

- [ ] `StatisticsStore` implementieren
- [ ] Caching optimieren
- [ ] Performance Profiling
- [ ] Integration Tests
- [ ] UI Tests (Critical Flows)
- [ ] Code Cleanup
- [ ] Alte `WorkoutStore` löschen
- [ ] Documentation Update

**Deliverable:** v2.0 Release Candidate

---

## Zusammenfassung

### ✅ Was wir gewinnen

1. **Testability** - 100% Business Logic testbar
2. **Maintainability** - Klare Layer-Trennung
3. **Scalability** - Neue Features isoliert hinzufügen
4. **Performance** - Optimierte Datenflüsse
5. **Type Safety** - Compile-Time Guarantees
6. **Team Collaboration** - Klare Verantwortlichkeiten

### 🎯 Architektur-Highlights

- ✅ **Clean Architecture** mit 4 Layern
- ✅ **SOLID Principles** durchgängig
- ✅ **Dependency Injection** für alle Services
- ✅ **Repository Pattern** für austauschbare Backends
- ✅ **Use Case Pattern** für Business Logic
- ✅ **Unidirektionaler Datenfluss**
- ✅ **Actor Isolation** für Thread Safety
- ✅ **Async/Await** überall
- ✅ **Type-Safe Errors**
- ✅ **70% Test Coverage**

### 📊 Erfolgsmetriken

| Metrik | v1.x | v2.0 Ziel |
|--------|------|-----------|
| Test Coverage | 15% | **70%+** |
| App Launch | 3-5s | **< 1.5s** |
| Größte Datei | 130KB | **< 30KB** |
| Compile Time | 45s | **< 20s** |
| Tech Debt | Hoch | **Niedrig** |

---

**Let's build the best fitness app! 💪**
