import SwiftUI
import AVFoundation
import AudioToolbox

struct AudioDebugView: View {
    @StateObject private var audioManager = AudioManager.shared
    @State private var customSoundName = "591279__awchacon__go"
    @State private var debugOutput: [String] = []
    
    var body: some View {
        NavigationView {
            List {
                Section("Sound-Datei Testen") {
                    HStack {
                        TextField("Sound-Dateiname", text: $customSoundName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Test") {
                            testCustomSound()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("Alle verfügbaren Sounds auflisten") {
                        listAvailableSounds()
                    }
                    
                    Button("Audio Session Info") {
                        checkAudioSession()
                    }
                }
                
                Section("System Sounds") {
                    Button("System Sound 1007 (SMS)") {
                        AudioServicesPlaySystemSound(1007)
                    }
                    
                    Button("System Sound 1015 (Boxing Bell)") {
                        AudioServicesPlaySystemSound(1015)
                    }
                }
                
                Section("Debug Output") {
                    ForEach(Array(debugOutput.enumerated()), id: \.offset) { index, message in
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("❌") ? .red : 
                                           message.contains("✅") ? .green : .primary)
                    }
                    
                    if !debugOutput.isEmpty {
                        Button("Clear Output") {
                            debugOutput.removeAll()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Audio Debug")
            .onAppear {
                addDebugMessage("Audio Debug View geladen")
                listAvailableSounds()
            }
        }
    }
    
    private func testCustomSound() {
        addDebugMessage("🔍 Teste Sound: '\(customSoundName)'")
        
        // Redirect print statements to our debug output
        audioManager.playNotificationSound(customSoundName)
        
        // Also test notification
        Task {
            let hasPermission = await audioManager.requestNotificationPermission()
            if hasPermission {
                audioManager.scheduleNotificationWithCustomSound(
                    title: "Test Notification", 
                    body: "Custom Sound Test", 
                    soundName: customSoundName
                )
                addDebugMessage("📱 Test-Notification gesendet")
            } else {
                addDebugMessage("❌ Notification-Berechtigung verweigert")
            }
        }
    }
    
    private func listAvailableSounds() {
        addDebugMessage("📂 Suche nach Sound-Dateien im Bundle...")
        
        guard let resourcePath = Bundle.main.resourcePath else {
            addDebugMessage("❌ Bundle resource path nicht verfügbar")
            return
        }
        
        let resourceURL = URL(fileURLWithPath: resourcePath)
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)
            let soundFiles = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "wav" || ext == "mp3" || ext == "m4a" || ext == "aiff"
            }
            
            if soundFiles.isEmpty {
                addDebugMessage("❌ Keine Audio-Dateien im Bundle gefunden")
            } else {
                addDebugMessage("✅ Gefundene Audio-Dateien:")
                soundFiles.forEach { url in
                    let fileName = url.lastPathComponent
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                    addDebugMessage("  📄 \(fileName) (\(fileSize) Bytes)")
                }
            }
        } catch {
            addDebugMessage("❌ Fehler beim Lesen des Bundle-Inhalts: \(error)")
        }
    }
    
    private func checkAudioSession() {
        let session = AVAudioSession.sharedInstance()
        addDebugMessage("🔊 Audio Session Info:")
        addDebugMessage("  Category: \(session.category)")
        addDebugMessage("  Mode: \(session.mode)")
        addDebugMessage("  Options: \(session.categoryOptions)")
        addDebugMessage("  Output Volume: \(session.outputVolume)")
        addDebugMessage("  Other Audio Playing: \(session.isOtherAudioPlaying)")
        
        // Test if we can activate the session
        do {
            try session.setActive(true)
            addDebugMessage("✅ Audio Session erfolgreich aktiviert")
        } catch {
            addDebugMessage("❌ Fehler beim Aktivieren der Audio Session: \(error)")
        }
    }
    
    private func addDebugMessage(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.debugTime.string(from: Date())
            debugOutput.append("[\(timestamp)] \(message)")
            
            // Keep only last 50 messages
            if debugOutput.count > 50 {
                debugOutput.removeFirst()
            }
        }
    }
}

extension DateFormatter {
    static let debugTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}

#Preview {
    AudioDebugView()
}