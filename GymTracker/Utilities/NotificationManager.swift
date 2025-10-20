//
//  NotificationManager.swift
//  GymTracker
//
//  Universal in-app notification system
//

import Combine
import SwiftUI

/// Universal notification manager for showing in-app notifications
///
/// Usage:
/// ```swift
/// @EnvironmentObject var notificationManager: NotificationManager
///
/// // Show notification
/// notificationManager.show("Workout gespeichert", type: .success)
/// notificationManager.show("Fehler aufgetreten", type: .error)
/// notificationManager.show("Nächste Übung", type: .info)
/// ```
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var currentNotification: InAppNotification?
    @Published var isShowing: Bool = false

    private var hideTask: Task<Void, Never>?

    /// Show a notification for 2 seconds
    func show(_ message: String, type: NotificationType = .success, icon: String? = nil) {
        // Cancel any existing hide task
        hideTask?.cancel()

        // Create notification
        let notification = InAppNotification(
            message: message,
            type: type,
            icon: icon ?? type.defaultIcon
        )

        // Show with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentNotification = notification
            isShowing = true
        }

        // Auto-hide after 2 seconds
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                isShowing = false
            }

            // Clear notification after animation
            try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
            guard !Task.isCancelled else { return }
            currentNotification = nil
        }
    }

    /// Manually hide the current notification
    func hide() {
        hideTask?.cancel()

        withAnimation(.easeOut(duration: 0.2)) {
            isShowing = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            currentNotification = nil
        }
    }
}

// MARK: - Notification Model

struct InAppNotification: Identifiable {
    let id = UUID()
    let message: String
    let type: NotificationType
    let icon: String
}

enum NotificationType {
    case success
    case error
    case warning
    case info

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var defaultIcon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}
