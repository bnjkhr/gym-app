import Foundation
import UIKit
import UserNotifications

/// Manages local push notifications for rest timer expiration
///
/// This manager implements smart notification logic:
/// - Only sends push notifications when app is background/inactive
/// - Uses deep links to navigate to active workout
/// - Coordinates with other notification channels (Live Activity, Overlay)
///
/// ## Architecture:
/// ```
/// RestTimerStateManager
///         ↓
/// NotificationManager (scheduleNotification)
///         ↓
/// UNUserNotificationCenter
///         ↓
/// User taps notification
///         ↓
/// Deep Link Handler → Navigate to workout
/// ```
///
/// ## Usage:
/// ```swift
/// // Schedule notification
/// NotificationManager.shared.scheduleNotification(for: timerState)
///
/// // Cancel notification
/// NotificationManager.shared.cancelNotifications()
/// ```
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // MARK: - Configuration

    private let center = UNUserNotificationCenter.current()
    private let restNotificationIdentifier = "rest_timer_notification_v2"

    /// Deep link URL scheme
    private let deepLinkScheme = "gymtracker"

    // MARK: - Published State

    /// Whether notifications are enabled (computed from system settings)
    @Published private(set) var notificationsEnabled: Bool = false

    /// Computed property for backward compatibility
    var hasNotificationPermission: Bool {
        notificationsEnabled
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        center.delegate = self

        Task {
            await updateAuthorizationStatus()
        }

        AppLogger.workouts.info("NotificationManager initialized")
    }

    // MARK: - Public API

    /// Requests notification authorization from user
    ///
    /// Should be called early in app lifecycle (e.g., on first launch).
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                AppLogger.workouts.info("✅ Notification authorization granted")
            } else {
                AppLogger.workouts.warning("⚠️ Notification authorization denied")
            }

            await updateAuthorizationStatus()

        } catch {
            AppLogger.workouts.error("❌ Failed to request notification authorization: \(error)")
        }
    }

    /// Schedules a notification for timer expiration
    ///
    /// Smart Logic:
    /// - Only schedules if app is background/inactive (foreground uses overlay)
    /// - Includes deep link to active workout
    /// - Automatically cancels previous notifications
    ///
    /// - Parameter state: Timer state to schedule notification for
    func scheduleNotification(for state: RestTimerState) {
        guard shouldSendPush() else {
            AppLogger.workouts.info(
                "⏭️ Skipping push notification (app is active, overlay will handle)")
            return
        }

        guard state.remainingSeconds > 0 else {
            AppLogger.workouts.warning("⚠️ Cannot schedule notification: timer already expired")
            return
        }

        Task {
            // Cancel any existing notifications
            cancelNotifications()

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Pause beendet"

            // Body with next exercise if available
            if let nextExercise = state.nextExerciseName {
                content.body = "Weiter geht's mit: \(nextExercise)"
            } else if let currentExercise = state.currentExerciseName {
                content.body = "Weiter geht's mit: \(currentExercise)"
            } else {
                content.body = "Weiter geht's! 💪🏼"
            }

            content.sound = .default
            content.badge = 1
            content.categoryIdentifier = "REST_TIMER"

            // User info for deep link handling
            content.userInfo = [
                "type": "rest_expired",
                "workoutId": state.workoutId.uuidString,
                "workoutName": state.workoutName,
                "stateId": state.id.uuidString,
            ]

            // Trigger at expiration time
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(state.remainingSeconds),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: restNotificationIdentifier,
                content: content,
                trigger: trigger
            )

            // Schedule
            do {
                try await center.add(request)
                AppLogger.workouts.info("✅ Notification scheduled: \(state.remainingSeconds)s")
            } catch {
                AppLogger.workouts.error("❌ Failed to schedule notification: \(error)")
            }
        }
    }

    /// Cancels all pending notifications
    func cancelNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [restNotificationIdentifier])
        AppLogger.workouts.debug("🗑️ Pending notifications cancelled")
    }

    /// Handles notification response (user tapped notification)
    ///
    /// - Parameter response: The notification response
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        guard let type = userInfo["type"] as? String,
            type == "rest_expired",
            let workoutIdString = userInfo["workoutId"] as? String,
            let workoutId = UUID(uuidString: workoutIdString)
        else {
            AppLogger.workouts.warning("⚠️ Invalid notification userInfo")
            return
        }

        AppLogger.workouts.info("📱 Notification tapped: workoutId=\(workoutId)")

        // Post notification for deep link handling
        NotificationCenter.default.post(
            name: .restTimerNotificationTapped,
            object: nil,
            userInfo: ["workoutId": workoutId]
        )
    }

    // MARK: - Private Helpers

    /// Determines if push notification should be sent
    ///
    /// Smart Logic:
    /// - Send if app is background/inactive (user won't see overlay)
    /// - Skip if app is active (overlay will show instead)
    ///
    /// - Returns: True if push should be sent
    private func shouldSendPush() -> Bool {
        let appState = UIApplication.shared.applicationState

        switch appState {
        case .active:
            // App is active - overlay will handle notification
            return false

        case .inactive, .background:
            // App is background - send push notification
            return true

        @unknown default:
            // Unknown state - send as fallback
            return true
        }
    }

    /// Updates authorization status from system settings
    private func updateAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized

        AppLogger.workouts.debug(
            "Notification authorization status: \(settings.authorizationStatus.rawValue)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handles notification while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even in foreground (as fallback if overlay fails)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    /// Handles notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.handleNotificationResponse(response)
        }
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when user taps rest timer notification
    ///
    /// UserInfo contains:
    /// - `workoutId`: UUID of the workout
    static let restTimerNotificationTapped = Notification.Name("restTimerNotificationTapped")
}

// MARK: - Legacy API (Deprecated)

extension NotificationManager {
    /// Legacy method - use `scheduleNotification(for:)` instead
    ///
    /// Note: This method is nonisolated to maintain backward compatibility
    /// with synchronous calling code. It uses Task to schedule on MainActor.
    @available(*, deprecated, message: "Use scheduleNotification(for: RestTimerState) instead")
    nonisolated func scheduleRestEndNotification(
        remainingSeconds: Int,
        workoutName: String,
        exerciseName: String?,
        workoutId: UUID? = nil
    ) {
        // Create temporary state for legacy support
        guard let workoutId = workoutId else { return }

        let state = RestTimerState.create(
            workoutId: workoutId,
            workoutName: workoutName,
            exerciseIndex: 0,
            setIndex: 0,
            duration: remainingSeconds,
            currentExerciseName: exerciseName,
            nextExerciseName: nil
        )

        Task { @MainActor in
            self.scheduleNotification(for: state)
        }
    }

    /// Legacy method - use `cancelNotifications()` instead
    ///
    /// Note: This method is nonisolated to maintain backward compatibility
    /// with synchronous calling code. It uses Task to cancel on MainActor.
    @available(*, deprecated, message: "Use cancelNotifications() instead")
    nonisolated func cancelRestEndNotification() {
        Task { @MainActor in
            self.cancelNotifications()
        }
    }
}
