# Active Workout Redesign - Integration Testing Guide

## 🚀 Wie du die neue UI testen kannst

### Option 1: SwiftUI Previews (EMPFOHLEN - Kein Code-Change nötig!)

1. **Öffne Xcode:**
   ```bash
   cd /Users/benkohler/Projekte/gym-app
   open GymBo.xcodeproj
   ```

2. **Öffne eine der neuen Dateien:**
   - `Cmd+Shift+O` (Quick Open)
   - Tippe: `ActiveWorkoutSheetView`
   - Enter

3. **Aktiviere Preview Canvas:**
   - Menü: `Editor → Canvas`
   - Oder: `Opt+Cmd+Enter`
   - Oder: Rechts oben auf "Adjust Editor Options" → "Canvas"

4. **Preview sollte laden:**
   - Falls nicht: Klick "Resume" im Preview Panel
   - Warte ~10-30 Sekunden beim ersten Mal

5. **Teste alle Previews:**
   ```
   ActiveWorkoutSheetView.swift:
   - Preview "Active Workout with Rest Timer"
   - Preview "Empty State"  
   - Preview "Multiple Exercises"
   
   TimerSection.swift:
   - Preview "With Active Rest Timer"
   - Preview "Without Rest Timer"
   - Preview "Insights Page"
   
   ActiveExerciseCard.swift:
   - Preview "Single Exercise"
   - Preview "With Notes"
   - Preview "Multiple Exercises"
   - Preview "Empty Sets"
   ```

---

### Option 2: Temporärer Test-Button (Für App-Testing)

Wenn du die neue View in der **echten App** testen willst:

#### Schritt 1: Füge Test-Button zu HomeView hinzu

Öffne: `GymTracker/Views/Components/Home/WorkoutsHomeView.swift` (oder ähnlich)

Füge irgendwo einen temporären Button hinzu:

```swift
// MARK: - TEMPORARY: Test Active Workout V2
@State private var showingTestWorkout = false

// Im body, z.B. in der Toolbar oder als FloatingActionButton:
Button("🧪 Test Active Workout V2") {
    showingTestWorkout = true
}
.sheet(isPresented: $showingTestWorkout) {
    ActiveWorkoutSheetView(
        workout: .constant(createTestWorkout()),
        workoutStore: workoutStore
    )
}

// Helper function für Test-Daten:
private func createTestWorkout() -> Workout {
    Workout(
        id: UUID(),
        name: "Test Workout",
        date: Date(),
        exercises: [
            WorkoutExercise(
                exercise: Exercise(
                    name: "Bench Press",
                    muscleGroups: [.chest],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                    ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                    ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                ]
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Squat",
                    muscleGroups: [.legs],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 5, weight: 140, restTime: 180, completed: false),
                    ExerciseSet(reps: 5, weight: 140, restTime: 180, completed: false),
                ]
            ),
        ],
        startDate: Date().addingTimeInterval(-300) // Started 5 mins ago
    )
}
```

#### Schritt 2: Import hinzufügen

Falls noch nicht vorhanden, stelle sicher dass am Anfang der Datei steht:
```swift
import SwiftUI
```

#### Schritt 3: Build & Run

```bash
# In Xcode:
Cmd+R

# Oder im Terminal:
xcodebuild -project GymBo.xcodeproj \
  -scheme GymTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  run
```

#### Schritt 4: Klick den Test-Button

- Öffne die App
- Finde den "🧪 Test Active Workout V2" Button
- Klick drauf
- Die neue Modal Sheet sollte erscheinen!

---

### Option 3: Ersetze die alte View (Production Integration)

**ACHTUNG:** Das ist die richtige Integration, aber **nicht reversibel** ohne Git!

#### In WorkoutDetailView.swift:

Finde die Stelle wo `ActiveWorkoutNavigationView` verwendet wird und ersetze sie:

```swift
// ALT:
// ActiveWorkoutNavigationView(...)

// NEU:
ActiveWorkoutSheetView(
    workout: $workout,
    workoutStore: workoutStore,
    onDismiss: {
        onActiveSessionEnd?()
        dismiss()
    }
)
```

**Tipp:** Mach vorher ein `git stash` oder `git branch test-integration`, damit du zurück kannst!

---

## ✅ Welche Option solltest du wählen?

| Option | Aufwand | Empfehlung |
|--------|---------|------------|
| **Option 1: Previews** | 0 Code | ⭐⭐⭐⭐⭐ Beste für Quick-Check |
| **Option 2: Test-Button** | ~20 Zeilen Code | ⭐⭐⭐⭐ Gut für echtes Testing |
| **Option 3: Production** | ~5 Zeilen Code | ⭐⭐ Nur wenn du sicher bist |

**Empfehlung:** Starte mit **Option 1 (Previews)** - kein Code-Change nötig!

---

## 🐛 Troubleshooting

### Preview lädt nicht?

```bash
# 1. Clean Build Folder
Xcode → Product → Clean Build Folder (Shift+Cmd+K)

# 2. Rebuild
Cmd+B

# 3. Preview neu starten
Opt+Cmd+P (Preview refresh)
```

### "Cannot find type 'ActiveWorkoutSheetView'"?

```bash
# Prüfe ob Datei im Projekt ist:
grep -r "ActiveWorkoutSheetView" GymBo.xcodeproj/project.pbxproj

# Sollte mindestens 2 Zeilen zurückgeben
# Falls nicht: Datei wurde nicht zum Projekt hinzugefügt
```

### Build Errors?

```bash
# Prüfe Branch:
git branch
# Sollte zeigen: * feature/active-workout-redesign

# Falls auf master:
git checkout feature/active-workout-redesign
```

---

## 📍 Wo sind die Dateien?

Alle neuen Komponenten sind hier:

```
GymTracker/Views/Components/ActiveWorkoutV2/
├── CompactSetRow.swift           ✅ Im Projekt
├── ExerciseSeparator.swift       ✅ Im Projekt  
├── BottomActionBar.swift         ✅ Im Projekt
├── ExerciseCard.swift            ✅ Im Projekt (als ActiveExerciseCard)
├── TimerSection.swift            ✅ Im Projekt
└── ActiveWorkoutSheetView.swift  ✅ Im Projekt
```

Du kannst sie in Xcode's **Project Navigator** (linke Sidebar) finden:
```
GymBo
└── GymTracker
    └── Views
        └── Components
            └── ActiveWorkoutV2  ← Hier!
```

---

## 🎯 Schnellste Testing-Methode (5 Minuten):

```bash
# 1. Xcode öffnen
open GymBo.xcodeproj

# 2. Cmd+Shift+O → "ActiveWorkoutSheetView" → Enter

# 3. Opt+Cmd+Enter (Preview Canvas öffnen)

# 4. Warte ~20 Sekunden

# 5. Interagiere mit Preview:
#    - Klick Checkboxen
#    - Tippe in Quick-Add Field
#    - Teste Menu Button
#    - Scroll durch Übungen

# 6. Switch Previews:
#    - Unten im Preview Panel siehst du alle 3 Previews
#    - Klick sie durch
```

**Fertig!** Du hast die neue UI getestet ohne Code-Änderung! 🎉

---

## 💡 Tipp: Live Preview Interaktion

Xcode's SwiftUI Preview ist **interaktiv**:
- Du kannst Buttons klicken
- Du kannst Text eingeben
- Du kannst scrollen
- Du siehst State-Changes in Echtzeit

Es ist fast wie die echte App! 🚀
