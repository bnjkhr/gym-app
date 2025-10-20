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
    // MARK: - Constants

    enum Layout {
        static let timerHeight: CGFloat = 300
        static let paginationDotSize: CGFloat = 6
        static let paginationDotSpacing: CGFloat = 6
        static let paginationBottomPadding: CGFloat = 12
    }

    enum Typography {
        static let timerFontSize: CGFloat = 96
        static let timerFontWeight: Font.Weight = .heavy
    }

    enum Spacing {
        static let pageSpacing: CGFloat = 16
        static let controlBottomPadding: CGFloat = 20
        static let controlIconSize: CGFloat = 32
        static let controlSpacing: CGFloat = 40
        static let controlLabelSpacing: CGFloat = 4
    }

    // MARK: - Dependencies

    @ObservedObject var restTimerManager: RestTimerStateManager
    let workoutStartDate: Date?

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
                    workoutStartDate: workoutStartDate
                )
                .tag(0)

                // Page 2: Insights (Placeholder)
                InsightsPageView()
                    .tag(1)
            }
            .frame(height: Layout.timerHeight)
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Pagination Dots
            HStack(spacing: Layout.paginationDotSpacing) {
                Circle()
                    .fill(currentPage == 0 ? .white : .white.opacity(0.3))
                    .frame(width: Layout.paginationDotSize, height: Layout.paginationDotSize)

                Circle()
                    .fill(currentPage == 1 ? .white : .white.opacity(0.3))
                    .frame(width: Layout.paginationDotSize, height: Layout.paginationDotSize)
            }
            .padding(.bottom, Layout.paginationBottomPadding)
        }
        .background(
            Color.black
                .ignoresSafeArea(edges: .top)
        )
        .foregroundStyle(.white)
    }
}

// MARK: - Timer Page

struct TimerPageView: View {
    @ObservedObject var restTimerManager: RestTimerStateManager
    let workoutStartDate: Date?

    var body: some View {
        VStack(spacing: TimerSection.Spacing.pageSpacing) {
            Spacer()

            // Timer Display
            if let restState = restTimerManager.currentState {
                // Active Rest Timer
                RestTimerDisplay(restState: restState)
            } else {
                // Workout Duration (no active rest)
                WorkoutDurationDisplay(startDate: workoutStartDate)
            }

            Spacer()

            // Controls (only with active rest timer)
            if restTimerManager.currentState != nil {
                TimerControls(restTimerManager: restTimerManager)
            }
        }
        .padding(.vertical, TimerSection.Spacing.controlBottomPadding)
    }
}

// MARK: - Rest Timer Display

struct RestTimerDisplay: View {
    let restState: RestTimerState

    @State private var currentTime = Date()

    private var remainingTime: String {
        // Calculate remaining time from current time to end date
        let timeInterval = restState.endDate.timeIntervalSince(currentTime)
        let seconds = max(0, Int(timeInterval))
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("PAUSE")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            Text(remainingTime)
                .font(
                    .system(
                        size: TimerSection.Typography.timerFontSize,
                        weight: TimerSection.Typography.timerFontWeight)
                )
                .monospacedDigit()
        }
        .onAppear {
            // Start timer that updates every second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}

// MARK: - Workout Duration Display

struct WorkoutDurationDisplay: View {
    let startDate: Date?

    @State private var currentTime = Date()

    private var formattedDuration: String {
        guard let startDate = startDate else {
            return "00:00"
        }

        // Calculate live duration from start date to current time
        let duration = currentTime.timeIntervalSince(startDate)
        let totalSeconds = max(0, Int(duration))
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
                .font(
                    .system(
                        size: TimerSection.Typography.timerFontSize,
                        weight: TimerSection.Typography.timerFontWeight)
                )
                .monospacedDigit()
        }
        .onAppear {
            // Start timer that updates every second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}

// MARK: - Timer Controls

struct TimerControls: View {
    @ObservedObject var restTimerManager: RestTimerStateManager

    var body: some View {
        HStack(spacing: TimerSection.Spacing.controlSpacing) {
            // -15s Button
            Button {
                adjustTimer(by: -15)
            } label: {
                VStack(spacing: TimerSection.Spacing.controlLabelSpacing) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: TimerSection.Spacing.controlIconSize))
                    Text("15s")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white.opacity(0.8))

            // Skip Button
            Button {
                skipTimer()
            } label: {
                VStack(spacing: TimerSection.Spacing.controlLabelSpacing) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: TimerSection.Spacing.controlIconSize))
                    Text("Skip")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white)

            // +15s Button
            Button {
                adjustTimer(by: 15)
            } label: {
                VStack(spacing: TimerSection.Spacing.controlLabelSpacing) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: TimerSection.Spacing.controlIconSize))
                    Text("15s")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.bottom, TimerSection.Spacing.controlBottomPadding)
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
        workoutStartDate: Date().addingTimeInterval(-240)  // Started 4 minutes ago
    )
    .frame(height: 350)
}

#Preview("Without Rest Timer (Workout Duration)") {
    @Previewable @StateObject var mockManager = RestTimerStateManager(
        storage: UserDefaults.standard)

    TimerSection(
        restTimerManager: mockManager,
        workoutStartDate: Date().addingTimeInterval(-847)  // Started 14:07 ago
    )
    .frame(height: 350)
}

#Preview("Insights Page") {
    InsightsPageView()
        .frame(height: 300)
        .background(Color.black)
}
