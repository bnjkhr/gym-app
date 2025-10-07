import Foundation
#if canImport(ActivityKit)
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var totalSeconds: Int
        var title: String
        var exerciseName: String?
        var isTimerExpired: Bool
        var currentHeartRate: Int? // Aktuelle Herzfrequenz in BPM
        var timerEndDate: Date? // Endzeitpunkt für nativen Timer im Widget
    }

    var workoutName: String
}
#endif

