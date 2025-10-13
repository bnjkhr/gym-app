# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**GymBo (GymTracker)** is a native iOS fitness tracking app built with SwiftUI and SwiftData. The app features AI-powered workout coaching, HealthKit integration, Live Activities, and comprehensive workout tracking with 161 predefined exercises.

**Tech Stack:**
- Swift 5.9+, iOS 17.0+
- SwiftUI + SwiftData (persistence)
- HealthKit (health data integration)
- ActivityKit (Live Activities & Dynamic Island)
- Combine (reactive programming)

---

## Build & Development Commands

### Building and Running
```bash
# Open project in Xcode
open GymBo.xcodeproj

# Build in Xcode: Cmd+B
# Run on simulator/device: Cmd+R
# Run tests: Cmd+U
```

**Note:** This is an Xcode project without package managers (no CocoaPods, SPM, or npm). All dependencies are system frameworks.

### Testing on Device
- **HealthKit** and **Live Activities** require a physical iOS device (not available in Simulator)
- Ensure proper signing in Xcode project settings

### First Launch
The app performs automatic database migrations on first launch (~2-5 seconds):
1. Loads 161 exercises from CSV
2. Seeds sample workouts
3. Generates exercise records from existing sessions
4. Populates last-used exercise metrics

---

## Architecture Overview

### MVVM + SwiftUI Hybrid

```
Views (SwiftUI)
    ↓ @Query, @EnvironmentObject
ViewModels (WorkoutStore - Singleton)
    ↓ Business Logic
Services (WorkoutAnalyzer, TipEngine, etc.)
    ↓ Data Access
Data Layer (SwiftData Entities + Domain Models)
```

### Key Architectural Patterns

1. **Separation of Concerns:**
   - **Domain Models** (Structs): `Exercise`, `Workout`, `WorkoutSession` - pure business logic
   - **SwiftData Entities** (@Model): `ExerciseEntity`, `WorkoutEntity`, etc. - persistence layer
   - **Mapping Layer**: Bidirectional conversion between entities and domain models

2. **WorkoutStore as Central ViewModel:**
   - Singleton managing app-wide state (active sessions, rest timer, user profile)
   - Injected into views via `@EnvironmentObject`
   - **Known Technical Debt:** Should be split into smaller services (SessionManager, ProfileManager, TimerManager)

3. **Reactive UI:**
   - SwiftUI views use `@Query` for reactive SwiftData binding
   - `@Published` properties in WorkoutStore trigger UI updates
   - Performance optimizations via `LazyVStack`/`LazyVGrid`

---

## Project Structure

```
GymTracker/
├── GymTrackerApp.swift           # App entry + migrations
├── ContentView.swift             # Root TabView (Home, Workouts, Insights)
├── Models/                       # Domain models (structs)
│   ├── Exercise.swift            # Exercise model + similarity algorithm
│   ├── Workout.swift             # Workout, WorkoutExercise, ExerciseSet
│   ├── WorkoutSession.swift      # Session history
│   ├── TrainingTip.swift         # AI coach tips
│   └── WorkoutPreferences.swift  # Wizard preferences
├── SwiftDataEntities.swift       # @Model persistence entities (7 entities)
├── Workout+SwiftDataMapping.swift # Entity ↔ Domain mapping
├── ViewModels/
│   ├── WorkoutStore.swift        # Central state management (⚠️ 130KB, needs refactoring)
│   ├── Theme.swift               # App theme + colors
│   ├── TipEngine.swift           # AI coach (15 rules)
│   ├── WorkoutAnalyzer.swift     # Training analysis
│   └── TipFeedbackManager.swift  # Tip feedback system
├── Views/                        # 30+ SwiftUI views
│   ├── WorkoutsHomeView.swift    # Home dashboard
│   ├── WorkoutsTabView.swift     # Workout list
│   ├── WorkoutDetailView.swift   # Active session + template view
│   ├── StatisticsView.swift      # Insights with glassmorphism
│   ├── ProfileView.swift         # User profile
│   └── ...
├── Services/                     # Business logic
│   ├── WorkoutAnalyzer.swift     # Plateau detection, muscle balance
│   ├── TipEngine.swift           # AI tip generation
│   └── TipFeedbackManager.swift  # Tip scoring
├── Managers/                     # Infrastructure
│   ├── HealthKitManager.swift    # HealthKit integration
│   ├── NotificationManager.swift # Push notifications
│   ├── AudioManager.swift        # Sound effects
│   └── BackupManager.swift       # Workout export/import
├── LiveActivities/
│   ├── WorkoutActivityAttributes.swift
│   └── WorkoutLiveActivityController.swift
├── Database/
│   └── ModelContainerFactory.swift # Container creation with fallbacks
├── Migrations/                   # Database migrations
│   ├── ExerciseDatabaseMigration.swift
│   ├── ExerciseRecordMigration.swift
│   └── ExerciseLastUsedMigration.swift
├── Seeders/
│   ├── ExerciseSeeder.swift      # CSV → Database (161 exercises)
│   └── WorkoutSeeder.swift       # Sample workouts
└── Resources/
    ├── exercises_with_ids.csv    # Exercise database
    └── workouts_with_ids.csv     # Sample workout templates
```

