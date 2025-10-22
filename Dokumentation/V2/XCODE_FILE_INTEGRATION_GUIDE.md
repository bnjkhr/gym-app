# Xcode File Integration Guide

**Problem:** Compiler-Fehler "Cannot find type '...' in scope"

**Ursache:** Die neuen V2 Clean Architecture Files wurden via Git erstellt, sind aber noch nicht im Xcode-Projekt registiert.

---

## 🔧 Schnelle Lösung: Alle Files hinzufügen

### Option 1: Via Xcode GUI (Empfohlen)

1. **Öffne Xcode:**
   ```bash
   open /Users/benkohler/Projekte/gym-app/GymBo.xcodeproj
   ```

2. **Finde GymTracker Group in Project Navigator** (linke Sidebar)

3. **Right-Click auf GymTracker → "Add Files to 'GymBo'..."**

4. **Navigiere zu `/Users/benkohler/Projekte/gym-app/GymTracker/`**

5. **Wähle ALLE neuen Ordner:**
   - ✅ `Domain/` (kompletter Ordner)
   - ✅ `Data/` (kompletter Ordner)
   - ✅ `Presentation/Stores/` (kompletter Ordner)
   - ✅ `Infrastructure/DI/` (DependencyContainer.swift sollte schon drin sein)

6. **Wichtig: Aktiviere folgende Optionen:**
   - ✅ "Copy items if needed" (NICHT aktivieren, Files sind schon da)
   - ✅ "Create groups" (NICHT "Create folder references")
   - ✅ "Add to targets: GymTracker" (Target auswählen!)

7. **Klick "Add"**

---

## 📋 Vollständige File-Liste zum Hinzufügen

### Domain Layer (Sprint 1.2)
```
GymTracker/Domain/
├── Entities/
│   ├── WorkoutSession.swift          [ADD]
│   ├── SessionExercise.swift         [ADD]
│   └── SessionSet.swift              [ADD]
├── RepositoryProtocols/
│   └── SessionRepositoryProtocol.swift [ADD]
└── UseCases/
    └── Session/
        ├── StartSessionUseCase.swift   [ADD]
        ├── CompleteSetUseCase.swift    [ADD]
        └── EndSessionUseCase.swift     [ADD]
```

### Data Layer (Sprint 1.3)
```
GymTracker/Data/
├── Entities/
│   ├── WorkoutSessionEntity.swift    [ADD]
│   ├── SessionExerciseEntity.swift   [ADD]
│   └── SessionSetEntity.swift        [ADD]
├── Mappers/
│   └── SessionMapper.swift           [ADD]
└── Repositories/
    └── SwiftDataSessionRepository.swift [ADD]
```

### Presentation Layer (Sprint 1.4)
```
GymTracker/Presentation/
└── Stores/
    └── SessionStore.swift            [ADD]
```

### Infrastructure Layer
```
GymTracker/Infrastructure/
└── DI/
    └── DependencyContainer.swift     [SHOULD EXIST]
```

---

## ✅ Verifizierung

Nach dem Hinzufügen der Files:

1. **Build das Projekt:**
   ```
   Cmd + B
   ```

2. **Erwartete Ergebnisse:**
   - ✅ BUILD SUCCEEDED
   - ✅ 0 Errors
   - ⚠️ Möglicherweise Warnings (ignorierbar)

3. **Falls Fehler bleiben:**
   - Check "Target Membership" für jedes File
   - Stelle sicher, dass "GymTracker" target aktiviert ist
   - Clean Build Folder (Cmd + Shift + K, dann Cmd + B)

---

## 🐛 Häufige Fehler

### Fehler 1: "Cannot find type 'SessionRepositoryProtocol'"

**Ursache:** `SessionRepositoryProtocol.swift` nicht zum Target hinzugefügt

**Lösung:**
1. Finde File im Project Navigator
2. Öffne File Inspector (rechte Sidebar, Cmd + Option + 1)
3. Unter "Target Membership" → ✅ GymTracker aktivieren

### Fehler 2: "Cannot find type 'WorkoutSession'"

**Ursache:** Domain Entities nicht zum Target hinzugefügt

