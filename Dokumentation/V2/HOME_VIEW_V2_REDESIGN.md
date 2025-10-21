# Home View V2 Redesign - Konzept

**Erstellt:** 2025-10-21  
**Aktualisiert:** 2025-10-21  
**Status:** 🔄 PLANUNG  
**Ziel:** Redesign der Home-Ansicht basierend auf Active Workout V2 Design-Prinzipien

---

## 📊 Implementierungs-Status

**Aktueller Stand:** Phase 1 Complete ✅ | Phase 2 Ready ⏳

**Übersicht:**
- ✅ Phase 0: Design & Konzept (ABGESCHLOSSEN - 100%)
- ✅ Phase 1: Layout & Dummy-Functions (ABGESCHLOSSEN - 100%)
- ⏳ Phase 2: Business Logic Integration (AUSSTEHEND)
- ⏳ Phase 3: Migration & Testing (AUSSTEHEND)

---

## 🎯 Design-Ziele

### Problem-Analyse der aktuellen HomeView

**WorkoutsHomeView.swift (Aktuell):**
```swift
// ❌ PROBLEME:
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
    ForEach(favoritedWorkouts) { workout in
        WorkoutTileCard(workout: workout, ...)
    }
}
```

**Issues:**
1. ❌ **Keine Swipe-to-Delete** - Löschen nur über Context Menu
2. ❌ **Keine Reorder-Funktion** - Favoriten-Reihenfolge fest
3. ❌ **Kleine Cards** - 2 pro Zeile, wenig Info sichtbar
4. ❌ **Grid-Layout** - Keine nativen iOS Gesten
5. ❌ **Komplexe Navigation** - Viele verschachtelte Sheets
6. ❌ **Kein Haptic Feedback** - Keine taktile Rückmeldung

### Home View V2 Ziele

**Was wir ändern:**
1. ✅ **List-basiertes Layout** - 1 Workout pro Zeile, mehr Info
2. ✅ **Swipe-to-Delete** - Schnelles Löschen von Workouts
3. ✅ **Drag-and-Drop Reorder** - Favoriten-Reihenfolge anpassen
4. ✅ **Native iOS Gesten** - Alle Standard-Interaktionen
5. ✅ **Kompakter Header** - Mehr Platz für Workout-Liste
6. ✅ **Haptic Feedback** - Alle Aktionen mit haptischer Rückmeldung
7. ✅ **Größere Cards** - Mehr Kontext auf einen Blick

---

## 🎨 Design-Konzept

### Layout-Vergleich

**VORHER (WorkoutsHomeView):**
```
┌─────────────────────────────┐
│ Guten Morgen, Ben! 🔒 ⚙️   │
│                             │
│ ┌──────────────────────┐    │
│ │ WorkoutHighlightCard │    │
│ │  Last Session Info   │    │
│ └──────────────────────┘    │
│                             │
│ ┌──────┐  ┌──────┐          │
│ │ Push │  │ Pull │          │ ← LazyVGrid (2 columns)
│ │  5   │  │  4   │          │
│ └──────┘  └──────┘          │
│ ┌──────┐  ┌──────┐          │
│ │ Legs │  │ Core │          │
│ └──────┘  └──────┘          │
└─────────────────────────────┘
```

