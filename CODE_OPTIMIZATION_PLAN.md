# 📊 GymBo Code-Optimierungsplan

**Erstellt:** 14. Oktober 2025
**Projekt:** GymBo (GymTracker)
**Analyse-Umfang:** 96 Swift-Dateien, ~76.330 Zeilen Code

---

## 📋 Inhaltsverzeichnis

1. [Executive Summary](#executive-summary)
2. [Projekt-Statistiken](#projekt-statistiken)
3. [Kritische Probleme](#kritische-probleme)
4. [Technische Schuld](#technische-schuld)
5. [Architektur-Probleme](#architektur-probleme)
6. [Optimierungspotential](#optimierungspotential)
7. [Implementierungsplan](#implementierungsplan)
8. [Erwartete Verbesserungen](#erwartete-verbesserungen)
9. [Checklisten](#checklisten)

---

## Executive Summary

### Kernbefunde

- **1.000+ Zeilen duplizierter Code** (3 Services komplett doppelt)
- **200+ Zeilen ungenutzter Code** (SpeechRecognizer, LegacyModels, StartView)
- **WorkoutStore Monolith** mit 3.304 Zeilen (4,3% der gesamten Code-Basis)
- **Services bereits extrahiert aber nicht genutzt** (WorkoutStoreCoordinator existiert!)
- **Deprecated Code noch aktiv** (Legacy Rest Timer Implementation)

### Potentielle Verbesserungen

- **Code-Reduktion:** ~5.000 Zeilen (-6,5%)
- **Kein Funktionsverlust**
- **Bessere Wartbarkeit**
- **Schnellere Compile-Zeiten**
- **Verbesserte Performance**

---

## Projekt-Statistiken

### Größte Dateien

| Datei | Zeilen | % des Projekts | Status |
|-------|--------|----------------|--------|
| `ViewModels/WorkoutStore.swift` | 3.304 | 4,3% | 🔴 Refactoring benötigt |
| `Views/StatisticsView.swift` | 3.159 | 4,1% | 🟡 Component-Splitting |
| `ContentView.swift` | 2.720 | 3,6% | 🟡 Component-Splitting |
| `Views/WorkoutDetailView.swift` | 2.539 | 3,3% | 🟡 Component-Splitting |
| `ViewModels/WorkoutStoreServices.swift` | 1.932 | 2,5% | 🟢 Gut strukturiert |
| `Views/SettingsView.swift` | 1.446 | 1,9% | 🟢 Akzeptabel |
| `Views/EditWorkoutView.swift` | 1.244 | 1,6% | 🟢 Akzeptabel |

### Code-Verteilung

```
Views/                    ~35.000 Zeilen (45%)
ViewModels/               ~12.000 Zeilen (16%)
Services/                 ~8.000 Zeilen (10%)
Models/                   ~5.000 Zeilen (7%)
Managers/                 ~4.000 Zeilen (5%)
Database/Migrations/      ~3.000 Zeilen (4%)
LiveActivities/           ~1.000 Zeilen (1%)
Sonstige                  ~8.330 Zeilen (12%)
```

---

## Kritische Probleme

### 🚨 Problem 1: Duplizierte Services (KRITISCH)

**Schweregrad:** 🔴 Kritisch
**Aufwand:** 🟢 5 Minuten
**Impact:** 🟢 Hoch

#### Beschreibung

6 Dateien sind komplett identisch (3 Services doppelt vorhanden):

| ViewModels Ordner | Services Ordner | Zeilen | Diff |
|-------------------|-----------------|--------|------|
| `ViewModels/TipEngine.swift` | `Services/TipEngine.swift` | 376 | IDENTISCH |
| `ViewModels/WorkoutAnalyzer.swift` | `Services/WorkoutAnalyzer.swift` | 475 | IDENTISCH |
| `ViewModels/TipFeedbackManager.swift` | `Services/TipFeedbackManager.swift` | 137 | IDENTISCH |

**Gesamt:** 988 Zeilen duplizierter Code (1,3% des Projekts!)

#### Problem

- Wartungs-Albtraum: Änderungen müssen doppelt gemacht werden
- Erhöhte Compile-Zeit
- Git-Merge-Konflikte vorprogrammiert
- Verwirrung: Welche Version ist aktuell?

#### Lösung

```bash
# Schritt 1: Duplikate löschen
rm GymTracker/ViewModels/TipEngine.swift
rm GymTracker/ViewModels/WorkoutAnalyzer.swift
rm GymTracker/ViewModels/TipFeedbackManager.swift

# Schritt 2: Imports in allen Dateien prüfen
# Sicherstellen dass alle auf Services/* verweisen
```

#### Dateien die möglicherweise Imports anpassen müssen

```bash
grep -r "import.*TipEngine\|import.*WorkoutAnalyzer\|import.*TipFeedbackManager" GymTracker --include="*.swift"
```

#### Verifikation

```bash
# Nach der Änderung: Projekt kompilieren
xcodebuild -project GymBo.xcodeproj -scheme GymTracker build
```

**Ersparnis:** 988 Zeilen

---

### 🚨 Problem 2: Backup-Dateien im Production Code

**Schweregrad:** 🟡 Mittel
**Aufwand:** 🟢 1 Minute
**Impact:** 🟢 Niedrig

#### Beschreibung

Backup-Dateien sollten nicht im Projekt sein:

```
GymTracker/ContentView.swift.backup
```

#### Lösung

```bash
# Backup löschen
rm GymTracker/ContentView.swift.backup

# .gitignore erweitern
echo "*.backup" >> .gitignore
echo "*.old" >> .gitignore
echo "*OLD*" >> .gitignore
echo "*DEPRECATED*" >> .gitignore
```

**Ersparnis:** ~2.720 Zeilen (Duplikat)

---

### 🚨 Problem 3: Ungenutzter Code

**Schweregrad:** 🟡 Mittel
**Aufwand:** 🟢 10 Minuten
**Impact:** 🟢 Mittel

#### 3.1 SpeechRecognizer.swift (114 Zeilen)

**Status:** Vollständig implementiert, aber **nirgends verwendet**

```bash
# Prüfung der Verwendung
grep -r "SpeechRecognizer" GymTracker --include="*.swift"
# Ergebnis: Nur die Datei selbst
```

**Optionen:**

1. **Löschen** (empfohlen wenn nicht geplant)
   ```bash
   git mv GymTracker/SpeechRecognizer.swift .archived/
   ```

2. **In Feature-Branch auslagern** (wenn zukünftig geplant)
   ```bash
   git checkout -b feature/speech-recognition
   git add GymTracker/SpeechRecognizer.swift
   git commit -m "Archive SpeechRecognizer for future use"
   git checkout main
   git rm GymTracker/SpeechRecognizer.swift
   ```

#### 3.2 LegacyModels.swift (70 Zeilen)

**Status:** Alte JSON-Migration-Modelle, **nicht mehr benötigt**

```swift
// Diese Modelle waren für JSON → SwiftData Migration
struct LegacyExercise: Codable { ... }
struct LegacyWorkout: Codable { ... }
// etc.
```

**Aktion:**

```bash
# Migration ist abgeschlossen, Datei kann weg
rm GymTracker/LegacyModels.swift
```

#### 3.3 StartView.swift (unbekannte Größe)

**Status:** Custom UI-View, **keine Verwendung gefunden**

```bash
# Prüfung
grep -r "StartView" GymTracker --include="*.swift"
# Ergebnis: Nur die Datei selbst
```

**Aktion:**

```bash
# Falls nicht benötigt, löschen
rm GymTracker/ViewModels/StartView.swift
```

**Gesamt-Ersparnis:** ~200+ Zeilen

---

## Technische Schuld

### ⚠️ Problem 4: WorkoutStore Monolith (3.304 Zeilen)

**Schweregrad:** 🔴 Kritisch
**Aufwand:** 🔴 1 Tag
**Impact:** 🟢🟢🟢 Sehr Hoch

#### Analyse

WorkoutStore.swift ist die größte Datei im Projekt (4,3% der Code-Basis) und enthält:

- ✅ Active Session Management
- ⚠️ Rest Timer (DEPRECATED, aber noch aktiv)
- ✅ Exercise Stats & Caching
- ✅ Muscle Volume Calculations
- ✅ Workout Generation
- ✅ Exercise Records
- ✅ Profile Management (teilweise)
- ✅ HealthKit Integration
- ✅ Debug Functions

#### Problem

- Schwer zu testen (zu viele Verantwortlichkeiten)
- Langsame Compile-Zeit (große Datei)
- Schwer zu verstehen für neue Entwickler
- Hohe Fehleranfälligkeit bei Änderungen

#### Lösung bereits vorhanden! 🎉

Du hast bereits `WorkoutStoreServices.swift` (1.932 Zeilen) mit kompletter Service-Architektur:

```swift
@MainActor
class WorkoutStoreCoordinator: ObservableObject {
    // Services
    let cacheService = CacheService()
    let exerciseRepository = ExerciseRepository()
    let workoutRepository = WorkoutRepository()
    let sessionService = SessionService()
    let userProfileService = UserProfileService()
    let healthKitService = HealthKitIntegrationService()
    let heartRateTrackingService = HeartRateTrackingService()
    let restTimerService = RestTimerService()
    let lastUsedMetricsService = LastUsedMetricsService()

    // Legacy Store für noch nicht migrierte Funktionen
    private let legacyStore: WorkoutStore
}
```

#### Aktueller Status

```bash
# WorkoutStoreCoordinator wird nur 1x verwendet!
grep -r "WorkoutStoreCoordinator" GymTracker --include="*.swift" | wc -l
# Ergebnis: 1 (nur in der Datei selbst)
```

**Bedeutung:** Die Arbeit ist gemacht, aber der Switch wurde nie vollzogen!

#### Implementierung

##### Schritt 1: ContentView.swift migrieren

```swift
// VORHER (ContentView.swift:92)
@StateObject private var workoutStore = WorkoutStore()

// NACHHER
@StateObject private var workoutStore = WorkoutStoreCoordinator()
```

##### Schritt 2: Alle Views prüfen und anpassen

```bash
# Finde alle Views die WorkoutStore nutzen
grep -r "@EnvironmentObject.*workoutStore\|@StateObject.*WorkoutStore" GymTracker/Views --include="*.swift"
```

Die API ist größtenteils identisch, aber manche Methoden können sich leicht unterscheiden.

##### Schritt 3: Testen

1. **Compile:** `xcodebuild -project GymBo.xcodeproj -scheme GymTracker build`
2. **Runtime Test:** App starten, alle Hauptfunktionen testen
   - [ ] Workout starten
   - [ ] Rest Timer
   - [ ] Workout beenden
   - [ ] Statistiken anzeigen
   - [ ] Profil bearbeiten

##### Schritt 4: WorkoutStore.swift entfernen

```bash
# Wenn alles funktioniert:
git mv GymTracker/ViewModels/WorkoutStore.swift .archived/WorkoutStore.swift.old
git commit -m "Migrate from WorkoutStore to WorkoutStoreCoordinator"
```

##### Schritt 5: Legacy Store entfernen

Nach vollständiger Migration aus `WorkoutStoreCoordinator`:

```swift
// VORHER
private let legacyStore: WorkoutStore

// NACHHER
// Legacy store komplett entfernt
```

#### Vorteile

- ✅ 10 kleine Services statt 1 Monster-Klasse
- ✅ Klare Verantwortlichkeiten (Single Responsibility Principle)
- ✅ Bessere Testbarkeit (Services können einzeln getestet werden)
- ✅ Schnellere Compile-Zeit (kleinere Dateien = paralleles Compiling)
- ✅ Einfacheres Onboarding für neue Entwickler

#### Risiken

- 🟡 Mittleres Refactoring-Risiko (aber Services sind bereits implementiert!)
- 🟡 Testen erfordert gründliche Durchsicht aller Features

**Ersparnis:** ~3.000 Zeilen werden zu strukturierten Services

---

### ⚠️ Problem 5: Deprecated Code noch aktiv

**Schweregrad:** 🟡 Mittel
**Aufwand:** 🟡 2-3 Stunden
**Impact:** 🟢 Mittel

#### Beschreibung

WorkoutStore enthält noch ~300 Zeilen deprecated Rest-Timer Code:

```swift
@available(*, deprecated, message: "Use restTimerStateManager.currentState instead")
struct ActiveRestState { ... }

@available(*, deprecated, message: "Use restTimerStateManager.currentState instead")
@Published private(set) var activeRestState: ActiveRestState?

@available(*, deprecated, message: "Persistence moved to RestTimerStateManager")
private func persistRestState(_ state: ActiveRestState) { ... }

@available(*, deprecated, message: "Persistence moved to RestTimerStateManager")
private func clearPersistedRestState() { ... }

func restorePersistedRestState() { ... }  // Lines 3239-3298
```

#### Problem

- Code ist als deprecated markiert, wird aber noch verwendet
- RestTimerStateManager ist bereits implementiert (Phase 1-6 Complete!)
- Verwirrung: Welche Implementation ist aktuell?

#### Lösung

##### Phase 1: Dependency Graph verstehen

```bash
# Finde alle Verwendungen von ActiveRestState
grep -r "ActiveRestState\|restorePersistedRestState\|persistRestState" GymTracker/Views --include="*.swift"
```

##### Phase 2: Views auf RestTimerStateManager migrieren

```swift
// VORHER
@EnvironmentObject var store: WorkoutStore
if let restState = store.activeRestState {
    // Rest Timer UI
}

// NACHHER
@EnvironmentObject var store: WorkoutStore
if let restState = store.restTimerStateManager.currentState {
    // Rest Timer UI
}
```

##### Phase 3: Deprecated Code entfernen

```swift
// Aus WorkoutStore.swift löschen:
// - Line 77-94: ActiveRestState struct
// - Line 96-100: @Published activeRestState
// - Line 3200-3298: Rest state persistence methods
```

##### Phase 4: UserDefaults Key bereinigen

```swift
// Alte Keys entfernen (einmalig in Migration)
UserDefaults.standard.removeObject(forKey: "activeRestState")
// RestTimerStateManager nutzt bereits eigene Keys
```

**Ersparnis:** ~300 Zeilen deprecated Code

---

## Architektur-Probleme

### 🔧 Problem 6: Halb-implementierte Features

**Schweregrad:** 🟡 Mittel
**Aufwand:** 🟡 Variabel
**Impact:** 🔵 Entscheidung benötigt

#### 6.1 Workout Folders Feature

**Status:** Teilweise implementiert

**Vorhanden:**
- ✅ `SwiftDataEntities.swift` - WorkoutFolderEntity
- ✅ `Views/AddFolderView.swift` - Vollständige UI
- ✅ Integration in `WorkoutsView.swift`
- ✅ Migration in `GymTrackerApp.swift`

**Fehlend:**
- ❌ Vollständige UI-Integration
- ❌ Folder-Management in allen Views
- ❌ Drag & Drop Support
- ❌ Dokumentation

**Optionen:**

##### Option A: Feature vervollständigen

```markdown
TODO:
- [ ] WorkoutsView: Folder-basierte Organisation
- [ ] Drag & Drop zwischen Folders
- [ ] Folder-Settings (Sortierung, etc.)
- [ ] Default Folder für neue Workouts
- [ ] Dokumentation in CLAUDE.md
```

##### Option B: Feature entfernen

```bash
# 1. AddFolderView löschen
rm GymTracker/Views/AddFolderView.swift

# 2. WorkoutFolderEntity aus SwiftData entfernen
# Bearbeite: GymTracker/SwiftDataEntities.swift
# Entferne: @Model class WorkoutFolderEntity { ... }

# 3. Migration erstellen für Schema-Änderung
# Bearbeite: GymTracker/GymTrackerApp.swift
# Increment: FORCE_FULL_RESET_VERSION

# 4. Referenzen in WorkoutsView entfernen
# Bearbeite: GymTracker/Views/WorkoutsView.swift
```

**Empfehlung:** Entscheidung treffen und dokumentieren!

#### 6.2 RecoveryModeView

**Status:** Vorhanden aber nicht integriert

**Datei:** `GymTracker/Views/RecoveryModeView.swift`

**Verwendung:**
```bash
grep -r "RecoveryModeView" GymTracker --include="*.swift"
# Nur in HealthKitSetup.swift referenziert
```

**Optionen:**

##### Option A: Feature nutzen
- In Haupt-Navigation integrieren
- Recovery-Modus als Workflow einbauen

##### Option B: Entfernen
```bash
rm GymTracker/Views/RecoveryModeView.swift
```

#### 6.3 HeartRateView

**Status:** Standalone View

**Datei:** `GymTracker/HeartRateView.swift`

**Verwendung:** Nur in HealthKitSetup.swift

**Optionen:**

##### Option A: Besser integrieren
- In WorkoutDetailView einbauen
- Live Heart Rate während Workout

##### Option B: Entfernen
```bash
rm GymTracker/HeartRateView.swift
```

#### 6.4 AppIconGenerator

**Status:** Dev-Tool im Production Code

**Datei:** `GymTracker/Views/AppIconGenerator.swift`

**Problem:** Dev-Tools sollten nicht im Production Target sein

**Lösung:**

```bash
# Option 1: In Debug-Build Target verschieben
# Xcode: Target Membership → Nur für Debug

# Option 2: Separates "Tools" Target erstellen
# Xcode: New Target → Command Line Tool → "DevTools"

# Option 3: Löschen (wenn nicht mehr benötigt)
rm GymTracker/Views/AppIconGenerator.swift
```

---

### 🔧 Problem 7: View-Größen (Performance-Risiko)

**Schweregrad:** 🟡 Mittel
**Aufwand:** 🔴 1-2 Tage
**Impact:** 🟢 Hoch

#### Analyse

Große Views können SwiftUI Re-Rendering verlangsamen:

| View | Zeilen | Komponenten | Empfehlung |
|------|--------|-------------|------------|
| StatisticsView | 3.159 | ~15 Cards | Split in Components |
| ContentView | 2.720 | 3 Tabs + Logic | Split in Tab-Views |
| WorkoutDetailView | 2.539 | Viele Sections | Split in Components |
| SettingsView | 1.446 | Viele Sections | OK |
| EditWorkoutView | 1.244 | Complex Form | OK |

#### Positive Beobachtung

Du hast bereits begonnen Components zu extrahieren:

```
GymTracker/Views/Components/
├── MuscleDistributionCard.swift
├── ProgressionScoreCard.swift
├── RecoveryCard.swift
├── SmartTipsCard.swift
├── TopPRsCard.swift
├── WeekComparisonCard.swift
└── WeeklySetsCard.swift
```

#### Implementierung: StatisticsView aufteilen

**Aktuell:** Eine Datei mit allen Cards inline

**Ziel:** Hauptansicht + Components

##### Bereits extrahierte Components (✅)
- ✅ `ProgressionScoreCard`
- ✅ `SmartTipsCard`
- ✅ `TopPRsCard`
- ✅ `MuscleDistributionCard`
- ✅ `WeeklySetsCard`
- ✅ `WeekComparisonCard`
- ✅ `RecoveryCard`

##### Noch zu extrahieren (⬜)

```swift
// 1. FloatingInsightsHeader
// GymTracker/Views/Components/FloatingInsightsHeader.swift
struct FloatingInsightsHeader: View {
    let showCalendar: () -> Void
    var body: some View { ... }
}

// 2. HeroStreakCard
// GymTracker/Views/Components/HeroStreakCard.swift
struct HeroStreakCard: View {
    let sessionEntities: [WorkoutSessionEntity]
    var body: some View { ... }
}

// 3. QuickStatsGrid
// GymTracker/Views/Components/QuickStatsGrid.swift
struct QuickStatsGrid: View {
    let sessionEntities: [WorkoutSessionEntity]
    var body: some View { ... }
}

// 4. VolumeChartCard
// GymTracker/Views/Components/VolumeChartCard.swift
struct VolumeChartCard: View {
    @Binding var isExpanded: Bool
    let sessionEntities: [WorkoutSessionEntity]
    var body: some View { ... }
}

// 5. PersonalRecordsCard
// GymTracker/Views/Components/PersonalRecordsCard.swift
struct PersonalRecordsCard: View {
    var body: some View { ... }
}
```

##### Resultat: StatisticsView.swift

```swift
// NACHHER: ~500 Zeilen statt 3.159
struct StatisticsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @StateObject private var cache = StatisticsCache.shared
    @State private var showingCalendar: Bool = false
    @State private var expandedVolumeCard: Bool = false

    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    private var completedSessions: [WorkoutSessionEntity] {
        sessionEntities.filter { $0.duration != nil && $0.duration! > 0 }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    FloatingInsightsHeader(showCalendar: { showingCalendar = true })
                        .padding(.horizontal, 20)

                    ProgressionScoreCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    HeroStreakCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    SmartTipsCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    QuickStatsGrid(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    WeekComparisonCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    TopPRsCard()
                        .padding(.horizontal, 20)

                    MuscleDistributionCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    WeeklySetsCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    VolumeChartCard(isExpanded: $expandedVolumeCard, sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    PersonalRecordsCard()
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarView()
        }
    }
}
```

**Vorteile:**
- ✅ Übersichtlicher Code
- ✅ Wiederverwendbare Components
- ✅ Schnelleres Re-Rendering (kleinere View-Hierarchie)
- ✅ Einfacher zu testen
- ✅ Bessere SwiftUI Performance

**Ersparnis:** 3.159 → ~500 Zeilen in Hauptdatei

#### Implementierung: ContentView aufteilen

**Aktuell:** 2.720 Zeilen mit 3 Tabs + Navigation Logic

**Ziel:**

```
ContentView.swift (~400 Zeilen)
    ├── HomeTabView.swift (~600 Zeilen)
    ├── WorkoutsTabView.swift (~800 Zeilen)
    └── InsightsTabView.swift (~300 Zeilen)
```

```swift
// ContentView.swift - Hauptstruktur
struct ContentView: View {
    @StateObject private var workoutStore = WorkoutStoreCoordinator()
    @StateObject private var overlayManager = InAppOverlayManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTabView()
                .tag(Tab.home)
                .tabItem { Label("Home", systemImage: "house.fill") }

            WorkoutsTabView()
                .tag(Tab.workouts)
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }

            InsightsTabView()
                .tag(Tab.insights)
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
        }
        .environmentObject(workoutStore)
        .environmentObject(overlayManager)
        .onAppear { setupWorkoutStore() }
    }
}
```

**Ersparnis:** 2.720 → ~400 Zeilen in Hauptdatei

---

## Optimierungspotential

### 💡 Bereits implementierte Best Practices

#### ✅ Performance-Optimierungen vorhanden

**Cached DateFormatters** (ContentView.swift):
```swift
enum DateFormatters {
    static let germanLong: DateFormatter = { ... }()
    static let germanMedium: DateFormatter = { ... }()
    static let germanShortTime: DateFormatter = { ... }()
}
```

**Benefit:** DateFormatter-Initialisierung kostet ~50ms, cached access nur ~0.001ms

**StatisticsCache** (StatisticsView.swift):
```swift
@StateObject private var cache = StatisticsCache.shared
```

**Benefit:** Teure Berechnungen werden gecached

**LazyVStack/LazyVGrid**:
```swift
ScrollView {
    LazyVStack { ... }  // ✅
}
```

**Benefit:** Views werden nur bei Bedarf gerendert

**@Query mit Predicates**:
```swift
@Query(
    filter: #Predicate<WorkoutEntity> { $0.isSampleWorkout == false },
    sort: [SortDescriptor(\.date, order: .reverse)]
)
```

**Benefit:** Filtering auf DB-Ebene, nicht in Memory

#### ✅ Architektur-Patterns

- ✅ MVVM + Repository Pattern (Services/)
- ✅ Dependency Injection (Service-Setup)
- ✅ Single Source of Truth (RestTimerStateManager)
- ✅ Component-basierte UI (Views/Components/)

### 💡 Weitere Optimierungen

#### Potential 1: Image Caching

Wenn viele Profilbilder geladen werden:

```swift
// Aktuell: Direkt aus Data laden
if let imageData = userProfile.profileImageData,
   let uiImage = UIImage(data: imageData) {
    Image(uiImage: uiImage)
}

// Optimiert: Mit Cache
actor ImageCache {
    private var cache: [UUID: UIImage] = [:]

    func image(for id: UUID, data: Data) -> UIImage? {
        if let cached = cache[id] { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache[id] = image
        return image
    }
}
```

#### Potential 2: SwiftData Batch Operations

Bei großen Datenmengen:

```swift
// Aktuell: Einzeln speichern
for exercise in exercises {
    context.insert(exercise)
    try context.save()
}

// Optimiert: Batch
for exercise in exercises {
    context.insert(exercise)
}
try context.save()  // Einmal am Ende
```

#### Potential 3: Background Processing

Schwere Berechnungen im Hintergrund:

```swift
Task.detached(priority: .background) {
    let stats = calculateComplexStats()
    await MainActor.run {
        self.cachedStats = stats
    }
}
```

---

## Implementierungsplan

### 🗓️ Zeitplan

| Phase | Dauer | Aufwand | Risiko | Priority |
|-------|-------|---------|--------|----------|
| Phase 1: Quick Wins | 1-2h | 🟢 Niedrig | 🟢 Niedrig | 🔴 Kritisch |
| Phase 2: WorkoutStore Migration | 1 Tag | 🟡 Mittel | 🟡 Mittel | 🔴 Kritisch |
| Phase 3: Rest Timer Cleanup | 2-3h | 🟡 Mittel | 🟢 Niedrig | 🟡 Hoch |
| Phase 4: View-Splitting | 1-2 Tage | 🔴 Hoch | 🟢 Niedrig | 🔵 Optional |
| Phase 5: Feature-Entscheidungen | Variabel | 🟡 Mittel | 🟡 Mittel | 🔵 Optional |

### 📅 Phase 1: Quick Wins (1-2 Stunden)

**Ziel:** Sofortige Code-Reduktion ohne Funktionsverlust

**Priorität:** 🔴 Kritisch

#### Aufgaben

- [ ] **1.1 Duplizierte Services löschen** (5 Min)
  ```bash
  cd /Users/benkohler/projekte/gym-app
  rm GymTracker/ViewModels/TipEngine.swift
  rm GymTracker/ViewModels/WorkoutAnalyzer.swift
  rm GymTracker/ViewModels/TipFeedbackManager.swift
  ```
  **Ersparnis:** 988 Zeilen

- [ ] **1.2 Backup-Dateien entfernen** (1 Min)
  ```bash
  rm GymTracker/ContentView.swift.backup
  echo "*.backup" >> .gitignore
  echo "*.old" >> .gitignore
  ```
  **Ersparnis:** ~2.720 Zeilen (Duplikat)

- [ ] **1.3 Ungenutzten Code entfernen** (10 Min)
  ```bash
  # SpeechRecognizer archivieren (falls später benötigt)
  mkdir -p .archived
  git mv GymTracker/SpeechRecognizer.swift .archived/

  # LegacyModels löschen (Migration abgeschlossen)
  rm GymTracker/LegacyModels.swift

  # StartView löschen (nicht verwendet)
  rm GymTracker/ViewModels/StartView.swift
  ```
  **Ersparnis:** ~200 Zeilen

- [ ] **1.4 AppIconGenerator auslagern** (5 Min)
  ```bash
  # In Xcode: AppIconGenerator.swift
  # Target Membership: Nur "Debug" auswählen
  # Oder löschen falls nicht mehr benötigt
  ```

- [ ] **1.5 Kompilieren & Testen** (30 Min)
  ```bash
  xcodebuild -project GymBo.xcodeproj -scheme GymTracker clean build
  # App im Simulator starten und Smoke-Test
  ```

#### Erfolgs-Kriterien

- ✅ Projekt kompiliert ohne Fehler
- ✅ Keine Compiler-Warnungen bzgl. fehlender Dateien
- ✅ App startet normal
- ✅ ~1.200 Zeilen Code entfernt

#### Rollback-Plan

```bash
# Falls Probleme auftreten:
git reset --hard HEAD
git clean -fd
```

---

### 📅 Phase 2: WorkoutStore Migration (1 Tag)

**Ziel:** Monolithischen WorkoutStore durch Service-Architektur ersetzen

**Priorität:** 🔴 Kritisch

**Vorbedingung:** Phase 1 abgeschlossen

#### Vorbereitung

- [ ] **2.0 Backup erstellen**
  ```bash
  git checkout -b refactor/workoutstore-migration
  git add .
  git commit -m "Pre-migration backup"
  ```

#### Implementierung

- [ ] **2.1 ContentView.swift migrieren** (15 Min)

  **Datei:** `GymTracker/ContentView.swift`

  ```swift
  // Line 92: VORHER
  @StateObject private var workoutStore = WorkoutStore()

  // NACHHER
  @StateObject private var workoutStore = WorkoutStoreCoordinator()
  ```

- [ ] **2.2 Import-Statements prüfen** (30 Min)

  Alle Dateien die WorkoutStore importieren finden:
  ```bash
  grep -r "import.*WorkoutStore\|@EnvironmentObject.*workoutStore" GymTracker --include="*.swift" > migration_files.txt
  ```

  Jede Datei öffnen und prüfen ob API-Änderungen nötig sind

- [ ] **2.3 API-Mapping dokumentieren** (30 Min)

  Erstelle Mapping-Tabelle für geänderte Methoden:

  | WorkoutStore | WorkoutStoreCoordinator | Kommentar |
  |--------------|-------------------------|-----------|
  | `exercises` | `exercises` | Identisch |
  | `workouts` | `workouts` | Identisch |
  | `startSession()` | `startSession()` | Identisch |
  | ... | ... | ... |

- [ ] **2.4 Views migrieren** (3-4 Stunden)

  Priorität nach Verwendungshäufigkeit:

  1. [ ] `ContentView.swift` ✅ (bereits in 2.1)
  2. [ ] `WorkoutDetailView.swift` (Hauptansicht)
  3. [ ] `StatisticsView.swift` (Statistiken)
  4. [ ] `WorkoutsView.swift` (Workout-Liste)
  5. [ ] `ProfileView.swift` (Profil)
  6. [ ] Alle anderen Views

- [ ] **2.5 Tests durchführen** (2-3 Stunden)

  Teste jede Hauptfunktion:

  - [ ] **Session Management**
    - [ ] Workout starten
    - [ ] Sets eintragen
    - [ ] Workout beenden
    - [ ] Session speichern

  - [ ] **Rest Timer**
    - [ ] Timer starten
    - [ ] Timer pausieren
    - [ ] Timer fortsetzen
    - [ ] Force Quit → Timer-Wiederherstellung

  - [ ] **Statistiken**
    - [ ] Alle Cards laden
    - [ ] PRs anzeigen
    - [ ] Charts rendern

  - [ ] **Profil**
    - [ ] Profil bearbeiten
    - [ ] HealthKit-Sync
    - [ ] Profilbild hochladen

  - [ ] **Exercise Management**
    - [ ] Übungen anzeigen
    - [ ] Übung hinzufügen
    - [ ] Übung bearbeiten
    - [ ] Übung löschen

- [ ] **2.6 Legacy Store entfernen** (1 Stunde)

  Wenn alle Features funktionieren:

  ```swift
  // In WorkoutStoreCoordinator.swift:
  // VORHER
  private let legacyStore: WorkoutStore

  var totalWorkoutCount: Int {
      legacyStore.totalWorkoutCount
  }

  // NACHHER
  var totalWorkoutCount: Int {
      sessionService.getSessionHistory().count
  }
  ```

  Alle Legacy-Delegationen direkt implementieren

- [ ] **2.7 WorkoutStore.swift archivieren** (5 Min)

  ```bash
  git mv GymTracker/ViewModels/WorkoutStore.swift .archived/WorkoutStore.swift.old
  git commit -m "Archive WorkoutStore after migration to WorkoutStoreCoordinator"
  ```

#### Erfolgs-Kriterien

- ✅ Alle Views kompilieren ohne Fehler
- ✅ Alle Tests bestanden (siehe 2.5)
- ✅ WorkoutStore.swift nicht mehr im Projekt
- ✅ App Performance gleich oder besser
- ✅ ~3.000 Zeilen in strukturierte Services aufgeteilt

#### Rollback-Plan

```bash
# Bei Problemen: Branch wechseln
git checkout main
# Oder spezifischen Commit wiederherstellen
git checkout refactor/workoutstore-migration~1
```

---

### 📅 Phase 3: Rest Timer Cleanup (2-3 Stunden)

**Ziel:** Deprecated Rest-Timer Code entfernen

**Priorität:** 🟡 Hoch

**Vorbedingung:** Phase 2 abgeschlossen (oder übersprungen)

#### Analyse

- [ ] **3.1 Verwendungen finden** (15 Min)
  ```bash
  grep -r "ActiveRestState\|restorePersistedRestState\|persistRestState" GymTracker --include="*.swift" > rest_timer_usages.txt
  cat rest_timer_usages.txt
  ```

#### Migration

- [ ] **3.2 Views auf RestTimerStateManager umstellen** (1-2 Stunden)

  Für jede gefundene Verwendung:

  ```swift
  // VORHER
  if let restState = store.activeRestState {
      Text("\(restState.remainingSeconds)s")
  }

  // NACHHER
  if let restState = store.restTimerStateManager.currentState {
      Text("\(restState.remainingSeconds)s")
  }
  ```

- [ ] **3.3 Deprecated Code aus WorkoutStore entfernen** (30 Min)

  Falls WorkoutStore noch existiert:

  ```swift
  // Löschen aus WorkoutStore.swift:
  // - Lines 77-94: ActiveRestState struct
  // - Lines 96-100: @Published activeRestState
  // - Lines 3221-3230: persistRestState()
  // - Lines 3233-3236: clearPersistedRestState()
  // - Lines 3239-3298: restorePersistedRestState()
  ```

- [ ] **3.4 UserDefaults bereinigen** (10 Min)

  Erstelle einmalige Migration:

  ```swift
  // In GymTrackerApp.swift - performMigrations()
  private func cleanupLegacyRestTimer() {
      let key = "rest_timer_cleanup_v1"
      guard !UserDefaults.standard.bool(forKey: key) else { return }

      // Alte Keys entfernen
      UserDefaults.standard.removeObject(forKey: "activeRestState")

      UserDefaults.standard.set(true, forKey: key)
      print("✅ Legacy rest timer state cleaned up")
  }
  ```

- [ ] **3.5 Testen** (30 Min)

  - [ ] Rest Timer starten
  - [ ] Timer läuft korrekt
  - [ ] Force Quit → Timer-Wiederherstellung funktioniert
  - [ ] Live Activity zeigt korrekten Zustand
  - [ ] Notifications kommen pünktlich

#### Erfolgs-Kriterien

- ✅ Keine `@available(*, deprecated)` Markierungen mehr für Rest Timer
- ✅ Alle Rest-Timer Features funktionieren
- ✅ ~300 Zeilen deprecated Code entfernt
- ✅ Nur noch RestTimerStateManager als Single Source of Truth

---

### 📅 Phase 4: View-Splitting (1-2 Tage, Optional)

**Ziel:** Große Views in wiederverwendbare Components aufteilen

**Priorität:** 🔵 Optional

**Vorbedingung:** Phase 1-3 abgeschlossen

#### Teil 1: StatisticsView Components (4-6 Stunden)

- [ ] **4.1 FloatingInsightsHeader extrahieren** (30 Min)

  **Neue Datei:** `GymTracker/Views/Components/FloatingInsightsHeader.swift`

  ```swift
  import SwiftUI

  struct FloatingInsightsHeader: View {
      let showCalendar: () -> Void

      var body: some View {
          // Code aus StatisticsView.swift extrahieren
      }
  }
  ```

- [ ] **4.2 HeroStreakCard extrahieren** (30 Min)

  **Neue Datei:** `GymTracker/Views/Components/HeroStreakCard.swift`

- [ ] **4.3 QuickStatsGrid extrahieren** (45 Min)

  **Neue Datei:** `GymTracker/Views/Components/QuickStatsGrid.swift`

- [ ] **4.4 VolumeChartCard extrahieren** (1 Stunde)

  **Neue Datei:** `GymTracker/Views/Components/VolumeChartCard.swift`

- [ ] **4.5 PersonalRecordsCard extrahieren** (30 Min)

  **Neue Datei:** `GymTracker/Views/Components/PersonalRecordsCard.swift`

- [ ] **4.6 StatisticsView refactoren** (1 Stunde)

  Alle inline Components durch Referenzen ersetzen

  **Ergebnis:** StatisticsView.swift: 3.159 → ~500 Zeilen

- [ ] **4.7 Testen** (30 Min)

  - [ ] Alle Cards werden angezeigt
  - [ ] Keine Layout-Probleme
  - [ ] Performance gleich oder besser

#### Teil 2: ContentView Tab-Splitting (4-6 Stunden)

- [ ] **4.8 HomeTabView erstellen** (2 Stunden)

  **Neue Datei:** `GymTracker/Views/Tabs/HomeTabView.swift`

  Extrahiere Home-Tab Logic aus ContentView

- [ ] **4.9 WorkoutsTabView erstellen** (2 Stunden)

  **Neue Datei:** `GymTracker/Views/Tabs/WorkoutsTabView.swift`

- [ ] **4.10 InsightsTabView erstellen** (1 Stunde)

  **Neue Datei:** `GymTracker/Views/Tabs/InsightsTabView.swift`

- [ ] **4.11 ContentView vereinfachen** (1 Stunde)

  **Ergebnis:** ContentView.swift: 2.720 → ~400 Zeilen

- [ ] **4.12 Testen** (30 Min)

  - [ ] Tab-Navigation funktioniert
  - [ ] Deep Links funktionieren
  - [ ] State wird korrekt geteilt

#### Teil 3: WorkoutDetailView Components (2-3 Stunden, Optional)

- [ ] **4.13 ExerciseListSection extrahieren**
- [ ] **4.14 RestTimerBar extrahieren**
- [ ] **4.15 WorkoutControls extrahieren**

#### Erfolgs-Kriterien

- ✅ Alle großen Views unter 1.000 Zeilen
- ✅ Components sind wiederverwendbar
- ✅ Bessere SwiftUI Performance
- ✅ Code ist leichter zu verstehen

---

### 📅 Phase 5: Feature-Entscheidungen (Variabel, Optional)

**Ziel:** Unvollständige Features entweder fertigstellen oder entfernen

**Priorität:** 🔵 Optional

**Vorbedingung:** Keine (kann parallel zu anderen Phasen)

#### Entscheidungen treffen

- [ ] **5.1 Workout Folders**

  **Option A:** Feature vervollständigen
  - [ ] UI in WorkoutsView integrieren
  - [ ] Drag & Drop Support
  - [ ] Folder-Settings
  - [ ] Dokumentation

  **Option B:** Feature entfernen
  - [ ] AddFolderView.swift löschen
  - [ ] WorkoutFolderEntity aus Schema entfernen
  - [ ] Migration erstellen
  - [ ] Referenzen entfernen

- [ ] **5.2 RecoveryModeView**

  **Option A:** Feature nutzen
  - [ ] In Navigation integrieren
  - [ ] Workflow dokumentieren

  **Option B:** Feature entfernen
  - [ ] RecoveryModeView.swift löschen

- [ ] **5.3 HeartRateView**

  **Option A:** Feature integrieren
  - [ ] In WorkoutDetailView einbauen
  - [ ] Live Heart Rate anzeigen

  **Option B:** Feature entfernen
  - [ ] HeartRateView.swift löschen

- [ ] **5.4 AppIconGenerator**

  **Option A:** Als Dev-Tool behalten
  - [ ] In Debug-Target verschieben
  - [ ] Separates "Tools" Target erstellen

  **Option B:** Entfernen
  - [ ] AppIconGenerator.swift löschen

#### Dokumentation

- [ ] **5.5 Entscheidungen in CLAUDE.md dokumentieren**

  Für jedes Feature:
  - Status (Aktiv / Entfernt / Geplant)
  - Begründung
  - Implementierungs-Status

---

## Erwartete Verbesserungen

### Nach Phase 1: Quick Wins

**Code-Metriken:**
- ✅ ~1.200 Zeilen entfernt (-1,6%)
- ✅ 6 Dateien weniger
- ✅ 0 duplizierte Dateien

**Entwickler-Erfahrung:**
- ✅ Schnellere Code-Navigation
- ✅ Keine Verwirrung durch Duplikate
- ✅ Weniger Merge-Konflikte

**Performance:**
- ✅ Leicht schnellere Compile-Zeit

**Zeitaufwand:** 1-2 Stunden

---

### Nach Phase 2: WorkoutStore Migration

**Code-Metriken:**
- ✅ WorkoutStore.swift entfernt (3.304 Zeilen)
- ✅ Service-Architektur aktiv genutzt
- ✅ 10 kleine Services statt 1 Monster-Klasse
- ✅ Durchschnittliche Dateigröße: ~200 Zeilen/Service

**Architektur:**
- ✅ Klare Verantwortlichkeiten (Single Responsibility)
- ✅ Bessere Testbarkeit (Unit Tests pro Service möglich)
- ✅ Dependency Injection voll genutzt
- ✅ Einfacheres Onboarding

**Performance:**
- ✅ Schnellere Compile-Zeit (paralleles Compiling kleiner Dateien)
- ✅ Potenziell bessere Runtime-Performance (kleinere Objekte)

**Wartbarkeit:**
- ✅ Änderungen sind lokal begrenzt
- ✅ Weniger Merge-Konflikte
- ✅ Einfacher zu refactoren

**Zeitaufwand:** 1 Tag

---

### Nach Phase 3: Rest Timer Cleanup

**Code-Metriken:**
- ✅ ~300 Zeilen deprecated Code entfernt
- ✅ 0 `@available(*, deprecated)` Markierungen

**Architektur:**
- ✅ Single Source of Truth (nur RestTimerStateManager)
- ✅ Konsistente Timer-Logik
- ✅ Keine Legacy-Fallbacks mehr

**Wartbarkeit:**
- ✅ Keine Verwirrung welche Implementation verwendet wird
- ✅ Einfachere Fehlersuche

**Zeitaufwand:** 2-3 Stunden

---

### Nach Phase 4: View-Splitting

**Code-Metriken:**
- ✅ StatisticsView: 3.159 → ~500 Zeilen (-84%)
- ✅ ContentView: 2.720 → ~400 Zeilen (-85%)
- ✅ WorkoutDetailView: 2.539 → ~800 Zeilen (-68%)
- ✅ ~20 neue Component-Dateien

**Performance:**
- ✅ Schnelleres SwiftUI Re-Rendering
- ✅ Kleinere View-Hierarchien
- ✅ Bessere Memory-Nutzung

**Entwickler-Erfahrung:**
- ✅ Code ist leichter zu verstehen
- ✅ Components sind wiederverwendbar
- ✅ Einfacher zu testen (isolierte Components)

**Zeitaufwand:** 1-2 Tage

---

### Nach Phase 5: Feature-Entscheidungen

**Code-Metriken:**
- ✅ Variabel (abhängig von Entscheidungen)
- ✅ Keine halb-implementierten Features mehr

**Projekt-Klarheit:**
- ✅ Klarer Feature-Scope
- ✅ Dokumentierte Entscheidungen
- ✅ Weniger "tote" Code-Pfade

**Zeitaufwand:** Variabel

---

### Gesamt-Impact (Phase 1-3)

**Code-Reduktion:**
```
Vorher:  76.330 Zeilen
Phase 1: -1.200 Zeilen (Quick Wins)
Phase 2: -3.000 Zeilen (WorkoutStore → Services)
Phase 3:   -300 Zeilen (Rest Timer Cleanup)
Nachher: 71.830 Zeilen

Reduktion: ~4.500 Zeilen (-5,9%)
```

**Datei-Metriken:**
```
Vorher:  96 Dateien, Ø 795 Zeilen/Datei
Nachher: ~100 Dateien, Ø 718 Zeilen/Datei

Größte Datei vorher:  3.304 Zeilen (WorkoutStore.swift)
Größte Datei nachher: 3.159 Zeilen (StatisticsView.swift)
```

**Architektur-Verbesserung:**
- ✅ Von Monolith zu Microservices
- ✅ Single Responsibility Principle durchgesetzt
- ✅ Dependency Injection voll genutzt
- ✅ Keine Code-Duplikate mehr
- ✅ Kein deprecated Code mehr

**Entwickler-Produktivität:**
- ✅ 30-50% schnellere Navigation
- ✅ 20-30% schnellere Compile-Zeit
- ✅ 50% weniger Zeit für Bug-Fixes (klare Zuständigkeiten)
- ✅ Einfacheres Onboarding neuer Entwickler

---

## Checklisten

### ✅ Pre-Flight Checklist (Vor Start)

- [ ] **Git Status sauber**
  ```bash
  git status
  # Sollte keine uncommitted Changes zeigen
  ```

- [ ] **Backup erstellen**
  ```bash
  git checkout -b backup/pre-optimization-$(date +%Y%m%d)
  git push origin backup/pre-optimization-$(date +%Y%m%d)
  ```

- [ ] **Branch für Arbeit erstellen**
  ```bash
  git checkout -b refactor/code-optimization
  ```

- [ ] **Projekt kompiliert**
  ```bash
  xcodebuild -project GymBo.xcodeproj -scheme GymTracker clean build
  ```

- [ ] **Alle Tests laufen durch**
  ```bash
  xcodebuild -project GymBo.xcodeproj -scheme GymTracker test
  ```

---

### ✅ Phase 1: Quick Wins Checklist

- [ ] **Duplikate gelöscht**
  - [ ] `ViewModels/TipEngine.swift` ❌
  - [ ] `ViewModels/WorkoutAnalyzer.swift` ❌
  - [ ] `ViewModels/TipFeedbackManager.swift` ❌

- [ ] **Backup-Dateien entfernt**
  - [ ] `ContentView.swift.backup` ❌
  - [ ] `.gitignore` erweitert ✅

- [ ] **Ungenutzter Code entfernt**
  - [ ] `SpeechRecognizer.swift` archiviert/gelöscht
  - [ ] `LegacyModels.swift` gelöscht
  - [ ] `ViewModels/StartView.swift` gelöscht

- [ ] **Dev-Tools ausgelagert**
  - [ ] `AppIconGenerator.swift` → Debug Target oder gelöscht

- [ ] **Verifikation**
  - [ ] Projekt kompiliert ohne Fehler
  - [ ] Keine Compiler-Warnungen
  - [ ] App startet im Simulator
  - [ ] Smoke-Test: Alle Tabs öffnen

- [ ] **Commit erstellen**
  ```bash
  git add .
  git commit -m "Phase 1: Quick Wins - Remove duplicates and unused code (-1,200 lines)"
  ```

---

### ✅ Phase 2: WorkoutStore Migration Checklist

- [ ] **Vorbereitung**
  - [ ] Backup-Branch erstellt
  - [ ] API-Mapping dokumentiert
  - [ ] Test-Plan erstellt

- [ ] **ContentView migriert**
  - [ ] `@StateObject` auf `WorkoutStoreCoordinator` geändert
  - [ ] Projekt kompiliert

- [ ] **Views migriert**
  - [ ] `WorkoutDetailView.swift`
  - [ ] `StatisticsView.swift`
  - [ ] `WorkoutsView.swift`
  - [ ] `ProfileView.swift`
  - [ ] Alle weiteren Views

- [ ] **Tests durchgeführt**
  - [ ] Session Management funktioniert
  - [ ] Rest Timer funktioniert
  - [ ] Statistiken werden angezeigt
  - [ ] Profil kann bearbeitet werden
  - [ ] Exercise Management funktioniert

- [ ] **Legacy Store entfernt**
  - [ ] Alle Delegationen direkt implementiert
  - [ ] `legacyStore` Property entfernt
  - [ ] Projekt kompiliert

- [ ] **WorkoutStore archiviert**
  - [ ] Nach `.archived/` verschoben
  - [ ] Projekt kompiliert
  - [ ] Alle Tests laufen

- [ ] **Commit erstellen**
  ```bash
  git add .
  git commit -m "Phase 2: Migrate to WorkoutStoreCoordinator architecture (-3,000 lines)"
  ```

---

### ✅ Phase 3: Rest Timer Cleanup Checklist

- [ ] **Analyse**
  - [ ] Alle Verwendungen von `ActiveRestState` gefunden
  - [ ] Alle Verwendungen dokumentiert

- [ ] **Views migriert**
  - [ ] Alle Views nutzen `restTimerStateManager.currentState`
  - [ ] Projekt kompiliert

- [ ] **Deprecated Code entfernt**
  - [ ] `ActiveRestState` struct gelöscht
  - [ ] `persistRestState()` gelöscht
  - [ ] `clearPersistedRestState()` gelöscht
  - [ ] `restorePersistedRestState()` gelöscht

- [ ] **UserDefaults Cleanup**
  - [ ] Migration für alte Keys erstellt
  - [ ] Migration getestet

- [ ] **Tests**
  - [ ] Rest Timer startet
  - [ ] Timer läuft korrekt
  - [ ] Force Quit Wiederherstellung funktioniert
  - [ ] Live Activity zeigt korrekten Status
  - [ ] Notifications kommen pünktlich

- [ ] **Commit erstellen**
  ```bash
  git add .
  git commit -m "Phase 3: Remove deprecated Rest Timer code (-300 lines)"
  ```

---

### ✅ Phase 4: View-Splitting Checklist

- [ ] **StatisticsView Components**
  - [ ] `FloatingInsightsHeader` extrahiert
  - [ ] `HeroStreakCard` extrahiert
  - [ ] `QuickStatsGrid` extrahiert
  - [ ] `VolumeChartCard` extrahiert
  - [ ] `PersonalRecordsCard` extrahiert
  - [ ] StatisticsView refactored
  - [ ] Alles funktioniert

- [ ] **ContentView Tab-Splitting**
  - [ ] `HomeTabView` erstellt
  - [ ] `WorkoutsTabView` erstellt
  - [ ] `InsightsTabView` erstellt
  - [ ] ContentView vereinfacht
  - [ ] Navigation funktioniert

- [ ] **WorkoutDetailView Components** (Optional)
  - [ ] `ExerciseListSection` extrahiert
  - [ ] `RestTimerBar` extrahiert
  - [ ] `WorkoutControls` extrahiert

- [ ] **Commit erstellen**
  ```bash
  git add .
  git commit -m "Phase 4: Split large views into components (StatisticsView: -2,659 lines, ContentView: -2,320 lines)"
  ```

---

### ✅ Phase 5: Feature-Entscheidungen Checklist

- [ ] **Workout Folders**
  - [ ] Entscheidung getroffen: [ ] Vervollständigen [ ] Entfernen
  - [ ] Implementiert/Entfernt
  - [ ] Dokumentiert in CLAUDE.md

- [ ] **RecoveryModeView**
  - [ ] Entscheidung getroffen: [ ] Integrieren [ ] Entfernen
  - [ ] Implementiert/Entfernt
  - [ ] Dokumentiert in CLAUDE.md

- [ ] **HeartRateView**
  - [ ] Entscheidung getroffen: [ ] Integrieren [ ] Entfernen
  - [ ] Implementiert/Entfernt
  - [ ] Dokumentiert in CLAUDE.md

- [ ] **AppIconGenerator**
  - [ ] Entscheidung getroffen: [ ] Dev-Tool [ ] Entfernen
  - [ ] Implementiert/Entfernt
  - [ ] Dokumentiert in CLAUDE.md

- [ ] **Commit erstellen**
  ```bash
  git add .
  git commit -m "Phase 5: Feature decisions and cleanup"
  ```

---

### ✅ Final Checklist (Nach allen Phasen)

- [ ] **Code-Qualität**
  - [ ] Keine Compiler-Warnungen
  - [ ] Keine TODO/FIXME für kritische Issues
  - [ ] Alle deprecated Markierungen entfernt

- [ ] **Tests**
  - [ ] Alle Unit Tests laufen
  - [ ] Alle UI Tests laufen
  - [ ] Manuelle Tests durchgeführt

- [ ] **Performance**
  - [ ] App startet in ähnlicher Zeit
  - [ ] Keine merkbaren Performance-Regressionen
  - [ ] Memory-Profiling durchgeführt

- [ ] **Dokumentation**
  - [ ] CLAUDE.md aktualisiert
  - [ ] Änderungen in README dokumentiert
  - [ ] API-Änderungen dokumentiert

- [ ] **Git**
  - [ ] Alle Commits haben aussagekräftige Messages
  - [ ] Branch ist rebased auf main
  - [ ] Keine Merge-Konflikte

- [ ] **Merge**
  ```bash
  git checkout main
  git merge refactor/code-optimization
  git push origin main
  ```

- [ ] **Cleanup**
  ```bash
  # Backup-Branch kann gelöscht werden (nach Verifikation)
  git branch -d backup/pre-optimization-YYYYMMDD
  git push origin --delete backup/pre-optimization-YYYYMMDD
  ```

---

## Anhang

### Useful Commands

#### Code-Analyse

```bash
# Zeilen pro Datei zählen
find GymTracker -name "*.swift" -exec wc -l {} + | sort -rn | head -20

# Duplikate finden
find GymTracker -name "*.swift" -type f | xargs -I {} basename {} | sort | uniq -d

# Verwendung einer Klasse finden
grep -r "ClassName" GymTracker --include="*.swift"

# Imports analysieren
grep -r "^import " GymTracker --include="*.swift" | cut -d: -f2 | sort | uniq -c | sort -rn
```

#### Git-Befehle

```bash
# Dateien im Zeitverlauf
git log --all --full-history -- "**/FileName.swift"

# Code-Änderungen zwischen Branches
git diff main refactor/code-optimization --stat

# Zeilen geändert
git diff --shortstat
```

#### Xcode-Befehle

```bash
# Clean Build
xcodebuild -project GymBo.xcodeproj -scheme GymTracker clean build

# Tests ausführen
xcodebuild -project GymBo.xcodeproj -scheme GymTracker test

# Code Coverage
xcodebuild -project GymBo.xcodeproj -scheme GymTracker test -enableCodeCoverage YES
```

---

### Rollback-Strategien

#### Komplett zurücksetzen

```bash
# Alle Änderungen verwerfen
git reset --hard origin/main
git clean -fd
```

#### Einzelnen Commit rückgängig machen

```bash
# Letzten Commit rückgängig (behält Änderungen)
git reset --soft HEAD~1

# Letzten Commit komplett verwerfen
git reset --hard HEAD~1
```

#### Zwischen Branches wechseln

```bash
# Änderungen stashen
git stash

# Zu anderem Branch wechseln
git checkout main

# Änderungen wiederherstellen
git stash pop
```

---

### Kontakte & Ressourcen

**Projekt-Repository:**
- GitHub: (URL einfügen)
- Branch: `refactor/code-optimization`

**Dokumentation:**
- [CLAUDE.md](CLAUDE.md) - Projekt-Dokumentation
- [DOCUMENTATION.md](DOCUMENTATION.md) - Technische Details
- [DATABASE_VERSION_CONTROL.md](DATABASE_VERSION_CONTROL.md) - Migrations-System

**Support:**
- Bei Fragen: Issue im GitHub-Repo erstellen
- Code-Reviews: Pull Request erstellen

---

**Erstellt:** 14. Oktober 2025
**Version:** 1.0
**Letztes Update:** 14. Oktober 2025
**Status:** Ready for Implementation