---

## Key Components & Systems

### 1. SwiftData Persistence

**7 Core Entities:**
- `ExerciseEntity` - 161 predefined exercises with deterministic UUIDs
- `WorkoutEntity` - Workout templates
- `WorkoutSessionEntity` - Training history
- `ExerciseRecordEntity` - Personal records (PRs)
- `UserProfileEntity` - User profile
- `WorkoutExerciseEntity` + `ExerciseSetEntity` - Relationships

**Mapping Strategy:**
- Always use `mapWorkoutEntity()` / `mapExerciseEntity()` from `Workout+SwiftDataMapping.swift`
- Context-based mapping with refetch for fresh state
- Defensive programming with nil-checks and fallbacks

**Performance Considerations:**
- Use `@Query` with predicates for filtering at DB level
- Cache frequently accessed data (see `exerciseStatsCache` in WorkoutStore)
- Use `LazyVStack`/`LazyVGrid` for large lists

### 2. WorkoutStore (Central ViewModel)

**Responsibilities:**
- Active session management (`startSession()`, `endSession()`)
- Rest timer with wall-clock sync (survives background/force quit)
- User profile persistence (via UserDefaults - **Technical Debt**)
- Exercise stats caching
- Home favorites management (max 4 workouts)

**Critical Methods:**
- `startSession(for:)` - Start workout session
- `endSession(for:)` - End session, export to HealthKit
- `startRest(for:duration:)` - Start rest timer with notifications
- `toggleHomeFavorite(workoutID:)` - Toggle favorite with 4-workout limit
- `getExerciseStats(exerciseId:)` - Get cached stats

**Usage Pattern:**
```swift
@EnvironmentObject var store: WorkoutStore

// Always check for modelContext
guard let context = store.modelContext else { return }
```

### 3. AI Coach System

**Components:**
- **WorkoutAnalyzer**: Analyzes training data (plateaus, muscle balance, recovery)
- **TipEngine**: Generates tips using 15 rules across 6 categories
- **TipFeedbackManager**: Tracks user feedback to improve tip relevance

**Tip Categories:**
1. Progression (progressive overload)
2. Balance (muscle group distribution)
3. Recovery (overtraining prevention)
4. Consistency (streak tracking)
5. Goal Alignment (rep ranges)
6. Achievements (PRs, milestones)

**Integration:**
- Tips displayed in `SmartTipsCard` on StatisticsView
- Refresh functionality with feedback system
- Priority-based display (High/Medium/Low)

### 4. HealthKit Integration

**Capabilities:**
- **Read:** Weight, height, birth date, biological sex
- **Write:** Workout sessions, active energy
- **Live:** Heart rate monitoring during workouts

**Key Files:**
- `HealthKitManager.swift` - Authorization & data sync
- `HealthKitWorkoutTracker.swift` - Live workout recording

**Important:**
- All HealthKit operations have 30-second timeout
- Graceful degradation on permission denial
- Always request authorization before use

### 5. Live Activities (iOS 16.1+)

**Features:**
- Dynamic Island integration during active workouts
- Rest timer countdown display
- Heart rate display
- Deep link: `workout://active`

**Controller:**
- `WorkoutLiveActivityController.shared` - Singleton
- Throttling: Max 2 updates/second
- Automatic cleanup of stale activities after force quit

**Synchronization:**
- App checks for active Live Activities on launch
- Restores workout state if Live Activity exists
- Persists workout ID in UserDefaults for restoration

### 6. Database Migrations

**Version Control System:**
```swift
struct DataVersions {
    static let EXERCISE_DATABASE_VERSION = 1
    static let SAMPLE_WORKOUT_VERSION = 2
    static let FORCE_FULL_RESET_VERSION = 2
}
```

**Migration Flow:**
1. Schema validation (check entity compatibility)
2. Force reset (if version bumped - nuclear option)
3. Exercise database update (if CSV changed)
4. Sample workout versioning
5. Exercise records generation
6. Last-used metrics population

**When to Increment Versions:**
- `EXERCISE_DATABASE_VERSION`: When `exercises_with_ids.csv` changes
- `SAMPLE_WORKOUT_VERSION`: When `workouts_with_ids.csv` changes
- `FORCE_FULL_RESET_VERSION`: For breaking schema changes (deletes all data except sessions)

