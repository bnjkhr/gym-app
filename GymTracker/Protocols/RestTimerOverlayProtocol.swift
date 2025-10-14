//
//  RestTimerOverlayProtocol.swift
//  GymTracker
//
//  Created by Claude on 2025-10-13.
//  Protocol for rest timer overlay management
//

import Foundation

/// Protocol for objects that can display rest timer expiration overlays
///
/// This protocol decouples RestTimerStateManager from InAppOverlayManager,
/// allowing for easier testing and avoiding circular dependencies.
/// Protocol for displaying rest timer expiration overlays
///
/// **Actor Isolation:** This protocol is `@MainActor` isolated because
/// all UI updates must happen on the main thread. Implementations must
/// also be `@MainActor` to satisfy this requirement.
@MainActor
protocol RestTimerOverlayProtocol: AnyObject {
    /// Shows the expired overlay for a given rest timer state
    ///
    /// This method is called when a rest timer expires to show
    /// a full-screen overlay to the user.
    ///
    /// - Parameter state: The expired timer state
    func showExpiredOverlay(for state: RestTimerState)
}
