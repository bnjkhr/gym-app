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

    var workoutId: UUID // UUID des aktiven Workouts für State-Wiederherstellung
    var workoutName: String
    var startDate: Date // Startzeit für Stale-Detection beim App-Neustart
}
#endif