### 7. Rest Timer System

**Features:**
- Wall-clock-based (survives background/app kill)
- Push notifications when timer ends
- Live Activity integration
- Persistent state across app restarts

**Implementation:**
```swift
struct ActiveRestState {
    let workoutId: UUID
    let remainingSeconds: Int
    let endDate: Date?  // Wall-clock time for background sync
    var isRunning: Bool
}
```

**Key Methods:**
- `startRest(for:duration:)` - Starts timer + notification
- `stopRest()` - Cancels timer + notification
- Timer syncs on `onAppear` using wall-clock time

---

## Common Development Patterns

### Working with SwiftData

```swift
// ✅ DO: Use @Query for reactive updates
@Query(
    filter: #Predicate<WorkoutEntity> { $0.isSampleWorkout == false },
    sort: [SortDescriptor(\WorkoutEntity.date, order: .reverse)]
)
private var workouts: [WorkoutEntity]

// ✅ DO: Map entities to domain models
let domainWorkouts = workouts.compactMap { 
    mapWorkoutEntity($0, context: modelContext) 
}

// ✅ DO: Always save after changes
context.insert(entity)
try context.save()

// ❌ DON'T: Access entity properties after deletion
// ❌ DON'T: Keep strong references to entities
```

### Adding New Views

```swift
struct MyNewView: View {
    @EnvironmentObject var store: WorkoutStore
    @Query private var workouts: [WorkoutEntity]
    
    var body: some View {
        // Use LazyVStack for performance
        ScrollView {
            LazyVStack {
                ForEach(workouts) { workout in
                    // Content
                }
            }
        }
        // Apply glassmorphism theme
        .background(AppTheme.backgroundGradient)
    }
}
```

### Adding New Migrations

1. Create migration file in `Migrations/`
2. Add version constant to `DataVersions` in `GymTrackerApp.swift`
3. Add migration step in `performMigrations()` method
4. Use `UserDefaults` to track completion
5. Log progress with `AppLogger`

```swift
private func performMyMigration(context: ModelContext) async {
    let version = UserDefaults.standard.integer(forKey: "myMigrationVersion")
    guard version < DataVersions.MY_MIGRATION_VERSION else { return }
    
    AppLogger.data.info("Running my migration...")
    // Migration logic here
    
    UserDefaults.standard.set(DataVersions.MY_MIGRATION_VERSION, forKey: "myMigrationVersion")
    AppLogger.data.info("✅ My migration complete")
}
```

### Working with Exercise Records

```swift
// Get exercise record
let descriptor = FetchDescriptor<ExerciseRecordEntity>(
    predicate: #Predicate { $0.exerciseId == exerciseId }
)
let record = try? context.fetch(descriptor).first

// Update record with new PR
if let record = record {
    if weight > record.maxWeight {
        record.maxWeight = weight
        record.maxWeightReps = reps
    }
    try context.save()
}
```

### Logging

```swift
// Use AppLogger for structured logging
AppLogger.app.info("App started")
AppLogger.data.error("Failed to save: \(error)")
AppLogger.workouts.debug("Processing workout...")
AppLogger.exercises.warning("Missing exercise data")
AppLogger.liveActivity.info("Live Activity started")
```

---

## Important Constraints & Limitations

### Design Constraints
- **Home Favorites**: Maximum 4 workouts (UI grid limitation)
- **Exercise UUIDs**: Must use deterministic UUIDs (format: `00000000-0000-0000-0000-XXXXXXXXXXXX`)
- **Sample Workouts**: Must have `isSampleWorkout = true` flag

### Technical Limitations
- **Live Activities**: Requires iOS 16.1+ and physical device
- **HealthKit**: Requires physical device for testing
- **User Profile**: Currently stored in UserDefaults (should migrate to SwiftData)

### Known Technical Debt
1. **WorkoutStore**: 130KB file, should be split into multiple services
2. **Profile Persistence**: Uses UserDefaults instead of SwiftData
3. **Unit Tests**: Missing for critical business logic
4. **SpeechRecognizer**: Incomplete implementation

---

## Database Schema Notes

### Exercise Entity Structure
- **161 predefined exercises** loaded from CSV
- **24 muscle groups**: chest, back, shoulders, biceps, triceps, legs, glutes, abs, etc.
- **5 equipment types**: freeWeights, machine, bodyweight, cable, mixed
- **3 difficulty levels**: anfänger, fortgeschritten, profi

### Deterministic UUIDs
Exercises use deterministic UUIDs for cross-device consistency:
```swift
let uuidString = "00000000-0000-0000-0000-\(String(format: "%012d", index))"
let uuid = UUID(uuidString: uuidString)!
```

