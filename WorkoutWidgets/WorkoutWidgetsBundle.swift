//
//  WorkoutWidgetsBundle.swift
//  WorkoutWidgets
//
//  Created by Ben Kohler on 30.09.25.
//

import SwiftUI
import WidgetKit

@main
struct WorkoutWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutWidgets()
        // WorkoutWidgetsControl() // Deaktiviert - Control Center Timer nicht benötigt
        WorkoutWidgetsLiveActivity()
    }
}
