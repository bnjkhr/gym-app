//
//  RestTimerExpiredOverlay.swift
//  GymTracker
//
//  Created by Claude on 2025-10-13.
//  Part of Robust Notification System - Phase 2
//

import SwiftUI

/// Full-screen overlay shown when rest timer expires
///
/// Displays a prominent notification that the rest period is over,
/// along with the next exercise to perform.
///
/// ## Design:
/// - Glassmorphism card with blur effect
/// - Large checkmark icon
/// - Exercise names (current + next)
/// - Primary action button ("Weiter")
/// - Smooth animations
struct RestTimerExpiredOverlay: View {

    // MARK: - Properties

    let state: RestTimerState
    let onDismiss: () -> Void

    // MARK: - Animation State

    @State private var showContent = false
    @State private var pulseAnimation = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black
                .opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }

            // Content card
            VStack(spacing: 0) {
                contentCard
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }

            // Start pulse animation for icon
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Content Card

    private var contentCard: some View {
        VStack(spacing: 28) {
            // Icon
            checkmarkIcon

            // Title
            titleSection

            // Exercise info
            if state.currentExerciseName != nil || state.nextExerciseName != nil {
                exerciseSection
            }

            // Action button
            actionButton
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
        )
        .padding(.horizontal, 40)
    }

    // MARK: - Checkmark Icon

    private var checkmarkIcon: some View {
        ZStack {
            // Outer circle with pulse
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 120, height: 120)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)

            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Pause beendet!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Weiter geht's mit deinem Training")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
        VStack(spacing: 16) {
            // Current exercise
            if let currentExercise = state.currentExerciseName {
                exerciseRow(
                    icon: "figure.strengthtraining.traditional",
                    label: "Aktuelle Übung",
                    exerciseName: currentExercise,
                    isHighlighted: true
                )
            }

            // Next exercise
            if let nextExercise = state.nextExerciseName {
                exerciseRow(
                    icon: "arrow.right.circle.fill",
                    label: "Nächste Übung",
                    exerciseName: nextExercise,
                    isHighlighted: false
                )
            }
        }
        .padding(AppLayout.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func exerciseRow(icon: String, label: String, exerciseName: String, isHighlighted: Bool)
        -> some View
    {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isHighlighted ? .green : .blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text(exerciseName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: dismissWithAnimation) {
            HStack(spacing: 8) {
                Text("Weiter")
                    .font(.system(size: 18, weight: .semibold))

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppLayout.CornerRadius.large)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Actions

    private func dismissWithAnimation() {
        HapticManager.shared.light()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showContent = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview("Expired Overlay - Full") {
    let state = RestTimerState.create(
        workoutId: UUID(),
        workoutName: "Push Day",
        exerciseIndex: 2,
        setIndex: 3,
        duration: 90,
        currentExerciseName: "Bankdrücken",
        nextExerciseName: "Schrägbankdrücken"
    )

    return RestTimerExpiredOverlay(state: state) {
        print("Dismissed")
    }
}

#Preview("Expired Overlay - No Exercise Names") {
    let state = RestTimerState.create(
        workoutId: UUID(),
        workoutName: "Push Day",
        exerciseIndex: 2,
        setIndex: 3,
        duration: 90
    )

    return RestTimerExpiredOverlay(state: state) {
        print("Dismissed")
    }
}

#Preview("Expired Overlay - Only Current") {
    let state = RestTimerState.create(
        workoutId: UUID(),
        workoutName: "Push Day",
        exerciseIndex: 2,
        setIndex: 3,
        duration: 90,
        currentExerciseName: "Kreuzheben"
    )

    return RestTimerExpiredOverlay(state: state) {
        print("Dismissed")
    }
}
