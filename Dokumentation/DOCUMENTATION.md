# GymBo - iOS Fitness Tracking App

## Übersicht

**GymBo (GymTracker)** ist eine hochmoderne native iOS-App für intelligentes Workout-Tracking mit Fokus auf Benutzerfreundlichkeit, Performance und Offline-Fähigkeit. Die App bietet umfassende Funktionen zur Trainingsplanung, -durchführung und -analyse mit AI-gestützten Features, HealthKit-Integration und Live Activities.

## Inhaltsverzeichnis

- [Features](#features)
- [Technologie-Stack](#technologie-stack)
- [Architektur](#architektur)
- [Views-Übersicht](#views-übersicht)
- [Datenmodell](#datenmodell)
- [Services & Manager](#services--manager)
- [Projektstruktur](#projektstruktur)
- [Features im Detail](#features-im-detail)
- [Performance-Optimierungen](#performance-optimierungen)
- [Installation & Setup](#installation--setup)

---

## Features

### 🏋️ Workout-Management
- **Workout-Vorlagen**: Erstellen, bearbeiten und verwalten von Trainingsvorlagen
- **Live-Sessions**: Aktive Workout-Sessions mit Echtzeit-Tracking und horizontaler Swipe-Navigation
- **161 vordefinierte Übungen** aus CSV-Datenbank mit 24 Muskelgruppen, 5 Equipment-Typen
- **Workout-Wizard**: KI-gestützter Assistent zur personalisierten Workout-Erstellung
- **Home-Favoriten**: Quick Access für bis zu 4 Lieblings-Workouts auf dem Home-Screen
- **Workout-Sharing**: Export/Import von Workouts als `.gymtracker` Dateien (JSON)
- **Sample Workouts**: Vordefinierte Trainings nach Kategorien (Maschinen, Freie Gewichte, Mixed)

### 📊 Tracking & Statistiken
- **Satz-für-Satz Tracking**: Detaillierte Erfassung von Gewicht, Wiederholungen und Completion-Status
- **Rest-Timer**: Automatischer Timer mit Push-Benachrichtigungen und Wall-Clock-Sync
- **Personal Records**: Automatische Erkennung von Max Weight, Max Reps und 1RM (Brzycki-Formel)
- **Volume Charts**: Visualisierung des Trainingsvolumens mit nativen Charts
- **Wochenstatistiken**: Workouts, Gesamtvolumen, Trainingszeit und Streak-Tracking
- **Session-Historie**: Vollständige History aller Trainings mit SessionDetailView
- **Progress Tracking**: Gewicht/Reps-Entwicklung pro Übung
- **Muscle Group Distribution**: Übersicht über trainierte Muskelgruppen

### 🧠 Smart Features (AI Coach)
- **Personalisierte Trainingstipps**: 15 Analyseregeln für intelligente Empfehlungen
- **6 Tip-Kategorien**: Progression, Balance, Recovery, Consistency, Goal Alignment, Achievements
- **WorkoutAnalyzer**: Erkennt Plateaus, Ungleichgewichte und Übertraining-Risiken
- **TipEngine**: Priorisierte Tips (High/Medium/Low) mit Feedback-System
- **Smart Insights**: Hero Streak Card, Quick Stats Grid, AI-Coach-Integration
- **Previous Values**: Letzte verwendete Gewichte und Wiederholungen werden vorgeschlagen
- **Exercise Similarity**: Algorithmus für ähnliche Übungs-Vorschläge (Exercise Swap)

### 🎯 HealthKit-Integration
- **Bidirektionale Synchronisation**: Lesen und Schreiben von Gesundheitsdaten
- **Live Heart Rate**: Echtzeit-Herzfrequenz-Tracking während Workouts
- **Profildaten-Import**: Gewicht, Größe, Geburtsdatum, Geschlecht
- **Workout-Export**: Sessions werden als HKWorkout-Samples zu HealthKit exportiert
- **Calorie Burn**: Aktive Energie-Berechnung
- **Health Card**: Anzeige von HealthKit-Daten in der Insights-View

### 📱 Live Activities & Widgets
- **Live Activities** (iOS 16.1+): Dynamic Island Integration für aktive Workouts
- **Rest Timer Countdown**: Live-Update im Dynamic Island
- **Deep Links**: `workout://active` für direkten App-Zugriff
- **Lock Screen Widget**: Workout-Status auf dem Sperrbildschirm
- **Throttling**: Max. 2 Updates/Sekunde für Performance

### 👤 Personalisierung
- **Benutzerprofil**: Name, Geburtsdatum, Größe, Gewicht, Profilbild (Kamera/Galerie)
- **Lockercard**: Digitale Spintnummer mit Badge-Anzeige
- **Workout-Präferenzen**: Ziel (Muskelaufbau, Kraft, Ausdauer, etc.), Erfahrungslevel, Equipment
- **Wochenziel**: Individuelles Trainingsziel pro Woche
- **Onboarding-System**: Interaktive Checkliste für neue Nutzer mit Progress-Tracking
- **Themes**: Modernes Farbschema (Power Orange, Deep Blue, Moss Green, etc.) mit Glassmorphism

### 🔔 Notifications & Audio
- **Rest Timer Notifications**: Push-Benachrichtigungen bei Timer-Ende
- **Configurable Sounds**: Konfigurierbare Audio-Feedback-Töne
- **Voice Input**: Spracheingabe für Gewichte/Reps (in Entwicklung)
- **Audio Manager**: Custom Sound Effects für Set-Completion

---

## Technologie-Stack

### Frameworks & SDKs
- **SwiftUI**: Deklaratives UI-Framework mit modernem Design
- **SwiftData**: Persistenz-Layer (iOS 17+) mit Schema-basiertem Modell
- **HealthKit**: Gesundheitsdaten-Integration (Workout-Recording, Heart Rate)
- **ActivityKit**: Live Activities & Dynamic Island
- **Combine**: Reactive Programming für State-Management
- **UserNotifications**: Push-Benachrichtigungen
- **AVFoundation**: Audio-Feedback
- **Charts**: Native Datenvisualisierung

### Sprache & Tools
- **Swift 5.9+**
- **iOS 17.0+ Target**
- **Xcode 15+**
- **SwiftLint**: Code Style Enforcement

---

## Architektur

### MVVM + SwiftUI Hybrid mit Repository-Pattern

```
┌─────────────────────────────────────────────────┐
│                    Views                         │
│   (SwiftUI Views mit @State, @Query, @Binding)  │
│   - WorkoutsHomeView, StatisticsView, etc.      │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│                 ViewModel                        │
│          (WorkoutStore als @StateObject)         │
│  - Session-Management, Rest Timer, Profile      │
│  - Exercise Stats Caching, Home Favorites       │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│              Services Layer                      │
│  - WorkoutAnalyzer, TipEngine                   │
│  - HealthKitManager, NotificationManager        │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│             Data Layer                           │
│  SwiftData Entities + Domain Models (Structs)   │
│  - ExerciseEntity, WorkoutEntity, etc.          │
│  - Mapping Layer für Trennung von Concerns      │
└─────────────────────────────────────────────────┘
```

### Komponenten-Übersicht

#### 1. **Views** (SwiftUI)
- Präsentationsschicht mit deklarativem UI und Glassmorphism-Design
- Verwendet `@Query` für reaktive SwiftData-Bindung
- `@EnvironmentObject` für WorkoutStore-Zugriff
- LazyVStack/LazyVGrid für Performance-Optimierung

#### 2. **ViewModel** (WorkoutStore)
- Zentrale State-Verwaltung für die gesamte App
- Session-Lifecycle-Management (Start/End/Active)
- Rest-Timer mit Wall-Clock-Sync für Hintergrund-Fähigkeit
- Profile-Persistierung via UserDefaults
- Exercise Stats Caching für schnellen Zugriff
- Home Favorites Management (max. 4 Limit)

#### 3. **Models**
- **Domain Models**: Value Types (Structs) für Business Logic
  - `Exercise` (mit Similarity-Algorithmus), `Workout`, `WorkoutExercise`, `ExerciseSet`
  - `WorkoutSession`, `TrainingTip`, `WorkoutPreferences`, `SessionStatistics`
- **SwiftData Entities**: Persistente Datenmodelle (@Model)
  - `ExerciseEntity`, `WorkoutEntity`, `WorkoutSessionEntity`
  - `ExerciseRecordEntity`, `UserProfileEntity`
- **Mapping-Layer**: Bidirektionale, sichere Konvertierung zwischen Layers
  - Context-basiert mit Refetch-Strategy
  - Defensive Programming mit Fallbacks

#### 4. **Services**
- `WorkoutAnalyzer`: Fortschrittsanalyse, Plateau-Erkennung, Muscle Balance
- `TipEngine`: AI-Coach mit 15 Regeln und Priorisierung
- `TipFeedbackManager`: User-Feedback für Tipp-Optimierung
- `HealthKitManager`: HealthKit-Integration mit Error Handling
- `HealthKitWorkoutTracker`: Live Heart Rate und Workout Recording
- `NotificationManager`: Push-Benachrichtigungen mit Sound
- `AudioManager`: Sound Effects und Voice Feedback
- `BackupManager`: Export/Import von Workouts
- `WorkoutLiveActivityController`: Live Activities Steuerung

---

## Views-Übersicht

### Tab-Navigation (ContentView.swift)

#### **Tab 1: Home (WorkoutsHomeView.swift)**
Moderner Dashboard mit personalisierten Informationen:
- **Zeitbasierte Begrüßung**: "Guten Morgen/Tag/Abend" basierend auf Tageszeit
- **Wochenstatistiken-Card**: Workouts diese Woche, Gesamtminuten
- **Onboarding-Card**: Interaktive Checkliste (Profil setup, Workouts erkundet, erstes Workout erstellt)
- **Workout-Highlight-Card**: Zeigt letztes absolviertes Training mit Infos
- **Favoriten-Grid**: Bis zu 4 Home-Favoriten mit Quick Access
- **Locker-Number Badge**: Spintnummer-Anzeige als Badge
- **Active Workout Bar**: Schwebendes Overlay mit Timer und Quick Actions

#### **Tab 2: Workouts (WorkoutsTabView.swift)**
Workout-Management und -Ausführung:
- **Workout-Liste**: Alle gespeicherten Trainingsvorlagen mit Sortierung
- **Sample-Workouts**: Vordefinierte Trainings nach Kategorien
- **Workout-Wizard**: KI-gestützter Generator mit Step-by-Step-Wizard
- **Exercise Picker**: Suchfunktion, Filter (Muskelgruppe, Equipment, Schwierigkeit)
- **Last-Used Anzeige**: "Zuletzt vor X Tagen"
- **Favoriten-Toggle**: Mit Limit-Enforcement (max. 4 Home-Favoriten)

#### **Tab 3: Insights (StatisticsView.swift)**
Moderne Glassmorphism-Oberfläche mit umfassenden Statistiken:
- **Hero Streak Card**: Konsistenz-Tracking mit Wochen-Streak und Kalendar-Integration
- **Smart Tips Card**: AI-Coach mit personalisierten Tipps, Refresh-Funktion und Feedback-System
- **Quick Stats Grid**: 2x2 Metriken (Workouts, Volumen, Zeit, Streak) mit Icons
- **Volume Chart Card**: Expandierbares Balkendiagramm mit Wochenansicht
- **Personal Records Card**: Top 3 Bestleistungen (Max Weight, Max Reps, 1RM)
- **Health Card**: HealthKit-Daten (wenn autorisiert) mit Live-Sync

### Detail-Views

#### **WorkoutDetailView.swift**
Zwei Modi mit intelligenter Navigation:
1. **Active Session Mode**:
   - Horizontale Swipe-Navigation zwischen Übungen
   - Set-by-Set Tracking (Gewicht, Reps, Completed-Checkbox)
   - Rest Timer mit automatischem Start nach Set
   - Previous Values (letzte Gewichte/Reps als Vorschlag)
   - Voice Input für Hands-free Bedienung
   - Live Heart Rate Display
   - Quick Actions: Set hinzufügen/löschen, Gewicht anpassen

2. **Template View Mode**:
   - Tab-Navigation (Überblick, Fortschritt, Veränderung)
   - Exercise-Liste mit Reorder-Funktion
   - Notes-Sektion für Trainingsnotizen
   - Edit-Modus für Template-Anpassung

#### **SessionDetailView.swift**
Detaillierte Trainingsanalyse:
- **Hero Section**: Datum, Dauer, Completion Rate (circular progress)
- **Summary Grid**: Volumen, Sets, Reps, Rest Time
- **Volume Chart**: Balkendiagramm pro Übung
- **Exercise Statistics**: Progression pro Übung mit Previous-Session-Vergleich
- **Heart Rate Data**: Min/Max/Avg aus HealthKit (wenn verfügbar)
- **Restart Option**: Session als neues Workout starten
- **Share**: Export als .gymtracker-Datei

#### **ExercisesView.swift & ExercisePickerView.swift**
Umfassender Übungskatalog:
- **Suchfunktion**: Echtzeit-Suche nach Name
- **Filter**: Muskelgruppe (24), Equipment-Typ (5), Schwierigkeit (3)
- **Sortierung**: Alphabetisch, Zuletzt verwendet, Schwierigkeit
- **Exercise Detail Sheet**: Beschreibung, Anleitung (Steps), Muskelgruppen
- **Exercise Swap**: Ähnliche Übungen basierend auf Similarity-Score
- **Last-Used Info**: Zeigt letzte Gewichte/Reps/Date

#### **ProfileView.swift & ProfileEditView.swift**
Benutzerprofil-Management:
- **Profilbild**: Upload via Kamera/Galerie mit Crop-Funktion
- **HealthKit-Sync**: Gewicht, Größe, Geburtsdatum importieren
- **Workout-Präferenzen**: Ziel (FitnessGoal), Erfahrung (ExperienceLevel), Equipment
- **Lockercard**: Digitale Spintnummer mit Eingabefeld
- **Statistics**: Lifetime-Workouts, Gesamtvolumen
- **Settings**: Navigation zu Einstellungen

#### **SettingsView.swift**
App-Einstellungen:
- **Notifications**: Rest-Timer Push-Benachrichtigungen aktivieren/deaktivieren
- **Sounds**: Audio-Feedback für Set-Completion und Timer
- **HealthKit**: Autorisierung und Sync-Status
- **Backup**: Workout-Export/Import
- **Theme**: Design-Einstellungen (in Entwicklung)
- **About**: App-Version, Entwickler-Info

#### **WorkoutWizardView.swift**
KI-gestützter Workout-Generator:
- **Step 1: Experience**: Anfänger/Fortgeschritten/Profi
- **Step 2: Goal**: Muskelaufbau, Kraft, Ausdauer, Gewichtsreduktion, Allgemeine Fitness
- **Step 3: Frequency**: Anzahl Trainings pro Woche
- **Step 4: Equipment**: Freie Gewichte, Maschinen, Körpergewicht, Kabel, Gemischt
- **Step 5: Duration**: 30/45/60/90 Minuten
- **Preview**: Generiertes Workout mit Übungsliste
- **Generate**: Intelligente Übungsauswahl basierend auf Präferenzen

---

## Datenmodell

### SwiftData Schema (7 Entities)

#### **ExerciseEntity**
```swift
@Model
class ExerciseEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroupsRaw: [String]          // 24 Muskelgruppen
    var equipmentTypeRaw: String           // 5 Equipment-Typen
    var difficultyLevelRaw: String         // Anfänger/Fortgeschritten/Profi
    var descriptionText: String
    var instructions: [String]             // Step-by-Step Anleitung
    var lastUsedWeight: Double?            // Letzte verwendete Gewichte
    var lastUsedReps: Int?                 // Letzte Wiederholungen
    var lastUsedSetCount: Int?             // Letzte Satz-Anzahl
    var lastUsedDate: Date?                // Letzte Verwendung
    var lastUsedRestTime: TimeInterval?    // Letzte Pausenzeit
}
```

#### **WorkoutEntity** (Template/Vorlage)
```swift
@Model
class WorkoutEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    @Relationship(deleteRule: .cascade) var exercises: [WorkoutExerciseEntity]
    var defaultRestTime: TimeInterval      // Standard-Pausenzeit
    var duration: TimeInterval?            // Geschätzte Dauer
    var notes: String                      // Trainingsnotizen
    var isFavorite: Bool                   // Home-Favorit
    var isSampleWorkout: Bool?             // Beispiel-Workout
}
```

#### **WorkoutSessionEntity** (History/Verlauf)
```swift
@Model
class WorkoutSessionEntity {
    @Attribute(.unique) var id: UUID
    var templateId: UUID?                  // Verknüpfung zu Template
    var name: String
    var date: Date
    @Relationship(deleteRule: .cascade) var exercises: [WorkoutExerciseEntity]
    var duration: TimeInterval?            // Tatsächliche Dauer
    var minHeartRate: Int?                 // Min. Herzfrequenz
    var maxHeartRate: Int?                 // Max. Herzfrequenz
    var avgHeartRate: Int?                 // Durchschnitt. Herzfrequenz
}
```

#### **WorkoutExerciseEntity**
```swift
@Model
class WorkoutExerciseEntity {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID                   // Verknüpfung zu Exercise
    var order: Int                         // Reihenfolge im Workout
    @Relationship(deleteRule: .cascade) var sets: [ExerciseSetEntity]
    var restTimeOverride: TimeInterval?    // Individuelle Pausenzeit
}
```

#### **ExerciseSetEntity**
```swift
@Model
class ExerciseSetEntity {
    @Attribute(.unique) var id: UUID
    var reps: Int
    var weight: Double
    var restTime: TimeInterval
    var completed: Bool                    // Set abgeschlossen
    var note: String?                      // Notiz pro Satz
}
```

#### **ExerciseRecordEntity** (Personal Records)
```swift
@Model
class ExerciseRecordEntity {
    var exerciseId: UUID                   // Primärschlüssel
    var maxWeight: Double                  // Höchstes Gewicht
    var maxWeightReps: Int                 // Reps bei Max Weight
    var maxReps: Int                       // Meiste Wiederholungen
    var bestEstimatedOneRepMax: Double     // 1RM (Brzycki-Formel)
}
```

#### **UserProfileEntity**
```swift
@Model
class UserProfileEntity {
    var name: String
    var birthDate: Date?
    var weight: Double?                    // kg
    var height: Double?                    // cm
    var biologicalSexRaw: Int16            // HKBiologicalSex
    var healthKitSyncEnabled: Bool
    var goalRaw: String                    // FitnessGoal
    var experienceRaw: String              // ExperienceLevel
    var profileImageData: Data?            // Profilbild
    var lockerNumber: String?              // Spintnummer
    var hasExploredWorkouts: Bool          // Onboarding-Status
    var hasCreatedFirstWorkout: Bool       // Onboarding-Status
    var hasSetupProfile: Bool              // Onboarding-Status
}
```

### Domain Models (Structs)

#### **Exercise.swift**
```swift
struct Exercise {
    let id: UUID
    let name: String
    let muscleGroups: [MuscleGroup]        // 24 verschiedene Muskelgruppen
    let equipmentType: EquipmentType       // 5 Typen
    let difficultyLevel: DifficultyLevel   // 3 Level
    let description: String
    let instructions: [String]

    // Similarity-Algorithmus (60% Muskelgruppen, 25% Equipment, 15% Schwierigkeit)
    func similarity(to other: Exercise) -> Double
}

enum MuscleGroup: String, CaseIterable {
    case chest, back, shoulders, biceps, triceps, legs, glutes, abs, cardio,
         forearms, calves, trapezius, lowerBack, upperBack, fullBody, hips,
         core, hamstrings, lats, grip, arms, adductors, obliques, hipFlexors,
         coordination  // 24 Muskelgruppen
}

enum EquipmentType: String, CaseIterable {
    case freeWeights, machine, bodyweight, cable, mixed
}

enum DifficultyLevel: String, CaseIterable {
    case anfänger, fortgeschritten, profi
}
```

#### **Workout.swift**
```swift
struct Workout {
    let id: UUID
    let name: String
    let exercises: [WorkoutExercise]
    let defaultRestTime: TimeInterval
    let duration: TimeInterval?
    let isFavorite: Bool
    let level: String?                     // Schwierigkeitslevel
    let workoutType: String?               // Typ (Push, Pull, etc.)
}

struct WorkoutExercise {
    let id: UUID
    let exercise: Exercise
    let sets: [ExerciseSet]
    let restTimeOverride: TimeInterval?
    let order: Int
}

struct ExerciseSet {
    let id: UUID
    let reps: Int
    let weight: Double
    let restTime: TimeInterval
    let completed: Bool
}
```

#### **WorkoutPreferences.swift**
```swift
struct WorkoutPreferences {
    var experience: ExperienceLevel        // Anfänger/Fortgeschritten/Profi
    var goal: FitnessGoal                  // 5 Ziele
    var equipment: EquipmentPreference
    var duration: WorkoutDuration          // 30/45/60/90 min
    var frequency: Int                     // Trainings pro Woche
}

enum FitnessGoal: String, CaseIterable {
    case muskelaufbau, kraft, ausdauer, gewichtsreduktion, allgemeineFitness
}
```

---

## Services & Manager

### **WorkoutStore.swift** (ViewModel)
Zentrale State-Verwaltung für die gesamte App:

**Properties:**
```swift
@Published var activeSessionID: UUID?
@Published var activeRestState: RestState?
@Published var userProfile: UserProfile
@Published var weeklyGoal: Int
var modelContext: ModelContext?
private var exerciseStatsCache: [UUID: ExerciseStats]
```

**Methoden:**
```swift
func startSession(for workoutID: UUID)
func endSession(for workoutID: UUID) -> WorkoutSession
func startRest(for workoutID: UUID, duration: TimeInterval)
func stopRest()
func toggleHomeFavorite(workoutID: UUID) -> Bool
func updateUserProfile(...)
func getExerciseStats(exerciseId: UUID) -> ExerciseStats?
```

### **WorkoutAnalyzer.swift**
Intelligente Trainingsanalyse:

**Funktionen:**
- **Progression Opportunities**: Plateau-Erkennung (3+ Trainings ohne Verbesserung)
- **Muscle Group Balance**: Volumen-Verteilung über Muskelgruppen
- **Recovery Status**: Übertraining-Risiko basierend auf Frequenz
- **Consistency Metrics**: Streak-Berechnung, Trainingsfrequenz
- **Goal Alignment**: Rep-Range-Matching (Kraft: 1-5, Hypertrophie: 6-12, Ausdauer: 15+)
- **Achievements**: PR-Erkennung, Milestones

**Output:**
```swift
struct WorkoutAnalysis {
    let progressionOpportunities: [Exercise]
    let muscleGroupBalance: [MuscleGroup: Double]
    let recoveryStatus: RecoveryStatus
    let consistencyScore: Double
    let goalAlignment: Double
    let achievements: [Achievement]
}
```

### **TipEngine.swift**
AI-Coach mit personalisierten Tipps:

**15 Regeln:**
1. Progressive Overload
2. Muscle Group Balance
3. Recovery Time
4. Consistency Streak
5. Goal-Specific Rep Ranges
6. Exercise Variety
7. Volume Tracking
8. Rest Time Optimization
9. Heart Rate Zones
10. Personal Record Recognition
11. Workout Duration
12. Set Completion Rate
13. Exercise Form Reminder
14. Plateau Breaking
15. Milestone Celebration

**Tip-Kategorien:**
```swift
enum TipCategory: String {
    case progression, balance, recovery, consistency, goalAlignment, achievements
}

struct TrainingTip {
    let id: UUID
    let category: TipCategory
    let priority: TipPriority      // High/Medium/Low
    let title: String
    let message: String
    let actionable: Bool
}
```

### **TipFeedbackManager.swift**
User-Feedback-System für Tip-Optimierung:
```swift
func recordFeedback(tipId: UUID, helpful: Bool)
func getTipScore(ruleId: String) -> Double
func shouldShowTip(ruleId: String) -> Bool
```

### **HealthKitManager.swift**
HealthKit-Integration mit Error Handling:

**Funktionen:**
```swift
func requestAuthorization() async throws
func fetchUserProfile() async -> UserProfile?
func syncWeight() async -> Double?
func saveWorkoutToHealthKit(session: WorkoutSession) async throws
func startHeartRateMonitoring(completion: @escaping (Double) -> Void)
func stopHeartRateMonitoring()
```

**Timeout-Mechanismus:**
- 30 Sekunden Timeout für alle HealthKit-Abfragen
- Graceful Degradation bei Fehlern

### **HealthKitWorkoutTracker.swift**
Live Workout Recording:
```swift
func startWorkout(type: HKWorkoutActivityType)
func endWorkout() async -> HKWorkout?
func pauseWorkout()
func resumeWorkout()
```

### **WorkoutLiveActivityController.swift**
Live Activities Steuerung:
```swift
func start(workoutName: String, restDuration: TimeInterval?)
func updateRestTimer(remaining: TimeInterval)
func updateHeartRate(_ heartRate: Int)
func updateProgress(setsCompleted: Int, setsTotal: Int)
func end()
```

**Throttling:** Max. 2 Updates/Sekunde für Performance

### **NotificationManager.swift**
Push-Benachrichtigungen:
```swift
func requestAuthorization() async -> Bool
func scheduleRestTimerEnd(after duration: TimeInterval)
func cancelAllNotifications()
```

### **AudioManager.swift**
Audio-Feedback:
```swift
func playSetCompletionSound()
func playTimerEndSound()
func setVolume(_ volume: Float)
```

### **BackupManager.swift**
Export/Import:
```swift
func exportWorkout(_ workout: Workout) -> URL?
func importWorkout(from url: URL) async throws -> Workout
```

**Format:** `.gymtracker` (JSON)

---

## Projektstruktur

```
GymTracker/
├── GymTrackerApp.swift                    # App Entry Point + Migrations
├── ContentView.swift                      # Root View (TabView mit 3 Tabs)
│
├── Models/                                # Domain Models (Value Types)
│   ├── Exercise.swift                     # Exercise struct + Similarity-Algorithmus
│   ├── Workout.swift                      # Workout, WorkoutExercise, ExerciseSet
│   ├── WorkoutSession.swift               # Session-Historie
│   ├── SessionStatistics.swift            # Statistik-Berechnungen
│   ├── ShareableWorkout.swift             # Export/Import Format
│   ├── TrainingTip.swift                  # Smart Tips
│   └── WorkoutPreferences.swift           # Wizard-Präferenzen
│
├── SwiftDataEntities.swift                # @Model Entities (Persistenz, 7 Entities)
├── Workout+SwiftDataMapping.swift         # Entity ↔ Domain Model Mapping (Safe Mapping)
│
├── ViewModels/
│   ├── WorkoutStore.swift                 # Zentrale State-Verwaltung (Observer Pattern)
│   ├── Theme.swift                        # App-Theme Definition (Glassmorphism)
│   ├── StartView.swift                    # Splash Screen
│   └── ProfilePersistenceHelper.swift     # Profile-Persistierung
│
├── Views/                                 # SwiftUI Views (23+ Views)
│   ├── WorkoutsHomeView.swift             # Home-Tab (Dashboard)
│   ├── WorkoutsTabView.swift              # Workouts-Tab (Liste)
│   ├── WorkoutDetailView.swift            # Workout-Ausführung (Active Session + Template)
│   ├── SessionDetailView.swift            # Session-Historie Detail
│   ├── EditWorkoutView.swift              # Workout-Editor
│   ├── ExercisesView.swift                # Übungskatalog
│   ├── ExercisePickerView.swift           # Übungsauswahl
│   ├── StatisticsView.swift               # Insights-Tab (Glassmorphism)
│   ├── ProfileView.swift                  # Benutzerprofil
│   ├── ProfileEditView.swift              # Profil-Editor
│   ├── SettingsView.swift                 # Einstellungen
│   ├── WorkoutWizardView.swift            # KI-Workout-Generator
│   ├── WorkoutCalendarView.swift          # Kalenderansicht
│   ├── EditWorkout/
│   │   ├── EditWorkoutHeader.swift        # Header-Component
│   │   └── EditWorkoutComponents.swift    # Weitere Components
│   └── Components/
│       └── SmartTipsCard.swift            # AI-Coach Card
│
├── Services/                              # Business Logic Layer
│   ├── WorkoutAnalyzer.swift              # Trainingsanalyse (15 Metriken)
│   ├── TipEngine.swift                    # AI-Coach (15 Regeln, 6 Kategorien)
│   └── TipFeedbackManager.swift           # Feedback-System
│
├── LiveActivities/
│   ├── WorkoutActivityAttributes.swift    # ActivityKit Attributes
│   └── WorkoutLiveActivityController.swift # Live Activities Controller
│
├── Database/
│   └── ModelContainerFactory.swift        # Container-Erstellung mit Fallback-Chain
│
├── Migrations/
│   ├── ExerciseDatabaseMigration.swift    # CSV → Database Import
│   ├── ExerciseRecordMigration.swift      # Personal Records Generation
│   └── ExerciseLastUsedMigration.swift    # Last-Used Values Population
│
├── Seeders/
│   ├── ExerciseSeeder.swift               # CSV → Database (161 Übungen)
│   └── WorkoutSeeder.swift                # Sample Workouts (versioniert)
│
├── Managers/                              # Infrastructure Layer
│   ├── HealthKitManager.swift             # HealthKit-Integration
│   ├── HealthKitWorkoutTracker.swift      # Live Workout Recording
│   ├── NotificationManager.swift          # Push-Benachrichtigungen
│   ├── AudioManager.swift                 # Sound Effects
│   ├── BackupManager.swift                # Export/Import
│   ├── SpeechRecognizer.swift             # Voice Input (in Entwicklung)
│   └── AppLogger.swift                    # Logging
│
└── Resources/
    ├── exercises.csv                      # 161 Übungen
    └── Sounds/
        └── *.m4a                          # Audio-Dateien
```

---

## Features im Detail

### 🎯 Workout-Wizard (KI-gestützter Generator)

**Ablauf (5 Steps):**
1. **Experience**: Anfänger/Fortgeschritten/Profi
2. **Goal**: Muskelaufbau, Kraft, Ausdauer, Gewichtsreduktion, Allgemeine Fitness
3. **Frequency**: Anzahl Trainings pro Woche
4. **Equipment**: Freie Gewichte, Maschinen, Körpergewicht, Kabel, Gemischt
5. **Duration**: 30/45/60/90 Minuten

**Intelligente Übungsauswahl:**
- Passt zu Erfahrungslevel (Difficulty Matching)
- Equipment-Filter
- Muskelgruppen-Balance
- Zeitbasierte Satz-Konfiguration
- Rep-Range-Matching für Ziel (Kraft: 1-5, Hypertrophie: 6-12, Ausdauer: 15+)

**Preview vor Speichern:**
- Vollständige Übungsliste
- Geschätzte Dauer
- Muskelgruppen-Verteilung

### 💪 Personal Records System

**Automatisches Tracking:**
- **Max Weight**: Höchstes Gewicht pro Übung
- **Max Reps**: Meiste Wiederholungen
- **Estimated 1RM**: Brzycki-Formel: `Weight × (36 / (37 - Reps))`

**ExerciseRecordMigration:**
- Generiert Records aus bestehenden Sessions beim ersten App-Start
- Inkrementelle Updates bei neuen Sessions
- Optimistisches Locking für Concurrency
- Batch-Processing für Performance

**Anzeige:**
- Top 3 PRs auf Statistics-View
- Exercise-Detail-Sheet mit History

### ⏱️ Rest-Timer (Advanced)

**Features:**
- **Wall-Clock-Sync**: Funktioniert auch im Hintergrund/App-Kill
- **Push-Notifications**: Benachrichtigung bei Timer-Ende
- **Live Activity**: Dynamic Island mit Countdown
- **Auto-Start**: Optional nach Set-Completion
- **Custom Duration**: Per Exercise oder Workout-Default

**Implementation:**
```swift
struct RestState: Equatable {
    let workoutId: UUID
    let duration: TimeInterval
    let startedAt: Date                     // Wall-Clock-Time für Hintergrund
    var remainingSeconds: Int
}
```

**Sync-Mechanismus:**
- `onAppear`: Refresh remaining time basierend auf Wall-Clock
- Timer-Publisher mit 1-Sekunden-Intervall
- Notification bei 0 Sekunden

### 🔄 Active Workout Navigation

**Horizontal Swipe:**
- Wische zwischen Übungen (TabView mit `.tabViewStyle(.page)`)
- Aktueller Index mit Dots-Indicator
- Exercise-Name im Header

**Quick Actions:**
- ➕ Set hinzufügen (mit Default-Werten)
- 🗑️ Set löschen (mit Confirmation)
- ⬆️⬇️ Gewicht anpassen (Stepper)
- ✓ Set als completed markieren

**Rest Timer Integration:**
- Automatischer Start nach Set (wenn aktiviert)
- Countdown-Anzeige über Workout-View
- Skip-Button

### 📊 Charts & Visualisierung

**Volume Chart (native Charts):**
```swift
Chart {
    ForEach(exercises) { exercise in
        BarMark(
            x: .value("Exercise", exercise.name),
            y: .value("Volume", exercise.totalVolume)
        )
        .foregroundStyle(AppTheme.primaryGradient)
    }
}
```

**Features:**
- Expandierbar (collapsed: 3 Bars, expanded: alle)
- Responsive Design
- Animierte Transitions
- Custom Colors (Gradient)

**Progress Charts:**
- Gewicht über Zeit (Line Chart)
- Reps über Zeit (Line Chart)
- Muscle Group Distribution (Pie Chart, geplant)

### 🧠 Smart Tips (AI Coach)

**15 Analyseregeln:**
1. **Progressive Overload**: Plateau-Erkennung (3+ Sessions ohne Verbesserung)
2. **Muscle Group Balance**: Volumen-Verteilung <25% pro Gruppe
3. **Recovery Time**: <48h zwischen gleichen Muskelgruppen
4. **Consistency Streak**: 3+ Wochen ohne Training
5. **Goal-Specific Rep Ranges**: Rep-Range-Matching
6. **Exercise Variety**: <3 verschiedene Übungen pro Gruppe
7. **Volume Tracking**: Totales Volumen zu niedrig (<1000kg)
8. **Rest Time Optimization**: Rest Time zu kurz/lang
9. **Heart Rate Zones**: Zone-basierte Empfehlungen
10. **Personal Record Recognition**: Neue PRs feiern
11. **Workout Duration**: Zu kurz (<20min) oder zu lang (>120min)
12. **Set Completion Rate**: <80% Completion
13. **Exercise Form Reminder**: Schwierigkeit passt nicht zu Erfahrung
14. **Plateau Breaking**: Deload-Empfehlung
15. **Milestone Celebration**: 10/25/50/100 Workouts

**Priorisierung:**
- **High**: Kritische Issues (Recovery, Plateau)
- **Medium**: Optimierungen (Balance, Volume)
- **Low**: Nice-to-have (Variety, Milestones)

**Feedback-Loop:**
- User kann Tipps als "hilfreich" bewerten
- Score-basierte Priorisierung
- Low-Score-Tips werden seltener angezeigt

### 🏡 Home-Favoriten

**Features:**
- Bis zu **4 Workouts** auf Home-Screen
- Quick Access mit Tap-to-Start
- Favoriten-Toggle mit Star-Icon
- Limit-Enforcement mit Alert

**Implementation:**
```swift
func toggleHomeFavorite(workoutID: UUID) -> Bool {
    let currentFavorites = workouts.filter { $0.isFavorite }
    if currentFavorites.count >= 4 && !workout.isFavorite {
        return false  // Alert anzeigen
    }
    workout.isFavorite.toggle()
    return true
}
```

### 📤 Workout-Sharing

**Export-Format (.gymtracker):**
```json
{
  "workout": {
    "id": "UUID",
    "name": "Push Day",
    "exercises": [
      {
        "exerciseId": "UUID",
        "exerciseName": "Bench Press",
        "sets": [
          { "reps": 10, "weight": 80.0, "restTime": 90 }
        ]
      }
    ],
    "defaultRestTime": 90,
    "notes": "Focus on form"
  },
  "exportDate": "2025-10-07T10:00:00Z",
  "appVersion": "1.0"
}
```

**Import-Mechanismus:**
- Exercise-Matching: Zuerst UUID, dann Name
- Fehlende Exercises werden übersprungen
- Version-Check für Kompatibilität
- Duplicate-Handling (neuer Name: "Push Day (imported)")

**Sharing:**
- Share Sheet mit AirDrop/Messages/Mail
- Deep Links: `gymbo://import?url=...`

### 🌐 HealthKit-Integration

**Bidirektionale Synchronisation:**

**Read (Import):**
- Geburtsdatum → Profilalter
- Gewicht → Profil
- Größe → Profil
- Biologisches Geschlecht → Profil

**Write (Export):**
```swift
let workout = HKWorkout(
    activityType: .traditionalStrengthTraining,
    start: session.date,
    end: session.date + session.duration,
    duration: session.duration,
    totalEnergyBurned: calories,
    totalDistance: nil,
    metadata: [
        "Workout Name": session.name,
        "Sets Completed": session.totalSets,
        "Total Volume": session.totalVolume
    ]
)
```

**Heart Rate Monitoring:**
- **Live Tracking**: HKAnchoredObjectQuery mit Streaming
- **Stop-Mechanismus**: Observer wird bei `endWorkout()` entfernt
- **Timeout**: 30 Sekunden für alle Queries
- **Error Handling**: Graceful Degradation bei fehlenden Permissions

---

## Performance-Optimierungen

### 1. Cached DateFormatters
```swift
enum DateFormatters {
    static let germanLong: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .long
        return formatter
    }()
    // Speedup: 50ms → 0.001ms pro Zugriff
}
```

### 2. Entity Caching in Views
```swift
@State private var cachedWorkouts: [Workout] = []

private func updateWorkoutCache(_ entities: [WorkoutEntity]) {
    // Nur bei Änderungen neu mappen
    cachedWorkouts = entities.compactMap { mapWorkoutEntity($0, context: modelContext) }
}

.onChange(of: workoutEntities) { _, newEntities in
    updateWorkoutCache(newEntities)
}
```

### 3. Safe Mapping mit Context
```swift
func mapWorkoutEntity(_ entity: WorkoutEntity, context: ModelContext) -> Workout? {
    // Refetch Entity aus Context für Fresh State
    guard let freshEntity = context.model(for: entity.id) as? WorkoutEntity else {
        return nil
    }
    // Map mit Defensive Programming
    return Workout(from: freshEntity)
}
```

### 4. LazyVStack/LazyVGrid
```swift
LazyVStack(spacing: 12) {
    ForEach(workouts, id: \.id) { workout in
        WorkoutCard(workout: workout)
    }
}
// On-Demand Rendering, nur sichtbare Items
```

### 5. Exercise Stats Caching
```swift
class WorkoutStore: ObservableObject {
    private var exerciseStatsCache: [UUID: ExerciseStats] = [:]

    func getExerciseStats(exerciseId: UUID) -> ExerciseStats? {
        if let cached = exerciseStatsCache[exerciseId] {
            return cached
        }
        // Compute and cache
        let stats = computeStats(exerciseId)
        exerciseStatsCache[exerciseId] = stats
        return stats
    }
}
```

### 6. Background Migrations
```swift
.task(priority: .userInitiated) {
    await performMigrations()  // Async, non-blocking
    withAnimation { isMigrationComplete = true }
}
```

### 7. @Query Optimierung
```swift
@Query(
    filter: #Predicate<WorkoutEntity> { $0.isSampleWorkout == false },
    sort: [SortDescriptor(\WorkoutEntity.date, order: .reverse)]
)
private var workouts: [WorkoutEntity]
// Filtered Query statt Array-Filter in View
```

### 8. Equatable RestState
```swift
struct RestState: Equatable {
    // Nur bei tatsächlichen Änderungen UI-Update
}
```

---

## Installation & Setup

### Voraussetzungen
- **macOS 14.0+** (Sonoma oder neuer)
- **Xcode 15.0+**
- **iOS 17.0+** Simulator oder Device
- **Apple Developer Account** (für HealthKit, Live Activities)

### Build & Run

```bash
# Repository klonen
git clone <repository-url>
cd gym-app

# Xcode öffnen
open GymBo.xcodeproj

# Build (Cmd+B)
# Run (Cmd+R) auf Simulator oder Device
```

### Erste Schritte

1. **Onboarding durchlaufen:**
   - Profil einrichten (Name, Geburtsdatum, Gewicht, Größe)
   - Beispielworkouts erkunden (Sample Workouts-Tab)
   - Erstes eigenes Workout erstellen (Workout-Wizard)

2. **HealthKit Berechtigung:**
   - Settings → Health → Authorize
   - Profildaten importieren

3. **Notifications aktivieren:**
   - Settings → Notifications → Allow
   - Rest-Timer Benachrichtigungen

4. **Home-Favoriten setzen:**
   - Workouts-Tab → Star-Icon bei max. 4 Workouts
   - Schnellzugriff auf Home-Tab

### Migrations beim ersten Start
Die App führt automatisch folgende Migrationen durch:
1. **Exercise Database**: 161 Übungen aus CSV
2. **Sample Workouts**: 5+ vordefinierte Trainings
3. **Exercise Records**: Personal Records aus bestehenden Sessions
4. **Last-Used Values**: Letzte Gewichte/Reps/Dates

⏱️ **Dauer**: ~2-5 Sekunden (einmalig)

---

## Bekannte Limitierungen

### Technical Debt
- **WorkoutStore**: Sollte in kleinere Services aufgeteilt werden (SRP-Verletzung)
- **UserProfile**: Persistierung via UserDefaults statt SwiftData (Inkonsistenz)
- **Unit Tests**: Fehlende Tests für kritische Business Logic (WorkoutAnalyzer, TipEngine)
- **SpeechRecognizer**: Unvollständige Implementierung

### Constraints
- **Home-Favoriten**: Max. 4 Workouts (UI-Design-Limitation)
- **Live Activities**: Nur iOS 16.1+ (API-Verfügbarkeit)
- **HealthKit**: Erfordert echtes Device für Testing
- **Workout-Export**: Nur JSON-Format (kein PDF/CSV)

### Geplante Features
- [ ] **Apple Watch App**: Standalone-Training mit Companion-App
- [ ] **iCloud Sync**: Multi-Device-Synchronisation
- [ ] **Workout-Templates Marketplace**: Community-Workouts teilen
- [ ] **Social Features**: Freunde hinzufügen, Challenges
- [ ] **Video-Anleitungen**: Exercise-Tutorials mit AVPlayer
- [ ] **Erweiterte Analytics**: Trendlinien, Prognosen, Heatmaps
- [ ] **Custom Exercises**: Benutzer-definierte Übungen
- [ ] **Supersets & Circuits**: Übungs-Gruppierung
- [ ] **Nutrition Tracking**: Ernährungsplan-Integration
- [ ] **iPad-Optimierung**: Split-View, Landscape-Mode

---

## Mitwirken

### Code Style
- **SwiftLint**: Enforce Code Style (Configuration in `.swiftlint.yml`)
- **Value Types**: Prefer Structs over Classes (außer SwiftData @Model)
- **Explicit `self`**: In Closures für Clarity
- **Comments**: Deutsch für UI-facing Strings, Englisch für Code

### Pull Request Guidelines
1. Feature Branch erstellen: `git checkout -b feature/my-feature`
2. Änderungen commiten: `git commit -m "Add feature: ..."`
3. Tests hinzufügen (wenn vorhanden)
4. PR gegen `master` öffnen mit Beschreibung

### Testing
```bash
# Run Tests
Cmd+U in Xcode

# UI Tests
Cmd+U mit UI Test Target
```

---

## Architektur-Entscheidungen

### Warum SwiftData statt CoreData?
- **Moderne API**: Swift-First mit Property Wrappers
- **Type Safety**: Compile-Time-Checks statt Runtime-Errors
- **@Query**: Reaktive UI-Updates ohne NSFetchedResultsController
- **Migration**: Leichtgewichtige Schema-Änderungen

### Warum Domain Models + Entities?
- **Separation of Concerns**: Business Logic getrennt von Persistenz
- **Testability**: Structs sind einfacher zu testen
- **Performance**: Value Types sind schneller und thread-safe
- **Flexibility**: Entities können sich ändern ohne Domain Models zu brechen

### Warum WorkoutStore als Singleton?
- **Shared State**: Active Session wird von mehreren Views benötigt
- **Rest Timer**: Globaler Timer-State
- **Profile**: User-Profil wird app-weit verwendet
- **Performance**: Caching von Exercise Stats

**Alternative (geplant):**
- Aufteilen in `SessionManager`, `ProfileManager`, `TimerManager`
- Dependency Injection statt Singleton

---

## Lizenz

**Proprietär** - Alle Rechte vorbehalten

© 2025 Ben Kohler

---

## Kontakt

Bei Fragen oder Feedback bitte ein Issue erstellen:
[GitHub Issues](https://github.com/yourusername/gym-app/issues)

---

**Version:** 1.0
**Letzte Aktualisierung:** 2025-10-07
**Autor:** Ben Kohler
**Plattform:** iOS 17.0+
**Sprache:** Swift 5.9+