**NACHHER (HomeViewV2):**
```
┌─────────────────────────────┐
│ Guten Morgen, Ben! 🔒 ⚙️   │
│ Woche: 3 Workouts · 180 Min │ ← Kompakter Stats Bar
│                             │
│ ┌─────────────────────────┐ │
│ │ 💪 Push Day             │ │ ← List (1 column)
│ │ 5 Übungen · 60 Min     │ │   Größere Cards
│ │ Chest, Shoulders, Tris │ │   Mehr Info sichtbar
│ │         [Start] [⋯]    │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🏋️ Pull Day            │ │ ← Swipe Left → Delete
│ │ 4 Übungen · 55 Min     │ │   Drag Handle → Reorder
│ │ Back, Biceps, Rear Delts│ │
│ │         [Start] [⋯]    │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🦵 Leg Day              │ │
│ │ 6 Übungen · 75 Min     │ │
│ │ Quads, Hams, Glutes    │ │
│ │         [Start] [⋯]    │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

### Design-Prinzipien (von Active Workout V2)

1. **Plain List** statt LazyVGrid
   - Native Swipe Gestures
   - Native Drag & Drop
   - Bessere Performance

2. **Größere Cards (1 pro Zeile)**
   - Workout Name + Icon
   - Exercise Count + Duration
   - Muscle Groups Preview
   - Quick Actions (Start, Menu)

3. **Haptic Feedback**
   - `light()` - Start Workout, Toggle Favorite
   - `impact()` - Drag & Drop Reorder
   - `warning()` - Delete Confirmation
   - `success()` - Workout Created

4. **Consistent Spacing**
   - 16px Horizontal Padding
   - 12px Card Spacing
   - 8px Internal Card Padding

---

## 🏗️ Komponenten-Struktur

### Datei-Organisation

```
GymTracker/Views/Components/HomeV2/
├── HomeViewV2.swift                 # Main Container (Pure UI)
├── WorkoutListCard.swift            # Single Workout Card
├── HomeHeaderSection.swift          # Greeting + Stats + Actions
├── QuickStatsBar.swift              # Week Stats (Workouts, Minutes)
└── HomeViewV2+Preview.swift         # Preview Data & Tests

GymTracker/Views/
└── WorkoutsHomeViewV2.swift         # Production Wrapper (Business Logic)
```

### Komponenten-Übersicht

#### 1. **HomeViewV2.swift** - Main Container

**Verantwortung:**
- Layout-Container für alle Subviews
- List-Management (Reorder, Delete)
- State-Management für UI
- **KEINE** Business Logic

**Interface:**
```swift
struct HomeViewV2: View {
    // Data
    var workouts: [Workout]
    var weekStats: WeekStats
    var greeting: String
    
    // Callbacks (Dummy in Phase 1)
    var onStartWorkout: ((UUID) -> Void)?
    var onDeleteWorkout: ((UUID) -> Void)?
    var onReorderWorkouts: ((IndexSet, Int) -> Void)?
    var onToggleFavorite: ((UUID) -> Void)?
    var onEditWorkout: ((UUID) -> Void)?
    
    // UI State
    @State private var isReorderMode: Bool = false
    @State private var workoutToDelete: Workout?
}
```

**Features:**
- [x] Scrollable List mit Workouts
- [x] Swipe-to-Delete (trailing action)
- [x] Drag-and-Drop Reorder (with toggle)
- [x] Header mit Greeting + Stats
- [x] Quick Stats Bar
- [x] Haptic Feedback

#### 2. **WorkoutListCard.swift** - Workout Card

**Design:**
```
┌───────────────────────────────┐
│ 💪 Push Day            [≡]   │ ← Drag Handle (reorder mode)
│ 5 Übungen · 60 Min           │ ← Stats
│ Chest, Shoulders, Triceps    │ ← Muscle Groups (max 3)
│                               │
│      [Start Workout] [⋯]     │ ← Actions
└───────────────────────────────┘
```

**Properties:**
```swift
struct WorkoutListCard: View {
    let workout: Workout
    let isReorderMode: Bool
    
    var onStart: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
}
```

**Features:**
- [x] Workout Icon (Emoji based on muscle groups)
- [x] Workout Name (Title)
- [x] Stats (Exercise Count, Est. Duration)
- [x] Muscle Groups (Chip-Style, max 3)
- [x] Start Button (Primary Action)
- [x] Menu Button (Edit, Delete, Share, etc.)
- [x] Drag Handle (only visible in reorder mode)

#### 3. **HomeHeaderSection.swift** - Greeting & Actions

**Design:**
```
┌─────────────────────────────────┐
│ Guten Morgen,        🔒123  ⚙️ │
│ Ben!                            │
└─────────────────────────────────┘
```

**Properties:**
```swift
struct HomeHeaderSection: View {
    let greeting: String
    let userName: String
    let lockerNumber: String?
    
