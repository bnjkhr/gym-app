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
                
                if context.state.remainingSeconds > 0 {
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
        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.blue)
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
                            Text(context.state.title)
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
                    if context.state.remainingSeconds > 0 {
                        VStack(spacing: 4) {
                            ProgressView(value: Double(context.state.totalSeconds - context.state.remainingSeconds),
                                       total: Double(context.state.totalSeconds))
                                .progressViewStyle(.linear)
                                .tint(.blue)
                            
                            if let exerciseName = context.state.exerciseName {
                                Text(exerciseName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                // Compact Leading UI (links in der Dynamic Island)
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                // Compact Trailing UI (rechts in der Dynamic Island)
                if context.state.remainingSeconds > 0 {
                    Text(formatTime(context.state.remainingSeconds))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .contentTransition(.numericText())
                } else {
                    Text("💪")
                }
            } minimal: {
                // Minimal UI (wenn viele Apps gleichzeitig in der Dynamic Island sind)
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.blue)
            }
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
        exerciseName: "Bankdrücken"
    )
    
    WorkoutActivityAttributes.ContentState(
        remainingSeconds: 0,
        totalSeconds: 1,
        title: "Workout läuft",
        exerciseName: nil
    )
}
