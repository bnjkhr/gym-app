import SwiftUI
import UIKit

extension Color {
    @available(*, deprecated, message: "Use AppTheme.deepBlue instead")
    static let darkPurple = Color(UIColor { trait in
        let light = UIColor(red: 30/255.0, green: 58/255.0, blue: 138/255.0, alpha: 1.0)
        let dark = UIColor(red: 11/255.0, green: 21/255.0, blue: 51/255.0, alpha: 1.0)
        return trait.userInterfaceStyle == .dark ? dark : light
    })

    static let customOrange = Color(red: 251/255.0, green: 127/255.0, blue: 51/255.0)

    static let customBlue = Color(red: 82/255.0, green: 167/255.0, blue: 204/255.0)
}
