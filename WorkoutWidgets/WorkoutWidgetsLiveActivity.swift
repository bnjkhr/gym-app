//
//  WorkoutWidgetsLiveActivity.swift
//  WorkoutWidgets
//
//  Created by Ben Kohler on 30.09.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen UI
            VStack(spacing: 8) {
                HStack {
                    Text(context.attributes.workoutName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(context.state.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if context.state.isTimerExpired {
                    // Timer abgelaufen - große Anzeige
                    VStack(spacing: 12) {
                        Text("Weiter geht's. 💪🏼")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else if context.state.remainingSeconds > 0 {
                    // Progress bar
                    ProgressView(value: Double(context.state.totalSeconds - context.state.remainingSeconds),
                               total: Double(context.state.totalSeconds))
                        .progressViewStyle(.linear)
                        .tint(.blue)

                    HStack {
                        if let exerciseName = context.state.exerciseName {
                            Text(exerciseName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatTime(context.state.remainingSeconds))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                } else if context.state.title == "Workout läuft" {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.blue)
                        Text("Training aktiv")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .widgetURL(URL(string: "workout://active"))
        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        // Icon zeigt Pause-Status oder Training
                        Image(systemName: context.state.remainingSeconds > 0 ? "pause.circle.fill" : "figure.strengthtraining.traditional")
                            .foregroundStyle(context.state.remainingSeconds > 0 ? .orange : .blue)
                        Text(context.attributes.workoutName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.remainingSeconds > 0 {
                        VStack(alignment: .trailing) {
                            Text(formatTime(context.state.remainingSeconds))
                                .font(.title2)
                                .fontWeight(.bold)
                                .contentTransition(.numericText())
                            Text("Pausentimer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .trailing) {
                            Text("Aktiv")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(context.state.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isTimerExpired {
                        VStack(spacing: 8) {
                            Text("Weiter geht's. 💪🏼")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                        .padding(.vertical, 8)
                    } else if context.state.remainingSeconds > 0 {
                        VStack(spacing: 4) {
                            ProgressView(value: Double(context.state.totalSeconds - context.state.remainingSeconds),
                                       total: Double(context.state.totalSeconds))
                                .progressViewStyle(.linear)
                                .tint(.orange)

                            if let exerciseName = context.state.exerciseName {
                                HStack {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.caption2)
                                    Text(exerciseName)
                                        .font(.subheadline)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                // Compact Leading UI (links in der Dynamic Island)
                Image(systemName: context.state.remainingSeconds > 0 ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundStyle(context.state.remainingSeconds > 0 ? .orange : .blue)
            } compactTrailing: {
                // Compact Trailing UI (rechts in der Dynamic Island)
                if context.state.remainingSeconds > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                        Text(formatTime(context.state.remainingSeconds))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .contentTransition(.numericText())
                    }
                } else {
                    Text("💪")
                }
            } minimal: {
                // Minimal UI (wenn viele Apps gleichzeitig in der Dynamic Island sind)
                Image(systemName: context.state.remainingSeconds > 0 ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundStyle(context.state.remainingSeconds > 0 ? .orange : .blue)
            }
            .widgetURL(URL(string: "workout://active"))
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Preview für die Live Activity
#Preview("Live Activity", as: .content, using: WorkoutActivityAttributes(workoutName: "Push Day")) {
    WorkoutWidgetsLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(
        remainingSeconds: 45,
        totalSeconds: 60,
        title: "Pause",
        exerciseName: "Bankdrücken",
        isTimerExpired: false
    )

    WorkoutActivityAttributes.ContentState(
        remainingSeconds: 0,
        totalSeconds: 1,
        title: "Pause beendet",
        exerciseName: nil,
        isTimerExpired: true
    )

    WorkoutActivityAttributes.ContentState(
        remainingSeconds: 0,
        totalSeconds: 1,
        title: "Workout läuft",
        exerciseName: nil,
        isTimerExpired: false
    )
}
