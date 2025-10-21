import SwiftUI

/// HomeWeekCalendar - Horizontal Week Calendar for HomeViewV2
///
/// **Design:**
/// - 7 days (Mo-So)
/// - Current day highlighted
/// - Workout indicator (dot) on days with workouts
/// - Compact, minimal design
///
/// **Usage:**
/// ```swift
/// HomeWeekCalendar(
///     workoutDates: [Date(), Date().addingTimeInterval(-86400)]
/// )
/// ```
struct HomeWeekCalendar: View {
    // MARK: - Properties

    let workoutDates: [Date]

    // MARK: - State

    @State private var weekDays: [WeekDay] = []

    // MARK: - Computed Properties

    private var calendar: Calendar {
        Calendar.current
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Text("Diese Woche")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HomeV2Theme.primaryText)

                Spacer()
            }

            // Calendar Strip
            HStack(spacing: 8) {
                ForEach(weekDays) { day in
                    DayCell(
                        day: day,
                        isToday: calendar.isDateInToday(day.date),
                        hasWorkout: hasWorkout(on: day.date)
                    )
                }
            }
        }
        .padding(16)
        .background(HomeV2Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HomeV2Theme.cardBorder, lineWidth: 1)
        )
        .onAppear {
            generateWeekDays()
        }
    }

    // MARK: - Helper Methods

    private func generateWeekDays() {
        let today = Date()
        let weekStart =
            calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            ) ?? today

        weekDays = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? today
            return WeekDay(
                id: offset,
                date: date,
                dayName: dayName(for: date),
                dayNumber: calendar.component(.day, from: date)
            )
        }
    }

    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EE"  // Mo, Di, Mi, ...
        return formatter.string(from: date)
    }

    private func hasWorkout(on date: Date) -> Bool {
        workoutDates.contains { workoutDate in
            calendar.isDate(workoutDate, inSameDayAs: date)
        }
    }
}

// MARK: - WeekDay Model

struct WeekDay: Identifiable {
    let id: Int
    let date: Date
    let dayName: String
    let dayNumber: Int
}

// MARK: - DayCell

struct DayCell: View {
    let day: WeekDay
    let isToday: Bool
    let hasWorkout: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Day Name (Mo, Di, ...)
            Text(day.dayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(
                    isToday ? HomeV2Theme.primaryButtonText : HomeV2Theme.secondaryText)

            // Day Number
            Text("\(day.dayNumber)")
                .font(.system(size: 15, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? HomeV2Theme.primaryButtonText : HomeV2Theme.primaryText)

            // Workout Indicator Dot
            Circle()
                .fill(hasWorkout ? HomeV2Theme.primaryText : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? HomeV2Theme.primaryButtonBackground : Color.clear)
        )
    }
}

// MARK: - Preview

#Preview("With Workouts") {
    let today = Date()
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

    return VStack(spacing: 16) {
        HomeWeekCalendar(
            workoutDates: [today, yesterday, twoDaysAgo]
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
}

#Preview("Empty Week") {
    VStack(spacing: 16) {
        HomeWeekCalendar(
            workoutDates: []
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
}

#Preview("Dark Mode") {
    let today = Date()
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

    return VStack(spacing: 16) {
        HomeWeekCalendar(
            workoutDates: [today, yesterday]
        )
    }
    .padding()
    .background(HomeV2Theme.pageBackground)
    .preferredColorScheme(.dark)
}
