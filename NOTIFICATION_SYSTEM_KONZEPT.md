#
**Notes**: Herzfrequenz anzeigen, Name Übung, nächste Übung. Design!!
# Konzept: Robustes Notification-System für Rest-Timer

## Executive Summary

Das aktuelle Notification-System hat mehrere Schwachstellen:
- Inkonsistente Zustände nach Force Quit
- Race Conditions zwischen verschiedenen Notification-Mechanismen
- Fehlende zentrale State-Verwaltung
- Unzuverlässige Timer-Synchronisation

Dieses Konzept beschreibt ein vollständig überarbeitetes System, das robust, wartbar und benutzerfreundlich ist.

---

## 1. Anforderungen

### 1.1 Funktionale Anforderungen

#### Notification-Typen
1. **In-App Overlay** (App geöffnet, im Vordergrund)
   - Großes, prominentes Overlay über der gesamten App
   - Zeigt "Pause beendet" mit Übungsname
   - Haptic Feedback
   - Sound (optional)
   - Kann nicht ignoriert werden, muss aktiv bestätigt werden

2. **Push-Notification** (App geschlossen oder im Hintergrund)
   - Standard iOS Push-Notification
   - Titel: "Pause beendet"
   - Body: "Weiter geht's mit: [Übungsname]"
   - Sound + Badge
   - Deep Link zurück zum aktiven Workout

3. **Extended Dynamic Island** (iPhone 14 Pro+, App im Hintergrund)
   - Expandiert automatisch wenn Timer abläuft
   - Zeigt "Pause beendet" prominent
   - Haptic Feedback via Live Activity Alert
   - Bleibt expanded für einige Sekunden

4. **Live Activity Anzeige** (während Workout läuft)
   - **Herzfrequenz**: Aktuelle HR in BPM (aus HealthKit)
   - **Aktuelle Übung**: Name der gerade laufenden Übung
   - **Nächste Übung**: Name der folgenden Übung (Vorschau)
   - **Rest-Timer**: Countdown mit Fortschrittsbalken (wenn aktiv)
   - Kontinuierliche Updates während gesamtem Workout

#### Timer-Funktionalität
- Timer läuft präzise, auch nach Force Quit
- Fortschrittsbalken in Live Activity aktualisiert sich kontinuierlich
- Timer-State wird persistent gespeichert
- Automatische Wiederherstellung nach App-Neustart

#### Robustheit
- Funktioniert nach Force Quit ohne Datenverlust
- Keine Race Conditions zwischen verschiedenen Mechanismen
- Graceful Degradation wenn Features nicht verfügbar

### 1.2 Nicht-funktionale Anforderungen

- **Performance**: Minimale Battery-Impact durch intelligentes Throttling
- **Zuverlässigkeit**: 99.9% erfolgreiche Notification-Delivery
- **Wartbarkeit**: Single Source of Truth, klare Verantwortlichkeiten
- **Testbarkeit**: Alle Komponenten isoliert testbar
- **UX**: Nahtlose Experience über alle App-States hinweg

### 1.3 Zusätzliche empfohlene Features

1. **Notification Preferences**
   - User kann wählen: In-App Overlay + Push + Dynamic Island (Standard)
   - User kann einzelne Kanäle deaktivieren
   - User kann Sound/Haptic separat konfigurieren

2. **Smart Notifications**
   - Wenn User das Display betrachtet (Proximity Sensor) → nur In-App Overlay
   - Wenn Display gesperrt → Push + Sound
   - Wenn App im Hintergrund → Push + Dynamic Island Alert

3. **Notification History**
   - Log aller gesendeten Notifications für Debugging
   - User kann im Debug-Menü sehen, welche Notifications verschickt wurden

4. **Notification Testing**
   - Debug-Button in Settings zum Testen aller Notification-Typen
   - Simuliert Timer-Ablauf ohne warten zu müssen

---

## 2. Aktuelle Probleme

### 2.1 Identifizierte Issues

