//
//  WorkoutWidgetsLiveActivity.swift
//  WorkoutWidgets
//
//  Created by Ben Kohler on 30.09.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

extension Color {
    static let customOrange = Color(red: 251/255.0, green: 127/255.0, blue: 51/255.0)
    static let customBlue = Color(red: 82/255.0, green: 167/255.0, blue: 204/255.0)
}

struct WorkoutWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen UI
            VStack(spacing: 8) {
                HStack {
                    Text(context.attributes.workoutName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
                        }
                    }

                    Text(context.state.title)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if context.state.isTimerExpired {
                    // Timer abgelaufen - große Anzeige
                    VStack(spacing: 12) {
                        Text("Weiter geht's. 💪🏼")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else if context.state.remainingSeconds > 0 {
                    // Progress bar
                    ProgressView(value: Double(context.state.totalSeconds - context.state.remainingSeconds),
                               total: Double(context.state.totalSeconds))
                        .progressViewStyle(.linear)
                        .tint(Color.customBlue)

                    HStack {
                        if let exerciseName = context.state.exerciseName {
                            Text(exerciseName)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        if let endDate = context.state.timerEndDate {
                            Text(timerInterval: Date()...endDate, countsDown: true)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        } else {
                            Text(formatTime(context.state.remainingSeconds))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                    }
                } else if context.state.title == "Workout läuft" {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.white)
                        Text("Training aktiv")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
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
                                    .foregroundStyle(.white)
                                Text("BPM")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
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
                // Expanded UI - einfach und ohne bottom region für compact presentation
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        if let exerciseName = context.state.exerciseName {
                            Text(exerciseName)
                        } else if context.state.isTimerExpired {
                            Text("Pause beendet")
                        } else {
                            Text(context.attributes.workoutName)
                        }
                    } icon: {
                        Image(systemName: context.state.remainingSeconds > 0 ? "pause.circle.fill" : "figure.strengthtraining.traditional")
                            .foregroundStyle(context.state.remainingSeconds > 0 ? Color.customOrange : .white)
                    }
                    .font(.body)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.remainingSeconds > 0 {
                        if let endDate = context.state.timerEndDate {
                            Text(timerInterval: Date()...endDate, countsDown: true)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .monospacedDigit()
                        } else {
                            Text(formatTime(context.state.remainingSeconds))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .monospacedDigit()
                        }
                    } else if let heartRate = context.state.currentHeartRate {
                        Label("\(heartRate)", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                    }
                }

                // Bottom region NUR wenn Timer abgelaufen - triggert expanded + alert
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isTimerExpired {
                        Text("Die Pause ist vorbei")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.vertical, 4)
                    }
                }
            } compactLeading: {
                // Compact Leading UI (links in der Dynamic Island)
                Image(systemName: context.state.remainingSeconds > 0 ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundStyle(context.state.remainingSeconds > 0 ? Color.customOrange : .white)
            } compactTrailing: {
                // Compact Trailing UI (rechts in der Dynamic Island)
                Group {
                    if context.state.remainingSeconds > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.customOrange)
                            if let endDate = context.state.timerEndDate {
                                Text(timerInterval: Date()...endDate, countsDown: true)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .foregroundStyle(.white)
                            } else {
                                Text(formatTime(context.state.remainingSeconds))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .contentTransition(.numericText())
                                    .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
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
                                .foregroundStyle(Color.customOrange)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        } else {
                            Text(formatTime(context.state.remainingSeconds))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.customOrange)
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
                            .foregroundStyle(.white)
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
#Preview("Live Activity", as: .content, using: WorkoutActivityAttributes(workoutName: "Push Day", startDate: Date())) {
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
