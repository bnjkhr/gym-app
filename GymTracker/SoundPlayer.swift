import AudioToolbox
import AVFoundation

enum SoundPlayer {
    static func playBoxBell() {
        // Ensure audio session is configured correctly before playing
        Task { @MainActor in
            AudioManager.shared.prepareForSound()
        }
        
        let boxingBellSoundID: SystemSoundID = 1015 // classic bell tone
        AudioServicesPlaySystemSound(boxingBellSoundID)
    }
}
