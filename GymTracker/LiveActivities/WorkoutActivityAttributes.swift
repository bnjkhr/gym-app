import Foundation
#if canImport(ActivityKit)
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var totalSeconds: Int
        var title: String
    }

    var workoutName: String
}
#endif
