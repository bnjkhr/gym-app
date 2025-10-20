# Active Workout View Redesign - Konzept

**Erstellt:** 2025-10-20  
**Aktualisiert:** 2025-10-20 (Major Update: Modal Sheet Design)  
**Status:** 🔨 In Implementierung - Phase 1 abgeschlossen  
**Ziel:** Redesign der aktiven Workout-Ansicht basierend auf Screenshot-Vorlage

---

## 📊 Implementierungs-Status

### ✅ Phase 1: Model-Erweiterungen (ABGESCHLOSSEN)
**Datum:** 2025-10-20  
**Dauer:** ~20 Minuten

**Änderungen:**
- ✅ `EquipmentType` Enum (bereits vorhanden)
- ✅ `Exercise.equipmentType` (bereits vorhanden)
- ✅ `Workout.startDate: Date?` hinzugefügt
- ✅ `Workout.currentDuration` computed property
- ✅ `Workout.formattedCurrentDuration` computed property
- ✅ `WorkoutExercise.notes: String?` hinzugefügt
- ✅ `WorkoutExercise.restTimeToNext: TimeInterval?` hinzugefügt
- ✅ `WorkoutExercise.formattedRestTimeToNext` computed property
- ✅ `WorkoutEntity.startDate` in SwiftData
- ✅ `WorkoutExerciseEntity.notes` in SwiftData
- ✅ `WorkoutExerciseEntity.restTimeToNext` in SwiftData

**Geänderte Dateien:**
- `GymTracker/Models/Workout.swift`
- `GymTracker/SwiftDataEntities.swift`

**Build Status:** ✅ Keine Compile-Fehler (alle Felder optional mit Defaults)

**Nächster Schritt:** Phase 2 - Basis-Komponenten

---

### ⏳ Phase 2: Basis-Komponenten (AUSSTEHEND)
Geplante Komponenten:
- `CompactSetRow.swift`
- `ExerciseSeparator.swift`
- `BottomActionBar.swift`

### ⏳ Phase 3-8: (AUSSTEHEND)
Siehe Implementierungs-Plan unten

---

## 🚨 Fundamentale Design-Änderung

**WICHTIG:** Die Active Workout View ist **KEINE Full-Screen View** mehr!

### Presentation Style
- ✅ **Modal Sheet** (kann nach unten gezogen werden)
- ✅ **Grabber** am oberen Rand sichtbar
- ✅ **Drag-to-Dismiss** Geste → Zurück zur HomeView
- ✅ **Dynamisches Layout:** Timer-Bereich nur bei aktivem Rest Timer

### Zwei Zustände