1. **State Management**
   - `activeRestState` nur im RAM
   - `activity` Referenz geht bei Force Quit verloren
   - Keine zentrale State-Machine

2. **Race Conditions**
   - `ensureActivityExists()` erstellt neue Activity während Update läuft
   - Notification Manager und Live Activity konkurrieren
   - Timer-Updates können verloren gehen

3. **Fehlende Persistenz**
   - Timer-State wird gespeichert, aber nicht transaktional
   - Keine Validierung beim Wiederherstellen
   - Keine Error-Recovery bei korrupten Daten

4. **Inkonsistente UX**
   - Notifications werden blockiert wenn Live Activity enabled
   - Kein In-App Overlay
   - Dynamic Island Alert funktioniert nicht zuverlässig

---

## 3. Architektur-Übersicht

### 3.1 Single Source of Truth Prinzip

```
┌─────────────────────────────────────────┐
│     RestTimerStateManager (SSOT)        │
│  - Verwaltet gesamten Timer-State       │
│  - Persistiert automatisch              │
│  - Notifiziert alle Observer            │
└─────────────────────────────────────────┘
              │
              ├──────────────┬──────────────┬──────────────┐
              ▼              ▼              ▼              ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │ Timer Engine │  │   Live       │  │ Notification │  │   In-App     │
    │              │  │  Activity    │  │   Manager    │  │   Overlay    │
    └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

### 3.2 Komponenten-Verantwortlichkeiten

#### RestTimerStateManager (Neu)
- **Verantwortung**: Single Source of Truth für Timer-State
- **Aufgaben**:
  - Timer-State verwalten (running, paused, expired)
  - Automatische Persistierung (transaktional)
  - State-Wiederherstellung beim App-Start
  - Observer-Pattern für State-Changes
  - Validierung aller State-Transitions

#### TimerEngine (Refactored)
- **Verantwortung**: Präzises Timer-Management
- **Aufgaben**:
  - High-precision Timer mit wall-clock synchronization
  - Background execution via BGTaskScheduler
  - Berechnet verbleibende Zeit basierend auf `endDate`
  - Notifiziert StateManager bei Ablauf

#### LiveActivityManager (Refactored)
- **Verantwortung**: Live Activity Lifecycle
- **Aufgaben**:
  - Activity erstellen/updaten/beenden
  - Activity-Instanz wiederherstellen
  - Fortschrittsbalken-Updates
  - Alert bei Timer-Ablauf (Extended Dynamic Island)

#### NotificationManager (Refactored)
- **Verantwortung**: Push-Notifications
- **Aufgaben**:
  - Push-Notifications schedulen/canceln
  - Permissions verwalten
  - Deep-Links handlen
  - Notification-Historie

#### InAppOverlayManager (Neu)
- **Verantwortung**: In-App Overlay
- **Aufgaben**:
  - Overlay anzeigen wenn App im Vordergrund
  - Haptic Feedback
  - Sound playback
  - User-Interaktion (Dismiss, Skip to next exercise)

---

## 4. Detailliertes Design

### 4.1 RestTimerState (Data Model)

```swift
struct RestTimerState: Codable {
    // Identity
    let id: UUID
    let workoutId: UUID
    let workoutName: String
    let exerciseIndex: Int
    let setIndex: Int

    // Timer
    let startDate: Date
    let endDate: Date
    var totalSeconds: Int

    // State
    var phase: Phase
    var lastUpdateDate: Date
    
    // Live Activity Display Data
    var currentExerciseName: String?
    var nextExerciseName: String?
    var currentHeartRate: Int?

    enum Phase: String, Codable {
        case running    // Timer läuft
        case paused     // User hat pausiert
        case expired    // Timer ist abgelaufen, wartet auf Acknowledge
        case completed  // User hat acknowledged
    }

    // Computed
    var remainingSeconds: Int {
        max(0, Int(endDate.timeIntervalSince(Date())))
    }

    var isActive: Bool {
        phase == .running || phase == .paused
    }

