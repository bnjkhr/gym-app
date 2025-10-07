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

                    // Herzfrequenz-Anzeige
                    if let heartRate = context.state.currentHeartRate {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text("\(heartRate)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

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
                        if let endDate = context.state.timerEndDate {
                            Text(timerInterval: Date()...endDate, countsDown: true)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                        } else {
                            Text(formatTime(context.state.remainingSeconds))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                    }
                } else if context.state.title == "Workout läuft" {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.blue)
                        Text("Training aktiv")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()

                        // Große Herzfrequenz-Anzeige wenn kein Timer läuft
                        if let heartRate = context.state.currentHeartRate {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                Text("\(heartRate)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("BPM")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                    Group {
                        if context.state.remainingSeconds > 0 {
                            VStack(alignment: .trailing) {
                                if let endDate = context.state.timerEndDate {
                                    Text(timerInterval: Date()...endDate, countsDown: true)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                } else {
                                    Text(formatTime(context.state.remainingSeconds))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .contentTransition(.numericText())
                                }
                                Text("Pausentimer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(alignment: .trailing, spacing: 4) {
                                // Herzfrequenz oder "Aktiv"
                                if let heartRate = context.state.currentHeartRate {
                                    HStack(spacing: 4) {
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.red)
                                        Text("\(heartRate)")
                                            .contentTransition(.numericText())
                                    }
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    Text("BPM")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Aktiv")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text(context.state.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .id(context.state.remainingSeconds)
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
                let _ = print("[Widget] compactTrailing: remainingSeconds = \(context.state.remainingSeconds)")
                Group {
                    if context.state.remainingSeconds > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                            if let endDate = context.state.timerEndDate {
                                Text(timerInterval: Date()...endDate, countsDown: true)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                            } else {
                                Text(formatTime(context.state.remainingSeconds))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .contentTransition(.numericText())
                            }
                        }
                    } else if let heartRate = context.state.currentHeartRate {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.red)
                            Text("\(heartRate)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .contentTransition(.numericText())
                        }
                    } else {
                        Text("💪")
                    }
                }
                .id(context.state.remainingSeconds)
            } minimal: {
                // Minimal UI (wenn viele Apps gleichzeitig in der Dynamic Island sind, z.B. mit Spotify)
                Group {
                    if context.state.remainingSeconds > 0 {
                        // Timer läuft - zeige verbleibende Zeit als Text
                        if let endDate = context.state.timerEndDate {
                            Text(timerInterval: Date()...endDate, countsDown: true)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        } else {
                            Text(formatTime(context.state.remainingSeconds))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                                .contentTransition(.numericText())
                        }
                    } else if let heartRate = context.state.currentHeartRate {
                        // Kein Timer, aber Herzfrequenz vorhanden
                        Text("\(heartRate)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                            .contentTransition(.numericText())
                    } else {
                        // Fallback: Icon
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.blue)
                    }
                }
                .id(context.state.remainingSeconds)
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
        isTimerExpired: false,
        currentHeartRate: nil,
        timerEndDate: Date().addingTimeInterval(45)
    )

    WorkoutActivityAttributes.ContentState(
        remainingSeconds: 0,
        totalSeconds: 1,
        title: "Pause beendet",
        exerciseName: nil,
        isTimerExpired: true,
        currentHeartRate: nil,
        timerEndDate: nil
    )

    WorkoutActivityAttributes.ContentState(
        remainingSeconds: 0,
        totalSeconds: 1,
        title: "Workout läuft",
        exerciseName: nil,
        isTimerExpired: false,
        currentHeartRate: nil,
        timerEndDate: nil
    )
}
