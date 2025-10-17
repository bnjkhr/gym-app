import SwiftData
import SwiftUI

/// Zeigt einen 7-Tage-Kalenderstreifen mit Workout-Indikatoren an.
///
/// Diese View ist Teil der StatisticsView-Modularisierung (Phase 3).
/// Sie visualisiert die letzten 7 Tage mit Markierungen für Tage mit absolvierten Workouts.
///
/// **Verantwortlichkeiten:**
/// - Darstellung der letzten 7 Tage (rückwärts chronologisch)
/// - Hervorhebung des heutigen Tages
/// - Visualisierung von Trainingstagen mit farbigen Punkten
/// - Deutsche Wochentags-Abkürzungen
/// - Navigation zum Kalender-Sheet bei Tap
///
/// **Design:**
/// - Horizontaler Scroll-Strip mit 7 Tagen
/// - Tagesnummer + Wochentags-Abkürzung (Mo, Di, Mi, ...)
/// - Heute-Markierung mit grauem Hintergrund
/// - Turquoise/Blue Punkt für Trainingstage
/// - Tap öffnet CalendarSessionsView
///
/// **Performance:**
/// - SwiftData @Query für Session-Abfrage
/// - Set-basierte Lookup für schnelle Tag-Checks
/// - Minimale View-Updates durch computed properties
///
/// **Verwendung:**
/// ```swift
/// DayStripView(showCalendar: {
///     showingCalendar = true
/// })
/// .padding(.horizontal, 20)
/// ```
///
/// - Version: 1.0
/// - SeeAlso: `StatisticsView`, `CalendarSessionsView`
struct DayStripView: View {
    /// Callback zum Öffnen des Kalender-Sheets
    let showCalendar: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    /// Die letzten 7 Tage (heute bis vor 6 Tagen)
    private var last7Days: [Date] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: Date())
        }
    }

    /// Set aller Tage mit Sessions für schnelle Lookups
    private var sessionDays: Set<Date> {
        let cal = Calendar.current
        return Set(sessionEntities.map { cal.startOfDay(for: $0.date) })
    }

    /// Konvertiert einen Date zu deutscher Wochentags-Abkürzung
    /// - Parameter date: Das Datum
    /// - Returns: Deutsche 2-Buchstaben-Abkürzung (Mo, Di, Mi, ...)
    private func germanWeekdayAbbreviation(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return "So"  // Sunday
        case 2: return "Mo"  // Monday
        case 3: return "Di"  // Tuesday
        case 4: return "Mi"  // Wednesday
        case 5: return "Do"  // Thursday
        case 6: return "Fr"  // Friday
        case 7: return "Sa"  // Saturday
        default: return ""
        }
    }

    var body: some View {
        Button(action: showCalendar) {
            HStack(spacing: 14) {
                ForEach(last7Days, id: \.self) { day in
                    let cal = Calendar.current
                    let isToday = cal.isDateInToday(day)
                    let hasSession = sessionDays.contains(cal.startOfDay(for: day))

                    VStack(spacing: 6) {
                        // Tagesnummer mit Heute-Markierung
                        ZStack {
                            if isToday {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 28, height: 28)
                            }
                            Text("\(cal.component(.day, from: day))")
                                .font(.body.weight(isToday ? .bold : .regular))
                                .foregroundStyle(.primary)
                        }

                        // Wochentags-Abkürzung
                        Text(germanWeekdayAbbreviation(for: day))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        // Session-Indikator (Punkt)
                        Circle()
                            .fill(
                                colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue
                            )
                            .frame(width: 6, height: 6)
                            .opacity(hasSession ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kalender öffnen")
        .appEdgePadding()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ExerciseEntity.self,
        ExerciseSetEntity.self,
        WorkoutExerciseEntity.self,
        WorkoutEntity.self,
        WorkoutSessionEntity.self,
        UserProfileEntity.self,
        configurations: config
    )

    // Seed test data - Sessions auf verschiedenen Tagen
    let bench = ExerciseEntity(
        id: UUID(),
        name: "Bankdrücken",
        muscleGroupsRaw: ["chest"],
        descriptionText: "",
        instructions: [],
        createdAt: Date()
    )

    let benchSet1 = ExerciseSetEntity(
        id: UUID(), reps: 10, weight: 60, restTime: 90, completed: true)
    let benchWE = WorkoutExerciseEntity(id: UUID(), exercise: bench, sets: [benchSet1])

    // Session heute
    let sessionToday = WorkoutSessionEntity(
        id: UUID(),
        templateId: UUID(),
        name: "Push Day",
        date: Date(),
        exercises: [benchWE],
        defaultRestTime: 90,
        duration: 3600,
        notes: ""
    )

    // Session vor 2 Tagen
    let session2DaysAgo = WorkoutSessionEntity(
        id: UUID(),
        templateId: UUID(),
        name: "Leg Day",
        date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
        exercises: [benchWE],
        defaultRestTime: 90,
        duration: 3600,
        notes: ""
    )

    // Session vor 5 Tagen
    let session5DaysAgo = WorkoutSessionEntity(
        id: UUID(),
        templateId: UUID(),
        name: "Pull Day",
        date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
        exercises: [benchWE],
        defaultRestTime: 90,
        duration: 3600,
        notes: ""
    )

    container.mainContext.insert(bench)
    container.mainContext.insert(sessionToday)
    container.mainContext.insert(session2DaysAgo)
    container.mainContext.insert(session5DaysAgo)

    return VStack {
        Text("7-Tage Übersicht")
            .font(.headline)
            .padding()

        DayStripView(showCalendar: {
            print("Kalender öffnen")
        })

        Spacer()
    }
    .modelContainer(container)
}
