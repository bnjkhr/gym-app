import SwiftUI
import UIKit

extension Color {
    static let mossGreen = Color(red: 72/255, green: 112/255, blue: 86/255)
    static let darkPurple = Color(UIColor { trait in
        // Default (Light Mode): the existing darker purple
        let light = UIColor(red: 48/255.0, green: 25/255.0, blue: 52/255.0, alpha: 1.0)
        // Dark Mode: use a lighter, more legible purple
        let dark = UIColor.systemPurple
        return trait.userInterfaceStyle == .dark ? dark : light
    })
}
