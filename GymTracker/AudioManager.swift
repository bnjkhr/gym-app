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
    /// - Parameter soundName: Name of the sound file (without extension)
    func playNotificationSound(_ soundName: String) {
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "wav") else {
            print("Sound file not found: \(soundName).wav")
            return
        }
        
        prepareForSound()
        
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        
        // Play the sound
        AudioServicesPlaySystemSound(soundID)
        
        // Clean up the sound ID after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AudioServicesDisposeSystemSoundID(soundID)
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
