# GymBo - iOS Fitness Tracking App

## Übersicht

GymBo ist eine native iOS-App für intelligentes Workout-Tracking mit Fokus auf Benutzerfreundlichkeit, Performance und Offline-Fähigkeit. Die App bietet umfassende Funktionen zur Trainingsplanung, -durchführung und -analyse.

## Inhaltsverzeichnis

- [Features](#features)
- [Technologie-Stack](#technologie-stack)
- [Architektur](#architektur)
- [Datenmodell](#datenmodell)
- [Projektstruktur](#projektstruktur)
- [Kernkomponenten](#kernkomponenten)
- [Features im Detail](#features-im-detail)
- [Installation & Setup](#installation--setup)
- [Performance-Optimierungen](#performance-optimierungen)

---

## Features

### 🏋️ Workout-Management
- **Workout-Vorlagen**: Erstellen, bearbeiten und verwalten von Trainingsvorlagen
- **Live-Sessions**: Aktive Workout-Sessions mit Echtzeit-Tracking
- **161 vordefinierte Übungen** aus CSV-Datenbank mit detaillierten Informationen
- **Workout-Wizard**: KI-gestützter Assistent zur Workout-Erstellung
- **Favoriten-System**: Markierung häufig verwendeter Workouts (max. 4 Home-Favoriten)
- **Workout-Sharing**: Export/Import von Workouts als `.gymtracker` Dateien

### 📊 Tracking & Statistiken
- **Satz-für-Satz Tracking**: Detaillierte Erfassung von Gewicht, Wiederholungen und Pausenzeiten
- **Rest-Timer**: Automatischer Timer mit Notification-Support
- **Personal Records**: Automatische Erkennung und Anzeige von Bestleistungen
- **Wochenfortschritt**: Visualisierung des Trainingsfortschritts
- **Kalenderansicht**: Übersicht über absolvierte Trainingseinheiten
- **Session-Historie**: Vollständige History aller Trainings

### 🎯 Smart Features
- **Live Activities** (iOS 16.1+): Dynamic Island Integration für aktive Workouts
- **HealthKit-Integration**: Synchronisation von Trainingsdaten und Gesundheitsmetriken
- **Sprachsteuerung**: SpeechRecognizer für Hands-free Bedienung (in Entwicklung)
- **Intelligente Empfehlungen**: Letzte verwendete Gewichte und Wiederholungen werden vorgeschlagen
- **Smart Tips**: Trainingsbasierte Tipps und Empfehlungen

### 👤 Personalisierung
- **Benutzerprofil**: Name, Geburtsdatum, Größe, Gewicht, Profilbild
- **Spint-Nummer**: Speicherung der Umkleidekabinen-Nummer
- **Wochenziel**: Individuelles Trainingsziel pro Woche
- **Onboarding**: Geführter Einstieg für neue Nutzer
- **Themes**: Anpassbares Farbschema (Power Orange, Deep Blue, Moss Green, etc.)

---

## Technologie-Stack

### Frameworks & SDKs
- **SwiftUI**: Deklaratives UI-Framework
- **SwiftData**: Persistenz-Layer (seit iOS 17)
- **HealthKit**: Gesundheitsdaten-Integration
- **ActivityKit**: Live Activities & Dynamic Island
- **Combine**: Reactive Programming
- **UserNotifications**: Push-Benachrichtigungen
- **AVFoundation**: Audio-Feedback
- **Charts**: Datenvisualisierung

### Sprache & Tools
- **Swift 5.9+**
- **iOS 17.0+ Target**
- **Xcode 15+**

---

## Architektur

### MVVM + SwiftUI Hybrid

```
┌─────────────────────────────────────────────────┐
│                     Views                        │
│  (SwiftUI Views mit @State, @Query, @Binding)   │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│                  ViewModel                       │
│          (WorkoutStore als @StateObject)         │
│  - Session-Management, State, Business Logic    │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│               Data Layer                         │
│  SwiftData Entities + Domain Models (Structs)   │
│  - ExerciseEntity, WorkoutEntity, etc.          │
└─────────────────────────────────────────────────┘
```

### Komponenten-Übersicht

#### 1. **Views** (SwiftUI)
- Präsentationsschicht mit deklarativem UI
- Verwendet `@Query` für reaktive SwiftData-Bindung
- `@EnvironmentObject` für WorkoutStore-Zugriff

#### 2. **ViewModel** (WorkoutStore)
- Zentrale State-Verwaltung
- Session-Lifecycle-Management
- Rest-Timer und Live Activity Control
- UserDefaults für Profile-Persistierung

#### 3. **Models**
- **Domain Models**: Value Types (Structs) für Business Logic
  - `Exercise`, `Workout`, `WorkoutExercise`, `ExerciseSet`
- **SwiftData Entities**: Persistente Datenmodelle
  - `ExerciseEntity`, `WorkoutEntity`, `WorkoutSessionEntity`, etc.
- **Mapping-Layer**: Bidirektionale Konvertierung zwischen Domain Models und Entities

#### 4. **Services**
- `WorkoutAnalyzer`: Trainingsanalyse
- `TipEngine`: Smart Tips Generierung
- `HealthKitManager`: HealthKit-Integration
- `NotificationManager`: Push-Benachrichtigungen
- `AudioManager`: Sound-Feedback

---

## Datenmodell

### SwiftData Schema

```swift
┌─────────────────────┐
│  ExerciseEntity     │
│─────────────────────│
│ + id: UUID          │
│ + name: String      │
│ + muscleGroupsRaw   │
│ + equipmentTypeRaw  │
│ + difficultyLevel   │
│ + lastUsedWeight    │
│ + lastUsedReps      │
└──────────┬──────────┘
           │ 1
           │
           │ *
┌──────────▼──────────┐       ┌─────────────────────┐
│WorkoutExerciseEntity│───────│  ExerciseSetEntity  │
│─────────────────────│ 1   * │─────────────────────│
│ + id: UUID          │       │ + id: UUID          │
│ + exercise          │       │ + reps: Int         │
│ + sets: [Set]       │       │ + weight: Double    │
└──────────┬──────────┘       │ + restTime: Time    │
           │                  │ + completed: Bool   │
           │                  └─────────────────────┘
           │
           │ *
┌──────────▼──────────┐
│   WorkoutEntity     │
│─────────────────────│
│ + id: UUID          │
│ + name: String      │
│ + exercises: []     │
│ + defaultRestTime   │
│ + isFavorite: Bool  │
│ + isSampleWorkout   │
└─────────────────────┘

┌─────────────────────┐
│WorkoutSessionEntity │  (Historie)
│─────────────────────│
│ + id: UUID          │
│ + templateId: UUID? │
│ + name: String      │
│ + date: Date        │
│ + exercises: []     │
│ + duration: Time?   │
└─────────────────────┘

┌─────────────────────┐
│ExerciseRecordEntity │  (Bestleistungen)
│─────────────────────│
��� + exerciseId: UUID  │
│ + maxWeight: Double │
│ + maxReps: Int      │
│ + bestOneRepMax     │
└─────────────────────┘

┌─────────────────────┐
│ UserProfileEntity   │
│─────────────────────│
│ + id: UUID          │
│ + name: String      │
│ + birthDate: Date?  │
│ + weight: Double?   │
│ + profileImageData  │
│ + lockerNumber      │
│ + hasExploredWorkouts│
└─────────────────────┘
```

### Enumerations

```swift
enum MuscleGroup: String, CaseIterable {
    case chest, back, shoulders, biceps, triceps,
         legs, glutes, abs, cardio, forearms, calves,
         trapezius, lowerBack, upperBack, fullBody,
         hips, core, hamstrings, lats, grip, arms,
         adductors, obliques, hipFlexors, traps,
         coordination
}

enum EquipmentType: String, CaseIterable {
    case freeWeights  // Freie Gewichte
    case machine      // Maschine
    case bodyweight   // Körpergewicht
    case cable        // Kabelzug
    case mixed        // Gemischt
}

enum DifficultyLevel: String, CaseIterable {
    case anfänger           // Anfänger
    case fortgeschritten    // Fortgeschritten
    case profi              // Profi
}
```

---

## Projektstruktur

```
GymTracker/
├── GymTrackerApp.swift           # App Entry Point + Migrations
├── ContentView.swift              # Root View (TabView)
│
├── Models/                        # Domain Models (Value Types)
│   ├── Exercise.swift             # Exercise struct + Enums
│   ├── Workout.swift              # Workout, WorkoutExercise, ExerciseSet
│   ├── WorkoutSession.swift       # Session-Historie
│   ├── ShareableWorkout.swift     # Export/Import Format
│   ├── TrainingTip.swift          # Smart Tips
│   └── WorkoutPreferences.swift   # Wizard-Präferenzen
│
├── SwiftDataEntities.swift        # @Model Entities (Persistenz)
├── Workout+SwiftDataMapping.swift # Entity ↔ Domain Model Mapping
│
├── ViewModels/
│   ├── WorkoutStore.swift         # Zentrale State-Verwaltung
│   ├── Theme.swift                # App-Theme Definition
│   └── ProfilePersistenceHelper.swift
│
├── Views/                         # SwiftUI Views
│   ├── WorkoutsView.swift         # Workout-Liste (Tab)
│   ├── WorkoutDetailView.swift    # Workout-Ausführung
│   ├── EditWorkoutView.swift      # Workout-Editor
│   ├── ExercisesView.swift        # Übungskatalog
│   ├── StatisticsView.swift       # Insights (Tab)
│   ├── ProfileView.swift          # Benutzerprofil
│   ├── SettingsView.swift         # Einstellungen
│   ├── WorkoutWizardView.swift    # KI-Workout-Generator
│   └── Components/
│       └── SmartTipsCard.swift
│
├── Services/
│   ├── WorkoutAnalyzer.swift      # Trainingsanalyse
│   ├── TipEngine.swift            # Tipp-Generierung
│   └── TipFeedbackManager.swift   # Tipp-Bewertung
│
├── LiveActivities/
│   ├── WorkoutActivityAttributes.swift
│   └── WorkoutLiveActivityController.swift
│
├── Database/
│   └── ModelContainerFactory.swift  # Container-Erstellung mit Fallbacks
│
├── Migrations/
│   ├── ExerciseDatabaseMigration.swift
│   ├── ExerciseRecordMigration.swift
│   └── ExerciseLastUsedMigration.swift
│
├── Seeders/
│   ├── ExerciseSeeder.swift        # CSV → Database Import
│   └── WorkoutSeeder.swift         # Sample Workouts
│
├── Managers/
│   ├── HealthKitManager.swift
│   ├── NotificationManager.swift
│   ├── AudioManager.swift
│   └── BackupManager.swift
│
└── Resources/
    ├── exercises.csv               # 161 Übungen
    └── Sounds/
        └── *.m4a                   # Audio-Dateien
```

---

## Kernkomponenten

### 1. GymTrackerApp.swift

**Zuständigkeiten:**
- App-Lifecycle
- SwiftData Container-Setup mit Fallback-Chain
- Automatische Datenmigrationen beim Start
- Storage Health Check

**Migrations-Pipeline:**
```swift
1. ExerciseDatabaseMigration    // CSV → Database
2. Exercise UUID Check          // Deterministische IDs prüfen
3. Sample Workout Update        // Versionierte Beispiel-Workouts
4. ExerciseRecord Migration     // Bestleistungen generieren
5. LastUsed Migration           // Letzte Werte setzen
6. Live Activity Setup          // Dynamic Island initialisieren
```

### 2. WorkoutStore.swift

**Properties:**
- `activeSessionID: UUID?` - Aktive Session
- `activeRestState: RestState?` - Rest-Timer State
- `userProfile: UserProfile` - Benutzerprofil
- `weeklyGoal: Int` - Wochenziel
- `modelContext: ModelContext?` - SwiftData Context

**Methoden:**
```swift
func startSession(for workoutID: UUID)
func endSession(for workoutID: UUID)
func startRest(for workoutID: UUID, duration: TimeInterval)
func stopRest()
func toggleHomeFavorite(workoutID: UUID) -> Bool
func updateUserProfile(...)
```

### 3. ModelContainerFactory.swift

**Robuste Container-Erstellung mit Fallback-Chain:**

```swift
1. Application Support (Standard, persistent)
   ↓ Fehler?
2. Documents Directory (Fallback, persistent)
   ↓ Fehler?
3. Temporary Directory (Fallback, flüchtig)
   ↓ Fehler?
4. In-Memory (Letzter Ausweg, flüchtig)
```

**Storage Health Check:**
- Verfügbarer Speicherplatz prüfen
- Schreibrechte validieren
- Korrupte Datenbanken erkennen

### 4. Live Activities (iOS 16.1+)

**WorkoutLiveActivityController:**
```swift
func start(workoutName: String)
func update(setsCompleted: Int, setsTotal: Int)
func end()
```

**Integration:**
- Deep Link Support: `workout://active`
- Dynamic Island Anzeige
- Lock Screen Widget

---

## Features im Detail

### Workout-Wizard

**Ablauf:**
1. Ziel-Auswahl (Muskelaufbau, Kraft, Ausdauer, etc.)
2. Erfahrungslevel (Anfänger, Fortgeschritten, Profi)
3. Verfügbares Equipment
4. Gewünschte Dauer
5. KI-generiertes Workout-Preview
6. Speichern oder Anpassen

**Implementierung:**
- `WorkoutWizardView.swift`
- `WorkoutPreferences` Model
- Intelligente Übungsauswahl basierend auf Präferenzen

### Personal Records System

**Automatische Tracking:**
- Höchstes Gewicht pro Übung
- Meiste Wiederholungen
- Geschätztes 1-Rep-Max (Brzycki-Formel)

**ExerciseRecordMigration:**
- Generiert Records aus bestehenden Sessions
- Inkrementelle Updates bei neuen Sessions
- Optimistisches Locking für Concurrency

### Rest-Timer

**Features:**
- Countdown mit Notification
- Hintergrund-fähig (WallClock-basiert)
- Automatischer Refresh bei Foreground
- Custom Sounds (über AudioManager)

**Implementation:**
```swift
struct RestState {
    let workoutId: UUID
    let duration: TimeInterval
    let startedAt: Date
    var remainingSeconds: Int
}
```

### Workout-Sharing

**Format: `.gymtracker` (JSON)**

```json
{
  "workout": {
    "name": "Push Day",
    "exercises": [...]
  },
  "exportDate": "2025-10-06T...",
  "appVersion": "1.0"
}
```

**Features:**
- AirDrop Support
- Import via File Provider
- Exercise Matching (Name-basiert oder UUID)
- Versionierung

---

## Performance-Optimierungen

### 1. Cached DateFormatters
```swift
enum DateFormatters {
    static let germanLong: DateFormatter = { ... }()
    static let germanMedium: DateFormatter = { ... }()
    // 50ms → 0.001ms pro Zugriff
}
```

### 2. Entity Caching in Views
```swift
@State private var cachedWorkouts: [Workout] = []

private func updateWorkoutCache(_ entities: [WorkoutEntity]) {
    cachedWorkouts = entities.compactMap { mapWorkoutEntity($0) }
}
```

### 3. LazyVStack/LazyVGrid
- On-demand Rendering
- Explizite IDs für Recycling
- Vermeidung von unnötigen Re-Renders

### 4. Background Migrations
```swift
.task(priority: .userInitiated) {
    await performMigrations()
    withAnimation { isMigrationComplete = true }
}
```

### 5. @Query Optimierung
```swift
@Query(sort: [SortDescriptor(\WorkoutEntity.date, order: .reverse)])
private var workouts: [WorkoutEntity]
```

---

## Installation & Setup

### Voraussetzungen
- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- iOS 17.0+ Simulator/Device

### Build & Run

```bash
# Repository klonen
git clone <repository-url>
cd gym-app

# Xcode öffnen
open GymBo.xcodeproj

# Build (Cmd+B)
# Run (Cmd+R)
```

### Erste Schritte

1. **Onboarding durchlaufen:**
   - Profil einrichten
   - Beispielworkouts erkunden
   - Erstes eigenes Workout erstellen

2. **HealthKit Berechtigung:**
   - Settings → Health → Authorize

3. **Notifications aktivieren:**
   - Settings → Notifications → Allow

---

## Bekannte Limitierungen

### Technical Debt
- WorkoutStore sollte in kleinere Services aufgeteilt werden
- UserProfile-Persistierung via UserDefaults statt SwiftData
- Fehlende Unit Tests für kritische Business Logic
- SpeechRecognizer incomplete

### Geplante Features
- [ ] Apple Watch Companion App (vielleicht)
- [ ] iCloud Sync
- [ ] Social Features (Freunde, Challenges)
- [ ] Erweiterte Analytics (Charts, Trends)

---

## Mitwirken

### Code Style
- SwiftLint Configuration
- Prefer Value Types over Reference Types
- Explicit `self` in Closures
- Comments in German for UI-facing strings

### Pull Request Guidelines
1. Feature Branch erstellen
2. Änderungen commiten
3. Tests hinzufügen (wenn vorhanden)
4. PR gegen `master` öffnen

---

## Lizenz

Proprietär - Alle Rechte vorbehalten

---

## Kontakt

Bei Fragen oder Feedback bitte ein Issue erstellen.

---

**Version:** 1.0
**Letzte Aktualisierung:** 2025-10-06
**Autor:** Ben Kohler