    var hasExpired: Bool {
        Date() >= endDate && phase != .completed
    }
}
```

### 4.2 RestTimerStateManager

```swift
@MainActor
class RestTimerStateManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var currentState: RestTimerState?

    // MARK: - Configuration
    private let persistenceKey = "restTimerState_v2"
    private let maxStateAge: TimeInterval = 24 * 3600 // 24 hours

    // MARK: - Dependencies
    private let storage: UserDefaults
    private let timerEngine: TimerEngine
    private let liveActivityManager: LiveActivityManager
    private let notificationManager: NotificationManager
    private let overlayManager: InAppOverlayManager

    // MARK: - Public API

    func startRest(for workout: Workout, exercise: Int, set: Int, duration: Int, currentExerciseName: String?, nextExerciseName: String?) {
        let state = RestTimerState(
            id: UUID(),
            workoutId: workout.id,
            workoutName: workout.name,
            exerciseIndex: exercise,
            setIndex: set,
            startDate: Date(),
            endDate: Date().addingTimeInterval(TimeInterval(duration)),
            totalSeconds: duration,
            phase: .running,
            lastUpdateDate: Date(),
            currentExerciseName: currentExerciseName,
            nextExerciseName: nextExerciseName,
            currentHeartRate: nil // Will be updated via HealthKit
        )

        applyStateChange(state)
    }
    
    func updateHeartRate(_ heartRate: Int) {
        guard var state = currentState else { return }
        state.currentHeartRate = heartRate
        state.lastUpdateDate = Date()
        applyStateChange(state)
    }

    func pauseRest() {
        guard var state = currentState, state.phase == .running else { return }
        state.phase = .paused
        state.lastUpdateDate = Date()
        applyStateChange(state)
    }

    func resumeRest() {
        guard var state = currentState, state.phase == .paused else { return }
        // Recalculate endDate based on remaining time
        let remaining = state.remainingSeconds
        state.endDate = Date().addingTimeInterval(TimeInterval(remaining))
        state.phase = .running
        state.lastUpdateDate = Date()
        applyStateChange(state)
    }

    func acknowledgeExpired() {
        guard var state = currentState, state.hasExpired else { return }
        state.phase = .completed
        state.lastUpdateDate = Date()
        applyStateChange(state)

        // Clean up after short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            clearState()
        }
    }

    func cancelRest() {
        clearState()
    }

    // MARK: - State Management

    private func applyStateChange(_ newState: RestTimerState?) {
        let oldState = currentState
        currentState = newState

        // Persist immediately (transactional)
        persistState(newState)

        // Notify all subsystems
        notifySubsystems(oldState: oldState, newState: newState)

        print("[StateManager] State changed: \(oldState?.phase.rawValue ?? "nil") → \(newState?.phase.rawValue ?? "nil")")
    }

    private func notifySubsystems(oldState: RestTimerState?, newState: RestTimerState?) {
        // Timer Engine
        if let state = newState, state.phase == .running {
            timerEngine.startTimer(until: state.endDate) { [weak self] in
                self?.handleTimerExpired()
            }
        } else {
            timerEngine.stopTimer()
        }

        // Live Activity
        liveActivityManager.updateForState(newState)

        // Notifications
        if let state = newState, state.phase == .running {
            notificationManager.scheduleNotification(for: state)
        } else {
            notificationManager.cancelNotifications()
        }
    }

    private func handleTimerExpired() {
        guard var state = currentState else { return }
        state.phase = .expired
        state.lastUpdateDate = Date()
        applyStateChange(state)

        // Trigger all notification channels
        triggerExpirationNotifications(for: state)
    }

    private func triggerExpirationNotifications(for state: RestTimerState) {
        // 1. Live Activity Alert (Extended Dynamic Island)
        liveActivityManager.showExpirationAlert(for: state)

        // 2. In-App Overlay (if app is active)
        if UIApplication.shared.applicationState == .active {
            overlayManager.showExpiredOverlay(for: state)
        }

        // 3. Push Notification (if app is inactive/background)
        // Note: Already scheduled, will fire automatically

        // 4. Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 5. Sound
        SoundPlayer.playBoxBell()
    }

    // MARK: - Persistence

    private func persistState(_ state: RestTimerState?) {
        do {
            if let state = state {
                let data = try JSONEncoder().encode(state)
                storage.set(data, forKey: persistenceKey)
                print("[StateManager] ✅ State persisted")
            } else {
                storage.removeObject(forKey: persistenceKey)
                print("[StateManager] ✅ State cleared")
            }
        } catch {
            print("[StateManager] ❌ Failed to persist state: \(error)")
        }
    }

    func restoreState() {
        guard let data = storage.data(forKey: persistenceKey) else {
            print("[StateManager] No persisted state found")
            return
        }

        do {
            var state = try JSONDecoder().decode(RestTimerState.self, from: data)

            // Validate state age
            let age = Date().timeIntervalSince(state.lastUpdateDate)
            guard age < maxStateAge else {
                print("[StateManager] ⚠️ State too old (\(Int(age/3600))h), discarding")
                clearState()
                return
            }

            // Validate and adjust state
            if state.hasExpired && state.phase == .running {
                state.phase = .expired
                print("[StateManager] ⏱️ Timer expired during app absence")
            }

            applyStateChange(state)

            // Trigger notifications if just expired
            if state.phase == .expired {
                triggerExpirationNotifications(for: state)
            }

            print("[StateManager] ✅ State restored: \(state.remainingSeconds)s remaining")
        } catch {
            print("[StateManager] ❌ Failed to restore state: \(error)")
            clearState()
        }
    }

    private func clearState() {
        applyStateChange(nil)
    }
}
```

### 4.3 TimerEngine

```swift
class TimerEngine {
    private var timer: Timer?
    private var endDate: Date?
    private var expirationHandler: (() -> Void)?

