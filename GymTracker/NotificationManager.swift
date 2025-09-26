import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    private let center = UNUserNotificationCenter.current()
    private let restNotificationIdentifier = "rest_end_notification"

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    func scheduleRestEndNotification(remainingSeconds: Int, workoutName: String, exerciseName: String?, workoutId: UUID? = nil) {
        guard remainingSeconds > 0 else { return }

        DispatchQueue.global(qos: .background).async {
            self.cancelRestEndNotification()

            let content = UNMutableNotificationContent()
            content.title = "Pause beendet"
            if let exerciseName = exerciseName, !exerciseName.isEmpty {
                content.body = "Weiter geht’s mit: \(exerciseName)"
            } else {
                content.body = "Weiter geht’s!"
            }
            content.sound = .default
            var info: [String: Any] = ["type": "rest_end", "workout": workoutName]
            if let workoutId { info["workoutId"] = workoutId.uuidString }
            content.userInfo = info

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remainingSeconds), repeats: false)
            let request = UNNotificationRequest(identifier: self.restNotificationIdentifier, content: content, trigger: trigger)

            self.center.add(request) { error in
                #if DEBUG
                if let error = error {
                    print("[NotificationManager] Failed to schedule rest notification: \(error.localizedDescription)")
                }
                #endif
            }
        }
    }

    func cancelRestEndNotification() {
        DispatchQueue.global(qos: .background).async {
            self.center.removePendingNotificationRequests(withIdentifiers: [self.restNotificationIdentifier])
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(name: .restEndNotificationTapped, object: nil, userInfo: userInfo)
        completionHandler()
    }
}

extension Notification.Name {
    static let restEndNotificationTapped = Notification.Name("restEndNotificationTapped")
}
