#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()

    private var activity: Activity<WorkoutActivityAttributes>?

    private init() {}

    func start(workoutName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task { await startOrUpdateGeneralState(workoutName: workoutName) }
    }

    func updateRest(workoutName: String, remainingSeconds: Int, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task {
            await ensureActivityExists(workoutName: workoutName)
            await updateState(
                remaining: max(remainingSeconds, 0),
                total: max(totalSeconds, 1),
                title: "Pause"
            )
        }
    }

    func clearRest(workoutName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task { await startOrUpdateGeneralState(workoutName: workoutName) }
    }

    func end() {
        guard let activity else { return }
        Task {
            let closingState = WorkoutActivityAttributes.ContentState(
                remainingSeconds: 0,
                totalSeconds: 1,
                title: "Workout beendet"
            )

            await activity.end(using: closingState, dismissalPolicy: .immediate)
            self.activity = nil
        }
    }

    // MARK: - Private

    private func ensureActivityExists(workoutName: String) async {
        if activity == nil {
            await startOrUpdateGeneralState(workoutName: workoutName)
        }
    }

    private func startOrUpdateGeneralState(workoutName: String) async {
        let baseState = WorkoutActivityAttributes.ContentState(
            remainingSeconds: 0,
            totalSeconds: 1,
            title: "Workout läuft"
        )

        if let activity {
            await activity.update(using: baseState)
            return
        }

        let attributes = WorkoutActivityAttributes(workoutName: workoutName)

        do {
            activity = try Activity.request(attributes: attributes, contentState: baseState, pushType: nil)
        } catch {
#if DEBUG
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
#endif
        }
    }

    private func updateState(remaining: Int, total: Int, title: String) async {
        let state = WorkoutActivityAttributes.ContentState(
            remainingSeconds: remaining,
            totalSeconds: max(total, 1),
            title: title
        )
        await updateState(state: state)
    }

    private func updateState(state: WorkoutActivityAttributes.ContentState) async {
        guard let activity else { return }
        await activity.update(using: state)
    }
}

#else
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()
    private init() {}

    func start(workoutName: String) {}
    func updateRest(workoutName: String, remainingSeconds: Int, totalSeconds: Int) {}
    func clearRest(workoutName: String) {}
    func end() {}
}
#endif
