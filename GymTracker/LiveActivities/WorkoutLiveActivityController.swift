#if canImport(ActivityKit)
import ActivityKit
import Foundation
import UIKit

@available(iOS 16.1, *)
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()

    private var activity: Activity<WorkoutActivityAttributes>?

    // Performance: Separate throttling for different update types
    private var lastTimerUpdateTime: Date?
    private var lastHeartRateUpdateTime: Date?
    private let timerUpdateInterval: TimeInterval = 1.0 // Timer updates every 1 second (must match)
    private let heartRateUpdateInterval: TimeInterval = 2.0 // Heart rate can be throttled more

    private var currentHeartRate: Int? // Cache für aktuelle Herzfrequenz

    // Performance: Track last state to avoid redundant updates
    private var lastSentState: (remainingSeconds: Int, heartRate: Int?)?

    private init() {}

    deinit {
        // Memory: Cleanup on dealloc (should never happen for singleton, but good practice)
        print("[LiveActivity] 🧹 Deinit called - cleaning up")
        lastTimerUpdateTime = nil
        lastHeartRateUpdateTime = nil
        currentHeartRate = nil
        lastSentState = nil
        // Note: Can't end activity in deinit due to async nature
    }
    
    func requestPermissionIfNeeded() {
        #if canImport(ActivityKit)
        Task {
            let authInfo = ActivityAuthorizationInfo()
            print("[LiveActivity] Auth Status - Activities Enabled: \(authInfo.areActivitiesEnabled)")
            print("[LiveActivity] Auth Status - Frequent Push Enabled: \(authInfo.areActivitiesEnabled)")

            if !authInfo.areActivitiesEnabled {
                print("[LiveActivity] ⚠️ Live Activities sind nicht aktiviert")
                print("[LiveActivity] 💡 Benutzer muss Live Activities in den Einstellungen aktivieren")
                print("[LiveActivity] 📱 Pfad: Einstellungen > [App Name] > Live Activities")
            } else {
                print("[LiveActivity] ✅ Live Activities sind aktiviert")
            }
        }
        #endif
    }

    func cleanupStaleActivities() {
        #if canImport(ActivityKit)
        let activities = Activity<WorkoutActivityAttributes>.activities
        guard !activities.isEmpty else { return }

        print("[LiveActivity] 🔍 Checking \(activities.count) active Live Activities for cleanup")

        for activity in activities {
            let age = Date().timeIntervalSince(activity.attributes.startDate)
            let ageInMinutes = Int(age / 60)

            // Wenn älter als 4 Stunden -> beenden (wahrscheinlich durch Force-Quit verwaist)
            if age > 4 * 3600 {
                print("[LiveActivity] 🗑️ Removing stale activity (age: \(ageInMinutes) minutes)")
                Task {
                    await activity.end(dismissalPolicy: .immediate)
                    print("[LiveActivity] ✅ Stale activity removed")
                }
            } else {
                print("[LiveActivity] ✓ Activity is fresh (age: \(ageInMinutes) minutes)")
            }
        }
        #endif
    }

    func start(workoutName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] ❌ Activities are not enabled")
            print("[LiveActivity] 💡 Benutzer sollte zu Einstellungen > [App Name] > Live Activities gehen")
            return
        }
        Task { await startOrUpdateGeneralState(workoutName: workoutName) }
    }

    func updateRest(workoutName: String, exerciseName: String?, remainingSeconds: Int, totalSeconds: Int, endDate: Date?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] ❌ updateRest: Activities not enabled")
            return
        }

        // Performance: Avoid redundant updates if state hasn't changed
        let normalizedRemaining = max(remainingSeconds, 0)
        if let lastState = lastSentState,
           lastState.remainingSeconds == normalizedRemaining,
           lastState.heartRate == currentHeartRate {
            // Skip update - nothing changed
            return
        }

        // Performance: Timer updates should come through every second
        // but we still track to prevent duplicate calls
        let now = Date()
        lastTimerUpdateTime = now
        lastSentState = (remainingSeconds: normalizedRemaining, heartRate: currentHeartRate)

        print("[LiveActivity] 🔄 updateRest: \(remainingSeconds)s / \(totalSeconds)s, HR: \(currentHeartRate?.description ?? "nil")")

        Task {
            await ensureActivityExists(workoutName: workoutName)
            await updateState(
                remaining: normalizedRemaining,
                total: max(totalSeconds, 1),
                title: "Pause",
                exerciseName: exerciseName,
                isTimerExpired: false,
                heartRate: currentHeartRate,
                timerEndDate: endDate
            )
        }
    }

    func clearRest(workoutName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Performance: Clear cached state when rest is cleared
        lastSentState = nil
        Task { await startOrUpdateGeneralState(workoutName: workoutName) }
    }

    func updateHeartRate(workoutName: String, heartRate: Int?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Performance: Always cache, but throttle actual updates
        let previousHeartRate = currentHeartRate
        currentHeartRate = heartRate

        // Performance: Skip if heart rate hasn't changed
        if previousHeartRate == heartRate {
            return
        }

        // Performance: Throttle heart rate updates more aggressively (2s interval)
        let now = Date()
        if let lastUpdate = lastHeartRateUpdateTime,
           now.timeIntervalSince(lastUpdate) < heartRateUpdateInterval {
            // Skip update but keep cached value for next timer update
            print("[LiveActivity] ⏭️ HR update throttled, cached for next update")
            return
        }
        lastHeartRateUpdateTime = now

        print("[LiveActivity] 💓 HR update: \(heartRate?.description ?? "nil")")

        Task {
            await ensureActivityExists(workoutName: workoutName)
            // Update nur die Herzfrequenz, behalte anderen State bei
            guard let activity = self.activity else { return }
            let currentState = await activity.content.state
            let newState = WorkoutActivityAttributes.ContentState(
                remainingSeconds: currentState.remainingSeconds,
                totalSeconds: currentState.totalSeconds,
                title: currentState.title,
                exerciseName: currentState.exerciseName,
                isTimerExpired: currentState.isTimerExpired,
                currentHeartRate: heartRate,
                timerEndDate: currentState.timerEndDate
            )
            await updateState(state: newState)
        }
    }

    func showRestEnded(workoutName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task {
            await ensureActivityExists(workoutName: workoutName)
            let state = WorkoutActivityAttributes.ContentState(
                remainingSeconds: 0,
                totalSeconds: 1,
                title: "Pause beendet",
                exerciseName: nil,
                isTimerExpired: true,
                currentHeartRate: currentHeartRate,
                timerEndDate: nil
            )
            await updateState(state: state, alertConfig: .init(
                title: "Weiter geht's. 💪🏼",
                body: "Die Pause ist vorbei",
                sound: .default
            ))
        }
    }

    func end() {
        guard let activity else { return }

        // Performance: Clear all state to prevent further updates
        let activityToEnd = activity
        self.activity = nil
        self.currentHeartRate = nil
        self.lastTimerUpdateTime = nil
        self.lastHeartRateUpdateTime = nil
        self.lastSentState = nil

        Task {
            let closingState = WorkoutActivityAttributes.ContentState(
                remainingSeconds: 0,
                totalSeconds: 1,
                title: "Workout beendet",
                exerciseName: nil,
                isTimerExpired: false,
                currentHeartRate: nil,
                timerEndDate: nil
            )

            await activityToEnd.end(using: closingState, dismissalPolicy: .immediate)
            print("[LiveActivity] ✅ Activity beendet")
        }
    }
    
    func testLiveActivity() {
        print("[LiveActivity] === Testing Live Activity functionality ===")
        
        #if canImport(ActivityKit)
        print("[LiveActivity] ActivityKit available: ✅")
        
        let authInfo = ActivityAuthorizationInfo()
        print("[LiveActivity] Activities enabled: \(authInfo.areActivitiesEnabled)")
        print("[LiveActivity] App in foreground: \(UIApplication.shared.applicationState == .active)")
        
        // Check if we're running in simulator
        #if targetEnvironment(simulator)
        print("[LiveActivity] ⚠️ Running in simulator - Live Activities may have limitations")
        #endif
        
        // Check Info.plist configuration
        if let supportsLiveActivities = Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool {
            print("[LiveActivity] NSSupportsLiveActivities in Info.plist: \(supportsLiveActivities)")
            if !supportsLiveActivities {
                print("[LiveActivity] ❌ NSSupportsLiveActivities ist auf false gesetzt!")
                print("[LiveActivity] 💡 Setzen Sie NSSupportsLiveActivities auf true in Info.plist")
            }
        } else {
            print("[LiveActivity] ❌ NSSupportsLiveActivities fehlt in Info.plist!")
            print("[LiveActivity] 💡 Fügen Sie NSSupportsLiveActivities=true zur Info.plist hinzu")
            print("[LiveActivity] 📝 Anleitung:")
            print("[LiveActivity]    1. Öffnen Sie Info.plist")
            print("[LiveActivity]    2. Fügen Sie hinzu: <key>NSSupportsLiveActivities</key><true/>")
            print("[LiveActivity]    3. Projekt neu builden")
            return
        }
        
        if !authInfo.areActivitiesEnabled {
            print("[LiveActivity] ❌ Live Activities nicht aktiviert")
            if Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool == true {
                print("[LiveActivity] 💡 Info.plist ist korrekt, aber Live Activities sind deaktiviert")
                print("[LiveActivity] 📱 Nach Info.plist Änderung sollte der Schalter in den Einstellungen erscheinen")
                print("[LiveActivity] 🔄 Versuchen Sie: App komplett schließen und neu starten")
            } else {
                print("[LiveActivity] 💡 Gehen Sie zu: Einstellungen > [App Name] > Live Activities")
            }
            return
        }
        
        Task {
            print("[LiveActivity] Starting test activity...")
            await startOrUpdateGeneralState(workoutName: "Test Workout")
            
            // Test update after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            print("[LiveActivity] Updating test activity...")
            await updateState(
                remaining: 30,
                total: 60,
                title: "Test Pause",
                exerciseName: "Test Exercise",
                isTimerExpired: false,
                heartRate: 145,
                timerEndDate: Date().addingTimeInterval(30)
            )
            
            // Auto-end after 10 seconds
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            print("[LiveActivity] Ending test activity...")
            end()
        }
        #else
        print("[LiveActivity] ❌ ActivityKit not available")
        #endif
    }

    // MARK: - Private

    private func ensureActivityExists(workoutName: String) async {
        if activity == nil {
            await startOrUpdateGeneralState(workoutName: workoutName)
        }
    }

    private func startOrUpdateGeneralState(workoutName: String) async {
        let baseState = WorkoutActivityAttributes.ContentState(
            remainingSeconds: 0,
            totalSeconds: 1,
            title: "Workout läuft",
            exerciseName: nil,
            isTimerExpired: false,
            currentHeartRate: currentHeartRate,
            timerEndDate: nil
        )

        if let activity {
            do {
                await activity.update(using: baseState)
                print("[LiveActivity] Updated existing activity: \(activity.id)")
            } catch {
                print("[LiveActivity] Failed to update activity: \(error.localizedDescription)")
            }
            return
        }

        let attributes = WorkoutActivityAttributes(workoutName: workoutName, startDate: Date())

        do {
            let newActivity = try Activity.request(attributes: attributes, contentState: baseState, pushType: nil)
            activity = newActivity
            print("[LiveActivity] Successfully started activity: \(newActivity.id)")
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
            print("[LiveActivity] Error details: \(error)")
            
            // Handle specific ActivityKit errors
            if let nsError = error as NSError? {
                print("[LiveActivity] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("[LiveActivity] User info: \(nsError.userInfo)")
                
                switch nsError.domain {
                case "ActivityKitErrorDomain":
                    switch nsError.code {
                    case 1: // Activity not enabled
                        print("[LiveActivity] ❌ Activities are not enabled for this app")
                        print("[LiveActivity] 💡 Enable in Settings > [App] > Live Activities")
                    case 2: // Activity limit exceeded
                        print("[LiveActivity] ❌ Too many active activities (max 8)")
                    case 3: // Activity disabled
                        print("[LiveActivity] ❌ Live Activities are disabled system-wide")
                    case 4: // Invalid request
                        print("[LiveActivity] ❌ Invalid activity request")
                    default:
                        print("[LiveActivity] ❌ ActivityKit error code: \(nsError.code)")
                    }
                case "NSOSStatusErrorDomain":
                    switch nsError.code {
                    case -54:
                        print("[LiveActivity] ⚠️ LaunchServices database error - this is often temporary")
                        print("[LiveActivity] 💡 Try: Clean build folder, restart Xcode/Simulator, or reboot device")
                    default:
                        print("[LiveActivity] ❌ OS Status error code: \(nsError.code)")
                    }
                default:
                    print("[LiveActivity] ❌ Other error domain: \(nsError.domain), code: \(nsError.code)")
                }
            }
        }
    }

    private func updateState(remaining: Int, total: Int, title: String, exerciseName: String?, isTimerExpired: Bool, heartRate: Int? = nil, timerEndDate: Date? = nil) async {
        let state = WorkoutActivityAttributes.ContentState(
            remainingSeconds: remaining,
            totalSeconds: max(total, 1),
            title: title,
            exerciseName: exerciseName,
            isTimerExpired: isTimerExpired,
            currentHeartRate: heartRate,
            timerEndDate: timerEndDate
        )
        await updateState(state: state)
    }

    private func updateState(state: WorkoutActivityAttributes.ContentState, alertConfig: AlertConfiguration? = nil) async {
        guard let activity else {
            print("[LiveActivity] ⚠️ Update fehlgeschlagen - keine aktive Activity")
            return
        }

        do {
            await activity.update(using: state, alertConfiguration: alertConfig)
            print("[LiveActivity] ✅ Update erfolgreich - remaining: \(state.remainingSeconds)s, expired: \(state.isTimerExpired)")
        } catch {
            print("[LiveActivity] ❌ Update fehlgeschlagen: \(error.localizedDescription)")
        }
    }
}

#else
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()
    private init() {}

    func start(workoutName: String) {}
    func updateRest(workoutName: String, exerciseName: String?, remainingSeconds: Int, totalSeconds: Int) {}
    func clearRest(workoutName: String) {}
    func showRestEnded(workoutName: String) {}
    func end() {}
}
#endif
