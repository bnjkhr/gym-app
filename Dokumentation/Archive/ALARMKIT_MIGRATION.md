# AlarmKit Migration Plan - Rest Timer

## Übersicht

Dieser Plan beschreibt die komplette Migration des Rest-Timers von der aktuellen Implementierung (basierend auf `Timer` und `NotificationManager`) zu Apples neuem **AlarmKit Framework**.

**Wichtiger Hinweis:** AlarmKit ist ab **iOS 26** (WWDC 2025) verfügbar, nicht iOS 18. Die Migration erfordert daher eine Anpassung der Mindestversion der App.

---

## Inhaltsverzeichnis

1. [Warum AlarmKit?](#warum-alarmkit)
2. [Aktuelle Implementierung - Analyse](#aktuelle-implementierung---analyse)
3. [AlarmKit - Überblick](#alarmkit---überblick)
4. [Migrationsplan](#migrationsplan)
5. [Detaillierte Implementierung](#detaillierte-implementierung)
6. [Zu entfernende Dateien](#zu-entfernende-dateien)
7. [Zu modifizierende Dateien](#zu-modifizierende-dateien)
8. [Neue Dateien](#neue-dateien)
9. [Testing-Strategie](#testing-strategie)
10. [Rollback-Plan](#rollback-plan)
11. [Timeline & Phasen](#timeline--phasen)

---

## Warum AlarmKit?

### Vorteile von AlarmKit

✅ **System-Level Alarms:** Durchdringt Silent Mode und Focus-Modi (ähnlich wie Apple's Clock App)  
✅ **Native Lock Screen Integration:** Automatische Anzeige auf dem Sperrbildschirm  
✅ **Dynamic Island Support:** Nahtlose Integration mit Live Activities  
✅ **Bessere Zuverlässigkeit:** Keine manuelle Timer-Verwaltung mehr nötig  
✅ **Snooze & Pause:** Eingebaute Pause/Resume-Funktionalität  
✅ **Einheitliche UX:** Konsistent mit Apple's Clock App  

### Nachteile / Herausforderungen

⚠️ **iOS 26+ erforderlich:** App muss Mindestversion anheben (Breaking Change!)  
⚠️ **Live Activity Pflicht:** Countdown-Timer benötigen zwingend eine Live Activity  
⚠️ **Neue Berechtigungen:** `NSAlarmKitUsageDescription` in Info.plist erforderlich  
⚠️ **Lernkurve:** Neues Framework, wenig Community-Erfahrung  

---

## Aktuelle Implementierung - Analyse

### Architektur-Überblick

```
RestTimerStateManager (SSOT)
        ↓
   ┌────┴────┬──────────┬───────────┐
   ↓         ↓          ↓           ↓
TimerEngine  LiveAct  Notifications Overlay
```

### Kern-Komponenten

#### 1. **Datenmodell**
- **`RestTimerState`** (`GymTracker/Models/RestTimerState.swift`)
  - Single Source of Truth für Timer-State
  - Codable für UserDefaults-Persistierung
  - Enthält: `startDate`, `endDate`, `totalSeconds`, `phase`, `exerciseInfo`, `heartRate`
  - Phasen: `.running`, `.paused`, `.expired`, `.completed`

#### 2. **Timer-Engine**
- **`TimerEngine`** (`GymTracker/Services/TimerEngine.swift`)
  - Basis: `Timer.scheduledTimer` mit 1s Tick-Intervall
  - Wall-clock basiert (überlebt App-Restart)
  - Expiration-Check bei jedem Tick
  - **Problem:** Manuelle Verwaltung, kein System-Level Support

#### 3. **State Manager**
- **`RestTimerStateManager`** (`GymTracker/ViewModels/RestTimerStateManager.swift`)
  - SSOT für gesamten Timer-Lifecycle
  - Koordiniert alle Subsysteme (Timer, Notifications, Live Activity, Overlay)
  - UserDefaults-Persistierung für Force-Quit Recovery
  - Throttling für Heart Rate Updates (5s)
  - **570 Zeilen Code** - komplex!

#### 4. **Coordinator**
- **`RestTimerCoordinator`** (`GymTracker/Coordinators/RestTimerCoordinator.swift`)
  - Abstraktions-Layer zwischen UI und State Manager
  - Stellt Published Properties für SwiftUI Views bereit
  - Convenience-Methoden (Presets, Time-Add/Subtract)
  - **~350 Zeilen Code**

#### 5. **Live Activity**
- **`WorkoutLiveActivityController`** (`GymTracker/LiveActivities/WorkoutLiveActivityController.swift`)
  - Manuelle Activity-Verwaltung via ActivityKit
  - Custom Throttling (Timer: 10s, Heart Rate: 2s)
  - **~600 Zeilen Code** - viel manuelles Update-Management

#### 6. **Notifications**
- **`NotificationManager`** (`GymTracker/NotificationManager.swift`)
  - `UNUserNotificationCenter` basiert
  - Schedult lokale Push-Notifications
  - Deep-Link Support für Notification-Taps
  - **Problem:** Wird von Silent Mode/Focus unterdrückt

#### 7. **Overlay**
- **`InAppOverlayManager`** (`GymTracker/Managers/InAppOverlayManager.swift`)
  - Zeigt Full-Screen Overlay bei Timer-Ablauf (nur wenn App aktiv)
  - Haptic Feedback & Sound
  - **`RestTimerExpiredOverlay`** (`GymTracker/Views/Overlays/RestTimerExpiredOverlay.swift`)
    - SwiftUI View mit Glassmorphism-Design

#### 8. **UI Integration**
- **`WorkoutStore`** - Initialisiert `RestTimerStateManager`
- **`WorkoutDetailView`** - Startet/Stoppt Timer
- **`ActiveWorkoutSetCard`** - Timer Controls (Pause, Resume, Add Time)
- **`ContentView`** - Deep-Link Handling

### Abhängigkeiten

```
WorkoutStore
    ↓
RestTimerStateManager
    ↓
┌───────┴────────┬───────────────┬──────────────┐
↓                ↓               ↓              ↓
TimerEngine  LiveActivity  Notifications  Overlay
```

### Persistierung

- **UserDefaults Key:** `restTimerState_v2`
- **Max Age:** 24 Stunden (dann verworfen)
- **Format:** JSON (Codable)
- **Recovery:** Bei App-Start wird State wiederhergestellt und geprüft

---

## AlarmKit - Überblick

### Framework-Anforderungen

- **iOS/iPadOS:** 26.0+
- **Imports:**
  ```swift
  import AlarmKit
  import ActivityKit // Für Countdown-Integration
  ```

### Kern-Klassen

#### 1. `AlarmManager`
```swift
let manager = AlarmManager.shared

// Autorisierung prüfen
let authState = manager.authorizationState

// Autorisierung anfordern
let state = try await manager.requestAuthorization()
```

#### 2. `AlarmAttributes<Metadata>`
```swift
struct TimerMetadata: AlarmMetadata {
    var workoutId: UUID
    var workoutName: String
    var exerciseName: String?
}

let attributes = AlarmAttributes<TimerMetadata>(
    presentation: AlarmPresentation(alert: alert),
    tintColor: .blue
)
```

#### 3. `AlarmPresentation`
```swift
let alert = AlarmPresentation.Alert(
    title: "Pause beendet!",
    stopButton: AlarmButton(text: "Fertig", textColor: .blue)
)

let presentation = AlarmPresentation(alert: alert)
```

#### 4. Timer-Konfiguration
```swift
let alarm = try await manager.schedule(
    id: UUID(),
    configuration: .timer(
        duration: 90, // Sekunden
        attributes: attributes
    )
)
```

#### 5. Alarm-Updates beobachten
```swift
for await alarms in manager.alarmUpdates {
    // Reagiere auf Timer-Änderungen
    // alarms ist [Alarm<Metadata>]
}
```

### Live Activity Integration

AlarmKit **erfordert** eine Live Activity für Countdown-Timer:

```swift
struct TimerActivityConfiguration: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<TimerMetadata>.self) { context in
            // Lock Screen / Dynamic Island
            if case let .countdown(countdown) = context.state.mode {
                Text(timerInterval: Date.now ... countdown.fireDate)
                    .monospacedDigit()
            }
        }
    }
}
```

### Wichtige Konzepte

1. **Metadata:** Custom Struct für zusätzliche Daten (muss `AlarmMetadata` konform sein)
2. **Presentation:** Definiert Alert-UI (Titel, Buttons, Farben)
3. **Timer vs. Scheduled Alarm:** Timer = Countdown ab jetzt, Alarm = zu bestimmter Uhrzeit
4. **System-Integration:** Alarms erscheinen automatisch in Lock Screen, Dynamic Island, StandBy

---

## Migrationsplan

### Phase 0: Vorbereitung

**Ziel:** App-Kompatibilität prüfen, iOS 26-Anforderung klären

- [ ] **Entscheidung:** iOS 26+ als Minimum akzeptabel? (Breaking Change!)
- [ ] **Alternative:** Feature-Flag für iOS 26+ Nutzer, Legacy-Timer für iOS < 26
- [ ] AlarmKit-Dokumentation studieren (WWDC 2025 Video anschauen)
- [ ] Proof-of-Concept: Einfacher Test-Timer mit AlarmKit implementieren

**Dauer:** 1-2 Tage

---

### Phase 1: Info.plist & Berechtigungen

**Ziel:** AlarmKit-Berechtigung einrichten

**Änderungen:**

1. **Info.plist:** `NSAlarmKitUsageDescription` hinzufügen
   ```xml
   <key>NSAlarmKitUsageDescription</key>
   <string>GymTracker nutzt Alarme, um dich an das Ende deiner Pause zu erinnern und sicherzustellen, dass du dein Training fortsetzt – auch im Silent Mode oder Focus.</string>
   ```

2. **Deployment Target anpassen:**
   - Projekt-Settings → Deployment Info → Minimum Deployments → iOS 26.0

3. **Autorisierung anfordern:**
   - Neue Methode in `WorkoutStore` oder `AppDelegate` (bei App-Start)
   ```swift
   private func requestAlarmKitAuthorization() async {
       let manager = AlarmManager.shared
       
       guard manager.authorizationState == .notDetermined else { return }
       
       do {
           let state = try await manager.requestAuthorization()
           if state == .authorized {
               AppLogger.workouts.info("✅ AlarmKit authorized")
           } else {
               AppLogger.workouts.warning("⚠️ AlarmKit denied")
           }
       } catch {
           AppLogger.workouts.error("❌ AlarmKit auth failed: \(error)")
       }
   }
   ```

**Dateien:**
- `Info.plist`
- `GymBo.xcodeproj/project.pbxproj` (Deployment Target)
- `GymTracker/App/GymBoApp.swift` (Autorisierung)

**Dauer:** 0.5 Tage

---

### Phase 2: Neues Datenmodell

**Ziel:** AlarmKit-kompatibles State-Modell erstellen

**Neue Datei:** `GymTracker/Models/RestAlarmState.swift`

```swift
import AlarmKit
import Foundation

/// Metadata für AlarmKit Timer
struct RestTimerMetadata: AlarmMetadata {
    var workoutId: UUID
    var workoutName: String
    var exerciseName: String?
    var nextExerciseName: String?
    var setIndex: Int
    var exerciseIndex: Int
    
    // Codable für Persistierung
}

/// State für Rest-Timer basierend auf AlarmKit
@MainActor
final class RestAlarmState: ObservableObject {
    /// Aktueller Alarm (nil wenn kein Timer läuft)
    @Published var currentAlarm: Alarm<RestTimerMetadata>?
    
    /// Herzfrequenz (wird separat getrackt, da nicht Teil von AlarmKit)
    @Published var currentHeartRate: Int?
    
    /// Computed Properties für UI
    var isRunning: Bool {
        guard let alarm = currentAlarm else { return false }
        
        if case .countdown = alarm.state {
            return true
        }
        return false
    }
    
    var isPaused: Bool {
        guard let alarm = currentAlarm else { return false }
        
        if case .paused = alarm.state {
            return true
        }
        return false
    }
    
    var remainingSeconds: Int {
        guard let alarm = currentAlarm,
              case let .countdown(countdown) = alarm.state else {
            return 0
        }
        
        return max(0, Int(countdown.fireDate.timeIntervalSinceNow))
    }
}
```

**Zu beachten:**

- AlarmKit managed den State selbst → weniger Code!
- Kein `TimerEngine` mehr nötig
- Keine manuelle `endDate`-Berechnung
- Herzfrequenz muss separat getrackt werden (nicht Teil von AlarmKit)

**Dauer:** 0.5 Tage

---

### Phase 3: Alarm Manager Service

**Ziel:** Service-Klasse für AlarmKit-Timer erstellen

**Neue Datei:** `GymTracker/Services/RestAlarmService.swift`

```swift
import AlarmKit
import Foundation

@MainActor
final class RestAlarmService: ObservableObject {
    private let manager = AlarmManager.shared
    
    @Published private(set) var currentAlarm: Alarm<RestTimerMetadata>?
    
    private var alarmUpdatesTask: Task<Void, Never>?
    
    init() {
        startObservingAlarms()
    }
    
    deinit {
        alarmUpdatesTask?.cancel()
    }
    
    // MARK: - Timer Controls
    
    /// Startet einen neuen Rest-Timer
    func startTimer(
        workoutId: UUID,
        workoutName: String,
        exerciseName: String?,
        nextExerciseName: String?,
        exerciseIndex: Int,
        setIndex: Int,
        duration: Int
    ) async throws {
        // Cancel existing timer
        if let current = currentAlarm {
            try await manager.dismiss(id: current.id)
        }
        
        let metadata = RestTimerMetadata(
            workoutId: workoutId,
            workoutName: workoutName,
            exerciseName: exerciseName,
            nextExerciseName: nextExerciseName,
            setIndex: setIndex,
            exerciseIndex: exerciseIndex
        )
        
        let alert = AlarmPresentation.Alert(
            title: "Pause beendet!",
            body: nextExerciseName.map { "Weiter mit: \($0)" } ?? "Weiter geht's! 💪🏼",
            stopButton: AlarmButton(text: "Fertig", textColor: .blue)
        )
        
        let attributes = AlarmAttributes<RestTimerMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .blue
        )
        
        let alarm = try await manager.schedule(
            id: UUID(),
            configuration: .timer(duration: duration, attributes: attributes)
        )
        
        currentAlarm = alarm
        
        AppLogger.workouts.info("⏱️ AlarmKit timer started: \(duration)s")
    }
    
    /// Pausiert den aktuellen Timer
    func pauseTimer() async throws {
        guard let alarm = currentAlarm else { return }
        
        try await manager.pause(id: alarm.id)
        
        AppLogger.workouts.info("⏸️ Timer paused")
    }
    
    /// Setzt einen pausierten Timer fort
    func resumeTimer() async throws {
        guard let alarm = currentAlarm else { return }
        
        try await manager.resume(id: alarm.id)
        
        AppLogger.workouts.info("▶️ Timer resumed")
    }
    
    /// Bricht den Timer ab
    func cancelTimer() async throws {
        guard let alarm = currentAlarm else { return }
        
        try await manager.dismiss(id: alarm.id)
        currentAlarm = nil
        
        AppLogger.workouts.info("❌ Timer cancelled")
    }
    
    // MARK: - Observation
    
    private func startObservingAlarms() {
        alarmUpdatesTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await alarms in manager.alarmUpdates {
                // Filter für unsere Timer (RestTimerMetadata)
                let restAlarms = alarms.compactMap { $0 as? Alarm<RestTimerMetadata> }
                
                // Nimm den ersten (sollte nur einer sein)
                self.currentAlarm = restAlarms.first
                
                // Wenn Alarm dismissed wurde
                if restAlarms.isEmpty {
                    self.currentAlarm = nil
                }
                
                AppLogger.workouts.debug("Alarm update: \(restAlarms.count) active")
            }
        }
    }
}
```

**Features:**
- ✅ Automatisches Alarm-Tracking via `alarmUpdates`
- ✅ Pause/Resume eingebaut
- ✅ Keine manuelle Timer-Verwaltung
- ✅ System-Level Integration

**Dauer:** 1 Tag

---

### Phase 4: Live Activity Anpassung

**Ziel:** Live Activity für AlarmKit-Countdown anpassen

**Zu modifizierende Datei:** `WorkoutWidgets/WorkoutWidgetsLiveActivity.swift`

**Änderungen:**

1. **Widget Configuration anpassen:**
   ```swift
   struct WorkoutWidgetsLiveActivity: Widget {
       var body: some WidgetConfiguration {
           // Bestehende ActivityConfiguration für Workout beibehalten
           ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
               // Bestehendes Layout
           }
           
           // NEUE Activity Configuration für AlarmKit Timer
           ActivityConfiguration(for: AlarmAttributes<RestTimerMetadata>.self) { context in
               timerActivityView(context: context)
           } dynamicIsland: { context in
               timerDynamicIsland(context: context)
           }
       }
       
       @ViewBuilder
       private func timerActivityView(
           context: ActivityViewContext<AlarmAttributes<RestTimerMetadata>>
       ) -> some View {
           VStack(spacing: 12) {
               // Timer Countdown
               if case let .countdown(countdown) = context.state.mode {
                   Text(timerInterval: Date.now ... countdown.fireDate)
                       .font(.system(size: 48, weight: .bold, design: .rounded))
                       .monospacedDigit()
               }
               
               // Exercise Info
               if let exercise = context.attributes.metadata.exerciseName {
                   Text(exercise)
                       .font(.headline)
               }
               
               // Pause/Resume Button (wenn unterstützt)
               // Dismiss Button (wenn unterstützt)
           }
           .padding()
       }
       
       @ViewBuilder
       private func timerDynamicIsland(
           context: ActivityViewContext<AlarmAttributes<RestTimerMetadata>>
       ) -> DynamicIsland {
           DynamicIsland {
               // Expanded UI
               DynamicIslandExpandedRegion(.center) {
                   if case let .countdown(countdown) = context.state.mode {
                       Text(timerInterval: Date.now ... countdown.fireDate)
                           .monospacedDigit()
                           .font(.title)
                   }
               }
               
               DynamicIslandExpandedRegion(.bottom) {
                   Text(context.attributes.metadata.exerciseName ?? "Pause")
                       .font(.caption)
               }
           } compactLeading: {
               Image(systemName: "timer")
           } compactTrailing: {
               if case let .countdown(countdown) = context.state.mode {
                   Text(timerInterval: Date.now ... countdown.fireDate)
                       .monospacedDigit()
                       .font(.caption2)
               }
           } minimal: {
               Image(systemName: "timer")
           }
       }
   }
   ```

2. **`WorkoutLiveActivityController` vereinfachen:**
   - Entfernen: Timer-Update-Logik (wird von AlarmKit gehandhabt)
   - Entfernen: Throttling-Code (nicht mehr nötig)
   - Behalten: Workout-Tracking (ohne Timer)

**Vorteile:**
- AlarmKit managed die Live Activity automatisch
- Kein manuelles Update-Management
- Weniger Code (~600 → ~200 Zeilen)

**Dauer:** 1-2 Tage

---

### Phase 5: UI-Integration

**Ziel:** UI-Layer auf AlarmKit umstellen

**Zu modifizierende Dateien:**

#### 1. `WorkoutStore.swift`
```swift
@MainActor
class WorkoutStore: ObservableObject {
    // ALT: let restTimerStateManager: RestTimerStateManager
    // NEU:
    let restAlarmService: RestAlarmService
    
    init() {
        self.restAlarmService = RestAlarmService()
    }
    
    // Timer-Methoden anpassen
    func startRest(...) {
        Task {
            try await restAlarmService.startTimer(
                workoutId: workout.id,
                workoutName: workout.name,
                exerciseName: exerciseName,
                nextExerciseName: nextExerciseName,
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                duration: duration
            )
        }
    }
    
    func pauseRest() {
        Task {
            try await restAlarmService.pauseTimer()
        }
    }
    
    // ... weitere Methoden
}
```

#### 2. `RestTimerCoordinator.swift`
- **Option A:** Komplette Entfernung (nicht mehr nötig)
- **Option B:** Vereinfachen zu Wrapper um `RestAlarmService` (für Backward-Kompatibilität)

**Empfehlung:** Coordinator entfernen, da AlarmKit-Service bereits einfach genug ist.

#### 3. `ActiveWorkoutSetCard.swift`
```swift
// ALT:
// if let state = workoutStore.restTimerStateManager.currentState {
//     Text("\(state.remainingSeconds)s")
// }

// NEU:
if let alarm = workoutStore.restAlarmService.currentAlarm,
   case let .countdown(countdown) = alarm.state {
    Text(timerInterval: Date.now ... countdown.fireDate)
        .monospacedDigit()
}
```

#### 4. `WorkoutDetailView.swift`
```swift
Button("Rest starten") {
    Task {
        try await workoutStore.restAlarmService.startTimer(
            workoutId: workout.id,
            workoutName: workout.name,
            exerciseName: currentExercise,
            nextExerciseName: nextExercise,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            duration: 90
        )
    }
}
```

**Dauer:** 2 Tage

---

### Phase 6: Cleanup & Removal

**Ziel:** Alte Timer-Implementierung entfernen

#### Zu entfernende Dateien:

1. ✅ `GymTracker/Services/TimerEngine.swift` (370 Zeilen)
2. ✅ `GymTracker/Models/RestTimerState.swift` (280 Zeilen)
3. ✅ `GymTracker/ViewModels/RestTimerStateManager.swift` (570 Zeilen)
4. ✅ `GymTracker/Coordinators/RestTimerCoordinator.swift` (350 Zeilen)
5. ✅ `GymTracker/Protocols/RestTimerOverlayProtocol.swift` (30 Zeilen)
6. ⚠️ `GymTracker/NotificationManager.swift` (behalten für andere Notifications)
7. ⚠️ `GymTracker/Managers/InAppOverlayManager.swift` (optional: behalten für zusätzliche UI)
8. ⚠️ `GymTracker/Views/Overlays/RestTimerExpiredOverlay.swift` (optional: behalten)

**Gesamt:** ~1.600 Zeilen Code entfernt!

#### Zu modifizierende Dateien:

1. `GymTracker/ViewModels/WorkoutStore.swift`
   - `restTimerStateManager` → `restAlarmService` ersetzen
   - Alle Timer-Methoden anpassen

2. `GymTracker/LiveActivities/WorkoutLiveActivityController.swift`
   - Timer-Update-Logik entfernen
   - Throttling entfernen
   - Nur Workout-Tracking behalten

3. `WorkoutWidgets/WorkoutWidgetsLiveActivity.swift`
   - Neue `AlarmAttributes<RestTimerMetadata>` Configuration hinzufügen

4. `GymTracker/ContentView.swift`
   - Deep-Link Handling anpassen (falls nötig)

5. Alle UI-Views mit Timer-Referenzen:
   - `ActiveWorkoutSetCard.swift`
   - `ActiveWorkoutExerciseView.swift`
   - `WorkoutDetailView.swift`
   - `ActiveWorkoutNavigationView.swift`

#### Tests entfernen/anpassen:

1. ❌ `GymTrackerTests/TimerEngineTests.swift` (entfernen)
2. ❌ `GymTrackerTests/RestTimerStateTests.swift` (entfernen)
3. ❌ `GymTrackerTests/RestTimerStateManagerTests.swift` (entfernen)
4. ❌ `GymTrackerTests/RestTimerPersistenceTests.swift` (entfernen)

**Dauer:** 1 Tag

---

### Phase 7: Neue Tests schreiben

**Ziel:** AlarmKit-Integration testen

**Neue Test-Dateien:**

1. `GymTrackerTests/RestAlarmServiceTests.swift`
   ```swift
   @MainActor
   final class RestAlarmServiceTests: XCTestCase {
       var service: RestAlarmService!
       
       override func setUp() async throws {
           service = RestAlarmService()
       }
       
       func testStartTimer() async throws {
           try await service.startTimer(
               workoutId: UUID(),
               workoutName: "Test",
               exerciseName: "Squat",
               nextExerciseName: "Bench",
               exerciseIndex: 0,
               setIndex: 0,
               duration: 90
           )
           
           XCTAssertNotNil(service.currentAlarm)
       }
       
       func testPauseResume() async throws {
           // ... Test Pause/Resume Logik
       }
       
       func testCancel() async throws {
           // ... Test Cancel Logik
       }
   }
   ```

2. `GymTrackerTests/RestAlarmIntegrationTests.swift`
   - End-to-End Tests mit WorkoutStore
   - UI-Integration Tests

**Herausforderung:** AlarmKit lässt sich evtl. schwer mocken → ggf. Protocol-Wrapper nötig

**Dauer:** 1-2 Tage

---

### Phase 8: Settings & User Preferences

**Ziel:** Benutzereinstellungen für AlarmKit anpassen

**Zu modifizierende Datei:** `GymTracker/Views/Settings/NotificationSettingsView.swift`

**Änderungen:**

1. **AlarmKit-Autorisierung anzeigen:**
   ```swift
   Section {
       HStack {
           Text("AlarmKit Berechtigung")
           Spacer()
           if AlarmManager.shared.authorizationState == .authorized {
               Image(systemName: "checkmark.circle.fill")
                   .foregroundColor(.green)
           } else {
               Button("Erlauben") {
                   Task {
                       try? await AlarmManager.shared.requestAuthorization()
                   }
               }
           }
       }
   } header: {
       Text("Timer-Berechtigungen")
   } footer: {
       Text("AlarmKit ermöglicht Timer, die selbst im Silent Mode und Focus alarmieren.")
   }
   ```

2. **Alte Notification-Settings entfernen:**
   - `enablePushNotifications` (nicht mehr relevant für AlarmKit)
   - `showInAppOverlay` (optional behalten)

**Dauer:** 0.5 Tage

---

## Detaillierte Implementierung

### A. AlarmKit Authorization Flow

**In `GymBoApp.swift`:**

```swift
@main
struct GymBoApp: App {
    @StateObject private var workoutStore = WorkoutStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutStore)
                .task {
                    await requestAlarmKitPermission()
                }
        }
    }
    
    private func requestAlarmKitPermission() async {
        let manager = AlarmManager.shared
        
        guard manager.authorizationState == .notDetermined else {
            return
        }
        
        do {
            let state = try await manager.requestAuthorization()
            AppLogger.workouts.info("AlarmKit authorization: \(state)")
        } catch {
            AppLogger.workouts.error("AlarmKit auth error: \(error)")
        }
    }
}
```

---

### B. Herzfrequenz-Integration

**Problem:** AlarmKit kennt keine Herzfrequenz → separates Tracking nötig

**Lösung:**

```swift
@MainActor
final class RestAlarmService: ObservableObject {
    @Published var currentHeartRate: Int?
    
    func updateHeartRate(_ heartRate: Int) {
        currentHeartRate = heartRate
        // Kein Update an AlarmKit nötig
        // Live Activity zeigt HR separat an
    }
}
```

**In Live Activity:**

```swift
struct TimerActivityView: View {
    let context: ActivityViewContext<AlarmAttributes<RestTimerMetadata>>
    @ObservedObject var service: RestAlarmService
    
    var body: some View {
        VStack {
            // Timer (von AlarmKit)
            if case let .countdown(countdown) = context.state.mode {
                Text(timerInterval: Date.now ... countdown.fireDate)
            }
            
            // Herzfrequenz (von RestAlarmService)
            if let hr = service.currentHeartRate {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("\(hr) BPM")
                }
            }
        }
    }
}
```

**Alternative:** ActivityAttributes erweitern (komplexer)

---

### C. Migration von UserDefaults-State

**Problem:** Alte Timer-States in UserDefaults können nach Migration zu Fehlern führen

**Lösung:** Cleanup-Code bei App-Start

```swift
// In WorkoutStore.init()
private func cleanupLegacyTimerState() {
    // Entferne alte UserDefaults-Keys
    UserDefaults.standard.removeObject(forKey: "restTimerState_v2")
    
    AppLogger.data.info("Legacy timer state cleaned up")
}
```

---

## Zu entfernende Dateien

### Services
- ❌ `GymTracker/Services/TimerEngine.swift` (370 Zeilen)

### Models
- ❌ `GymTracker/Models/RestTimerState.swift` (280 Zeilen)

### ViewModels
- ❌ `GymTracker/ViewModels/RestTimerStateManager.swift` (570 Zeilen)

### Coordinators
- ❌ `GymTracker/Coordinators/RestTimerCoordinator.swift` (350 Zeilen)

### Protocols
- ❌ `GymTracker/Protocols/RestTimerOverlayProtocol.swift` (30 Zeilen)

### Tests
- ❌ `GymTrackerTests/TimerEngineTests.swift`
- ❌ `GymTrackerTests/RestTimerStateTests.swift`
- ❌ `GymTrackerTests/RestTimerStateManagerTests.swift`
- ❌ `GymTrackerTests/RestTimerPersistenceTests.swift`

**Gesamt entfernt:** ~1.600 Zeilen Code + Tests

---

## Zu modifizierende Dateien

### Core Files
1. ✏️ `GymTracker/ViewModels/WorkoutStore.swift`
   - `restTimerStateManager` → `restAlarmService` ersetzen
   - Alle Timer-Methoden async machen

2. ✏️ `GymTracker/LiveActivities/WorkoutLiveActivityController.swift`
   - Timer-Update-Logik entfernen (~400 Zeilen weniger)
   - Throttling entfernen
   - Nur Workout-State behalten

3. ✏️ `WorkoutWidgets/WorkoutWidgetsLiveActivity.swift`
   - Neue `AlarmAttributes<RestTimerMetadata>` Configuration hinzufügen

4. ✏️ `GymTracker/NotificationManager.swift`
   - Rest-Timer Notifications entfernen
   - Andere Notifications behalten

### UI Files
5. ✏️ `GymTracker/Views/Components/ActiveWorkoutSetCard.swift`
   - Timer-Display auf AlarmKit umstellen
   - `Text(timerInterval:)` nutzen

6. ✏️ `GymTracker/Views/WorkoutDetailView.swift`
   - `startRest()` auf async umstellen
   - Error-Handling hinzufügen

7. ✏️ `GymTracker/Views/Components/ActiveWorkoutExerciseView.swift`
   - Timer-State-Abfragen anpassen

8. ✏️ `GymTracker/Views/Components/ActiveWorkoutNavigationView.swift`
   - Timer-Display anpassen

9. ✏️ `GymTracker/ContentView.swift`
   - Deep-Link Handling für AlarmKit anpassen (falls nötig)

### Settings
10. ✏️ `GymTracker/Views/Settings/NotificationSettingsView.swift`
    - AlarmKit-Berechtigung anzeigen
    - Alte Settings entfernen

11. ✏️ `GymTracker/Views/Settings/DebugMenuView.swift`
    - AlarmKit-Debug-Infos hinzufügen

### Configuration
12. ✏️ `Info.plist`
    - `NSAlarmKitUsageDescription` hinzufügen

13. ✏️ `GymBo.xcodeproj/project.pbxproj`
    - Deployment Target → iOS 26.0

---

## Neue Dateien

### Models
1. ➕ `GymTracker/Models/RestTimerMetadata.swift`
   ```swift
   import AlarmKit
   
   struct RestTimerMetadata: AlarmMetadata {
       var workoutId: UUID
       var workoutName: String
       var exerciseName: String?
       var nextExerciseName: String?
       var exerciseIndex: Int
       var setIndex: Int
   }
   ```

### Services
2. ➕ `GymTracker/Services/RestAlarmService.swift`
   - AlarmKit-Integration
   - Timer-Lifecycle-Management
   - Alarm-Updates beobachten
   - ~200 Zeilen (statt 570 in RestTimerStateManager)

### Tests
3. ➕ `GymTrackerTests/RestAlarmServiceTests.swift`
   - Unit Tests für RestAlarmService

4. ➕ `GymTrackerTests/RestAlarmIntegrationTests.swift`
   - Integration Tests

**Gesamt neu:** ~300-400 Zeilen

---

## Testing-Strategie

### Unit Tests

**Neue Tests:**
- ✅ `RestAlarmServiceTests`
  - `testStartTimer()`
  - `testPauseTimer()`
  - `testResumeTimer()`
  - `testCancelTimer()`
  - `testAlarmUpdatesObservation()`

**Herausforderung:** AlarmKit mocken
- **Option A:** Protocol-Wrapper um `AlarmManager`
- **Option B:** Integration Tests statt Unit Tests
- **Option C:** Test-Doubles mit Dependency Injection

### Integration Tests

**End-to-End Szenarien:**
1. ✅ Timer starten → Läuft → Abgelaufen → Alert anzeigen
2. ✅ Timer starten → Pausieren → Fortsetzen → Abgelaufen
3. ✅ Timer starten → Abbrechen → Kein Alert
4. ✅ App beenden → App starten → Timer läuft weiter
5. ✅ Herzfrequenz-Update während Timer läuft

### Manual Testing Checklist

- [ ] AlarmKit-Berechtigung anfordern
- [ ] Timer starten (90s)
- [ ] Live Activity erscheint auf Lock Screen
- [ ] Dynamic Island zeigt Timer
- [ ] Timer pausieren → Fortsetzung funktioniert
- [ ] Timer abbrechen → Verschwindet korrekt
- [ ] App in Background → Timer läuft weiter
- [ ] App Force-Quit → Timer läuft nach Neustart weiter
- [ ] Silent Mode → Timer alarmiert trotzdem
- [ ] Focus Mode → Timer durchdringt Focus
- [ ] Herzfrequenz-Update → Live Activity zeigt HR
- [ ] Timer abgelaufen → Alert erscheint (Vollbild)
- [ ] Alert dismissen → Timer verschwindet

### Performance Testing

- [ ] Memory Leaks prüfen (Instruments)
- [ ] Battery Impact testen (Background Timer)
- [ ] Live Activity Update-Frequenz prüfen

---

## Rollback-Plan

### Falls AlarmKit Probleme macht

**Plan B: Feature-Flag für iOS 26+**

```swift
var useAlarmKit: Bool {
    if #available(iOS 26, *) {
        return true
    } else {
        return false
    }
}
```

**Legacy-Timer beibehalten für iOS < 26:**
- Alte Implementierung **nicht** löschen
- Conditional Compilation verwenden
- Zwei Code-Pfade parallel

**Code-Beispiel:**

```swift
func startRest(...) {
    if #available(iOS 26, *) {
        Task {
            try await restAlarmService.startTimer(...)
        }
    } else {
        // Legacy implementation
        restTimerStateManager.startRest(...)
    }
}
```

**Vorteil:** Graduelle Migration, kein Breaking Change  
**Nachteil:** Code-Komplexität verdoppelt sich temporär

---

### Falls iOS 26 Requirement zu früh

**Alternative:** Migration auf **iOS 27** verschieben

- Mehr Zeit für Community-Feedback
- Mehr Dokumentation & Tutorials verfügbar
- Bessere Stabilität von AlarmKit
- Höhere iOS 26 Adoption bei Nutzern

---

## Timeline & Phasen

### Optimistisches Szenario (10-12 Tage)

| Phase | Dauer | Beschreibung |
|-------|-------|--------------|
| 0. Vorbereitung | 1-2 Tage | Entscheidung, PoC, WWDC Video |
| 1. Berechtigungen | 0.5 Tage | Info.plist, Deployment Target |
| 2. Datenmodell | 0.5 Tage | `RestTimerMetadata` erstellen |
| 3. Alarm Service | 1 Tag | `RestAlarmService` implementieren |
| 4. Live Activity | 1-2 Tage | Widget anpassen |
| 5. UI Integration | 2 Tage | Alle Views umstellen |
| 6. Cleanup | 1 Tag | Alte Files entfernen |
| 7. Tests | 1-2 Tage | Neue Tests schreiben |
| 8. Settings | 0.5 Tage | Settings anpassen |
| 9. QA & Testing | 1 Tag | Manual Testing |

**Gesamt:** 10-12 Arbeitstage

---

### Realistisches Szenario (15-20 Tage)

| Phase | Dauer | Beschreibung |
|-------|-------|--------------|
| 0. Vorbereitung | 2-3 Tage | PoC, Learning Curve |
| 1-3. Setup | 2 Tage | Berechtigungen, Models, Service |
| 4. Live Activity | 2-3 Tage | Komplexe Integration |
| 5. UI Integration | 3-4 Tage | Viele Files, Edge Cases |
| 6-7. Cleanup & Tests | 3-4 Tage | Gründliches Testing |
| 8-9. Settings & QA | 2-3 Tage | Polish, Bug Fixes |
| 10. Buffer | 1-2 Tage | Unvorhergesehene Probleme |

**Gesamt:** 15-20 Arbeitstage

---

## Risiken & Mitigations

### Risiko 1: iOS 26 Requirement zu hoch

**Wahrscheinlichkeit:** Hoch  
**Impact:** Kritisch  
**Mitigation:**
- Feature-Flag für iOS 26+ nutzen
- Legacy-Timer für iOS < 26 beibehalten
- Migration auf iOS 27 verschieben

### Risiko 2: AlarmKit Bugs / Instabilität

**Wahrscheinlichkeit:** Mittel  
**Impact:** Hoch  
**Mitigation:**
- Gründliches Testing auf realen Geräten
- Beta-Phase mit kleiner Nutzergruppe
- Rollback-Plan vorbereiten

### Risiko 3: Herzfrequenz-Integration kompliziert

**Wahrscheinlichkeit:** Mittel  
**Impact:** Mittel  
**Mitigation:**
- Herzfrequenz als separates Feature behandeln
- Falls nötig: Temporär ohne HR in Live Activity

### Risiko 4: Live Activity Configuration fehlerhaft

**Wahrscheinlichkeit:** Mittel  
**Impact:** Hoch  
**Mitigation:**
- Proof-of-Concept vorab erstellen
- Apple Developer Forums konsultieren
- Fallback auf einfaches Layout

### Risiko 5: Testing schwierig (AlarmKit mocken)

**Wahrscheinlichkeit:** Hoch  
**Impact:** Mittel  
**Mitigation:**
- Protocol-Wrapper um AlarmManager
- Fokus auf Integration Tests
- Manuelle Testing Checkliste

---

## Zusammenfassung

### Aufwand

| Kategorie | Alt (Zeilen) | Neu (Zeilen) | Differenz |
|-----------|--------------|--------------|-----------|
| Models | 280 | 50 | **-230** |
| Services | 370 | 200 | **-170** |
| ViewModels | 570 | 0 | **-570** |
| Coordinators | 350 | 0 | **-350** |
| Live Activity | 600 | 200 | **-400** |
| Protocols | 30 | 0 | **-30** |
| **Gesamt** | **2.200** | **450** | **-1.750** |

**Code-Reduktion:** ~79% weniger Code! 🎉

### Vorteile der Migration

✅ **1.750 Zeilen weniger Code** → Wartbarkeit  
✅ **Keine manuelle Timer-Verwaltung** → Weniger Bugs  
✅ **System-Level Alarms** → Durchdringt Silent Mode/Focus  
✅ **Native Lock Screen Integration** → Bessere UX  
✅ **Eingebaute Pause/Resume** → Einfacher  
✅ **Automatisches Live Activity Management** → Weniger Komplexität  

### Nachteile / Herausforderungen

⚠️ **iOS 26+ Required** → Breaking Change  
⚠️ **Neue Berechtigungen** → Nutzer müssen zustimmen  
⚠️ **Lernkurve** → Neues Framework  
⚠️ **Wenig Community-Erfahrung** → Weniger Support  

---

## Empfehlung

### ✅ **Migration durchführen**, wenn:

1. Du bereit bist, iOS 26 als Mindestversion zu setzen
2. Du ca. 2-3 Wochen Entwicklungszeit hast
3. Du eine bessere, nativere UX möchtest
4. Du bereit bist, ~1.750 Zeilen Code zu löschen 😊

### ⏸️ **Migration verschieben**, wenn:

1. iOS 26 Adoption noch zu niedrig ist (prüfen!)
2. iOS 27 mehr Stabilität bietet
3. Mehr Community-Feedback gewünscht ist

### 🚫 **Nicht migrieren**, wenn:

1. iOS < 26 Support zwingend nötig ist
2. Keine Zeit für gründliches Testing
3. Aktuelle Lösung stabil funktioniert

---

## Nächste Schritte

1. ☑️ **Diesen Plan reviewen**
2. ☐ **Entscheidung treffen:** iOS 26 vs. warten vs. Feature-Flag
3. ☐ **WWDC 2025 Session anschauen:** "Wake up to the AlarmKit API"
4. ☐ **Proof-of-Concept:** Einfacher Test-Timer mit AlarmKit
5. ☐ **Timeline finalisieren**
6. ☐ **Mit Phase 0 starten**

---

**Erstellt:** 2025-10-19  
**Autor:** Claude (AI Assistant)  
**Version:** 1.0  
**Status:** Draft / Zur Review
