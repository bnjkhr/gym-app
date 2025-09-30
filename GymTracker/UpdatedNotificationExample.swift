import SwiftUI
import UserNotifications

struct UpdatedNotificationExample: View {
    @StateObject private var audioManager = AudioManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Notification-Sounds")
                    .font(.title)
                    .padding()
                
                // Aktueller Standard-Sound anzeigen
                VStack {
                    Text("Aktueller Standard-Sound:")
                        .font(.headline)
                    Text(audioManager.defaultNotificationSound)
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button("Standard-Sound abspielen") {
                    audioManager.playNotificationSound(audioManager.defaultNotificationSound)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test-Notification senden") {
                    Task {
                        let hasPermission = await audioManager.requestNotificationPermission()
                        if hasPermission {
                            // Verwendet automatisch den Standard-Sound
                            audioManager.scheduleNotification(
                                title: "Test-Notification",
                                body: "Dies verwendet Ihren Standard-Sound!"
                            )
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                
                NavigationLink(destination: NotificationSoundSettings()) {
                    Label("Sound-Einstellungen", systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("💡 Tipp: Gehen Sie zu den Sound-Einstellungen, um Ihren Standard-Sound zu ändern")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .navigationTitle("Notifications")
        }
    }
}

#Preview {
    UpdatedNotificationExample()
}