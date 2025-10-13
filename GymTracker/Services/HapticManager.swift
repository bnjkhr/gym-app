//
//  HapticManager.swift
//  GymTracker
//
//  Created by Claude on 2025-10-13.
//  Part of Robust Notification System - Phase 2
//

import UIKit

/// Centralized manager for haptic feedback
///
/// Provides a consistent interface for triggering haptic feedback throughout the app.
/// Respects user preferences for haptic feedback.
///
/// ## Usage:
/// ```swift
/// HapticManager.shared.success()  // Timer completed
/// HapticManager.shared.warning()  // Timer paused
/// HapticManager.shared.error()    // Timer cancelled
/// HapticManager.shared.light()    // Button tap
/// ```
final class HapticManager {

    // MARK: - Singleton

    static let shared = HapticManager()

    private init() {}

    // MARK: - Configuration

    /// Whether haptic feedback is enabled
    private var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "hapticsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsEnabled") }
    }

    // MARK: - Generators

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Public API

    /// Success haptic (for timer completion, workout end)
    func success() {
        guard enabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    /// Warning haptic (for timer pause, skip)
    func warning() {
        guard enabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Error haptic (for timer cancellation, errors)
    func error() {
        guard enabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    /// Light impact haptic (for button taps)
    func light() {
        guard enabled else { return }
        impactGenerator.impactOccurred()
    }

    /// Selection changed haptic (for segmented controls, pickers)
    func selection() {
        guard enabled else { return }
        selectionGenerator.selectionChanged()
    }

    /// Medium impact haptic (for drag and drop)
    func impact() {
        guard enabled else { return }
        impactGenerator.impactOccurred()
    }

    /// Heavy impact haptic (for major state changes)
    func heavyImpact() {
        guard enabled else { return }
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        heavyGenerator.impactOccurred()
    }

    // MARK: - Preparation

    /// Prepares the haptic engine for upcoming feedback
    ///
    /// Call this before showing UI that will trigger haptic feedback
    /// to reduce latency.
    func prepare() {
        guard enabled else { return }
        notificationGenerator.prepare()
        impactGenerator.prepare()
        selectionGenerator.prepare()
    }
}
