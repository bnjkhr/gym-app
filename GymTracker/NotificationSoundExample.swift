import SwiftUI
import UserNotifications

struct NotificationSoundExample: View {
    @StateObject private var audioManager = AudioManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Eigene Notification-Sounds")
                .font(.title)
                .padding()
            
            Button("Sound direkt abspielen") {
                // Spielt Ihre .wav-Datei direkt ab
                // Ersetzen Sie "mein_sound" mit dem Namen Ihrer .wav-Datei (ohne Erweiterung)
                audioManager.playNotificationSound("mein_sound")
            }
            .buttonStyle(.borderedProminent)
            
            Button("Notification mit eigenem Sound senden") {
                Task {
                    // Berechtigung anfordern falls nötig
                    let hasPermission = await audioManager.requestNotificationPermission()
                    
                    if hasPermission {
                        // Notification mit eigenem Sound erstellen
                        audioManager.scheduleNotificationWithCustomSound(
                            title: "Eigener Sound",
                            body: "Dies ist eine Notification mit eigenem Sound!",
                            soundName: "mein_sound" // Name Ihrer .wav-Datei ohne Erweiterung
                        )
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            Text("Hinweis: Ersetzen Sie 'mein_sound' mit dem Namen Ihrer .wav-Datei")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}

#Preview {
    NotificationSoundExample()
}