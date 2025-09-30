import SwiftUI

struct NotificationSoundSettings: View {
    @StateObject private var audioManager = AudioManager.shared
    
    // Liste aller verfügbaren Sounds in Ihrer App
    private let availableSounds = [
        "591279__awchacon__go.wav",      // Ersetzen Sie dies mit Ihrem tatsächlichen Dateinamen
        "default",         // Für System-Standard
        "alternative"      // Falls Sie weitere Sounds haben
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Notification Sound")) {
                    ForEach(availableSounds, id: \.self) { sound in
                        HStack {
                            Text(soundDisplayName(sound))
                            
                            Spacer()
                            
                            if audioManager.defaultNotificationSound == sound {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                            
                            Button(action: {
                                // Sound-Vorschau abspielen
                                audioManager.playNotificationSound(sound)
                            }) {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            audioManager.defaultNotificationSound = sound
                        }
                    }
                }
                
                Section(header: Text("Test")) {
                    Button("Test-Notification senden") {
                        Task {
                            let hasPermission = await audioManager.requestNotificationPermission()
                            if hasPermission {
                                audioManager.scheduleNotification(
                                    title: "Test",
                                    body: "Dies ist eine Test-Notification mit Ihrem Standard-Sound!"
                                )
                            }
                        }
                    }
                }
                
                Section(footer: Text("Wählen Sie Ihren bevorzugten Sound für alle Notifications aus. Tippen Sie auf das Play-Symbol für eine Vorschau.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Sound-Einstellungen")
        }
    }
    
    private func soundDisplayName(_ sound: String) -> String {
        switch sound {
        case "default":
            return "System Standard"
        case "mein_sound":
            return "Mein eigener Sound"  // Anpassen an Ihren Sound
        default:
            return sound.capitalized
        }
    }
}

#Preview {
    NotificationSoundSettings()
}
