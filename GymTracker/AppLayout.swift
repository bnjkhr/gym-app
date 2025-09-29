import SwiftUI

enum AppLayout {
    // Unified edge padding used across the app
    static let edge: CGFloat = 16
}

extension View {
    /// Apply the app's standard edge padding (default: horizontal)
    func appEdgePadding(_ edges: Edge.Set = .horizontal) -> some View {
        self.padding(edges, AppLayout.edge)
    }
}