#### Zustand 1: Mit aktivem Rest Timer (Screenshot 1)
```
┌─────────────────────────────┐
│ === Grabber ===             │
│ [←] [...] 1/15 [Finish]     │ ← Header
│                             │
│ ┌─────────────────────────┐ │
│ │   🖤 TIMER SECTION 🖤   │ │ ← Schwarzer Bereich
│ │      01:45              │ │
│ │      04:00              │ │
│ │  [-15] Skip [+15]       │ │
│ │      • •                │ │ ← 2 Dots
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🎯 Lat Pulldown         │ │
│ │    Cable                │ │
│ │                         │ │
│ │  100 kg    8 reps   ☐   │ │ ← Set-Reihe
│ │  Type anything...       │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

#### Zustand 2: Ohne aktiven Rest Timer (Screenshot 2 - NEU!)
```
┌─────────────────────────────┐
│ === Grabber ===             │
│ [←] [...] 0/14 [Finish]     │ ← Header
│                             │
│ ❌ KEIN TIMER BEREICH       │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🔴 Squat                │ │
│ │    Barbell              │ │
│ │                         │ │
│ │  135 kg    6 reps   ☐   │ │
│ │  135 kg    6 reps   ☐   │ │
│ │  135 kg    7 reps   ☐   │ │
│ │  Type anything...       │ │
│ │  + icon   03:00         │ │ ← Pause zwischen Übungen?
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🔴 Hack Squat           │ │
│ │    Machine              │ │
│ │                         │ │
│ │  80 kg     9 reps   ☐   │ │
│ │  80 kg     8 reps   ☐   │ │
│ └─────────────────────────┘ │
│                             │
│ [🔄] [➕] [↕️]              │ ← Bottom Bar
└─────────────────────────────┘
```

---

## 📸 Screenshot-Analyse

### Screenshot 1: Mit aktivem Rest Timer

#### Header-Bereich (Schwarz)
1. **Navigation (Top-Links)**
   - Zurück-Button (Pfeil nach links)
   - Menü-Button (drei Punkte)

2. **Fortschrittsanzeige (Top-Rechts)**
   - Aktueller Satz / Gesamtsätze: `1 / 15`
   - "Finish" Button

3. **Timer (Zentral, groß)**
   - Große Timer-Anzeige: `01:45` (weiß, sehr prominent) - **Rest Timer Countdown**
   - Workout-Dauer darunter: `04:00` (grau, kleiner) - **Gesamtzeit des Workouts**

4. **Timer-Kontrollen (Unter Timer)**
   - Links: -15 Sekunden Icon
   - Mitte: "Skip" Button (Text) - Überspringt Timer, geht zum nächsten Set
   - Rechts: +15 Sekunden Icon

5. **Paginierung**
   - Dots zur Anzeige der aktuellen Seite (zwei Dots sichtbar)

#### Set-Card-Bereich (Hell)
6. **Übungs-Header**
   - Roter Punkt + Übungsname: "Lat Pulldown"
   - Equipment-Typ: "Cable" (grau, kleiner)

7. **Set-Einträge (kompakt)**
   - Jede Reihe zeigt: `100 kg | 8 reps | ☐`

8. **Eingabe-Bereich**
   - Placeholder: "Type anything..." (grau)

---

### Screenshot 2: Ohne aktiven Rest Timer (NEU!)

#### Grabber & Header
1. **Grabber** (Drag Handle)
   - Horizontale Linie am oberen Rand
   - **Funktion:** Sheet nach unten ziehen → HomeView

2. **Navigation Header**
   - Links: Zurück-Button (Pfeil)
   - Mitte (oben): Drei-Punkte-Menü
   - Mitte: **"0 / 14"** (aktueller Set / total Sets)
   - Rechts: **"Finish"** Button

3. **Progress Indicator**
   - Kein Progress Bar sichtbar im Screenshot
   - Nur numerischer Fortschritt "0 / 14"

#### Übungs-Karten (Mehrere sichtbar!)

**Übung 1: Squat**
4. **Übungs-Header**
   - Roter Punkt + Übungsname: "Squat"
   - Equipment: "Barbell"
   - Drei-Punkte-Menü rechts

5. **Set-Einträge (3 Reihen)**
   - Reihe 1: `135 Kg | 6 reps | ☐`
   - Reihe 2: `135 Kg | 6 reps | ☐`
   - Reihe 3: `135 Kg | 7 reps | ☐`

6. **Eingabe-Bereich**
   - "Type anything..." Placeholder
   - Kein Checkbox in dieser Zeile

7. **Übungs-Separator / Timer?**
   - Plus Icon (links)
   - **"03:00"** Timer (mittig)
   - Keine weiteren Elemente

**Übung 2: Hack Squat**
8. **Übungs-Header**
   - Roter Punkt + "Hack Squat"
   - Equipment: "Machine"
   - Drei-Punkte-Menü rechts

9. **Set-Einträge (3 Reihen)**
   - Reihe 1: `80 Kg | 9 reps | ☐`
   - Reihe 2: `80 Kg | 8 reps | ☐`
   - Reihe 3: `80 Kg | 8 reps | ☐`

#### Bottom Action Bar (Fixiert am unteren Rand)
10. **Drei Icons**
   - Links: Wiederholung/Undo Icon
   - Mitte: **Plus Icon (groß, prominent)**
   - Rechts: Sortieren/Reorder Icon

---

## 🔍 Gap-Analyse: Screenshot vs. Aktueller Code

### 🚨 FUNDAMENTALE ÄNDERUNGEN

**Aktuell:** Full-Screen Navigation mit TabView  
**Neu:** Modal Sheet mit dynamischem Layout

| Aspekt | Aktuell | Neu (Screenshot) |
|--------|---------|------------------|
| **Presentation** | Full-Screen NavigationView | Modal Sheet (.sheet modifier) |
| **Dismiss** | Zurück-Button | Drag-to-Dismiss + Zurück-Button |
| **Timer Position** | Immer oben (fest) | Nur bei aktivem Rest Timer |
| **Navigation** | TabView (eine Übung pro Seite) | ScrollView (mehrere Übungen sichtbar) |
| **Layout** | Timer + Eine Übung | Dynamisch: Timer (optional) + Alle Übungen |

### Was bereits vorhanden ist ✅

1. **Rest Timer State Management** (`RestTimerState.swift`)
   - ✅ Vollständige Timer-Logik
   - ✅ Pause/Resume/Stop
   - ✅ Persistenz
   - **Kann wiederverwendet werden**

2. **Set-Completion Logic**
   - ✅ Toggle Completion
   - ✅ Auto-Advance Notifications
   - **Kann wiederverwendet werden**

3. **Data Models**
   - ✅ Workout, WorkoutExercise, ExerciseSet
   - **Müssen erweitert werden** (Equipment, startDate, notes)

### Was komplett neu ist ❌

1. **Modal Sheet Presentation**
   - ❌ Aktuell: Full-Screen NavigationView
   - ✅ Neu: Modal Sheet mit Drag-to-Dismiss
   - **Fundamentale Änderung der Präsentation**

2. **Dynamisches Layout (Timer on/off)**
   - ❌ Aktuell: Timer-Bereich immer sichtbar
   - ✅ Neu: Timer erscheint nur bei aktivem Rest Timer
   - **Bedingte UI-Struktur**

3. **ScrollView statt TabView**
   - ❌ Aktuell: TabView (eine Übung pro Seite)
   - ✅ Neu: ScrollView (alle Übungen, vertikal scrollbar)
   - **Navigation komplett anders**

4. **Mehrere Übungen gleichzeitig sichtbar**
   - ❌ Aktuell: Nur eine Übung im TabView
   - ✅ Neu: Screenshot zeigt 2 Übungen (Squat + Hack Squat)
   - **Übersicht statt Fokus**

5. **Kompakte Set-Reihen**
   - ❌ Aktuell: Große Set-Cards mit vielen Details
   - ✅ Neu: Kompakte Reihen (`135 Kg | 6 reps | ☐`)
   - **Deutlich platzsparender**

6. **Grabber für Drag-to-Dismiss**
   - ❌ Aktuell: Nicht vorhanden
   - ✅ Neu: Grabber am oberen Rand
   - **Sheet-typisches UI-Element**

7. **Bottom Action Bar (fixiert)**
   - ❌ Aktuell: Add Set Button im ScrollView
   - ✅ Neu: Fixierte Bottom Bar mit 3 Icons
   - **Immer erreichbar**

8. **Übungs-Separatoren mit Timer**
   - ❌ Aktuell: Keine Separatoren
   - ✅ Neu: `+ | 03:00` zwischen Übungen
   - **Pause zwischen Übungen?**

9. **Equipment-Anzeige**
   - ❌ Aktuell: Nicht vorhanden
   - ✅ Neu: "Barbell", "Machine" unter Übungsname

10. **"Type anything..." zwischen Sets**
    - ❌ Aktuell: Separates Feld
    - ✅ Neu: Direkt in Übungs-Card integriert

---

## 🎨 Design-Philosophie

### Aktuelle Implementierung
- **Eine Set-Card = Eine große, touch-freundliche Karte**
- Viel Platz für Eingabefelder (32pt Font)
- Rest Timer Controls direkt in der Card
- Vertikales Scrolling durch Sets

### Screenshot-Design
- **Kompaktere, listenbasierte Darstellung**
- Timer-Fokus im oberen Bereich
- Mehrere Sets gleichzeitig sichtbar
- Weniger Scrolling erforderlich

### Philosophischer Unterschied
```
Aktuell:     Ein Set im Fokus, große Inputs, viel Platz
Screenshot:  Übersicht über mehrere Sets, kompakt, Timer-zentriert
```

---

## 🏗️ Architektur-Vorschlag (KOMPLETT NEU!)

### ❌ ALTE Architektur (wird verworfen)
```
ActiveWorkoutNavigationView (Full-Screen)
└── TabView (Horizontales Swipen zwischen Übungen)
    └── Eine Übung pro Seite