    var onShowSettings: (() -> Void)?
    var onShowLockerInput: (() -> Void)?
}
```

#### 4. **QuickStatsBar.swift** - Week Stats

**Design:**
```
┌─────────────────────────────────┐
│  📊 Diese Woche                 │
│  3 Workouts · 180 Minuten       │
└─────────────────────────────────┘
```

**Properties:**
```swift
struct QuickStatsBar: View {
    let weekStats: WeekStats
}

struct WeekStats {
    let workoutCount: Int
    let totalMinutes: Int
}
```

---

## 📋 Phasen-Plan

### Phase 0: Design & Konzept ✅

**Status:** 🔄 IN ARBEIT  
**Zeitaufwand:** 1 Stunde

- [x] Problem-Analyse der aktuellen HomeView
- [x] Design-Konzept erstellen
- [x] Komponenten-Struktur definieren
- [x] Dokumentation schreiben (dieses Dokument)

---

### Phase 1: Layout & Dummy-Functions

**Status:** ⏳ AUSSTEHEND  
**Geschätzter Zeitaufwand:** 2-3 Stunden

#### Tasks:

**1.1 HomeViewV2.swift - Main Container** (45 Min)
- [ ] File erstellen (`GymTracker/Views/Components/HomeV2/HomeViewV2.swift`)
- [ ] List-basiertes Layout implementieren
- [ ] Swipe-to-Delete mit Dummy-Callback
- [ ] Drag-and-Drop mit lokalem Array-Update
- [ ] Reorder-Mode Toggle Button
- [ ] Haptic Feedback für alle Interaktionen

```swift
struct HomeViewV2: View {
    var workouts: [Workout]
    var onStartWorkout: ((UUID) -> Void)? = nil
    var onDeleteWorkout: ((UUID) -> Void)? = nil
    var onReorderWorkouts: ((IndexSet, Int) -> Void)? = nil
    
    @State private var isReorderMode = false
    @State private var localWorkouts: [Workout]
    
    init(workouts: [Workout], ...) {
        self.workouts = workouts
        self._localWorkouts = State(initialValue: workouts)
    }
    
