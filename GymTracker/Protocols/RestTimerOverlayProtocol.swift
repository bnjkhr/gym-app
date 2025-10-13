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
protocol RestTimerOverlayProtocol: AnyObject {
    /// Shows the expired overlay for a given rest timer state
    func showExpiredOverlay(for state: RestTimerState)
}
