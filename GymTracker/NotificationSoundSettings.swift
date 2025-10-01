import SwiftUI
import AudioToolbox

struct NotificationSoundSettings: View {
    @StateObject private var audioManager = AudioManager.shared
    @State private var availableSounds: [String] = []
    @State private var isLoadingSounds = true
    
    var body: some View {
        NavigationView {
            List {
                if isLoadingSounds {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Lade verfügbare Sounds...")
                                .font(.subheadline)
                        }
                    }
                } else {
                    Section(header: Text("Verfügbare Sounds")) {
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
                    
                    Section(header: Text("System Sounds")) {
                        Button("Standard iOS Notification Sound") {
                            // Play default system sound
                            AudioServicesPlaySystemSound(1007)
                        }
                        
                        Button("SMS Sound") {
                            AudioServicesPlaySystemSound(1007)
                        }
                        
                        Button("Boxing Bell") {
                            AudioServicesPlaySystemSound(1015)
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
            .onAppear {
                loadAvailableSounds()
            }
        }
    }
    
    private func loadAvailableSounds() {
        isLoadingSounds = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var sounds: [String] = []
            
            // Scan bundle for audio files
            if let resourcePath = Bundle.main.resourcePath {
                let resourceURL = URL(fileURLWithPath: resourcePath)
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)
                    let audioFiles = contents.filter { url in
                        let ext = url.pathExtension.lowercased()
                        return ext == "wav" || ext == "mp3" || ext == "m4a" || ext == "aiff"
                    }
                    
                    sounds = audioFiles.map { url in
                        url.deletingPathExtension().lastPathComponent
                    }.sorted()
                    
                } catch {
                    print("Error loading sounds: \(error)")
                }
            }
            
            // Add some fallback/system sounds if no custom sounds found
            if sounds.isEmpty {
                sounds = ["default", "system"]
            }
            
            DispatchQueue.main.async {
                self.availableSounds = sounds
                self.isLoadingSounds = false
            }
        }
    }
    
    private func soundDisplayName(_ sound: String) -> String {
        switch sound {
        case "default", "system":
            return "System Standard"
        case "591279__awchacon__go":
            return "Go Signal"
        default:
            // Convert filename to readable format
            return sound
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }
}

#Preview {
    NotificationSoundSettings()
}
