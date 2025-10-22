import SwiftData
import SwiftUI

/// Zeigt einen interaktiven Monatskalender mit Workout-Sessions an.
///
/// Diese View ist Teil der StatisticsView-Modularisierung (Phase 3).
/// Sie präsentiert eine vollständige Kalenderansicht mit Monatswechsel, Tagesauswahl
/// und einer Liste der Trainings für den ausgewählten Tag.
///
/// **Verantwortlichkeiten:**
/// - Monatskalender mit Navigation (vorheriger/nächster Monat)
/// - Darstellung von Trainingstagen mit farbigen Indikatoren
/// - Tagesauswahl mit visueller Hervorhebung
/// - Liste der Trainings für den ausgewählten Tag
/// - Navigation zu SessionDetailView für einzelne Sessions
/// - Deutsche Lokalisierung (Monatsnamen, Wochentage)
///
/// **Design:**
/// - NavigationStack mit "Kalender" Titel
/// - Monatsnavigation mit Chevron-Buttons
/// - 7x Grid für Wochentage (Mo-So)
/// - Interaktive Tages-Zellen mit Session-Indikatoren
/// - Liste mit NavigationLinks zu SessionDetailView
/// - Empty State für Tage ohne Trainings
///
/// **Performance:**
/// - SwiftData @Query für Session-Abfrage
/// - Set-basierte Lookups für schnelle Tag-Checks
/// - LazyVGrid für effizienten Kalender-Rendering
/// - Optional-basierte Grid-Cells für führende Platzhalter
///
/// **Verwendung:**
/// ```swift
/// .sheet(isPresented: $showingCalendar) {
///     CalendarSessionsView()
/// }
/// ```
///
/// - Version: 1.0
/// - SeeAlso: `StatisticsView`, `SessionDetailView`, `DayStripView`
struct CalendarSessionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: [SortDescriptor(\WorkoutSessionEntityV1.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntityV1]

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    /// Formatierter Monatstitel (z.B. "Oktober 2025")
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: displayedMonth)
    }

    /// Alle Tage im angezeigten Monat
    private var daysInMonth: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
            let monthStart = cal.date(
                from: cal.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        return range.compactMap { day -> Date? in
            cal.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    /// Grid-Tage mit führenden nil-Platzhaltern für korrekte Wochentag-Ausrichtung
    private var gridDays: [Date?] {
        let cal = Calendar.current
        guard
            let monthStart = cal.date(
                from: cal.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let weekday = cal.component(.weekday, from: monthStart)  // 1=Sun...
        let leading = (weekday + 5) % 7  // convert to Monday=0 leading count
        let leadingPlaceholders: [Date?] = Array(repeating: nil, count: leading)
        return leadingPlaceholders + daysInMonth.map { Optional($0) }
    }

    /// Set aller Tage mit Sessions für schnelle Lookups
    private var sessionDays: Set<Date> {
        let cal = Calendar.current
        return Set(sessionEntities.map { cal.startOfDay(for: $0.date) })
    }

    /// Gibt alle Trainings für ein bestimmtes Datum zurück
    /// - Parameter date: Das Datum
    /// - Returns: Array von WorkoutSession-Objekten für diesen Tag
    private func sessions(on date: Date) -> [WorkoutSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let sameDay = sessionEntities.filter { cal.isDate($0.date, inSameDayAs: start) }
        return sameDay.map { WorkoutSession(entity: $0, in: modelContext) }.sorted {
            $0.date > $1.date
        }
    }

    var body: some View {
        let weekdaySymbols: [String] = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            return formatter.veryShortWeekdaySymbols ?? ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        }()

        NavigationStack {
            VStack(spacing: 12) {
                // Header with month navigation
                HStack {
                    Button {
                        displayedMonth =
                            Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth)
                            ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(monthTitle)
                        .font(.headline)
                    Spacer()
                    Button {
                        displayedMonth =
                            Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth)
                            ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .appEdgePadding()

                // Weekday symbols (German)
                HStack {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekdaySymbols[index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .appEdgePadding()

                // Calendar grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                    spacing: 6
                ) {
                    ForEach(gridDays.indices, id: \.self) { idx in
                        if let day = gridDays[idx] {
                            let cal = Calendar.current
                            let isToday = cal.isDateInToday(day)
                            let isSelected = cal.isDate(
                                cal.startOfDay(for: day), inSameDayAs: selectedDate)
                            let hasSession = sessionDays.contains(cal.startOfDay(for: day))

                            VStack(spacing: 6) {
                                // Day number with selection/today highlighting
                                ZStack {
                                    Circle()
                                        .fill(
                                            isSelected
                                                ? (colorScheme == .dark
                                                    ? AppTheme.turquoiseBoost.opacity(0.25)
                                                    : AppTheme.deepBlue.opacity(0.25))
                                                : (isToday
                                                    ? Color(.systemGray4) : Color(.systemGray6))
                                        )
                                        .frame(width: 36, height: 36)
                                    Text(String(cal.component(.day, from: day)))
                                        .font(.subheadline.weight(.medium))
                                }

                                // Session indicator dot
                                Circle()
                                    .fill(
                                        colorScheme == .dark
                                            ? AppTheme.turquoiseBoost : AppTheme.deepBlue
                                    )
                                    .frame(width: 6, height: 6)
                                    .opacity(hasSession ? 1 : 0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDate = cal.startOfDay(for: day)
                            }
                        } else {
                            // Placeholder for leading empty cells
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .appEdgePadding()

                // Sessions list for selected date
                let daySessions = sessions(on: selectedDate)
                if daySessions.isEmpty {
                    VStack(spacing: 8) {
                        Text("Keine Trainings an diesem Tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    List {
                        ForEach(daySessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.name)
                                        .font(.subheadline.weight(.semibold))
                                    HStack(spacing: 8) {
                                        Text(formatTime(session.date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        let completedExercises = session.exercises.filter {
                                            exercise in
                                            exercise.sets.contains(where: { $0.completed })
                                        }.count
                                        Text("• \(completedExercises) Übungen abgeschlossen")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Formatiert eine Zeit im deutschen Format (z.B. "14:30")
    /// - Parameter date: Das Datum
    /// - Returns: Formatierter Zeitstring
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Date Helpers

extension Calendar {
    /// Prüft ob zwei Dates am gleichen Tag sind
    fileprivate func isDate(_ date1: Date, inSameDayAs startOfDay: Date) -> Bool {
        isDate(date1, equalTo: startOfDay, toGranularity: .day)
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

    // Seed exercises
    let bench = ExerciseEntity(
        id: UUID(),
        name: "Bankdrücken",
        muscleGroupsRaw: ["chest"],
        descriptionText: "",
        instructions: [],
        createdAt: Date()
    )

    // Seed sessions auf verschiedenen Tagen
    let benchSet1 = ExerciseSetEntity(
        id: UUID(), reps: 10, weight: 60, restTime: 90, completed: true)
    let benchWE = WorkoutExerciseEntity(id: UUID(), exercise: bench, sets: [benchSet1])

    // Session heute
    let session1 = WorkoutSessionEntityV1(
        id: UUID(),
        templateId: UUID(),
        name: "Push Day",
        date: Date(),
        exercises: [benchWE],
        defaultRestTime: 90,
        duration: 3600,
        notes: ""
    )

    // Session vor 3 Tagen
    let session2 = WorkoutSessionEntityV1(
        id: UUID(),
        templateId: UUID(),
        name: "Leg Day",
        date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
        exercises: [benchWE],
        defaultRestTime: 90,
        duration: 3200,
        notes: ""
    )

    // Session vor 7 Tagen
    let session3 = WorkoutSessionEntityV1(
        id: UUID(),
        templateId: UUID(),
        name: "Pull Day",
        date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
        exercises: [benchWE],
        defaultRestTime: 90,
        duration: 3300,
        notes: ""
    )

    container.mainContext.insert(bench)
    container.mainContext.insert(session1)
    container.mainContext.insert(session2)
    container.mainContext.insert(session3)

    CalendarSessionsView()
        .modelContainer(container)
}
