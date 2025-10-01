import Foundation
import AVFoundation
import UIKit
import UserNotifications
import AudioToolbox

@MainActor
class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var ignoreMuteSwitch: Bool {
        didSet {
            UserDefaults.standard.set(ignoreMuteSwitch, forKey: "ignoreMuteSwitch")
            updateAudioSession()
        }
    }
    
    // MARK: - Standard Notification Sound
    @Published var defaultNotificationSound: String {
        didSet {
            UserDefaults.standard.set(defaultNotificationSound, forKey: "defaultNotificationSound")
        }
    }
    
    private init() {
        self.ignoreMuteSwitch = UserDefaults.standard.bool(forKey: "ignoreMuteSwitch")
        // Setzen Sie hier den Namen Ihrer .wav-Datei (ohne Erweiterung) als Standard
        self.defaultNotificationSound = UserDefaults.standard.string(forKey: "defaultNotificationSound") ?? "591279__awchacon__go"
        updateAudioSession()
        
        // Listen for audio session interruptions and route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            if ignoreMuteSwitch {
                // Override mute switch - sounds will play even when device is muted
                try audioSession.setCategory(.playback, mode: .default, options: [])
            } else {
                // Respect mute switch - sounds will be silenced when device is muted
                try audioSession.setCategory(.ambient, mode: .default, options: [])
            }
            
            try audioSession.setActive(true, options: [])
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio session was interrupted (e.g., phone call, another app)
            break
        case .ended:
            // Audio session interruption ended
            updateAudioSession()
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        // Reapply audio session configuration when route changes
        // (e.g., headphones connected/disconnected)
        updateAudioSession()
    }
    
    /// Call this method before playing any sounds to ensure proper audio session setup
    func prepareForSound() {
        updateAudioSession()
    }
    
    // MARK: - Notification Sounds
    
    /// Plays a custom notification sound
    /// - Parameter soundName: Name of the sound file (with or without extension)
    func playNotificationSound(_ soundName: String) {
        // Debug: List all available sound files in the bundle
        if let resourcePath = Bundle.main.resourcePath {
            let resourceURL = URL(fileURLWithPath: resourcePath)
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)
                let soundFiles = contents.filter { $0.pathExtension.lowercased() == "wav" }
                print("Available sound files in bundle:")
                soundFiles.forEach { print("- \($0.lastPathComponent)") }
            } catch {
                print("Could not list bundle contents: \(error)")
            }
        }
        
        // Try different approaches to find the sound file
        var soundURL: URL?
        
        // Remove .wav extension if present to normalize the name
        let cleanSoundName = soundName.replacingOccurrences(of: ".wav", with: "")
        
        // Method 1: Try with explicit .wav extension
        soundURL = Bundle.main.url(forResource: cleanSoundName, withExtension: "wav")
        
        // Method 2: If not found, try without extension (maybe it's already included)
        if soundURL == nil {
            soundURL = Bundle.main.url(forResource: soundName, withExtension: nil)
        }
        
        // Method 3: Try different case variations
        if soundURL == nil {
            soundURL = Bundle.main.url(forResource: cleanSoundName.lowercased(), withExtension: "wav")
        }
        
        guard let finalSoundURL = soundURL else {
            print("❌ Sound file not found: \(soundName)")
            print("Tried:")
            print("- \(cleanSoundName).wav")
            print("- \(soundName)")
            print("- \(cleanSoundName.lowercased()).wav")
            
            // Fallback to system sound
            AudioServicesPlaySystemSound(1007) // SMS received tone
            return
        }
        
        print("✅ Found sound file: \(finalSoundURL.lastPathComponent)")
        
        // Verify file exists and is readable
        guard FileManager.default.fileExists(atPath: finalSoundURL.path) else {
            print("❌ Sound file exists in bundle but not accessible: \(finalSoundURL.path)")
            AudioServicesPlaySystemSound(1007)
            return
        }
        
        prepareForSound()
        
        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(finalSoundURL as CFURL, &soundID)
        
        guard status == noErr else {
            print("❌ Failed to create system sound ID. Status: \(status)")
            
            // Try alternative method with AVAudioPlayer
            playWithAVAudioPlayer(url: finalSoundURL)
            return
        }
        
        print("✅ Playing sound with ID: \(soundID)")
        
        // Play the sound
        AudioServicesPlaySystemSound(soundID)
        
        // Clean up the sound ID after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            AudioServicesDisposeSystemSoundID(soundID)
        }
    }
    
    /// Fallback method using AVAudioPlayer
    private func playWithAVAudioPlayer(url: URL) {
        print("🔄 Trying AVAudioPlayer fallback for: \(url.lastPathComponent)")
        
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.volume = 1.0
            audioPlayer.prepareToPlay()
            
            let success = audioPlayer.play()
            print(success ? "✅ AVAudioPlayer started successfully" : "❌ AVAudioPlayer failed to start")
            
            // Keep a reference to prevent deallocation
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                audioPlayer.stop()
            }
            
        } catch {
            print("❌ AVAudioPlayer error: \(error)")
        }
    }
    
    /// Creates a notification with custom sound
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - soundName: Name of the sound file (without extension). If nil, uses default sound
    ///   - identifier: Unique identifier for the notification
    func scheduleNotificationWithCustomSound(
        title: String,
        body: String,
        soundName: String? = nil,
        identifier: String = UUID().uuidString
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        // Use provided sound or default
        let soundToUse = soundName ?? defaultNotificationSound
        content.sound = UNNotificationSound(named: UNNotificationSoundName("\(soundToUse).wav"))
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    /// Creates a notification with default sound (convenience method)
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - identifier: Unique identifier for the notification
    func scheduleNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString
    ) {
        scheduleNotificationWithCustomSound(
            title: title,
            body: body,
            soundName: nil, // Uses default sound
            identifier: identifier
        )
    }
    
    /// Requests notification permission if not already granted
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
}
