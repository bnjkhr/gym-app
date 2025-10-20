//
//  TimerSection.swift
//  GymTracker
//
//  Phase 4: Active Workout Redesign
//  Timer section with pagination (Timer ↔ Insights)
//

import SwiftUI

/// Timer section displayed at top of active workout
///
/// Features:
/// - TabView with 2 pages: Timer and Insights
/// - Always black background
/// - Pagination dots at bottom
/// - Shows rest timer OR workout duration
struct TimerSection: View {
    // MARK: - Dependencies

    @ObservedObject var restTimerManager: RestTimerStateManager
    let workoutDuration: TimeInterval

    // MARK: - State

    @State private var currentPage: Int = 0  // 0 = Timer, 1 = Insights

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // TabView with 2 pages
            TabView(selection: $currentPage) {
                // Page 1: Timer
                TimerPageView(
                    restTimerManager: restTimerManager,
                    workoutDuration: workoutDuration
                )
                .tag(0)

                // Page 2: Insights (Placeholder)
                InsightsPageView()
                    .tag(1)
            }
            .frame(height: 300)
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Pagination Dots
            HStack(spacing: 6) {
                Circle()
                    .fill(currentPage == 0 ? .white : .white.opacity(0.3))
                    .frame(width: 6, height: 6)

                Circle()
                    .fill(currentPage == 1 ? .white : .white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            .padding(.bottom, 12)
        }
        .background(Color.black)
        .foregroundStyle(.white)
    }
}

// MARK: - Timer Page

struct TimerPageView: View {
    @ObservedObject var restTimerManager: RestTimerStateManager
    let workoutDuration: TimeInterval

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Timer Display
            if let restState = restTimerManager.currentState {
                // Active Rest Timer
                RestTimerDisplay(restState: restState)
            } else {
                // Workout Duration (no active rest)
                WorkoutDurationDisplay(duration: workoutDuration)
            }

            Spacer()

            // Controls (only with active rest timer)
            if restTimerManager.currentState != nil {
                TimerControls(restTimerManager: restTimerManager)
            }
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Rest Timer Display

struct RestTimerDisplay: View {
    let restState: RestTimerState

    private var remainingTime: String {
        let seconds = restState.remainingSeconds
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("REST")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            Text(remainingTime)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()
        }
    }
}

// MARK: - Workout Duration Display

struct WorkoutDurationDisplay: View {
    let duration: TimeInterval

    private var formattedDuration: String {
        let totalSeconds = Int(duration)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("WORKOUT")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            Text(formattedDuration)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()
        }
    }
}

// MARK: - Timer Controls

struct TimerControls: View {
    @ObservedObject var restTimerManager: RestTimerStateManager

    var body: some View {
        HStack(spacing: 40) {
            // -15s Button
            Button {
                adjustTimer(by: -15)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                    Text("15s")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white.opacity(0.8))

            // Skip Button
            Button {
                skipTimer()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 32))
                    Text("Skip")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white)

            // +15s Button
            Button {
                adjustTimer(by: 15)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                    Text("15s")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func adjustTimer(by seconds: Int) {
        guard let currentState = restTimerManager.currentState else { return }

        // Adjust endDate by adding/subtracting seconds
        let newEndDate = currentState.endDate.addingTimeInterval(TimeInterval(seconds))

        // Create updated state
        var updatedState = currentState
        updatedState.endDate = newEndDate
        updatedState.lastUpdateDate = Date()

        // Update via manager (if there's a public API for this)
        // For now, we'll need to add this method to RestTimerStateManager
        // restTimerManager.updateState(updatedState)

        // TODO: Add adjustTimer(by:) method to RestTimerStateManager
        print("Adjust timer by \(seconds)s - new end date: \(newEndDate)")
    }

    private func skipTimer() {
        // Cancel the rest timer
        restTimerManager.cancelRest()

        // TODO: Notify parent to advance to next set
        // This should trigger navigation logic in parent view
        NotificationCenter.default.post(
            name: NSNotification.Name("SkipRestTimer"),
            object: nil
        )
    }
}

// MARK: - Insights Page (Placeholder)

struct InsightsPageView: View {
    var body: some View {
        VStack {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            Text("Insights")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))

            Text("Coming soon")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - Previews

#Preview("With Active Rest Timer") {
    @Previewable @StateObject var mockManager = {
        let manager = RestTimerStateManager(storage: UserDefaults.standard)

        // Create mock workout for preview
        let mockWorkout = Workout(
            id: UUID(),
            name: "Test Workout",
            date: Date(),
            exercises: []
        )

        // Start a rest timer
        manager.startRest(
            for: mockWorkout,
            exercise: 0,
            set: 2,
            duration: 90,
            currentExerciseName: "Squat",
            nextExerciseName: "Bench Press"
        )

        return manager
    }()

    TimerSection(
        restTimerManager: mockManager,
        workoutDuration: 240  // 4 minutes
    )
    .frame(height: 350)
}

#Preview("Without Rest Timer (Workout Duration)") {
    @Previewable @StateObject var mockManager = RestTimerStateManager(
        storage: UserDefaults.standard)

    TimerSection(
        restTimerManager: mockManager,
        workoutDuration: 847  // 14:07
    )
    .frame(height: 350)
}

#Preview("Insights Page") {
    InsightsPageView()
        .frame(height: 300)
        .background(Color.black)
}