    func startTimer(until endDate: Date, onExpire: @escaping () -> Void) {
        stopTimer()

        self.endDate = endDate
        self.expirationHandler = onExpire

        // Use wall-clock based timer for accuracy
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkExpiration()
        }

        // Immediate check
        checkExpiration()

        print("[TimerEngine] ⏱️ Timer started until \(endDate)")
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        expirationHandler = nil
        print("[TimerEngine] ⏹️ Timer stopped")
    }

    private func checkExpiration() {
        guard let endDate = endDate else { return }

        if Date() >= endDate {
            print("[TimerEngine] ⏰ Timer expired!")
            expirationHandler?()
            stopTimer()
        }
    }
}
```

### 4.4 InAppOverlayManager (Neu)

```swift
@MainActor
class InAppOverlayManager: ObservableObject {
    @Published var isShowingOverlay = false
    @Published var currentState: RestTimerState?

    func showExpiredOverlay(for state: RestTimerState) {
        currentState = state
        isShowingOverlay = true

        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        print("[Overlay] Showing expired overlay")
    }

    func dismissOverlay() {
        isShowingOverlay = false
        currentState = nil
    }
}

// SwiftUI View
struct RestTimerExpiredOverlay: View {
    let state: RestTimerState
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Large Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                // Title
                Text("Pause beendet!")
                    .font(.system(size: 32, weight: .bold))

                // Exercise name
                if let exerciseName = getExerciseName(for: state) {
                    Text("Weiter geht's mit:")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(exerciseName)
                        .font(.system(size: 24, weight: .semibold))
                }

                // Action Button
                Button(action: onDismiss) {
                    Text("Weiter")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 16)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(radius: 20)
            .padding(40)
        }
    }
}
```

### 4.5 LiveActivityManager Integration

```swift
extension LiveActivityManager {
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
            updateRestTimer(
                workoutId: state.workoutId,
                workoutName: state.workoutName,
                currentExerciseName: state.currentExerciseName,
                nextExerciseName: state.nextExerciseName,
                currentHeartRate: state.currentHeartRate,
                remainingSeconds: state.remainingSeconds,
                totalSeconds: state.totalSeconds,
                endDate: nil // No endDate = paused
            )