    var body: some View {
        List {
            ForEach(localWorkouts) { workout in
                WorkoutListCard(
                    workout: workout,
                    isReorderMode: isReorderMode,
                    onStart: { 
                        HapticManager.shared.light()
                        onStartWorkout?(workout.id) 
                    }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        HapticManager.shared.warning()
                        onDeleteWorkout?(workout.id)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
            .onMove { source, destination in
                localWorkouts.move(fromOffsets: source, toOffset: destination)
                HapticManager.shared.impact()
                onReorderWorkouts?(source, destination)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
    }
}
```

**1.2 WorkoutListCard.swift** (60 Min)
- [ ] File erstellen (`GymTracker/Views/Components/HomeV2/WorkoutListCard.swift`)
- [ ] Card Layout (Icon, Title, Stats, Muscle Groups)
- [ ] Start Button
- [ ] Menu Button (Dummy)
- [ ] Drag Handle (conditional, reorder mode only)

```swift
struct WorkoutListCard: View {
    let workout: Workout
    let isReorderMode: Bool
    
    var onStart: (() -> Void)?
    var onEdit: (() -> Void)?
    
    private var workoutIcon: String {
        // Logic to determine emoji based on muscle groups
        if workout.exercises.contains(where: { $0.exercise.muscleGroups.contains(.chest) }) {
            return "💪"
        } else if workout.exercises.contains(where: { $0.exercise.muscleGroups.contains(.back) }) {
            return "🏋️"
        } else if workout.exercises.contains(where: { $0.exercise.muscleGroups.contains(.legs) }) {
            return "🦵"
        }
        return "🔥"
    }
    
    private var estimatedDuration: Int {
        // Calculate based on exercises and sets
        workout.exercises.reduce(0) { total, ex in
            total + (ex.sets.count * 3) // ~3 min per set
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header Row
            HStack(spacing: 12) {
                Text(workoutIcon)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("\(workout.exercises.count) Übungen · \(estimatedDuration) Min")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Muscle Groups
            HStack(spacing: 6) {
                ForEach(uniqueMuscleGroups.prefix(3), id: \.self) { group in
                    Text(group.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                        )
                }
                Spacer()
            }
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    HapticManager.shared.light()
                    onStart?()
                } label: {
                    Text("Start Workout")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.powerOrange)
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    onEdit?()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    private var uniqueMuscleGroups: [MuscleGroup] {
        Array(Set(workout.exercises.flatMap { $0.exercise.muscleGroups }))
            .sorted { $0.displayName < $1.displayName }
    }
}
```

**1.3 HomeHeaderSection.swift** (30 Min)
- [ ] File erstellen
- [ ] Greeting Logic (time-based)
- [ ] User Name Display
- [ ] Locker Number Badge
- [ ] Settings Button

**1.4 QuickStatsBar.swift** (20 Min)
- [ ] File erstellen
- [ ] Week Stats Display
- [ ] Icon + Text Layout

**1.5 Preview Data** (15 Min)
- [ ] File erstellen (`HomeViewV2+Preview.swift`)
- [ ] Preview-Workouts erstellen
- [ ] Preview-Stats erstellen
- [ ] Mehrere Preview-Szenarien (Empty, 1 Workout, Many Workouts)

```swift
#Preview("Standard - 4 Workouts") {
    @Previewable @State var workouts = PreviewData.standardWorkouts
    
    HomeViewV2(
        workouts: workouts,
        weekStats: WeekStats(workoutCount: 3, totalMinutes: 180),
        greeting: "Guten Morgen",
        userName: "Ben",
        onStartWorkout: { id in print("Start: \(id)") },
        onDeleteWorkout: { id in 
            workouts.removeAll { $0.id == id }
            print("Deleted: \(id)") 
        },
        onReorderWorkouts: { source, dest in
            workouts.move(fromOffsets: source, toOffset: dest)
            print("Reordered")
        }
    )
}

#Preview("Empty State") {
    HomeViewV2(
        workouts: [],
        weekStats: WeekStats(workoutCount: 0, totalMinutes: 0),
        greeting: "Guten Morgen",
        userName: "Ben"
    )
}

#Preview("Single Workout") {
    HomeViewV2(
        workouts: [PreviewData.pushWorkout],
        weekStats: WeekStats(workoutCount: 1, totalMinutes: 60),
        greeting: "Guten Tag",
        userName: "Ben"
    )
}
```

---

### Phase 2: Business Logic Integration

**Status:** ⏳ AUSSTEHEND  
**Geschätzter Zeitaufwand:** 1-2 Stunden

#### Tasks:

**2.1 WorkoutReorderService.swift** (45 Min)
- [ ] Service erstellen (`GymTracker/Services/WorkoutReorderService.swift`)
- [ ] `sortOrder` Property zu `WorkoutEntity` hinzufügen
- [ ] `reorderWorkouts()` Method implementieren
- [ ] SwiftData Persistence

```swift
// WorkoutEntity+Extensions.swift
extension WorkoutEntity {
    @Attribute var sortOrder: Int = 0
}

// WorkoutReorderService.swift
class WorkoutReorderService {
    let modelContext: ModelContext
    
    func reorderWorkouts(
        from source: IndexSet,
        to destination: Int,
        in workouts: [Workout]
    ) throws {
        var mutableWorkouts = workouts
        mutableWorkouts.move(fromOffsets: source, toOffset: destination)
        
        // Update sortOrder for all workouts
        for (index, workout) in mutableWorkouts.enumerated() {
            if let entity = try? fetchEntity(id: workout.id) {
                entity.sortOrder = index
            }
        }
        
        try modelContext.save()
    }
    
    private func fetchEntity(id: UUID) throws -> WorkoutEntity? {
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
```

**2.2 WorkoutsHomeViewV2.swift - Production Wrapper** (45 Min)
- [ ] File erstellen (`GymTracker/Views/WorkoutsHomeViewV2.swift`)
- [ ] SwiftData @Query Integration
- [ ] WorkoutActionService Integration
- [ ] WorkoutReorderService Integration
- [ ] Callbacks mit echten Services verbinden

```swift
struct WorkoutsHomeViewV2: View {
    @EnvironmentObject var workoutStore: WorkoutStoreCoordinator
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: [
        SortDescriptor(\WorkoutEntity.sortOrder),
        SortDescriptor(\WorkoutEntity.date, order: .reverse)
    ])
    private var workoutEntities: [WorkoutEntity]
    
    @State private var cachedWorkouts: [Workout] = []
    
    private var workoutActionService: WorkoutActionService {
        WorkoutActionService(modelContext: modelContext, workoutStore: workoutStore)
    }
    
    private var workoutReorderService: WorkoutReorderService {
        WorkoutReorderService(modelContext: modelContext)
    }
    
    var body: some View {
        HomeViewV2(
            workouts: cachedWorkouts,
            weekStats: WeekStats(
                workoutCount: workoutsThisWeek,
                totalMinutes: minutesThisWeek
            ),
            greeting: timeBasedGreeting,
            userName: workoutStore.userProfile.name,
            onStartWorkout: { id in
                startWorkout(with: id)
            },
            onDeleteWorkout: { id in
                deleteWorkout(id: id)
            },
            onReorderWorkouts: { source, destination in
                reorderWorkouts(from: source, to: destination)
            }
        )
        .onChange(of: workoutEntities) { _, newEntities in
            updateWorkoutCache(newEntities)
        }
        .onAppear {
            updateWorkoutCache(workoutEntities)
        }
    }
    
    private func startWorkout(with id: UUID) {
        workoutStore.startSession(for: id)
        // Navigation handled by WorkoutStore
    }
    
    private func deleteWorkout(id: UUID) {
        do {
            try workoutActionService.deleteWorkout(id: id, in: Array(workoutEntities))
        } catch {
            print("Error deleting workout: \(error)")
        }
    }
    
    private func reorderWorkouts(from source: IndexSet, to destination: Int) {
        do {
            try workoutReorderService.reorderWorkouts(
                from: source,
                to: destination,
                in: cachedWorkouts
            )
            updateWorkoutCache(workoutEntities)
        } catch {
            print("Error reordering workouts: \(error)")
        }
    }
    
    private func updateWorkoutCache(_ entities: [WorkoutEntity]) {
        cachedWorkouts = entities.compactMap { Workout(entity: $0, in: modelContext) }
    }
}
```

---

### Phase 3: Migration & Testing

**Status:** ⏳ AUSSTEHEND  
**Geschätzter Zeitaufwand:** 1 Stunde

#### Tasks:

**3.1 A/B Testing Setup** (20 Min)
- [ ] Feature Flag erstellen (`UserDefaults` key: `"homeViewV2Enabled"`)
- [ ] Toggle in SettingsView

```swift
// SettingsView.swift
Toggle("Home View V2 (Beta)", isOn: $useHomeViewV2)
    .onChange(of: useHomeViewV2) { _, newValue in
        UserDefaults.standard.set(newValue, forKey: "homeViewV2Enabled")
    }
```

**3.2 ContentView Integration** (20 Min)
- [ ] Conditional View Rendering in ContentView

```swift
// ContentView.swift
if UserDefaults.standard.bool(forKey: "homeViewV2Enabled") {
    WorkoutsHomeViewV2()
        .environmentObject(workoutStore)
} else {
    WorkoutsHomeView()
        .environmentObject(workoutStore)
}
```

**3.3 Testing & Bug Fixing** (20 Min)
- [ ] Test alle Swipe-to-Delete Szenarien
- [ ] Test Drag-and-Drop Reorder
- [ ] Test Edge Cases (Empty State, Single Workout, Many Workouts)
- [ ] Test Dark Mode
- [ ] Test Performance (20+ Workouts)

---

## 🧪 Test-Szenarien

### Swipe-to-Delete
- [ ] Swipe left → Delete button erscheint
- [ ] Tap Delete → Workout wird gelöscht
- [ ] Full swipe → Sofortiges Löschen
- [ ] Swipe abbrechen → Keine Änderung

### Drag-and-Drop Reorder
- [ ] Tap Reorder Button → Drag Handles erscheinen
- [ ] Drag Workout nach oben → Reihenfolge ändert sich
- [ ] Drag Workout nach unten → Reihenfolge ändert sich
- [ ] Tap Reorder Button (Deaktivieren) → Handles verschwinden
- [ ] Reihenfolge bleibt nach App-Neustart

### Edge Cases
- [ ] **Empty State** - Keine Workouts vorhanden
- [ ] **Single Workout** - Nur 1 Workout
- [ ] **Many Workouts** - 10+ Workouts (Performance)
- [ ] **Long Workout Names** - Text wrapping
- [ ] **No Muscle Groups** - Fallback anzeigen
- [ ] **All Workouts Deleted** - Empty State erscheint

### Dark Mode
- [ ] Alle Farben korrekt in Dark Mode
- [ ] Kontrast ausreichend
- [ ] Cards gut sichtbar

---

## 🐛 Known Issues & Workarounds

### Aktuell (Phase 0)
- **Keine Blocker** - Kann sofort mit Phase 1 gestartet werden

---

## 📝 Session-Logs

### Session 1 - Design & Planung (2025-10-21)

**Status:** ✅ ABGESCHLOSSEN  
**Zeitaufwand:** ~1 Stunde  
**Phase:** Phase 0 Complete

**Achievements:**
- ✅ Problem-Analyse der aktuellen HomeView
- ✅ Design-Konzept erstellt (List vs Grid)
- ✅ Komponenten-Struktur definiert
- ✅ Phasen-Plan erstellt (Phase 1-3)
- ✅ Dokumentation geschrieben (HOME_VIEW_V2_REDESIGN.md)
- ✅ V2_MASTER_PROGRESS.md erstellt

**Decisions:**
- **Layout-First Approach:** Erst UI mit Dummy-Callbacks, dann Business Logic
- **List statt Grid:** Bessere native Gesture-Unterstützung
- **1 Card pro Zeile:** Mehr Informationen sichtbar
- **Reorder als Toggle:** Nicht permanent aktiv (weniger versehentliches Dragging)

**Next Steps:**
- 🔄 Phase 1 starten: HomeViewV2.swift implementieren

---

### Session 2 - Phase 1 Implementation (2025-10-21)

**Status:** ✅ ABGESCHLOSSEN  
**Zeitaufwand:** ~45 Minuten  
**Phase:** Phase 1 Complete (100%)

**Achievements:**
- ✅ HomeViewV2.swift erstellt (Main Container)
- ✅ WorkoutListCard.swift erstellt (Workout Card Component)
- ✅ HomeHeaderSection.swift erstellt (Header Component)
- ✅ QuickStatsBar.swift erstellt (Stats Component)
- ✅ Alle Components mit Previews
- ✅ Build erfolgreich (keine Errors)

**Implementierte Features:**
1. **HomeViewV2.swift**
   - List-basiertes Layout
   - Swipe-to-Delete mit Dummy-Callback
   - Drag-and-Drop mit lokalem Array-Update
   - Reorder-Mode Toggle Button
   - Haptic Feedback für alle Interaktionen
   - Empty State View
   - 3 Preview-Szenarien (Standard, Empty, Single)

2. **WorkoutListCard.swift**
   - Workout Icon (Emoji based on muscle groups)
   - Exercise Count + Estimated Duration (3 min/set)
   - Muscle Groups Tags (max 3)
   - Start Button + Menu Button
   - Favorite Star Toggle
   - 3 Preview-Szenarien (Push Day, Leg Day, Empty)

3. **HomeHeaderSection.swift**
   - Greeting + User Name
   - Locker Number Badge
   - Settings Button
   - 3 Preview-Szenarien (With/Without Name, Dark Mode)

4. **QuickStatsBar.swift**
   - Week Workout Count
   - Week Total Minutes
   - Icon Color basierend auf Activity
   - 3 Preview-Szenarien (Active, Empty, Dark Mode)

**Code Stats:**
- **Dateien erstellt:** 4
- **Zeilen Code:** ~600
- **Preview-Szenarien:** 12 total
- **Build-Zeit:** ~25 Sekunden
- **Errors:** 0 ✅

**Decisions:**
- **List height:** Fixed height calculation (`count * 200px`) - funktioniert für Phase 1, aber könnte in Phase 2 verbessert werden
- **Workout Icon Logic:** Priorität: Chest > Back > Legs > Shoulders > Arms
- **Estimated Duration:** 3 Min pro Set (inkl. Rest) - grobe Schätzung
- **Empty State:** Einfacher Design (Icon + Text), könnte später erweitert werden

**Next Steps:**
- ⏳ Phase 2: Business Logic Integration
- ⏳ WorkoutReorderService erstellen
- ⏳ WorkoutsHomeViewV2 Production Wrapper

---

## 🎓 Design-Entscheidungen & Rationale

### Warum List statt LazyVGrid?

**Vorteile:**
1. ✅ Native `.swipeActions()` - Out-of-the-box Swipe-to-Delete
2. ✅ Native `.onMove()` - Drag-and-Drop ohne Custom Gestures
3. ✅ Bessere Performance bei vielen Items
4. ✅ Konsistent mit iOS Standard-Apps (Mail, Reminders, etc.)

**Nachteile:**
- ⚠️ Weniger kompakt (1 pro Zeile statt 2)
- Aber: Mehr Info sichtbar → Trade-off lohnt sich

### Warum Reorder als Toggle-Mode?

**Alternative:** Permanent sichtbare Drag-Handles (wie Reminders-App)

**Entscheidung:** Toggle-Mode (wie Active Workout V2)

**Begründung:**
1. ✅ Weniger visuelles Clutter (Handles nur wenn benötigt)
2. ✅ Verhindert versehentliches Dragging
3. ✅ Klare Trennung: Normal-Mode vs Edit-Mode
4. ✅ Konsistent mit Active Workout V2 Design

### Warum größere Cards (1 pro Zeile)?

**Trade-off:** Weniger Workouts sichtbar auf einen Blick

**Aber:**
- ✅ Muscle Groups Preview sichtbar
- ✅ Estimated Duration sichtbar
- ✅ Größerer "Start"-Button (easier tap target)
- ✅ Mehr Kontext → bessere UX

**User-Feedback:** Wird in Phase 3 getestet

---

## 📚 Referenzen

- **Active Workout V2:** `Dokumentation/V2/ACTIVE_WORKOUT_REDESIGN.md`
- **Apple HIG - Lists:** https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
- **SwiftUI List:** https://developer.apple.com/documentation/swiftui/list

---

**Zuletzt aktualisiert:** 2025-10-21 - Phase 0 Complete
