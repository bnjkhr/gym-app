import SwiftUI

// MARK: - HomeV2 Theme

/// HomeV2 Theme - Zentrale Farbdefinitionen für Light/Dark Mode
struct HomeV2Theme {
    static let cardBackground = Color(
        uiColor: UIColor {
            $0.userInterfaceStyle == .dark ? UIColor(white: 0.15, alpha: 1.0) : UIColor.white
        })
    static let pageBackground = Color(
        uiColor: UIColor {
            $0.userInterfaceStyle == .dark ? UIColor.black : UIColor.systemGroupedBackground
        })
    static let cardBorder = Color(
        uiColor: UIColor {
            $0.userInterfaceStyle == .dark ? UIColor(white: 0.3, alpha: 1.0) : UIColor.systemGray5
        })
    static let primaryText = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor.white : UIColor.black })
    static let secondaryText = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor.systemGray : UIColor.gray })
    static let primaryButtonBackground = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor.white : UIColor.black })
    static let primaryButtonText = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor.black : UIColor.white })
    static let secondaryButtonBackground = Color(
        uiColor: UIColor {
            $0.userInterfaceStyle == .dark ? UIColor(white: 0.3, alpha: 1.0) : UIColor.systemGray6
        })
    static let secondaryButtonText = primaryText
    static let iconColor = primaryText
    static let iconColorSecondary = secondaryText
}

// MARK: - HomeWeekStats

/// Home Week Statistics Model (Simplified)
///
/// Repräsentiert die einfache Workout-Statistik für die Home View.
/// Unterscheidet sich von `WeekStats` in `WeekComparison.swift` (detaillierte Analytics).
struct HomeWeekStats {
    let workoutCount: Int
    let totalMinutes: Int
}

/// QuickStatsBar - Week Statistics Display
///
/// **Layout:**
/// ```
/// 📊 Diese Woche
/// 3 Workouts · 180 Minuten
/// ```
///
/// **Features:**
/// - Workout Count für aktuelle Woche
/// - Total Minutes für aktuelle Woche
/// - Kompaktes Design
///
/// **Usage:**
/// ```swift
/// QuickStatsBar(
///     weekStats: HomeWeekStats(workoutCount: 3, totalMinutes: 180)
/// )
/// ```
struct QuickStatsBar: View {
    // MARK: - Properties

    let weekStats: HomeWeekStats

    // MARK: - Computed Properties

    private var statsText: String {
        if weekStats.workoutCount == 0 {
            return "Noch keine Workouts diese Woche"
        }

        let workoutsText = weekStats.workoutCount == 1 ? "Workout" : "Workouts"
        let minutesText = weekStats.totalMinutes == 1 ? "Minute" : "Minuten"

        return
            "\(weekStats.workoutCount) \(workoutsText) · \(weekStats.totalMinutes) \(minutesText)"
    }

    private var iconName: String {
        weekStats.workoutCount > 0 ? "chart.bar.fill" : "chart.bar"
    }

    private var iconColor: Color {
        weekStats.workoutCount > 0 ? HomeV2Theme.primaryText : HomeV2Theme.secondaryText
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.1))
                )

            // Stats Text
            VStack(alignment: .leading, spacing: 2) {
                Text("Diese Woche")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HomeV2Theme.secondaryText)

                Text(statsText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HomeV2Theme.primaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(HomeV2Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HomeV2Theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Active Week") {
    VStack(spacing: 16) {
        QuickStatsBar(
            weekStats: HomeWeekStats(workoutCount: 3, totalMinutes: 180)
        )

        QuickStatsBar(
            weekStats: HomeWeekStats(workoutCount: 1, totalMinutes: 45)
        )

        QuickStatsBar(
            weekStats: HomeWeekStats(workoutCount: 7, totalMinutes: 420)
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
}

#Preview("Empty Week") {
    VStack(spacing: 16) {
        QuickStatsBar(
            weekStats: HomeWeekStats(workoutCount: 0, totalMinutes: 0)
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
}

#Preview("Dark Mode") {
    VStack(spacing: 16) {
        QuickStatsBar(
            weekStats: HomeWeekStats(workoutCount: 5, totalMinutes: 300)
        )

        QuickStatsBar(
            weekStats: HomeWeekStats(workoutCount: 0, totalMinutes: 0)
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
    .preferredColorScheme(.dark)
}