        case .expired:
            // Show "Pause beendet" with alert
            showExpirationAlert(for: state)

        case .completed:
            // Return to "Workout läuft" - show current exercise info
            showWorkoutRunning(
                workoutId: state.workoutId,
                workoutName: state.workoutName,
                currentExerciseName: state.currentExerciseName,
                nextExerciseName: state.nextExerciseName,
                currentHeartRate: state.currentHeartRate
            )
        }
    }

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
}
```

---

## 5. Implementierungs-Roadmap

### Phase 1: Foundation (2-3 Tage)
1. ✅ `RestTimerState` Model erstellen
2. ✅ `RestTimerStateManager` implementieren
3. ✅ `TimerEngine` refactoren
4. ✅ Persistenz-Layer mit Tests
5. ✅ State-Wiederherstellung implementieren

### Phase 2: UI Components (1-2 Tage)
1. ✅ `InAppOverlayManager` erstellen
2. ✅ `RestTimerExpiredOverlay` View
3. ✅ Integration in ContentView
4. ✅ Haptic Feedback abstrahieren

### Phase 3: Live Activity (1-2 Tage)
1. ✅ `LiveActivityManager` refactoren
2. ✅ Alert Configuration
3. ✅ State-basierte Updates
4. ✅ Activity-Instanz Wiederherstellung verbessern

### Phase 4: Notifications (1 Tag)
1. ✅ `NotificationManager` aufräumen
2. ✅ Notification History
3. ✅ Smart Notification Logic
4. ✅ Deep Links

### Phase 5: Integration & Testing (2-3 Tage)
1. ✅ WorkoutStore Integration
2. ✅ End-to-End Tests
3. ✅ Force Quit Tests
4. ✅ Background Execution Tests
5. ✅ Performance Profiling

### Phase 6: Polish & Settings (1 Tag)
1. ✅ User Preferences UI
2. ✅ Debug Menu
3. ✅ Notification Test Button
4. ✅ Dokumentation

**Gesamtaufwand: 8-12 Tage**

---

## 6. Migration Strategy

### 6.1 Backward Compatibility

Alter Code bleibt vorerst bestehen mit Deprecation Warnings:

```swift
@available(*, deprecated, message: "Use RestTimerStateManager instead")
func startRest(for workout: Workout, ...) {
    // Delegate to new system
    RestTimerStateManager.shared.startRest(...)
}
```

### 6.2 Feature Flag

```swift
@AppStorage("useNewNotificationSystem")
private var useNewSystem: Bool = false
```

User kann in Settings zwischen altem und neuem System wechseln.

### 6.3 Data Migration

```swift
func migrateOldTimerState() {
    // Check for old persisted state
    if let oldState = UserDefaults.standard.data(forKey: "activeRestState") {
        // Convert to new format
        let newState = convertToNewState(oldState)
        RestTimerStateManager.shared.restoreState(newState)

        // Clean up old data
        UserDefaults.standard.removeObject(forKey: "activeRestState")
    }
}
```

---

## 7. Testing Strategy

### 7.1 Unit Tests

```swift
class RestTimerStateManagerTests: XCTestCase {
    func testStateTransitions() { }
    func testPersistence() { }
    func testRestoration() { }
    func testExpiration() { }
    func testForceQuitRecovery() { }
}
```

### 7.2 Integration Tests

```swift
class NotificationSystemIntegrationTests: XCTestCase {
    func testEndToEndTimerFlow() { }
    func testForceQuitAndRestore() { }
    func testBackgroundExecution() { }
    func testAllNotificationChannels() { }
}
```

### 7.3 Manual Test Scenarios

1. **Happy Path**
   - Start rest timer → wait for expiration → verify all notifications

2. **Force Quit**
   - Start timer → force quit → reopen → verify restoration

3. **Background**
   - Start timer → background app → verify push notification

4. **Permissions**
   - Deny notifications → verify graceful fallback

5. **Edge Cases**
   - Very short timer (1s)
   - Very long timer (10min+)
   - Multiple force quits
   - System time change

---

## 8. Monitoring & Analytics

### 8.1 Key Metrics

- Notification delivery rate
- Timer accuracy (actual vs expected expiration time)
- Force quit recovery success rate
- User engagement with in-app overlay

### 8.2 Logging

```swift
enum NotificationEvent {
    case timerStarted(duration: Int)
    case timerExpired
    case overlayShown
    case pushDelivered
    case liveActivityAlertShown
    case forceQuitRecovered
    case statePersisted
    case stateRestored
}