```

### ✅ NEUE Architektur (Modal Sheet)

```
HomeView
└── .sheet(isPresented: $showingActiveWorkout)
    └── ActiveWorkoutSheetView (NEU!)
        ├── Grabber (Drag Handle)
        ├── Header
        │   ├── Back Button
        │   ├── Menu (...)
        │   ├── Progress (0 / 14)
        │   └── Finish Button
        │
        ├── TimerSection (CONDITIONAL - nur bei aktivem Rest Timer)
        │   └── TabView (2 Seiten)
        │       ├── Seite 1: Timer View
        │       │   ├── Rest Timer / Workout Timer
        │       │   ├── Workout Duration
        │       │   ├── [-15s] [Skip] [+15s]
        │       │   └── Dots (• •)
        │       └── Seite 2: Insights View (TODO)
        │
        ├── ScrollView (Alle Übungen)
        │   ├── ExerciseCard (Übung 1)
        │   │   ├── Header (Name + Equipment)
        │   │   ├── CompactSetRow (Set 1)
        │   │   ├── CompactSetRow (Set 2)
        │   │   ├── CompactSetRow (Set 3)
        │   │   └── QuickAddField ("Type anything...")
        │   │
        │   ├── ExerciseSeparator (+ | 03:00)
        │   │
        │   ├── ExerciseCard (Übung 2)
        │   │   └── ...
        │   │
        │   └── ... (weitere Übungen)
        │
        └── BottomActionBar (Fixiert)
            ├── Repeat Icon (links)
            ├── Plus Icon (mittig, groß)
            └── Reorder Icon (rechts)
```

### Neue Komponenten (komplett überarbeitet)

#### 1. `ActiveWorkoutSheetView.swift` (NEU - Haupt-Container)
Ersetzt: `ActiveWorkoutNavigationView.swift`  
Verantwortung: Modal Sheet Container

```swift
struct ActiveWorkoutSheetView: View {
    @Binding var workout: Workout
    @Environment(\.dismiss) var dismiss
    let workoutStore: WorkoutStoreCoordinator
    
