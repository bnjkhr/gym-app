import AudioToolbox

enum SoundPlayer {
    static func playBoxBell() {
        let boxingBellSoundID: SystemSoundID = 1015 // classic bell tone
        AudioServicesPlaySystemSound(boxingBellSoundID)
    }
}