func logEvent(_ event: NotificationEvent) {
    // Log to analytics
    // Store in local history for debugging
}
```

---

## 9. Offene Fragen & Diskussionspunkte

### 9.1 UX Decisions

1. **Overlay Dismiss Behavior**
   - Auto-dismiss nach X Sekunden?
   - Oder User muss explizit bestätigen?
   - **Empfehlung**: Explizite Bestätigung, aber mit Timeout (30s)

2. **Notification Priority**
   - Was wenn mehrere Timer gleichzeitig ablaufen?
   - **Empfehlung**: Nur ein Timer erlaubt, Queue system für zukünftige Erweiterung

3. **Sound Customization**
   - Verschiedene Sounds für verschiedene Timer?
   - **Empfehlung**: Erstmal ein Sound, später erweitern

### 9.2 Technical Decisions

1. **Background Execution**
   - BGTaskScheduler oder Timer + RunLoop?
   - **Empfehlung**: Timer + RunLoop für kurze Intervalle (< 10min), BGTaskScheduler als Fallback

2. **Persistence Format**
   - JSON in UserDefaults oder CoreData?
   - **Empfehlung**: JSON in UserDefaults für Einfachheit

3. **State Machine Library**
   - Eigene Implementierung oder Library (z.B. SwiftState)?
   - **Empfehlung**: Eigene Implementierung, zu simpel für Library

---

## 10. Zusammenfassung

### Vorteile des neuen Systems

✅ **Single Source of Truth** - Keine inkonsistenten States mehr
✅ **Robust** - Funktioniert nach Force Quit zuverlässig
✅ **Wartbar** - Klare Verantwortlichkeiten, testbar
✅ **Erweiterbar** - Neue Notification-Kanäle einfach hinzufügbar
✅ **Bessere UX** - Alle Notification-Typen perfekt koordiniert

### Risiken & Mitigation

⚠️ **Komplexität** - Mehr Code
   → Mitigation: Gute Tests, klare Dokumentation

⚠️ **Migration** - Breaking Changes
   → Mitigation: Feature Flag, schrittweise Migration

⚠️ **Performance** - Mehr Overhead
   → Mitigation: Performance Tests, Profiling

### Empfehlung

Dieses System sollte implementiert werden, weil:
1. Es alle aktuellen Bugs behebt
2. Es eine solide Foundation für zukünftige Features bietet
3. Es die UX erheblich verbessert
4. Der Aufwand (8-12 Tage) im Verhältnis zum Nutzen gerechtfertigt ist

---

## Appendix

### A. Code Samples

Vollständige Code-Beispiele befinden sich in:
- `/docs/code-samples/RestTimerStateManager.swift`
- `/docs/code-samples/InAppOverlayManager.swift`
- `/docs/code-samples/TimerEngine.swift`

### B. UI Mockups

Mockups für das In-App Overlay:
- `/docs/mockups/overlay-expired.png`
- `/docs/mockups/overlay-with-next-exercise.png`

### C. References

- Apple Documentation: Live Activities
- Apple Documentation: Local Notifications
- Apple Documentation: Background Execution
- WWDC22: Meet ActivityKit

---

**Version**: 1.0
**Datum**: 2025-01-XX
**Autor**: Claude (AI Assistant)
**Status**: Konzept - Bereit für Review & Diskussion