    var body: some View {
        VStack(spacing: 0) {
            // Grabber
            // Header (Back, Menu, Progress, Finish)
            
            // Timer Section (CONDITIONAL)
            if workoutStore.restTimerStateManager.currentState != nil {
                TimerSection()
            }
            
            // ScrollView mit allen Übungen
            ScrollView {
                ForEach(workout.exercises) { exercise in
                    ExerciseCard(exercise: exercise)
                    ExerciseSeparator() // + | 03:00
                }
            }
            
            // Bottom Action Bar (fixiert)
            BottomActionBar()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false) // Drag-to-dismiss erlaubt
    }
}
```

**Presentation:**
```swift
// In HomeView / WorkoutDetailView
.sheet(isPresented: $showingActiveWorkout) {
    ActiveWorkoutSheetView(workout: $workout, workoutStore: workoutStore)
}
```

#### 2. `TimerSection.swift` (NEU - CONDITIONAL)
Verantwortung: Timer-Bereich (nur bei aktivem Rest Timer)

```swift
struct TimerSection: View {
    @ObservedObject var workoutStore: WorkoutStoreCoordinator
    @State private var timerPage: Int = 0 // 0 = Timer, 1 = Insights
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $timerPage) {
                // Seite 1: Timer
                TimerView()
                    .tag(0)
                
                // Seite 2: Insights (TODO)
                InsightsView()
                    .tag(1)
            }
            .frame(height: 300) // Feste Höhe
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Pagination Dots
            HStack(spacing: 6) {
                Circle().fill(timerPage == 0 ? .white : .white.opacity(0.3))
                    .frame(width: 6, height: 6)
                Circle().fill(timerPage == 1 ? .white : .white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            .padding(.bottom, 8)
        }
        .background(Color.black)
    }
}
```

#### 3. `ExerciseCard.swift` (NEU)
Verantwortung: Eine Übungs-Karte mit allen Sets

```swift
struct ExerciseCard: View {
    @Binding var exercise: WorkoutExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle().fill(.red).frame(width: 8, height: 8)
                VStack(alignment: .leading) {
                    Text(exercise.exercise.name)
                        .font(.headline)
                    Text(exercise.exercise.equipment?.rawValue ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu { /* ... */ } label: {
                    Image(systemName: "ellipsis")
                }
            }
            
            // Sets (kompakt)
            ForEach(exercise.sets) { set in
                CompactSetRow(set: $set)
            }
            
            // Quick-Add Field
            TextField("Type anything...", text: $quickAddInput)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
```

#### 4. `CompactSetRow.swift` (NEU)
Verantwortung: Kompakte Set-Reihe (`135 Kg | 6 reps | ☐`)

```swift
struct CompactSetRow: View {
    @Binding var set: ExerciseSet
    
    var body: some View {
        HStack(spacing: 16) {
            // Weight
            HStack {
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                Text("Kg")
                    .foregroundStyle(.secondary)
            }
            
            // Reps
            HStack {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                Text("reps")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Checkbox
            Button {
                set.completed.toggle()
                // Trigger rest timer if needed
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }
}
```

#### 5. `ExerciseSeparator.swift` (NEU)
Verantwortung: Separator zwischen Übungen

```swift
struct ExerciseSeparator: View {
    var restTime: TimeInterval = 180 // 03:00
    
    var body: some View {
        HStack {
            Button {
                // Add new exercise?
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(formatTime(restTime))
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
```

#### 6. `BottomActionBar.swift` (NEU)
Verantwortung: Fixierte Bottom Bar

```swift
struct BottomActionBar: View {
    var body: some View {
        HStack(spacing: 0) {
            Button {
                // Repeat/Undo action
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
            }
            .frame(maxWidth: .infinity)
            
            Button {
                // Add new exercise/set
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
            }
            .frame(maxWidth: .infinity)
            
            Button {
                // Reorder exercises
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.title2)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
    }
}
```

---

## 📋 Implementierungs-Plan (KOMPLETT NEU!)

### ⚠️ WICHTIG: Kompletter Neuaufbau erforderlich

Die neue Architektur ist **so fundamental anders**, dass ein schrittweiser Umbau nicht sinnvoll ist.  
**Empfehlung:** Baue die neue View parallel, teste sie, und ersetze dann die alte komplett.

---

### Phase 1: Model-Erweiterungen 📦 ✅ ABGESCHLOSSEN
**Ziel:** Data Models für neue Features vorbereiten

**Schritte:**
1. ✅ `EquipmentType` Enum erstellen (bereits vorhanden!)
2. ✅ `Exercise.equipment` Feld hinzufügen (bereits vorhanden!)
3. ✅ `Workout.startDate` Feld hinzufügen
4. ✅ `WorkoutExercise.notes` Feld hinzufügen
5. ✅ `WorkoutExercise.restTimeToNext` Feld hinzufügen (für 03:00 Timer)
6. ✅ SwiftData Entities entsprechend erweitern

**Dauer:** ~20 Minuten (geplant: 1-2h)  
**Risiko:** Niedrig (keine Migration nötig, nur neue optionale Felder)  
**Blocker:** Keine  
**Status:** ✅ Abgeschlossen am 2025-10-20

---

### Phase 2: Basis-Komponenten 🧱
**Ziel:** Kleinste Bausteine ohne Dependencies bauen

**Schritte:**
1. `CompactSetRow.swift` - Kompakte Set-Reihe
2. `ExerciseSeparator.swift` - Separator mit Timer
3. `BottomActionBar.swift` - Fixierte Bottom Bar
4. Teste Komponenten mit Preview/Dummy-Daten

**Dauer:** 2-3 Stunden  
**Risiko:** Niedrig  
**Blocker:** Keine

---

### Phase 3: ExerciseCard 🎴
**Ziel:** Übungs-Karte mit Sets zusammenbauen

**Schritte:**
1. `ExerciseCard.swift` erstellen
2. Integriere `CompactSetRow`
3. Quick-Add Field implementieren (Parser: "100 x 8")
4. Menu (Drei-Punkte) implementieren
5. Teste mit echten Workout-Daten

**Dauer:** 2-3 Stunden  
**Risiko:** Niedrig  
**Blocker:** Phase 2

---

### Phase 4: TimerSection (Optional) ⏱️
**Ziel:** Timer-Bereich mit 2 Seiten (TabView)

**Schritte:**
1. `TimerSection.swift` erstellen (TabView mit 2 Seiten)
2. Seite 1: `TimerView` (Rest Timer + Controls)
3. Seite 2: `InsightsView` (Placeholder für später)
4. Integriere `RestTimerStateManager`
5. Teste -15s / +15s / Skip Buttons

**Dauer:** 3-4 Stunden  
**Risiko:** Mittel (RestTimer Integration)  
**Blocker:** Keine (parallel zu Phase 3 möglich)

---

### Phase 5: ActiveWorkoutSheetView 📄
**Ziel:** Haupt-Container zusammenbauen

**Schritte:**
1. `ActiveWorkoutSheetView.swift` erstellen
2. Header implementieren (Back, Menu, Progress, Finish)
3. Grabber (automatisch via `.presentationDragIndicator`)
4. Conditional TimerSection einbauen
5. ScrollView mit `ExerciseCard`s
6. `BottomActionBar` integrieren
7. Sheet Presentation in HomeView/WorkoutDetailView

**Dauer:** 2-3 Stunden  
**Risiko:** Niedrig  
**Blocker:** Phase 2, 3, 4

---

### Phase 6: State Management & Logic 🔄
**Ziel:** Alle Interaktionen verdrahten

**Schritte:**
1. Set Completion → Rest Timer triggern
2. Rest Timer → ExerciseCard scrolling/highlighting
3. Quick-Add → Set hinzufügen
4. Bottom Bar Actions implementieren
5. Drag-to-Dismiss → Workout pausieren?
6. Progress Tracking (0 / 14)
7. Persistence (SwiftData Updates)

**Dauer:** 4-5 Stunden  
**Risiko:** Hoch (viele Abhängigkeiten)  
**Blocker:** Alle vorherigen Phasen

---

### Phase 7: Polish & Testing ✨
**Ziel:** Feinschliff und Bug-Fixes

**Schritte:**
1. Animationen (Timer erscheinen/verschwinden)
2. Haptic Feedback
3. Keyboard Handling (dismiss on scroll)
4. Dark Mode Testen
5. Verschiedene Bildschirmgrößen
6. Edge Cases (leere Sets, keine Übungen, etc.)
7. Performance (bei 20+ Sets)

**Dauer:** 3-4 Stunden  
**Risiko:** Niedrig  
**Blocker:** Phase 6

---

### Phase 8: Migration & Cleanup 🧹
**Ziel:** Alte Views entfernen

**Schritte:**
1. Alle Referenzen zu `ActiveWorkoutNavigationView` ersetzen
2. Alte Files löschen:
   - `ActiveWorkoutNavigationView.swift`
   - `ActiveWorkoutExerciseView.swift`
   - `ActiveWorkoutSetCard.swift`
3. Tests aktualisieren
4. Code-Kommentare aufräumen
5. Finale Testdurchläufe

**Dauer:** 2-3 Stunden  
**Risiko:** Mittel (mögliche breaking changes)  
**Blocker:** Phase 7

---

### Gesamt-Schätzung

| Phase | Dauer | Risiko | Parallelisierbar |
|-------|-------|--------|------------------|
| 1. Models | 1-2h | Mittel | Nein |
| 2. Basis-Komponenten | 2-3h | Niedrig | Ja (zu Phase 4) |
| 3. ExerciseCard | 2-3h | Niedrig | Ja (zu Phase 4) |
| 4. TimerSection | 3-4h | Mittel | Ja (zu Phase 2-3) |
| 5. Sheet Container | 2-3h | Niedrig | Nein |
| 6. State Management | 4-5h | Hoch | Nein |
| 7. Polish | 3-4h | Niedrig | Teilweise |
| 8. Migration | 2-3h | Mittel | Nein |
| **GESAMT** | **19-27h** | | |

**Realistische Schätzung:** 20-25 Stunden (mit Pausen, Debugging, Iterationen)

---

## 🤔 Technische Überlegungen

### 1. Timer-Integration

**Frage:** Wie zeigt der Timer den aktiven Set?

**Aktueller Code:**
- Timer ist in `ActiveWorkoutSetCard` integriert
- Jeder Set hat eigenen Timer-Bereich

**Screenshot:**
- Timer ist global, oben
- Timer zeigt Zeit für aktuell aktiven Set

**Lösung:**
```swift
// TimerSection sollte aktiven Set von RestTimerState holen
if let restState = workoutStore.restTimerStateManager.currentState,
   restState.exerciseIndex == currentExerciseIndex {
    // Zeige Timer für restState.setIndex
}
```

---

### 2. Set-Completion & Auto-Advance

**Frage:** Wie funktioniert Auto-Advance mit Inline-Checkboxen?

**Aktueller Code:**
- `toggleCompletion` löst Rest Timer aus
- `NavigateToNextExercise` Notification bei letztem Set

**Screenshot:**
- Checkbox-Toggle sollte gleich funktionieren
- Evtl. Auto-Scroll zum nächsten unvollständigen Set?

**Vorschlag:**
- Behalte aktuelle Logik bei
- Füge optional Auto-Scroll zum nächsten Set hinzu
- Skip-Button überspringt Timer und geht zum nächsten Set

---

### 3. Layout-Strategie

**Frage:** Feste Höhen oder dynamisch?

**Option A: Feste Proportionen**
```swift
VStack(spacing: 0) {
    TimerSection()
        .frame(height: UIScreen.main.bounds.height * 0.4) // 40% oben
    
    SetsSection()
        .frame(maxHeight: .infinity) // 60% unten
}
```

**Option B: Flexible Layout**
```swift
GeometryReader { geometry in
    VStack(spacing: 0) {
        TimerSection()
            .frame(minHeight: 250, maxHeight: 350)
        
        SetsSection()
            .frame(maxHeight: .infinity)
    }
}
```

**Empfehlung:** Option B (flexibler, funktioniert auf mehr Geräten)

---

### 4. Dark Mode & Farben

**Screenshot:** Schwarzer Timer-Bereich, heller Set-Bereich

**Implementierung:**
```swift
TimerSection()
    .background(Color.black) // Immer schwarz
    .foregroundStyle(.white)

SetsSection()
    .background(Color(.systemBackground)) // Adaptiv
```

**Wichtig:** Timer-Bereich sollte auch im Light Mode schwarz bleiben (wie im Screenshot)

---

### 5. Swipe-Gesten & Pagination

**Aktueller Code:**
- `TabView` mit `.page(indexDisplayMode: .never)`
- Dots manuell gezeichnet in Progress Bar

**Screenshot:**
- Dots unter Timer
- Nur 2 Dots (aktuelle Übung + nächste?)

**Frage:** Zeigt jeder Dot eine Übung oder jede "Seite" (inkl. Completion)?

**Vorschlag:**
- Behalte `TabView` bei
- Zeige Dots für Übungen + Completion Screen
- Aktualisiere Dot-Position basierend auf `currentExerciseIndex`

---

### 6. Equipment-Feld

**Frage:** Woher kommt "Cable"?

**Analyse:**
```swift
struct Exercise {
    var name: String
    var category: String
    var equipment: String?  // Fehlt aktuell?
}
```

**Lösung:**
- Prüfe, ob `Exercise` Model bereits `equipment` hat
- Falls nicht: Füge neues Feld hinzu
- Zeige in `SetsSection` Header an

---

### 7. "Type anything..." Eingabefeld

**Funktion:** ✅ Quick-Add für Sets UND Notizen (beide Funktionen)

**Implementierung:**
```swift
// Smart Input Parser
if input.matches("\\d+\\s*x\\s*\\d+") {
    // Format: "100 x 8" → Neuer Set mit 100kg, 8 Reps
    let components = input.split(by: "x")
    let weight = Double(components[0].trimmed())
    let reps = Int(components[1].trimmed())
    addSet(weight: weight, reps: reps)
} else {
    // Alles andere → Als Notiz speichern
    saveNote(input)
}
```

**Beispiele:**
- `"100 x 8"` → Set: 100kg, 8 Reps
- `"80x10"` → Set: 80kg, 10 Reps  
- `"Felt heavy today"` → Notiz zur Übung

---

### 8. Action Bar Icons

**Screenshot:** Zwei Icons unten (Plus, Notes) - **Kein Undo-Button**

**Implementierung:**
```swift
HStack {
    Spacer()
    
    Button { /* Add set */ } label: {
        Image(systemName: "plus.circle.fill")
            .font(.title2)
    }
    
    Spacer()
    
    Button { /* Add/view notes */ } label: {
        Image(systemName: "note.text")
            .font(.title2)
    }
    
    Spacer()
}
```

**Note:** Undo-Funktionalität ist NICHT im neuen Design enthalten.

---

### 9. Fortschrittsanzeige "1 / 15"

**Frage:** Was bedeutet "15"?

**Optionen:**
1. Gesamtanzahl Sets in dieser Übung
2. Gesamtanzahl Sets im gesamten Workout
3. Gesamtanzahl Sets bis Workout-Ende

**Screenshot-Kontext:**
- Zeigt "1 / 15" bei erster Übung (Lat Pulldown)
- 3 Sets sichtbar + 1 Input Row = vermutlich 3-4 Sets für diese Übung
- **15 = wahrscheinlich Total Sets im Workout**

**Implementierung:**
```swift
let totalSetsInWorkout = workout.exercises.reduce(0) { $0 + $1.sets.count }
let completedSets = workout.exercises.flatMap { $0.sets }.filter { $0.completed }.count

Text("\(completedSets + 1) / \(totalSetsInWorkout)")
```

---

## 🎯 Entscheidungen erforderlich

### Design-Entscheidungen
1. **Kompakt vs. Touch-freundlich:**  
   Screenshot ist kompakter → evtl. schwerer zu tippen auf kleinen Screens?

2. **Timer immer sichtbar:**  
   Timer-Bereich ist immer da, auch wenn kein Timer läuft?

3. **Set-Input Methode:**  
   Inline TextField vs. Modal Sheet für große Inputs?

### Funktionale Entscheidungen
4. **Skip-Button Verhalten:**  
   - Überspringt nur Timer?
   - Oder überspringt ganzen Set und geht zum nächsten?

5. **Auto-Scroll:**  
   Nach Set-Completion automatisch zum nächsten unvollständigen Set scrollen?

6. **Equipment-Datenbank:**  
   Muss Exercise Model erweitert werden? Gibt es Equipment-Liste?

7. **Undo-Funktionalität:**  
   Wie weit zurück kann man "undo"? Nur letzter Set oder mehrere Schritte?

---

## 📊 Aufwandsschätzung

| Phase | Aufgabe | Stunden | Risiko |
|-------|---------|---------|--------|
| 1 | Prototyp neue Views | 2-3h | Niedrig |
| 2 | State Management | 1-2h | Mittel |
| 3 | Integration TabView | 2-3h | Mittel |
| 4 | Polish & Details | 3-4h | Niedrig |
| 5 | Migration & Cleanup | 1-2h | Niedrig |
| **Gesamt** | | **9-14h** | |

---

## 🚀 Empfohlenes Vorgehen

### Schritt 1: Klärung offener Fragen (mit User)
- Welche Entscheidungen (siehe oben) sollen wie getroffen werden?
- Gibt es Equipment-Daten in der Datenbank?
- Soll alte View komplett ersetzt oder parallel existieren (Feature Flag)?

### Schritt 2: Prototyp bauen
- Erstelle `ActiveWorkoutPageView_v2.swift`
- Baue UI mit Dummy-Daten
- Teste Darstellung auf verschiedenen Bildschirmgrößen

### Schritt 3: Inkrementelle Integration
- Feature Flag: `useCompactWorkoutView` in Settings
- Behalte alte View, bis neue stabil ist
- A/B Test mit echten Workouts

### Schritt 4: Rollout
- Feedback sammeln
- Bugs fixen
- Alte View entfernen

---

## ✅ Geklärt - User Feedback

1. **Equipment-Feld:** ✅ JA - `Exercise` Model um `equipment: String?` erweitern

2. **Fortschritt:** ✅ "1 / 15" = Aktueller Set / Total Sets im Workout (korrekt)

3. **Skip-Button:** ✅ Timer überspringen, zum nächsten Set

4. **Undo-Button:** ✅ Gibt es NICHT im neuen Design

5. **"Type anything" Feld:** ✅ Beides (Quick-Add "100 x 8" UND Notizen)

6. **Layout:** ✅ Komplett ersetzen (Modularisiert neu bauen)

7. **Dark Mode:** ✅ Timer-Bereich immer schwarz

8. **Timer-Kontrollen:** ✅ -15s (links) / +15s (rechts) unter Timer

9. **Workout-Dauer:** ✅ Unter Timer zeigt Gesamtdauer des Workouts (nicht Ziel-Zeit)

---

## 🔗 Referenzen

### Betroffene Dateien
- `GymTracker/Views/Components/ActiveWorkoutNavigationView.swift`
- `GymTracker/Views/Components/ActiveWorkoutExerciseView.swift`
- `GymTracker/Views/Components/ActiveWorkoutSetCard.swift`
- `GymTracker/Models/Workout.swift`
- `GymTracker/Models/RestTimerState.swift`
- `GymTracker/ViewModels/Theme.swift`

### Neue Dateien (geplant)
- `GymTracker/Views/Components/ActiveWorkoutPageView.swift`
- `GymTracker/Views/Components/TimerSection.swift`
- `GymTracker/Views/Components/SetsSection.swift`
- `GymTracker/Views/Components/CompactSetRow.swift`

---

## 💡 Zusätzliche Ideen

### Nice-to-have Features
1. **Gestensteuerung:**
   - Swipe-up auf Timer-Bereich: Timer-Details / Einstellungen
   - Long-press auf Set: Reorder Sets
   
2. **Animationen:**
   - Set-Completion mit Celebration Animation
   - Timer-Ablauf mit Puls-Effekt
   
3. **Accessibility:**
   - VoiceOver für alle Elemente
   - Dynamic Type Support
   - Larger Text Compatibility

4. **Smart Features:**
   - Auto-Fill basierend auf letzten Werten
   - Weight Suggestions (5kg Schritte)
   - Rest Time Recommendations

---

**Status:** ✅ Alle Fragen geklärt - Bereit für Implementierung  
**Nächste Schritte:** Phase 1 - Prototyp mit modularen Komponenten starten

---

## 🔥 Weitere Entscheidungen (finale Antworten)

### 1. Exercise Model - Equipment-Feld ✅
**Entscheidung:** Als Enum mit vordefinierten Werten

**Implementierung:**
```swift
enum EquipmentType: String, Codable, CaseIterable {
    case cable = "Cable"
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case machine = "Machine"
    case bodyweight = "Bodyweight"
    case kettlebell = "Kettlebell"
    case band = "Band"
    case plate = "Plate"
    case other = "Other"
}

struct Exercise {
    var name: String
    var category: String
    var equipment: EquipmentType?  // ✅ Als Enum
}
```

**Vorteile:**
- Typsicher (keine Tippfehler)
- Lokalisierbar (für Deutsche UI)
- Filterable (Equipment-Filter in Listen)
- CaseIterable (für Picker/Dropdown)

---

### 2. Workout-Dauer Tracking ✅
**Entscheidung:** In `Workout` Model mit neuem `startDate` Feld

**Implementierung:**
```swift
struct Workout {
    var duration: TimeInterval?  // Bereits vorhanden (finale Dauer)
    var startDate: Date?         // ✅ NEU: Wann wurde Session gestartet?
    
    // Computed Property für Live-Dauer
    var currentDuration: TimeInterval {
        guard let start = startDate else { return duration ?? 0 }
        return Date().timeIntervalSince(start)
    }
}
```

**Workflow:**
1. User startet Workout → `workout.startDate = Date()`
2. Während Session → Timer zeigt `workout.currentDuration`
3. User beendet Workout → `workout.duration = currentDuration`, `startDate = nil`

**Persistenz:** `startDate` wird in SwiftData gespeichert (force quit recovery)

---

### 3. Set-Reihenfolge bei Quick-Add ✅
**Entscheidung:** Am Ende der Liste (K.I.S.S. Prinzip)

**Implementierung:**
```swift
func handleQuickAdd(input: String) {
    if let (weight, reps) = parseSetInput(input) {
        let newSet = ExerciseSet(
            reps: reps,
            weight: weight,
            restTime: workout.defaultRestTime,
            completed: false
        )
        workout.exercises[currentExerciseIndex].sets.append(newSet)
        // Append to SwiftData entity as well
        appendEntitySet(exerciseId, newSet)
    } else {
        // Save as note
        workout.exercises[currentExerciseIndex].notes = input
    }
}
```

**K.I.S.S. Prinzip:** Einfachste Implementierung, User kann Sets per Drag & Drop umordnen falls nötig

---

### 4. Notizen-Scope ✅
**Entscheidung:** Pro Übung (in `WorkoutExercise`)

**Implementierung:**
```swift
struct WorkoutExercise: Identifiable, Codable {
    let id: UUID
    var exercise: Exercise
    var sets: [ExerciseSet]
    var notes: String?  // ✅ NEU: Notizen pro Übung
}
```

**UI Integration:**
- "Type anything..." Feld speichert in `workout.exercises[currentIndex].notes`
- Notiz-Icon in Action Bar zeigt/editiert `notes`
- Notizen werden in Session History angezeigt

**Beispiel:**
```
Übung: Lat Pulldown
Notizen: "Felt heavy today, reduce weight next time"
```

---

### 5. Rest Timer vs. Workout Timer ✅
**Entscheidung:** Zeigt nur Workout-Gesamtdauer (keine Rest Timer Controls)

**Implementierung - Kein Rest Timer aktiv:**
```
┌──────────────────────────┐
│                          │
│       04:23              │  ← Workout-Gesamtdauer (groß)
│   Workout Timer          │  ← Label (klein, grau)
│                          │
│  [KEINE BUTTONS]         │  ← Kein Skip, kein -15s/+15s
│                          │
└──────────────────────────┘
```

**Implementierung - Rest Timer aktiv:**
```
┌──────────────────────────┐
│       01:45              │  ← Rest Timer Countdown (groß)
│       04:23              │  ← Workout-Dauer (klein, grau)
│                          │
│  [-15s] [Skip] [+15s]    │  ← Buttons nur bei aktivem Rest Timer
└──────────────────────────┘
```

**Logic:**
```swift
if let restState = workoutStore.restTimerStateManager.currentState {
    // Zeige Rest Timer + Buttons
} else {
    // Zeige nur Workout-Dauer (groß, zentriert)
    // KEINE Buttons
}
```

**Note:** Kann später angepasst werden (z.B. "Ready" State oder Play-Button)

---

### 6. Pagination Dots ✅
**Entscheidung:** 2 Dots für Timer-Bereich = Timer + Insights

**Screenshot-Kontext:**
- 2 Dots am unteren Ende des Timer-Bereichs (nicht für Übungen!)
- **Seite 1:** Rest Timer / Workout Timer (wie im Screenshot)
- **Seite 2:** Insights zum aktuellen Workout (wird später spezifiziert)

**Implementierung:**
```swift
// Timer-Bereich ist ein eigener TabView mit 2 Seiten
struct TimerSection: View {
    @State private var timerPage: Int = 0  // 0 = Timer, 1 = Insights
    
    var body: some View {
        TabView(selection: $timerPage) {
            // Seite 1: Timer (Rest Timer oder Workout-Dauer)
            TimerView()
                .tag(0)
            
            // Seite 2: Insights (TODO: später spezifizieren)
            WorkoutInsightsView()
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black)
        
        // Pagination Dots
        HStack(spacing: 6) {
            Circle()
                .fill(timerPage == 0 ? Color.white : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
            Circle()
                .fill(timerPage == 1 ? Color.white : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
        }
    }
}
```

**Wichtig:** 
- Dots sind NICHT für Navigation zwischen Übungen
- Swipe horizontal im Timer-Bereich = Timer ↔ Insights
- Swipe horizontal im Set-Bereich = Übung ↔ Übung (wie bisher)

**TODO:** Insights-Seite wird später spezifiziert (z.B. Statistiken, Fortschritt, Herzfrequenz)

---

### 7. Haptic Feedback ✅
**Entscheidung:** Minimal - nur Set Completion + Long Press

**Implementierung:**
```swift
// ✅ Set Completion Toggle
Button {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    toggleCompletion()
} label: { /* Checkbox */ }

// ✅ Long Press (Delete, Reorder)
.onLongPressGesture {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    showDeleteConfirmation = true
}
```

**NICHT verwenden:**
- ❌ Timer Skip (zu häufig)
- ❌ -15s / +15s (zu häufig)
- ❌ Quick-Add (zu subtil)
- ❌ Swipe zwischen Übungen (System-Geste)

**Rationale:** Weniger ist mehr - Haptic Feedback nur für wichtige Aktionen

---

### 8. Inline Editing Verhalten ✅
**Entscheidung:** Immer editierbare TextFields (wie Screenshot)

**Implementierung:**
```swift
struct CompactSetRow: View {
    @Binding var set: ExerciseSet
    
    var body: some View {
        HStack(spacing: 12) {
            // Weight TextField (immer editierbar)
            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
                .frame(width: 80)
            
            Text("kg")
                .foregroundStyle(.secondary)
            
            // Reps TextField (immer editierbar)
            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.leading)
                .frame(width: 60)
            
            Text("reps")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Checkbox
            Button { toggleCompletion() } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
            }
        }
        .padding()
    }
}
```

**Vorteile:**
- Schneller Input (kein Modal)
- Wie im Screenshot
- Touch-freundlich genug für große Finger

---

### 9. Checkpoint/Persistence ✅
**Entscheidung:** Immediate Persistence (aktuelles System beibehalten)

**Implementierung:**
```swift
// Set-Werte ändern → sofort speichern
TextField("0", value: Binding(
    get: { set.weight },
    set: { newValue in
        set.weight = newValue
        updateEntitySet(exerciseId, setId) { entity in
            entity.weight = newValue
        }
    }
))

// Notizen speichern
func saveNote(_ text: String) {
    workout.exercises[currentIndex].notes = text
    updateEntityExercise(exerciseId) { entity in
        entity.notes = text
    }
}

// Workout Start Time
func startWorkout() {
    workout.startDate = Date()
    saveWorkout()  // SwiftData auto-save
}
```

**Persistenz-Punkte:**
- ✅ Set-Werte (weight, reps)
- ✅ Set Completion
- ✅ Workout Start Time
- ✅ Notizen pro Übung
- ✅ Equipment (wenn Exercise Model erweitert)

**Rationale:** Immediate Persistence = kein Datenverlust bei App Crash

---

## 🎯 Finale Zusammenfassung

### Alle Entscheidungen getroffen ✅

1. **Equipment:** Enum (EquipmentType)
2. **Workout-Dauer:** startDate Feld hinzufügen
3. **Quick-Add:** Am Ende der Liste
4. **Notizen:** Pro Übung (WorkoutExercise.notes)
5. **Timer ohne Rest:** Zeigt Workout-Dauer, keine Buttons
6. **Pagination:** 2 Dots im Timer-Bereich (Timer ↔ Insights)
7. **Haptic:** Nur Set Completion + Long Press
8. **Inline Editing:** Immer editierbare TextFields
9. **Persistence:** Immediate (aktuelles System)

### Bereit für Implementierung 🚀

**Nächste Schritte:**
1. Phase 1: Prototyp mit modularen Komponenten
2. Model-Erweiterungen (Equipment, startDate, notes)
3. TimerSection Component
4. CompactSetRow Component
5. Integration in TabView

**Geschätzte Gesamtdauer:** 9-14 Stunden
