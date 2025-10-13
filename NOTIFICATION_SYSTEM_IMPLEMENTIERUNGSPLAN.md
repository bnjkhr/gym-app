# Implementierungsplan: Robustes Notification-System für Rest-Timer

**Version**: 1.0  
**Datum**: 2025-10-13  
**Basierend auf**: NOTIFICATION_SYSTEM_KONZEPT.md  
**Geschätzter Aufwand**: 8-12 Arbeitstage  

---

## Inhaltsverzeichnis

1. [Executive Summary](#1-executive-summary)
2. [Phasenübersicht](#2-phasenübersicht)
3. [Phase 1: Foundation](#3-phase-1-foundation-2-3-tage)
4. [Phase 2: UI Components](#4-phase-2-ui-components-1-2-tage)
5. [Phase 3: Live Activity](#5-phase-3-live-activity-1-2-tage)
6. [Phase 4: Notifications](#6-phase-4-notifications-1-tag)
7. [Phase 5: Integration & Testing](#7-phase-5-integration--testing-2-3-tage)
8. [Phase 6: Polish & Settings](#8-phase-6-polish--settings-1-tag)
9. [Migrations-Strategie](#9-migrations-strategie)
10. [Testing & Quality Assurance](#10-testing--quality-assurance)
11. [Rollout-Strategie](#11-rollout-strategie)
12. [Risiken & Mitigation](#12-risiken--mitigation)

---

## 1. Executive Summary

### Projektziel
Implementierung eines robusten, zuverlässigen Notification-Systems für Rest-Timer, das alle aktuellen Bugs behebt und eine konsistente User Experience über alle App-States hinweg bietet.

### Hauptprobleme die gelöst werden
- ❌ Inkonsistente Zustände nach Force Quit
- ❌ Race Conditions zwischen Notification-Mechanismen
- ❌ Fehlende zentrale State-Verwaltung
- ❌ Unzuverlässige Timer-Synchronisation
- ❌ Kein In-App Overlay bei Timer-Ablauf

### Neue Features
- ✅ In-App Overlay bei Timer-Ablauf (wenn App aktiv)
- ✅ Extended Dynamic Island Alert (iPhone 14 Pro+)
- ✅ Robuste State-Persistierung mit Force-Quit-Recovery
- ✅ Single Source of Truth für Timer-State
- ✅ Smart Notification Logic (basierend auf App-State)
- ✅ Live Activity mit erweiterter Anzeige:
  - Herzfrequenz (aus HealthKit)
  - Aktuelle Übung
  - Nächste Übung (Vorschau)
  - Rest-Timer Countdown

### Architektur-Prinzipien
1. **Single Source of Truth**: Alle Timer-States in `RestTimerStateManager`
2. **Separation of Concerns**: Jede Komponente hat klare Verantwortlichkeit
3. **Testability**: Alle Komponenten isoliert testbar
4. **Robustness**: Graceful Degradation, keine Silent Failures

---

## 2. Phasenübersicht

| Phase | Beschreibung | Dauer | Abhängigkeiten |
|-------|-------------|-------|----------------|
| **Phase 1** | Foundation (Core State Management) | 2-3 Tage | - |
| **Phase 2** | UI Components (In-App Overlay) | 1-2 Tage | Phase 1 |
| **Phase 3** | Live Activity Integration | 1-2 Tage | Phase 1 |
| **Phase 4** | Notification Manager | 1 Tag | Phase 1 |
| **Phase 5** | Integration & Testing | 2-3 Tage | Phase 1-4 |
| **Phase 6** | Polish & Settings | 1 Tag | Phase 5 |

**Gesamt**: 8-12 Arbeitstage

---

## 3. Phase 1: Foundation (2-3 Tage)

### Ziel
Implementierung der Core-Komponenten für State-Management und Timer-Engine.

### 3.1 RestTimerState Model erstellen

**Datei**: `GymTracker/Models/RestTimerState.swift` (NEU)

**Tasks**:
- [ ] Struct `RestTimerState` mit allen Properties erstellen
- [ ] `Phase` Enum implementieren (running, paused, expired, completed)
- [ ] Computed Properties implementieren (`remainingSeconds`, `isActive`, `hasExpired`)
- [ ] `Codable` Conformance für Persistierung
- [ ] `Equatable` Conformance für State-Vergleiche
- [ ] Unit Tests schreiben

**Akzeptanzkriterien**:
- ✅ Model ist vollständig codable (JSON serialization funktioniert)
- ✅ Alle computed properties funktionieren korrekt
- ✅ Unit Tests decken alle Edge Cases ab (expired timer, negative time, etc.)

**Code-Struktur**:
```swift
struct RestTimerState: Codable, Equatable {
    let id: UUID
    let workoutId: UUID
    let workoutName: String
    let exerciseIndex: Int
    let setIndex: Int
    let startDate: Date
    let endDate: Date
    var totalSeconds: Int
    var phase: Phase
    var lastUpdateDate: Date
    
    // Live Activity Display Data (NEU)
    var currentExerciseName: String?
    var nextExerciseName: String?
    var currentHeartRate: Int?
    
    enum Phase: String, Codable { ... }
    
    var remainingSeconds: Int { ... }
    var isActive: Bool { ... }
    var hasExpired: Bool { ... }
}
```

**Geschätzter Aufwand**: 4 Stunden

---

### 3.2 TimerEngine refactoren

**Datei**: `GymTracker/Services/TimerEngine.swift` (NEU)

**Tasks**:
- [ ] Neue Klasse `TimerEngine` erstellen
- [ ] Wall-clock-based Timer implementieren (nicht relative Zeit)
- [ ] `startTimer(until:onExpire:)` Methode
- [ ] `stopTimer()` Methode
- [ ] `checkExpiration()` mit präziser Zeit-Berechnung
- [ ] Background Execution Support
- [ ] Unit Tests

**Akzeptanzkriterien**:
- ✅ Timer funktioniert präzise auch nach App-Restart
- ✅ Timer läuft im Hintergrund weiter (iOS-Limitierungen beachten)
- ✅ Expiration-Callback wird zuverlässig aufgerufen
- ✅ Kein Memory Leak bei Stop/Start-Zyklen

**Code-Struktur**:
```swift
class TimerEngine {
    private var timer: Timer?
    private var endDate: Date?
    private var expirationHandler: (() -> Void)?
    
    func startTimer(until endDate: Date, onExpire: @escaping () -> Void)
    func stopTimer()
    private func checkExpiration()
}
```

**Geschätzter Aufwand**: 3 Stunden

---

### 3.3 RestTimerStateManager implementieren

**Datei**: `GymTracker/ViewModels/RestTimerStateManager.swift` (NEU)

**Tasks**:
- [ ] ObservableObject-Klasse erstellen
- [ ] `@Published var currentState: RestTimerState?`
- [ ] Public API implementieren:
  - [ ] `startRest(for:exercise:set:duration:currentExerciseName:nextExerciseName:)`
  - [ ] `updateHeartRate(_:)` - HealthKit Integration
  - [ ] `pauseRest()`
  - [ ] `resumeRest()`
  - [ ] `acknowledgeExpired()`
  - [ ] `cancelRest()`
- [ ] Private State Management:
  - [ ] `applyStateChange(_:)` - Transaktionale State-Updates
  - [ ] `notifySubsystems(oldState:newState:)` - Observer-Pattern
  - [ ] `handleTimerExpired()` - Expiration-Logic
- [ ] Persistierung implementieren:
  - [ ] `persistState(_:)` - JSON zu UserDefaults
  - [ ] `restoreState()` - Restore mit Validation
  - [ ] `clearState()` - Cleanup
- [ ] Validation & Error Handling
- [ ] Integration mit TimerEngine
- [ ] Logging & Debugging-Support
- [ ] Unit Tests

**Akzeptanzkriterien**:
- ✅ Alle State-Transitions funktionieren korrekt
- ✅ State wird sofort und transaktional persistiert
- ✅ State-Restoration nach Force Quit funktioniert (inkl. abgelaufene Timer)
- ✅ Alte States (> 24h) werden automatisch verworfen
- ✅ Keine Race Conditions bei schnellen State-Changes

**Code-Struktur**:
```swift
@MainActor
class RestTimerStateManager: ObservableObject {
    @Published private(set) var currentState: RestTimerState?
    
    private let storage: UserDefaults
    private let timerEngine: TimerEngine
    
    // Public API
    func startRest(...)
    func pauseRest()
    func resumeRest()
    func acknowledgeExpired()
    func cancelRest()
    
    // State Management
    private func applyStateChange(_:)
    private func notifySubsystems(oldState:newState:)
    private func handleTimerExpired()
    
    // Persistence
    private func persistState(_:)
    func restoreState()
    private func clearState()
}
```

**Geschätzter Aufwand**: 8 Stunden

---

### 3.4 Persistenz-Layer testen

**Tasks**:
- [ ] Tests für JSON Serialization/Deserialization
- [ ] Tests für State-Restoration nach verschiedenen Delays
- [ ] Tests für korrupte Daten-Handling
- [ ] Tests für alte State-Verwerfung (> 24h)
- [ ] Tests für Force-Quit-Simulation

**Akzeptanzkriterien**:
- ✅ 100% Test-Coverage für Persistenz-Logic
- ✅ Alle Edge Cases abgedeckt
- ✅ Performance-Tests (Persistierung < 10ms)

**Geschätzter Aufwand**: 3 Stunden

---

### Phase 1 Deliverables
- ✅ `RestTimerState.swift` mit Unit Tests
- ✅ `TimerEngine.swift` mit Unit Tests
- ✅ `RestTimerStateManager.swift` mit Unit Tests
- ✅ Persistenz vollständig getestet
- ✅ Force-Quit-Recovery funktioniert

**Phase 1 Gesamt**: 18-20 Stunden (2-3 Tage)

---

## 4. Phase 2: UI Components (1-2 Tage)

### Ziel
In-App Overlay für Timer-Ablauf implementieren.

### 4.1 InAppOverlayManager erstellen

**Datei**: `GymTracker/Managers/InAppOverlayManager.swift` (NEU)

**Tasks**:
- [ ] ObservableObject-Klasse erstellen
- [ ] `@Published var isShowingOverlay: Bool`
- [ ] `@Published var currentState: RestTimerState?`
- [ ] `showExpiredOverlay(for:)` Methode
- [ ] `dismissOverlay()` Methode
- [ ] Haptic Feedback Integration
- [ ] Sound Playback Integration (BoxBell)
- [ ] Auto-Dismiss Timer (optional, mit Timeout)

**Akzeptanzkriterien**:
- ✅ Overlay wird nur bei App-State = .active angezeigt
- ✅ Haptic Feedback triggert korrekt
- ✅ Sound spielt ab (wenn enabled)
- ✅ Overlay kann programmatisch geschlossen werden

**Code-Struktur**:
```swift
@MainActor
class InAppOverlayManager: ObservableObject {
    @Published var isShowingOverlay = false
    @Published var currentState: RestTimerState?
    
    func showExpiredOverlay(for state: RestTimerState)
    func dismissOverlay()
}
```

**Geschätzter Aufwand**: 2 Stunden

---

### 4.2 RestTimerExpiredOverlay View

**Datei**: `GymTracker/Views/Overlays/RestTimerExpiredOverlay.swift` (NEU)

**Tasks**:
- [ ] SwiftUI View erstellen
- [ ] Glassmorphism Design (konsistent mit App-Theme)
- [ ] Komponenten implementieren:
  - [ ] Großes Checkmark-Icon (SF Symbol)
  - [ ] "Pause beendet!" Headline
  - [ ] "Weiter geht's mit:" Subheadline
  - [ ] Übungsname (dynamisch)
  - [ ] "Weiter" Button (Primary CTA)
  - [ ] Optional: "Skip" Button für nächste Übung
- [ ] Animationen:
  - [ ] Fade-In Animation
  - [ ] Icon Scale Animation
  - [ ] Button Pulse (subtil)
- [ ] Accessibility:
  - [ ] VoiceOver Labels
  - [ ] Dynamic Type Support
  - [ ] Haptic Feedback Feedback

**Akzeptanzkriterien**:
- ✅ Design passt zum Rest der App (Glassmorphism)
- ✅ Alle Texte sind dynamisch (aus RestTimerState)
- ✅ Animationen sind smooth (60 FPS)
- ✅ Accessibility Score: 100% (VoiceOver, Dynamic Type)
- ✅ Funktioniert auf allen iOS-Device-Größen

**Design-Spezifikationen**:
```
Overlay:
- Background: Color.black.opacity(0.6) + blur
- Card: AppTheme glassmorphism card
- Padding: 32pt
- Corner Radius: 24pt
- Shadow: radius 20pt

Icon:
- System: checkmark.circle.fill
- Size: 80pt
- Color: .green

Title:
- Font: .system(size: 32, weight: .bold)
- Color: .primary

Subtitle:
- Font: .headline
- Color: .secondary

Exercise Name:
- Font: .system(size: 24, weight: .semibold)
- Color: .primary

Button:
- Height: 56pt
- Corner Radius: 12pt
- Background: .blue
- Text: .white, .headline
```

**Geschätzter Aufwand**: 4 Stunden

---

### 4.3 Integration in ContentView

**Datei**: `GymTracker/ContentView.swift` (ÄNDERN)

**Tasks**:
- [ ] `@StateObject var overlayManager = InAppOverlayManager()`
- [ ] `.overlay()` Modifier mit `RestTimerExpiredOverlay`
- [ ] `onChange(of: overlayManager.isShowingOverlay)` für Analytics
- [ ] Übergabe des Managers an `RestTimerStateManager`

**Code-Änderungen**:
```swift
struct ContentView: View {
    @StateObject private var overlayManager = InAppOverlayManager()
    
    var body: some View {
        TabView {
            // ... existing tabs
        }
        .overlay {
            if overlayManager.isShowingOverlay {
                RestTimerExpiredOverlay(
                    state: overlayManager.currentState!,
                    onDismiss: {
                        overlayManager.dismissOverlay()
                        // Trigger acknowledgeExpired()
                    }
                )
            }
        }
    }
}
```

**Geschätzter Aufwand**: 1 Stunde

---

### 4.4 Haptic Feedback abstrahieren

**Datei**: `GymTracker/Services/HapticManager.swift` (NEU)

**Tasks**:
- [ ] Utility-Klasse für Haptic Feedback erstellen
- [ ] Verschiedene Feedback-Typen:
  - [ ] `success()` - für Timer-Ablauf
  - [ ] `warning()` - für Pause/Skip
  - [ ] `error()` - für Fehler
  - [ ] `light()` - für UI-Interaktionen
- [ ] User-Präferenz-Support (Haptic on/off)

**Code-Struktur**:
```swift
class HapticManager {
    static let shared = HapticManager()
    
    @AppStorage("hapticsEnabled") private var enabled = true
    
    func success()
    func warning()
    func error()
    func light()
}
```

**Geschätzter Aufwand**: 1 Stunde

---

### Phase 2 Deliverables
- ✅ `InAppOverlayManager.swift`
- ✅ `RestTimerExpiredOverlay.swift` mit Animationen
- ✅ `HapticManager.swift`
- ✅ Integration in ContentView
- ✅ UI Tests für Overlay

**Phase 2 Gesamt**: 8-10 Stunden (1-2 Tage)

---

## 5. Phase 3: Live Activity (1-2 Tage)

### Ziel
Live Activity Manager refactoren und Extended Dynamic Island Alert implementieren.

### 5.1 LiveActivityManager refactoren

**Datei**: `GymTracker/LiveActivities/WorkoutLiveActivityController.swift` (ÄNDERN)

**Tasks**:
- [ ] `updateForState(_:)` Methode implementieren
  - [ ] Switch über `RestTimerState.Phase`
  - [ ] State-basierte Updates statt direkte Parameter
  - [ ] **NEU**: Übertrage currentExerciseName, nextExerciseName, currentHeartRate
- [ ] Activity-Instanz-Wiederherstellung verbessern
  - [ ] Stale Activity Detection (> 24h)
  - [ ] Orphaned Activity Cleanup
- [ ] Throttling optimieren
  - [ ] Nur bei tatsächlichen State-Changes updaten
  - [ ] Debouncing für schnelle Aufrufe
- [ ] Error Handling verbessern
  - [ ] Graceful Degradation bei Permissions
  - [ ] Logging für alle Activity-Events
- [ ] **NEU**: HealthKit Integration für Herzfrequenz-Updates
  - [ ] Callback-Mechanismus für HR-Updates
  - [ ] Throttling auf max 1 Update/5 Sekunden

**Code-Änderungen**:
```swift
extension WorkoutLiveActivityController {
    func updateForState(_ state: RestTimerState?) {
        guard let state = state else {
            endActivity()
            return
        }
        
        switch state.phase {
        case .running:
            updateRestTimer(
                workoutId: state.workoutId,
                workoutName: state.workoutName,
                currentExerciseName: state.currentExerciseName,
                nextExerciseName: state.nextExerciseName,
                currentHeartRate: state.currentHeartRate,
                remainingSeconds: state.remainingSeconds,
                totalSeconds: state.totalSeconds,
                endDate: state.endDate
            )
        case .paused:
            updateRestTimer(/* mit endDate = nil */)
        case .expired:
            showExpirationAlert(for: state)
        case .completed:
            showWorkoutRunning(
                workoutId: state.workoutId,
                workoutName: state.workoutName,
                currentExerciseName: state.currentExerciseName,
                nextExerciseName: state.nextExerciseName,
                currentHeartRate: state.currentHeartRate
            )
        }
    }
}
```

**Akzeptanzkriterien**:
- ✅ Live Activity reflektiert immer aktuellen State
- ✅ Keine unnötigen Updates (Performance)
- ✅ Activity überlebt Force Quit
- ✅ Alte Activities werden automatisch aufgeräumt
- ✅ **NEU**: Herzfrequenz wird angezeigt und aktualisiert (wenn HealthKit verfügbar)
- ✅ **NEU**: Aktuelle und nächste Übung werden korrekt angezeigt
- ✅ **NEU**: Graceful Degradation wenn HR nicht verfügbar (zeige "-- BPM")

**Geschätzter Aufwand**: 5 Stunden (+ 1h für HR-Integration)

---

### 5.2 Extended Dynamic Island Alert

**Datei**: `GymTracker/LiveActivities/WorkoutLiveActivityController.swift` (ÄNDERN)

**Tasks**:
- [ ] `showExpirationAlert(for:)` Methode implementieren
- [ ] AlertConfiguration mit passendem Sound
- [ ] ContentState für "Pause beendet"
- [ ] Animated Icon in Dynamic Island
- [ ] Auto-Collapse nach 5 Sekunden

**Code-Struktur**:
```swift
func showExpirationAlert(for state: RestTimerState) {
    let alertState = WorkoutActivityAttributes.ContentState(
        remainingSeconds: 0,
        totalSeconds: 1,
        title: "Pause beendet",
        exerciseName: nil,
        isTimerExpired: true,
        currentHeartRate: nil,
        timerEndDate: nil
    )
    
    Task {
        await updateStateWithAlert(
            state: alertState,
            alert: AlertConfiguration(
                title: "Weiter geht's! 💪",
                body: "Die Pause ist vorbei",
                sound: .default
            )
        )
    }
}
```

**Akzeptanzkriterien**:
- ✅ Dynamic Island expandiert automatisch
- ✅ Haptic Feedback triggert
- ✅ Sound spielt (wenn enabled)
- ✅ Alert ist visuell ansprechend
- ✅ Funktioniert nur auf iPhone 14 Pro/15 Pro (Graceful Degradation auf älteren Geräten)

**Geschätzter Aufwand**: 3 Stunden

---

### 5.3 Live Activity Testing

**Tasks**:
- [ ] Tests auf echtem iPhone 14 Pro/15 Pro
- [ ] Force Quit während Rest Timer
- [ ] Background-Verhalten
- [ ] Alert-Timing (genau bei Ablauf)
- [ ] Interaction mit Overlay (keine Überlappung)

**Test-Cases**:
1. Happy Path: Timer läuft → Alert erscheint → User acknowledges
2. Force Quit: Timer läuft → Force Quit → Timer läuft weiter → Alert erscheint
3. Background: App in Background → Alert erscheint → User tappt → App öffnet
4. No Permissions: Live Activity disabled → graceful fallback zu Push

**Geschätzter Aufwand**: 2 Stunden

---

### Phase 3 Deliverables
- ✅ Refactored `WorkoutLiveActivityController.swift`
- ✅ Extended Dynamic Island Alert funktioniert
- ✅ Force Quit Recovery für Live Activities
- ✅ Tests auf Physical Device
- ✅ **NEU**: HealthKit Herzfrequenz-Integration
- ✅ **NEU**: Übungsname-Anzeige (aktuell + nächste)

**Phase 3 Gesamt**: 10 Stunden (1-2 Tage, +1h für neue Features)

---

## 6. Phase 4: Notifications (1 Tag)

### Ziel
NotificationManager aufräumen und Smart Notification Logic implementieren.

### 6.1 NotificationManager refactoren

**Datei**: `GymTracker/Managers/NotificationManager.swift` (ÄNDERN)

**Tasks**:
- [ ] Bestehenden Code aufräumen und vereinfachen
- [ ] `scheduleNotification(for:)` mit RestTimerState
- [ ] `cancelNotifications()` Methode
- [ ] Smart Notification Logic:
  - [ ] Nur Push wenn App inaktiv/background
  - [ ] Keine Push wenn App aktiv (Overlay übernimmt)
- [ ] Deep Link Handling:
  - [ ] URL Scheme: `gymtracker://workout/active`
  - [ ] Navigation zum aktiven Workout
- [ ] Notification History (lokal speichern)
- [ ] User Preferences (Sound, Badge, Alert)

**Code-Struktur**:
```swift
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    func scheduleNotification(for state: RestTimerState)
    func cancelNotifications()
    func handleNotificationResponse(_ response: UNNotificationResponse)
    
    private func shouldSendPush() -> Bool {
        // Smart logic basierend auf App-State
    }
}
```

**Akzeptanzkriterien**:
- ✅ Push Notifications nur wenn sinnvoll (nicht bei aktivem App)
- ✅ Deep Links funktionieren zuverlässig
- ✅ Permissions werden korrekt gehandhabt
- ✅ Notification History ist abrufbar (Debug)

**Geschätzter Aufwand**: 3 Stunden

---

### 6.2 Deep Link Integration

**Datei**: `GymTracker/GymTrackerApp.swift` (ÄNDERN)

**Tasks**:
- [ ] `.onOpenURL()` Handler in App hinzufügen
- [ ] URL Parsing für `gymtracker://` Scheme
- [ ] Navigation zum aktiven Workout
- [ ] Tab-Switch wenn nötig

**Code-Änderungen**:
```swift
@main
struct GymTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        if url.host == "workout", url.path == "/active" {
            // Navigate to active workout
        }
    }
}
```

**Geschätzter Aufwand**: 2 Stunden

---

### 6.3 Notification Testing

**Tasks**:
- [ ] Test auf Physical Device (Push benötigt echtes Device)
- [ ] Verschiedene App-States testen
- [ ] Deep Link Navigation testen
- [ ] Permission-Denial-Fallback testen

**Test-Cases**:
1. App aktiv → kein Push, nur Overlay
2. App Background → Push + Deep Link funktioniert
3. App geschlossen → Push + Cold Start
4. Permissions denied → graceful degradation

**Geschätzter Aufwand**: 2 Stunden

---

### Phase 4 Deliverables
- ✅ Refactored `NotificationManager.swift`
- ✅ Deep Link Integration
- ✅ Smart Notification Logic
- ✅ Tests auf Physical Device

**Phase 4 Gesamt**: 7 Stunden (1 Tag)

---

## 7. Phase 5: Integration & Testing (2-3 Tage)

### Ziel
Alle Komponenten integrieren und End-to-End Tests durchführen.

### 7.1 WorkoutStore Integration

**Datei**: `GymTracker/ViewModels/WorkoutStore.swift` (ÄNDERN)

**Tasks**:
- [ ] `RestTimerStateManager` als Property hinzufügen
- [ ] Alte Rest-Timer-Logik entfernen:
  - [ ] `activeRestState` Property (deprecated)
  - [ ] `restEndDate` Property (deprecated)
  - [ ] Alte Timer-Logic (deprecated)
- [ ] Neue Methoden delegieren an `RestTimerStateManager`:
  - [ ] `startRest()` → `stateManager.startRest(...)` mit currentExerciseName, nextExerciseName
  - [ ] `pauseRest()` → `stateManager.pauseRest()`
  - [ ] `stopRest()` → `stateManager.cancelRest()`
- [ ] **NEU**: HealthKit Herzfrequenz-Integration
  - [ ] Observer für HR-Updates aus HealthKitWorkoutTracker
  - [ ] Callback zu `stateManager.updateHeartRate(_:)`
  - [ ] Throttling (max 1 Update/5 Sekunden)
- [ ] **NEU**: Übungsname-Extraktion
  - [ ] Helper-Methode um aktuelle/nächste Übung zu ermitteln
  - [ ] Übergabe an `startRest()` Call
- [ ] Migration von altem State (einmalig)
- [ ] Backward Compatibility sicherstellen
- [ ] Deprecation Warnings hinzufügen

**Code-Änderungen**:
```swift
class WorkoutStore: ObservableObject {
    // New
    let restTimerStateManager = RestTimerStateManager()
    
    // Deprecated
    @available(*, deprecated, message: "Use restTimerStateManager instead")
    @Published var activeRestState: ActiveRestState?
    
    func startRest(...) {
        restTimerStateManager.startRest(...)
    }
    
    // ... delegate all other methods
}
```

**Akzeptanzkriterien**:
- ✅ Alle Rest-Timer-Features funktionieren über neues System
- ✅ Keine Regression in bestehender Funktionalität
- ✅ Alter Code wird nicht mehr verwendet
- ✅ **NEU**: Herzfrequenz wird in Live Activity angezeigt
- ✅ **NEU**: Übungsnamen werden korrekt extrahiert und angezeigt

**Geschätzter Aufwand**: 5 Stunden (+ 1h für HR + Übungsname-Integration)

---

### 7.2 End-to-End Tests

**Datei**: `GymTrackerTests/NotificationSystemE2ETests.swift` (NEU)

**Tasks**:
- [ ] Test Suite erstellen
- [ ] Test Cases implementieren:

**Test 1: Happy Path**
```swift
func testHappyPath() async throws {
    // 1. Start workout
    // 2. Complete set
    // 3. Start rest timer (5s)
    // 4. Wait for expiration
    // 5. Verify all notifications triggered
    // 6. Acknowledge
    // 7. Verify state cleaned up
}
```

**Test 2: Force Quit Recovery**
```swift
func testForceQuitRecovery() async throws {
    // 1. Start rest timer
    // 2. Simulate force quit (clear RAM)
    // 3. Restore state from UserDefaults
    // 4. Verify timer continues correctly
    // 5. Verify notifications still trigger
}
```

**Test 3: Background Execution**
```swift
func testBackgroundExecution() async throws {
    // 1. Start rest timer
    // 2. Move app to background
    // 3. Wait for expiration
    // 4. Verify push notification sent
    // 5. Verify Live Activity updated
}
```

**Test 4: Multiple State Transitions**
```swift
func testMultipleTransitions() async throws {
    // 1. Start timer
    // 2. Pause timer
    // 3. Resume timer
    // 4. Expire timer
    // 5. Acknowledge
    // 6. Verify all transitions persisted correctly
}
```

**Test 5: Concurrent Operations**
```swift
func testConcurrentOperations() async throws {
    // 1. Start timer
    // 2. Quickly pause/resume multiple times
    // 3. Verify no race conditions
    // 4. Verify state is consistent
}
```

**Akzeptanzkriterien**:
- ✅ Alle Tests bestehen (100% Pass Rate)
- ✅ Keine Flaky Tests
- ✅ Tests laufen in < 30 Sekunden

**Geschätzter Aufwand**: 8 Stunden

---

### 7.3 Manual Testing auf Device

**Test-Checkliste**:

**Device Requirements**:
- [ ] iPhone 14 Pro oder neuer (für Dynamic Island)
- [ ] iOS 17.0+
- [ ] Notifications enabled
- [ ] Live Activities enabled

**Test Scenarios**:

1. **Basic Flow**
   - [ ] Start workout
   - [ ] Complete set
   - [ ] Start 30s rest
   - [ ] Wait for expiration
   - [ ] Verify In-App Overlay appears
   - [ ] Verify Haptic Feedback
   - [ ] Verify Sound plays
   - [ ] Acknowledge overlay
   - [ ] Verify overlay dismisses

2. **Live Activity**
   - [ ] Verify Live Activity shows countdown
   - [ ] Verify progress bar animates smoothly
   - [ ] Verify Dynamic Island updates
   - [ ] Wait for expiration
   - [ ] Verify Extended Dynamic Island Alert

3. **Force Quit**
   - [ ] Start 60s rest
   - [ ] Force quit app (swipe up)
   - [ ] Wait 30s
   - [ ] Reopen app
   - [ ] Verify timer restored correctly
   - [ ] Verify Live Activity still active
   - [ ] Wait for expiration
   - [ ] Verify all notifications work

4. **Background**
   - [ ] Start 30s rest
   - [ ] Move app to background (Home button)
   - [ ] Wait for expiration
   - [ ] Verify Push Notification
   - [ ] Verify Dynamic Island Alert
   - [ ] Tap notification
   - [ ] Verify Deep Link works

5. **Permissions**
   - [ ] Deny Notifications → verify graceful degradation
   - [ ] Deny Live Activities → verify fallback to Push
   - [ ] Re-enable → verify everything works again

6. **Edge Cases**
   - [ ] Very short timer (3s)
   - [ ] Very long timer (5min)
   - [ ] Pause/Resume multiple times
   - [ ] Cancel mid-timer
   - [ ] Start timer, end workout immediately

7. **NEU: Live Activity Daten**
   - [ ] Herzfrequenz-Anzeige funktioniert
   - [ ] HR-Updates werden korrekt throttled
   - [ ] Übungsname aktuell + nächste korrekt
   - [ ] Graceful Degradation ohne HealthKit

8. **Performance**
   - [ ] Battery impact measurement (30min workout)
   - [ ] CPU usage während timer
   - [ ] Memory leaks (Instruments)
   - [ ] **NEU**: HR-Update Performance (keine Battery-Drain)

**Geschätzter Aufwand**: 7 Stunden (+ 1h für HR/Übungsname Tests)

---

### 7.4 Performance Profiling

**Tools**:
- Xcode Instruments
- Energy Log
- Memory Graph Debugger

**Metriken**:
- [ ] CPU-Auslastung während Timer: < 5%
- [ ] Memory Footprint: < 10 MB zusätzlich
- [ ] Battery Impact: "Low" in Energy Log
- [ ] Keine Memory Leaks
- [ ] Persistierung < 10ms
- [ ] State-Restoration < 50ms

**Geschätzter Aufwand**: 2 Stunden

---

### Phase 5 Deliverables
- ✅ Vollständige WorkoutStore Integration
- ✅ End-to-End Test Suite
- ✅ Manual Testing auf Physical Device abgeschlossen
- ✅ Performance Profiling abgeschlossen
- ✅ Alle Bugs gefixt
- ✅ **NEU**: HealthKit HR-Integration vollständig getestet
- ✅ **NEU**: Übungsname-Anzeige funktioniert in allen Szenarien

**Phase 5 Gesamt**: 23 Stunden (2-3 Tage, +3h für neue Features)

---

## 8. Phase 6: Polish & Settings (1 Tag)

### Ziel
User Preferences UI, Debug-Tools und finale Dokumentation.

### 8.1 User Preferences UI

**Datei**: `GymTracker/Views/Settings/NotificationSettingsView.swift` (NEU)

**Tasks**:
- [ ] SwiftUI View für Notification-Einstellungen
- [ ] Toggles für:
  - [ ] In-App Overlay (on/off)
  - [ ] Push Notifications (on/off)
  - [ ] Live Activity (on/off)
  - [ ] Sound (on/off)
  - [ ] Haptic Feedback (on/off)
- [ ] Erklärungstexte für jeden Setting
- [ ] Link zu System-Einstellungen (für Permissions)
- [ ] Preview-Button zum Testen

**UI-Struktur**:
```swift
struct NotificationSettingsView: View {
    @AppStorage("showInAppOverlay") private var showOverlay = true
    @AppStorage("enablePushNotifications") private var enablePush = true
    @AppStorage("enableLiveActivity") private var enableLiveActivity = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    
    var body: some View {
        Form {
            Section("Benachrichtigungen") { ... }
            Section("Sound & Haptik") { ... }
            Section("Erweitert") { ... }
        }
    }
}
```

**Akzeptanzkriterien**:
- ✅ Alle Settings funktionieren sofort (keine App-Restart nötig)
- ✅ Erklärungstexte sind klar und hilfreich
- ✅ Preview-Funktion zeigt realistische Notifications

**Geschätzter Aufwand**: 3 Stunden

---

### 8.2 Debug Menu

**Datei**: `GymTracker/Views/Settings/DebugMenuView.swift` (NEU)

**Tasks**:
- [ ] Debug-Ansicht für Entwickler
- [ ] Features:
  - [ ] "Test In-App Overlay" Button
  - [ ] "Test Push Notification" Button
  - [ ] "Test Live Activity Alert" Button
  - [ ] Notification History anzeigen
  - [ ] State Inspector (aktueller Timer-State)
  - [ ] Force Clear State Button
  - [ ] Logs anzeigen
- [ ] Nur in Debug Builds verfügbar

**UI-Features**:
```swift
struct DebugMenuView: View {
    var body: some View {
        List {
            Section("Notifications testen") {
                Button("Test In-App Overlay") { ... }
                Button("Test Push Notification") { ... }
                Button("Test Live Activity") { ... }
            }
            
            Section("State Inspector") {
                if let state = stateManager.currentState {
                    Text("Phase: \(state.phase)")
                    Text("Remaining: \(state.remainingSeconds)s")
                    // ...
                }
            }
            
            Section("History") {
                ForEach(notificationHistory) { notification in
                    Text(notification.description)
                }
            }
        }
    }
}
```

**Geschätzter Aufwand**: 2 Stunden

---

### 8.3 Dokumentation

**Dateien zu aktualisieren**:

1. **CLAUDE.md** (Projekt-Dokumentation)
   - [ ] Neue Komponenten dokumentieren
   - [ ] Architecture Section updaten
   - [ ] Code Samples hinzufügen

2. **README.md** (User-facing)
   - [ ] Neue Features beschreiben
   - [ ] Screenshots hinzufügen
   - [ ] Troubleshooting Section

3. **Code Comments**
   - [ ] Alle öffentlichen APIs dokumentieren
   - [ ] SwiftDoc Comments für neue Klassen
   - [ ] Inline Comments für komplexe Logik

**Geschätzter Aufwand**: 2 Stunden

---

### Phase 6 Deliverables
- ✅ `NotificationSettingsView.swift`
- ✅ `DebugMenuView.swift`
- ✅ Aktualisierte Dokumentation
- ✅ Code Review abgeschlossen

**Phase 6 Gesamt**: 7 Stunden (1 Tag)

---

## 9. Migrations-Strategie

### 9.1 Backward Compatibility

**Strategie**: Alte API bleibt vorerst bestehen mit Deprecation Warnings.

**Code-Struktur**:
```swift
// WorkoutStore.swift
extension WorkoutStore {
    @available(*, deprecated, message: "Use restTimerStateManager.startRest() instead")
    func startRest(for workout: Workout, exerciseIndex: Int, setIndex: Int, duration: Int) {
        // Delegate to new system
        restTimerStateManager.startRest(
            for: workout,
            exercise: exerciseIndex,
            set: setIndex,
            duration: duration
        )
    }
    
    // ... similar for other methods
}
```

**Migration Timeline**:
- **Phase 1-5**: Alte API funktioniert, aber deprecated
- **Phase 6**: Deprecation Warnings in allen Views
- **Post-Release (1 Monat später)**: Alte API komplett entfernen

---

### 9.2 Feature Flag

**Optional**: Feature Flag für schrittweises Rollout.

```swift
struct FeatureFlags {
    @AppStorage("useNewNotificationSystem")
    static var useNewNotificationSystem: Bool = true
}

// Usage in WorkoutStore
func startRest(...) {
    if FeatureFlags.useNewNotificationSystem {
        restTimerStateManager.startRest(...)
    } else {
        // Old implementation
    }
}
```

**Empfehlung**: Nur verwenden wenn sehr risikoavers. Sonst direkt mit neuem System starten.

---

### 9.3 Data Migration

**Einmalige Migration** von altem zu neuem State-Format.

```swift
// Run once on app start in Phase 5
func migrateOldTimerState() {
    // Check for old format in UserDefaults
    if let oldData = UserDefaults.standard.data(forKey: "activeRestState") {
        // Parse old format
        struct OldState: Codable {
            let workoutId: UUID
            let remainingSeconds: Int
            let endDate: Date?
        }
        
        guard let oldState = try? JSONDecoder().decode(OldState.self, from: oldData) else {
            return
        }
        
        // Convert to new format
        // ... (needs workout details, exercise index, etc.)
        
        // Clean up old data
        UserDefaults.standard.removeObject(forKey: "activeRestState")
    }
}
```

**Call-Site**: In `GymTrackerApp.init()` oder `ContentView.onAppear()`

---

## 10. Testing & Quality Assurance

### 10.1 Unit Tests

**Test Coverage Ziel**: > 80%

**Test Files**:
- `RestTimerStateTests.swift`
- `TimerEngineTests.swift`
- `RestTimerStateManagerTests.swift`
- `InAppOverlayManagerTests.swift`
- `NotificationManagerTests.swift`

**Key Test Cases**:
- State transitions (all valid paths)
- Persistierung & Deserialization
- Timer expiration accuracy
- Force quit recovery
- Concurrent operations (race conditions)

---

### 10.2 Integration Tests

**Test Suite**: `NotificationSystemIntegrationTests.swift`

**Test Scenarios**:
1. End-to-End Timer Flow
2. Force Quit & Restore
3. Background Execution
4. All Notification Channels
5. Permission Denials
6. Performance under load

---

### 10.3 Manual Testing

**Test Matrix**:

| Scenario | Device | iOS Version | Status |
|----------|--------|-------------|--------|
| Happy Path | iPhone 15 Pro | 17.0 | ✅ |
| Force Quit | iPhone 14 Pro | 17.0 | ✅ |
| Background | iPhone 13 | 16.4 | ✅ |
| No Permissions | iPhone SE | 17.0 | ✅ |
| Edge Cases | iPhone 15 Pro Max | 17.1 | ✅ |

---

### 10.4 Acceptance Criteria

**System gilt als "fertig" wenn**:
- ✅ Alle Unit Tests bestehen (> 80% Coverage)
- ✅ Alle Integration Tests bestehen
- ✅ Manual Testing auf 3+ Devices erfolgreich
- ✅ Keine kritischen Bugs
- ✅ Performance-Metriken eingehalten
- ✅ Code Review abgeschlossen
- ✅ Dokumentation vollständig

---

## 11. Rollout-Strategie

### 11.1 Internal Release (Phase 1)

**Ziel**: Frühes Feedback von internem Team

- Deployment: TestFlight (Internal Testers)
- Dauer: 3-5 Tage
- Feedback-Kanal: GitHub Issues
- Metriken: Crash Rate, Notification Delivery Rate

### 11.2 Beta Release (Phase 2)

**Ziel**: Breites Feedback von Beta-Testern

- Deployment: TestFlight (External Testers)
- Dauer: 1-2 Wochen
- Feedback-Kanal: In-App Feedback + GitHub
- Metriken: User Engagement, Feature Adoption

### 11.3 Production Release (Phase 3)

**Ziel**: Public Release

- Deployment: App Store
- Rollout: 100% sofort (kein Staged Rollout nötig)
- Monitoring: Analytics, Crash Reports
- Hotfix-Readiness: Ja

---

## 12. Risiken & Mitigation

### 12.1 Technische Risiken

**Risiko 1: Performance-Impact durch zu viele Updates**
- **Wahrscheinlichkeit**: Mittel
- **Impact**: Hoch
- **Mitigation**: Throttling, Profiling in Phase 5

**Risiko 2: Race Conditions bei State-Updates**
- **Wahrscheinlichkeit**: Niedrig
- **Impact**: Hoch
- **Mitigation**: @MainActor, transaktionale Updates, Tests

**Risiko 3: Live Activity stoppt nach iOS-Update**
- **Wahrscheinlichkeit**: Niedrig
- **Impact**: Mittel
- **Mitigation**: Graceful Degradation, Push als Fallback

---

### 12.2 UX-Risiken

**Risiko 1: Overlay nervt User (zu aufdringlich)**
- **Wahrscheinlichkeit**: Mittel
- **Impact**: Mittel
- **Mitigation**: User Preferences, Auto-Dismiss Option

**Risiko 2: Zu viele Notifications gleichzeitig**
- **Wahrscheinlichkeit**: Niedrig
- **Impact**: Mittel
- **Mitigation**: Smart Logic (nur ein Channel aktiv)

---

### 12.3 Schedule-Risiken

**Risiko 1: Scope Creep**
- **Wahrscheinlichkeit**: Hoch
- **Impact**: Mittel
- **Mitigation**: Striktes Festhalten an Plan, "Nice-to-Have" Features für später

**Risiko 2: Unerwartete Bugs in Phase 5**
- **Wahrscheinlichkeit**: Mittel
- **Impact**: Hoch
- **Mitigation**: Buffer-Zeit eingeplant (2-3 Tage), Daily Reviews

---

## Zusammenfassung

### Gesamt-Aufwand
- **Phase 1**: 18-20 Stunden (2-3 Tage)
- **Phase 2**: 8-10 Stunden (1-2 Tage)
- **Phase 3**: 10 Stunden (1-2 Tage) ⬆️ +1h für HR-Integration
- **Phase 4**: 7 Stunden (1 Tag)
- **Phase 5**: 23 Stunden (2-3 Tage) ⬆️ +3h für HR/Übungsname-Tests
- **Phase 6**: 7 Stunden (1 Tag)

**Gesamt: 73-77 Stunden = 9-10 Arbeitstage**

**⚠️ Neue Features (HR + Übungsnamen) fügen +4 Stunden hinzu**

### Kritischer Pfad
Phase 1 → Phase 2 → Phase 5

(Phase 3 & 4 können teilweise parallel laufen)

### Success Metrics
- ✅ Notification Delivery Rate: > 99%
- ✅ Force Quit Recovery Rate: 100%
- ✅ User Satisfaction: > 4.5/5 (Feedback)
- ✅ Crash Rate: < 0.1%
- ✅ Performance Impact: "Low" Battery Usage

---

**Nächste Schritte**:
1. Review dieses Plans mit Team
2. Approval einholen
3. Branch erstellen: `feature/robust-notification-system`
4. Mit Phase 1 starten

**Fragen oder Änderungen**: Siehe NOTIFICATION_SYSTEM_KONZEPT.md Section 9 "Offene Fragen"