**Lösung:** Alle 3 Entity-Files hinzufügen:
- `WorkoutSession.swift`
- `SessionExercise.swift`
- `SessionSet.swift`

### Fehler 3: "Cannot find type 'SwiftDataSessionRepository'"

**Ursache:** Data Layer nicht zum Target hinzugefügt

**Lösung:** Kompletten `Data/` Ordner hinzufügen

### Fehler 4: Files erscheinen rot im Project Navigator

**Ursache:** Files existieren auf Disk, aber Xcode findet sie nicht

**Lösung:**
1. Entferne rote Files aus Xcode (Delete → "Remove Reference")
2. Füge Files erneut hinzu (Add Files to 'GymBo'...)

---

## 🚀 Alternative: Script-basierte Integration

Falls GUI nicht funktioniert, kannst du Files programmatisch hinzufügen:

```bash
# Navigiere zum Projekt
cd /Users/benkohler/Projekte/gym-app

# Liste alle neuen V2 Files
find GymTracker/Domain -name "*.swift"
find GymTracker/Data -name "*.swift"
find GymTracker/Presentation/Stores -name "*.swift"

# HINWEIS: .pbxproj Manipulation ist fehleranfällig
# Empfehlung: Nutze Xcode GUI statt Script
```

---

## 📊 Erwartete Projektstruktur in Xcode

Nach erfolgreichem Hinzufügen sollte deine Project Navigator so aussehen:

```
GymBo
├── GymTracker
│   ├── Domain
│   │   ├── Entities
│   │   │   ├── WorkoutSession.swift
│   │   │   ├── SessionExercise.swift
│   │   │   └── SessionSet.swift
│   │   ├── RepositoryProtocols
│   │   │   └── SessionRepositoryProtocol.swift
│   │   └── UseCases
│   │       └── Session
│   │           ├── StartSessionUseCase.swift
│   │           ├── CompleteSetUseCase.swift
│   │           └── EndSessionUseCase.swift
│   ├── Data
│   │   ├── Entities
│   │   │   ├── WorkoutSessionEntity.swift
│   │   │   ├── SessionExerciseEntity.swift
│   │   │   └── SessionSetEntity.swift
│   │   ├── Mappers
│   │   │   └── SessionMapper.swift
│   │   └── Repositories
│   │       └── SwiftDataSessionRepository.swift
│   ├── Presentation
│   │   ├── Stores
│   │   │   └── SessionStore.swift
│   │   └── Views
│   │       └── ActiveWorkout
│   │           └── ActiveWorkoutSheetView.swift (refactored)
│   └── Infrastructure
│       └── DI
│           └── DependencyContainer.swift
```

---

## 🎯 Nach erfolgreicher Integration

1. **Rebuild:**
   ```
   Cmd + Shift + K  (Clean Build Folder)
   Cmd + B          (Build)
   ```

2. **Erwartung:**
   ```
   ✅ BUILD SUCCEEDED
   ```

3. **Nächster Schritt:**
   - Manual Testing im Simulator
   - Session mit neuer SessionStore starten
   - Verifizieren, dass alle Use Cases funktionieren

---

## 📞 Falls weiterhin Probleme

**Debug-Checkliste:**

1. ✅ Alle Files existieren auf Disk?
   ```bash
   ls -la GymTracker/Domain/Entities/
   ls -la GymTracker/Data/Repositories/
   ls -la GymTracker/Presentation/Stores/
   ```

2. ✅ Target Membership korrekt?
   - Jedes File im File Inspector prüfen
   - "GymTracker" muss aktiviert sein

3. ✅ Keine duplicate Symbols?
   - Keine Files doppelt hinzugefügt?
   - Clean Build Folder

4. ✅ Swift Version kompatibel?
   - Sollte Swift 5.x sein
   - Check Build Settings → Swift Language Version

5. ✅ Deployment Target kompatibel?
   - iOS 18.0+ (wegen @Model/@Relationship)

---

**Viel Erfolg! 🚀**

Bei weiteren Problemen: Check SPRINT_1_4_PROGRESS.md für Details zu jedem File.
