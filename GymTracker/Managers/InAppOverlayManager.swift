//
//  InAppOverlayManager.swift
//  GymTracker
//
//  Created by Claude on 2025-10-13.
//  Part of Robust Notification System - Phase 2
//

import Foundation
import SwiftUI

/// Manages the in-app overlay for rest timer expiration
///
/// Shows a full-screen modal overlay when the rest timer expires and the app is in the foreground.
/// This provides immediate, unmissable feedback to the user.
///
/// ## Features:
/// - Full-screen overlay with glassmorphism design
/// - Haptic feedback
/// - Sound playback
/// - Exercise name display (current + next)
/// - Auto-dismiss option (optional)
///
/// ## Usage:
/// ```swift
/// @StateObject var overlayManager = InAppOverlayManager()
///
/// // Show overlay when timer expires
/// overlayManager.showExpiredOverlay(for: state)
///
/// // User dismisses
/// overlayManager.dismissOverlay()
/// ```
@MainActor
final class InAppOverlayManager: ObservableObject, RestTimerOverlayProtocol {

    // MARK: - Published State

    /// Whether the overlay is currently visible
    @Published var isShowingOverlay: Bool = false

    /// The rest timer state to display in the overlay
    @Published var currentState: RestTimerState?

    // MARK: - Configuration

    /// Whether to play sound when showing overlay
    @AppStorage("restTimerSoundEnabled")
    private var soundEnabled: Bool = true

    /// Whether to provide haptic feedback
    @AppStorage("restTimerHapticsEnabled")
    private var hapticsEnabled: Bool = true

    /// Auto-dismiss timeout in seconds (0 = disabled)
    private let autoDismissTimeout: TimeInterval = 0  // Disabled by default

    /// Auto-dismiss task
    private var autoDismissTask: Task<Void, Never>?

    // MARK: - Public API

    /// Shows the expired overlay for a given rest timer state
    ///
    /// Triggers haptic feedback and sound if enabled.
    ///
    /// - Parameter state: The expired rest timer state
    func showExpiredOverlay(for state: RestTimerState) {
        AppLogger.workouts.info("Showing expired overlay for workout: \(state.workoutName)")

        currentState = state
        isShowingOverlay = true

        // Trigger haptic feedback
        if hapticsEnabled {
            triggerHapticFeedback()
        }

        // Play sound
        if soundEnabled {
            playSound()
        }

        // Schedule auto-dismiss if enabled
        if autoDismissTimeout > 0 {
            scheduleAutoDismiss()
        }
    }

    /// Dismisses the overlay
    ///
    /// Cancels any pending auto-dismiss.
    func dismissOverlay() {
        AppLogger.workouts.info("Dismissing expired overlay")

        // Cancel auto-dismiss
        autoDismissTask?.cancel()
        autoDismissTask = nil

        // Hide overlay
        isShowingOverlay = false

        // Clear state after animation completes
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3s
            self.currentState = nil
        }
    }

    // MARK: - Private Methods

    /// Triggers haptic feedback
    private func triggerHapticFeedback() {
        HapticManager.shared.success()
    }

    /// Plays the rest timer completion sound
    private func playSound() {
        // TODO: Integrate with AudioManager when available
        // AudioManager.shared.playBoxBell()
        AppLogger.workouts.debug("🔊 Sound playback triggered")
    }

    /// Schedules auto-dismiss after timeout
    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()

        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(autoDismissTimeout * 1_000_000_000))

            if !Task.isCancelled {
                dismissOverlay()
            }
        }
    }
}

// MARK: - Debug Support

extension InAppOverlayManager {
    /// Debug description
    var debugDescription: String {
        if isShowingOverlay, let state = currentState {
            return
                "InAppOverlayManager(showing: \(state.workoutName), exercise: \(state.currentExerciseName ?? "unknown"))"
        } else {
            return "InAppOverlayManager(hidden)"
        }
    }
}
