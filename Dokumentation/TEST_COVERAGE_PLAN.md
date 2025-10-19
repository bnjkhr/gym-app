# Test Coverage Plan - GymBo

**Datum:** 19. Oktober 2025
**Status:** In Progress
**Aktuell:** <5% Test Coverage
**Ziel:** 60-70% Test Coverage

---

## Executive Summary

Die App hat aktuell nur Tests für das RestTimer-System (~4 Test-Dateien). Kritische Business-Logic in Services, Coordinators und ViewModels ist **nicht getestet**. Dieses Dokument definiert einen systematischen Plan um Test Coverage auf 60-70% zu erhöhen.

---

## 1. Bestehende Tests (✅ Already Done)

### RestTimer System
- ✅ `TimerEngineTests.swift` - TimerEngine Unit Tests
- ✅ `RestTimerStateTests.swift` - RestTimerState Tests
- ✅ `RestTimerStateManagerTests.swift` - StateManager Tests
- ✅ `RestTimerPersistenceTests.swift` - Persistence Tests

**Coverage:** ~90% für RestTimer-Komponenten

---

## 2. Kritische Komponenten ohne Tests (❌ Priority High)

### 2.1 Services (Höchste Priorität)

#### WorkoutDataService.swift
**Warum kritisch:** Zentrale Business Logic für Workout-Daten
**Test-Umfang:** ~15-20 Tests
**Geschätzte Zeit:** 2-3 Stunden

**Tests:**
- [ ] `testFetchAllWorkouts()` - Fetch all workouts
- [ ] `testActiveWorkout()` - Get active workout by ID
- [ ] `testHomeWorkouts()` - Fetch home favorites
- [ ] `testAddWorkout()` - Add new workout
- [ ] `testUpdateWorkout()` - Update existing workout
- [ ] `testDeleteWorkout()` - Delete workout
- [ ] `testToggleFavorite()` - Toggle favorite status
- [ ] `testToggleHomeFavorite()` - Toggle home favorite
- [ ] `testExercises()` - Fetch all exercises
- [ ] `testSimilarExercises()` - Find similar exercises by muscle group
- [ ] `testAddExercise()` - Add new exercise
- [ ] `testUpdateExercise()` - Update exercise
- [ ] `testDeleteExercise()` - Delete exercise
- [ ] `testExerciseByName()` - Fetch exercise by name
- [ ] Edge Case: Invalid IDs, nil context, empty database

#### ProfileService.swift
**Warum kritisch:** User Profile & Onboarding Logic
**Test-Umfang:** ~10 Tests
**Geschätzte Zeit:** 1.5 Stunden

**Tests:**
- [ ] `testLoadProfile()` - Load user profile
- [ ] `testLoadProfile_FirstTime()` - Create default profile on first load
- [ ] `testUpdateProfile()` - Update profile data
- [ ] `testUpdateProfileImage()` - Update profile image
- [ ] `testUpdateLockerNumber()` - Update locker number
- [ ] `testMarkOnboardingStep()` - Mark onboarding progress
- [ ] `testProfilePersistence()` - Profile survives app restart
- [ ] Edge Case: Nil context, invalid data

#### WorkoutAnalyticsService.swift
**Warum kritisch:** Statistik-Berechnungen müssen akkurat sein
**Test-Umfang:** ~20 Tests
**Geschätzte Zeit:** 3-4 Stunden

**Tests:**
- [ ] `testTotalWorkoutCount()` - Count total workouts
- [ ] `testAverageWorkoutsPerWeek()` - Calculate weekly average
- [ ] `testCurrentWeekStreak()` - Calculate streak
- [ ] `testAverageDurationMinutes()` - Calculate avg duration
- [ ] `testMuscleVolume()` - Calculate volume by muscle group
- [ ] `testExerciseStats()` - Get stats for specific exercise
- [ ] `testWorkoutsByDay()` - Group workouts by day
- [ ] `testCacheInvalidation()` - Cache invalidates correctly
- [ ] `testCachePerformance()` - Cache improves performance
- [ ] Edge Cases: Empty database, single workout, date boundaries

#### WorkoutSessionService.swift
**Warum kritisch:** Session Recording & History
**Test-Umfang:** ~12 Tests
**Geschätzte Zeit:** 2 Stunden

**Tests:**
- [ ] `testRecordSession()` - Record new session
- [ ] `testGetSessionHistory()` - Fetch session history
- [ ] `testRemoveSession()` - Delete session
- [ ] `testPrepareSessionStart()` - Prepare workout for session
- [ ] Edge Cases: Duplicate sessions, invalid workout ID

#### LastUsedMetricsService.swift
**Warum kritisch:** "Zuletzt verwendet" Feature
**Test-Umfang:** ~8 Tests
**Geschätzte Zeit:** 1.5 Stunden

**Tests:**
- [ ] `testLastMetrics()` - Get last used metrics
- [ ] `testCompleteLastMetrics()` - Get complete metrics
- [ ] `testUpdateLastUsedMetrics()` - Update after session
- [ ] Edge Cases: No previous data, multiple exercises

#### WorkoutGenerationService.swift
**Warum kritisch:** AI Workout Generation
**Test-Umfang:** ~15 Tests
**Geschätzte Zeit:** 2.5 Stunden

