//
//  NotificationPill.swift
//  GymTracker
//
//  Universal in-app notification pill
//

import SwiftUI

/// Universal notification pill that displays in-app notifications
/// Automatically shown/hidden by InAppNotificationManager
struct NotificationPill: View {
    @ObservedObject var manager: InAppNotificationManager

    var body: some View {
        VStack {
            if let notification = manager.currentNotification {
                HStack(spacing: 8) {
                    Image(systemName: notification.icon)
                        .font(.system(size: 16))

                    Text(notification.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(notification.type.color)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .opacity(manager.isShowing ? 1 : 0)
                .scaleEffect(manager.isShowing ? 1 : 0.8)
                .offset(y: manager.isShowing ? 0 : -20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)  // Position below Dynamic Island
        .allowsHitTesting(false)  // Don't block touches
    }
}

#Preview("Success") {
    @Previewable @StateObject var manager = InAppNotificationManager.shared

    ZStack {
        Color.black.ignoresSafeArea()

        NotificationPill(manager: manager)

        VStack {
            Spacer()

            Button("Show Success") {
                manager.show("Workout gespeichert", type: .success)
            }
            .buttonStyle(.borderedProminent)

            Button("Show Error") {
                manager.show("Fehler aufgetreten", type: .error)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button("Show Warning") {
                manager.show("Achtung: Keine Verbindung", type: .warning)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button("Show Info") {
                manager.show("Nächste Übung", type: .info)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}