### Workout Relationships
```
WorkoutEntity
  └─ exercises: [WorkoutExerciseEntity]
       ├─ exerciseId: UUID → ExerciseEntity
       └─ sets: [ExerciseSetEntity]
            ├─ weight: Double
            ├─ reps: Int
            └─ completed: Bool
```

### Session vs Template
- **WorkoutEntity**: Reusable template (appears in workout list)
- **WorkoutSessionEntity**: Historical record (appears in session history)
- Sessions may reference a template via `templateId`

---

## Code Style & Conventions

### Swift Style
- Use structs for domain models (value types preferred)
- Use classes only for SwiftData entities (@Model) and ViewModels
- Explicit `self` in closures for clarity
- Prefer guard statements for early returns

### Comments
- **German** for UI-facing strings and user-visible text
- **English** for code comments and technical documentation
- SwiftDoc comments for public APIs

### Naming
- Views: Descriptive names ending in "View" (e.g., `WorkoutDetailView`)
- Entities: Descriptive names ending in "Entity" (e.g., `ExerciseEntity`)
- Services: Descriptive names (e.g., `WorkoutAnalyzer`, `TipEngine`)

---

## Performance Optimization Checklist

When adding new features:

- [ ] Use `@Query` with predicates instead of array filtering
- [ ] Implement caching for frequently accessed data
- [ ] Use `LazyVStack`/`LazyVGrid` for long lists
- [ ] Add `Equatable` conformance to prevent unnecessary updates
- [ ] Cache expensive computations (e.g., date formatters)
- [ ] Use background tasks for heavy operations
- [ ] Profile with Instruments if performance issues occur

---

## Testing Guidelines

### Manual Testing
- Test on **physical device** for HealthKit and Live Activities
- Test **force quit** scenarios (rest timer, Live Activities)
- Test **background scenarios** (rest timer continues)
- Test **database migrations** on fresh install

### Critical Paths to Test
1. Start workout → complete sets → end session
2. Rest timer → force quit → reopen app (timer should sync)
3. HealthKit sync → verify data appears in Health app
4. Live Activity → force quit → verify activity persists
5. Home favorites → add 5th workout (should show alert)

---

## Common Gotchas

### SwiftData
- **Entities become invalid after deletion** - don't access properties after `context.delete()`
- **Context must be passed explicitly** - entities don't carry their context
- **Use refetch strategy** - always refetch from context for fresh data

### WorkoutStore
- **Singleton pattern** - only one instance, injected via `@EnvironmentObject`
- **ModelContext must be set** - views must set `store.modelContext` on appear
- **Profile changes** - increment `profileUpdateTrigger` to force UI updates

### Rest Timer
- **Wall-clock based** - uses `Date()` not `Timer` for background sync
- **Notifications** - require authorization and `restNotificationsEnabled` flag
- **Live Activity throttling** - max 2 updates/second to prevent performance issues

### Live Activities
- **Force quit handling** - app syncs with existing activities on launch
- **Stale cleanup** - automatically removes old activities
- **WorkoutID persistence** - stored in UserDefaults for restoration

---

## Relevant Documentation Files

- **README.md**: User-facing documentation, features overview
- **DOCUMENTATION.md**: Complete technical documentation (architecture, views, services)
- **DATABASE_VERSION_CONTROL.md**: Migration system details
- **VIEWS_DOCUMENTATION.md**: Views catalog
- **TESTFLIGHT_UPDATE_GUIDE.md**: App Store deployment
- **SECURITY.md**: Security considerations

---

## When Making Changes

### Before Modifying SwiftData Schema
1. Consider if migration is needed
2. Increment `FORCE_FULL_RESET_VERSION` for breaking changes
3. Test on fresh install and existing data
4. Document schema changes in this file

### Before Modifying WorkoutStore
1. Consider if functionality belongs in separate service
2. Test impact on all views using `@EnvironmentObject`
3. Check for performance impact (large file, frequently updated)

### Before Adding New Dependencies
1. This project intentionally has no external dependencies
2. All functionality uses system frameworks
3. Avoid adding CocoaPods, SPM, or third-party libraries unless absolutely necessary

---

## Deployment Notes

### TestFlight
- Follow **TESTFLIGHT_UPDATE_GUIDE.md** for releases
- Increment build number for each TestFlight build
- Test migrations thoroughly before release

### Versioning
- App version in Info.plist
- Database versions in `DataVersions` struct
- Sample workout version in `WorkoutSeeder`

---

This documentation should be updated as the codebase evolves. When adding significant features or making architectural changes, update this file accordingly.