**Tests:**
- [ ] `testGenerateWorkout_Basic()` - Generate basic workout
- [ ] `testGenerateWorkout_ByGoal()` - Different fitness goals
- [ ] `testGenerateWorkout_ByExperience()` - Different experience levels
- [ ] `testGenerateWorkout_ByEquipment()` - Equipment preferences
- [ ] `testGenerateWorkout_ByDuration()` - Duration preferences
- [ ] `testExerciseSelection_MuscleGroupBalance()` - Balanced muscle groups
- [ ] Edge Cases: No exercises available, invalid preferences

---

### 2.2 SwiftData Entities (Medium Priority)

#### SwiftDataEntities.swift
**Test-Umfang:** ~10 Tests
**Geschätzte Zeit:** 2 Stunden

**Tests:**
- [ ] `testExerciseEntity_Mapping()` - Exercise to Entity and back
- [ ] `testWorkoutEntity_Mapping()` - Workout to Entity and back
- [ ] `testWorkoutSessionEntity_Mapping()` - Session mapping
- [ ] `testUserProfileEntity_Mapping()` - Profile mapping
- [ ] `testExerciseRecordEntity_Mapping()` - Record mapping
- [ ] Edge Cases: Null values, invalid data

---

### 2.3 Models (Medium Priority)

#### Exercise.swift, Workout.swift, WorkoutSession.swift
**Test-Umfang:** ~15 Tests
**Geschätzte Zeit:** 2 Stunden

**Tests:**
- [ ] `testExercise_Initialization()` - Create exercise
- [ ] `testExercise_MuscleGroupMapping()` - Muscle group enum
- [ ] `testExercise_EquipmentMapping()` - Equipment enum
- [ ] `testWorkout_AddExercise()` - Add exercise to workout
- [ ] `testWorkout_RemoveExercise()` - Remove exercise
- [ ] `testWorkout_Duration()` - Calculate workout duration
- [ ] `testWorkoutSession_VolumeCalculation()` - Calculate total volume
- [ ] Edge Cases: Empty workouts, invalid exercises

---

### 2.4 Utilities (Low Priority)

#### ExerciseSeeder.swift
**Test-Umfang:** ~5 Tests
**Geschätzte Zeit:** 1 Stunde

**Tests:**
- [ ] `testCreateRealisticExercises()` - Creates valid exercises
- [ ] `testExerciseCount()` - Correct number of exercises
- [ ] `testExerciseUniqueness()` - No duplicate exercises
- [ ] `testExerciseValidation()` - All exercises have required fields

---

## 3. Test Implementation Strategy

### Phase 1: Foundation (Week 1) - 8-10 Hours
**Priority:** Critical Services

1. ✅ Set up test infrastructure (Already done)
2. Write tests for **WorkoutDataService** (2-3h)
3. Write tests for **ProfileService** (1.5h)
4. Write tests for **WorkoutSessionService** (2h)
5. Write tests for **LastUsedMetricsService** (1.5h)

**Expected Coverage after Phase 1:** ~25-30%

---

### Phase 2: Analytics & Generation (Week 2) - 6-8 Hours
**Priority:** Business Logic

1. Write tests for **WorkoutAnalyticsService** (3-4h)
2. Write tests for **WorkoutGenerationService** (2.5h)

**Expected Coverage after Phase 2:** ~40-50%

---

### Phase 3: Models & Entities (Week 3) - 4-5 Hours
**Priority:** Data Layer

1. Write tests for **SwiftData Entities** (2h)
2. Write tests for **Models** (2h)
3. Write tests for **ExerciseSeeder** (1h)

**Expected Coverage after Phase 3:** ~60-70%

---

## 4. Testing Tools & Setup

### Test Framework
- **XCTest** - Standard iOS testing framework
- **@testable import GymBo** - Access internal methods

### Mock Dependencies
We need to create mocks for:
- [ ] `ModelContext` - SwiftData context mock
- [ ] `FetchDescriptor` - Mock fetch results
- [ ] `HealthKitManager` - Mock HealthKit interactions

### Test Utilities
Create helper files:
- [ ] `TestHelpers.swift` - Common test utilities
- [ ] `MockModelContext.swift` - Mock SwiftData context
- [ ] `TestFixtures.swift` - Sample data for tests

---

## 5. Coverage Measurement

### Tools
- Xcode Code Coverage (built-in)
- Command: `xcodebuild test -enableCodeCoverage YES`

### Target Metrics
| Component | Current | Target | Priority |
|-----------|---------|--------|----------|
| **Services** | 0% | 80% | ✅ High |
| **Models** | 0% | 70% | Medium |
| **Entities** | 0% | 70% | Medium |
| **Utilities** | 0% | 60% | Low |
| **Overall** | <5% | 60-70% | ✅ Goal |

---

## 6. Continuous Integration

### CI Setup (Future)
- [ ] Add GitHub Actions workflow
- [ ] Run tests on every PR
- [ ] Enforce minimum coverage (50%)
- [ ] Generate coverage reports

---

## 7. Documentation

After each phase:
- [ ] Update this document with results
- [ ] Document test patterns used
- [ ] Create testing guidelines for future contributors
- [ ] Add coverage badge to README

---

## Next Actions

1. **TODAY:** Start Phase 1 - WorkoutDataService tests
2. Write first 5-10 tests for WorkoutDataService
3. Set up MockModelContext
4. Run tests and measure initial coverage
5. Iterate and improve

---

**Last Updated:** 2025-10-19
**Next Review:** After Phase 1 completion
