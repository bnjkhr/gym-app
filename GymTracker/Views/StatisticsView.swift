import SwiftUI
import Charts

private struct StatisticsScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct StatisticsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var headerHidden: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var didSetInitialOffset: Bool = false
    @State private var showingCalendar: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: StatisticsScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("statisticsScroll")).minY
                        )
                }
                .frame(height: 0)

                DayStripView(showCalendar: { showingCalendar = true })
                    .environmentObject(workoutStore)

                // Neue Übersicht (letztes Workout)
                ProgressOverviewCardView()
                    .environmentObject(workoutStore)

                // Neue Infobox: Veränderungen (Gewicht/Volumen & Wiederholungen)
                ProgressDeltaInfoCardView()
                    .environmentObject(workoutStore)

                // Bestehende Bereiche
                MostUsedExercisesView()
                    .environmentObject(workoutStore)

                RecentActivityView()
                    .environmentObject(workoutStore)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onPreferenceChange(StatisticsScrollOffsetPreferenceKey.self) { newValue in
            if !didSetInitialOffset {
                lastScrollOffset = newValue
                didSetInitialOffset = true
                return
            }
            let delta = newValue - lastScrollOffset
            if delta < -5 {
                if !headerHidden { headerHidden = true }
            } else if delta > 5 {
                if headerHidden { headerHidden = false }
            }
            lastScrollOffset = newValue
        }
        .coordinateSpace(name: "statisticsScroll")
        .sheet(isPresented: $showingCalendar) {
            CalendarSessionsView()
                .environmentObject(workoutStore)
        }
    }
}

// MARK: - Neue Karten

private struct ProgressOverviewCardView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    private var lastSession: WorkoutSession? {
        workoutStore.sessionHistory.sorted { $0.date > $1.date }.first
    }

    private var lastVolume: Double? {
        guard let session = lastSession else { return nil }
        return session.exercises.reduce(0) { partial, ex in
            partial + ex.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private var lastDateText: String {
        guard let session = lastSession else { return "–" }
        return session.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }

    private var lastExerciseCountText: String {
        guard let session = lastSession else { return "–" }
        return "\(session.exercises.count)"
    }

    private var lastVolumeText: String {
        guard let vol = lastVolume else { return "–" }
        let tons = vol / 1000.0
        return tons.formatted(.number.precision(.fractionLength(2))) + " t"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Übersicht")
                .font(.headline)

            HStack(spacing: 12) {
                statBox(title: "Gewicht", value: lastVolumeText, icon: "scalemass.fill", tint: .mossGreen)
                statBox(title: "Datum", value: lastDateText, icon: "calendar", tint: .blue)
                statBox(title: "Übungen", value: lastExerciseCountText, icon: "list.bullet", tint: .orange)
            }
        }
        .appEdgePadding()
    }

    private func statBox(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
    }
}

private struct ProgressDeltaInfoCardView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    private var lastTwoSessions: [WorkoutSession] {
        workoutStore.sessionHistory.sorted { $0.date > $1.date }.prefix(2).map { $0 }
    }

    private var lastSession: WorkoutSession? { lastTwoSessions.first }
    private var prevSession: WorkoutSession? { lastTwoSessions.count > 1 ? lastTwoSessions[1] : nil }

    private func volume(for session: WorkoutSession) -> Double {
        session.exercises.reduce(0) { partial, ex in
            partial + ex.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private func reps(for session: WorkoutSession) -> Int {
        session.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
    }

    private var deltaVolumeText: String {
        guard let last = lastSession, let prev = prevSession else {
            return "Neu: kein Vergleich"
        }
        let delta = volume(for: last) - volume(for: prev)
        let formatted = delta.magnitude.formatted(.number.precision(.fractionLength(1))) + " kg"
        if delta == 0 {
            return "Gleich wie zuletzt"
        } else if delta > 0 {
            return "+\(formatted) vs. letzte Session"
        } else {
            return "-\(formatted) vs. letzte Session"
        }
    }

    private var deltaRepsText: String {
        guard let last = lastSession, let prev = prevSession else {
            return "Neu: kein Vergleich"
        }
        let delta = reps(for: last) - reps(for: prev)
        if delta == 0 {
            return "Gleich wie zuletzt"
        } else if delta > 0 {
            return "+\(delta) Wdh. vs. letzte Session"
        } else {
            return "\(delta) Wdh. vs. letzte Session"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Veränderung seit der letzten Session")
                .font(.headline)

            VStack(spacing: 10) {
                HStack {
                    Text("Gewicht")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(deltaVolumeText)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                }
                HStack {
                    Text("Wiederholungen")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(deltaRepsText)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .appEdgePadding()
    }
}

// MARK: - Bestehende Bereiche (unverändert)

struct MostUsedExercisesView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var exerciseUsage: [(Exercise, Int)] {
        var usage: [UUID: Int] = [:]

        for workout in workoutStore.workouts {
            for workoutExercise in workout.exercises {
                usage[workoutExercise.exercise.id, default: 0] += 1
            }
        }

        return workoutStore.exercises
            .map { exercise in
                (exercise, usage[exercise.id] ?? 0)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Beliebteste Übungen")
                .font(.headline)

            if exerciseUsage.isEmpty {
                Text("Noch keine Workouts aufgezeichnet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(exerciseUsage.enumerated()), id: \.offset) { index, item in
                    let (exercise, count) = item
                    HStack {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundColor(.mossGreen)

                        Text(exercise.name)

                        Spacer()

                        Text("\(count)x")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .appEdgePadding()
    }
}

struct RecentActivityView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var recentWorkouts: [Workout] {
        workoutStore.workouts
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Letzte Aktivität")
                .font(.headline)

            if recentWorkouts.isEmpty {
                Text("Noch keine Workouts aufgezeichnet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(recentWorkouts) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .fontWeight(.medium)

                            Text(workout.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(workout.exercises.count) Übungen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .appEdgePadding()
    }
}

// MARK: - Day Strip (7-day calendar)
private struct DayStripView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    let showCalendar: () -> Void

    private var last7Days: [Date] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: Date())
        }
    }

    private var sessionDays: Set<Date> {
        let cal = Calendar.current
        return Set(workoutStore.sessionHistory.map { cal.startOfDay(for: $0.date) })
    }

    var body: some View {
        Button(action: showCalendar) {
            HStack(spacing: 14) {
                ForEach(last7Days, id: \.self) { day in
                    let cal = Calendar.current
                    let isToday = cal.isDateInToday(day)
                    let hasSession = sessionDays.contains(cal.startOfDay(for: day))

                    VStack(spacing: 6) {
                        ZStack {
                            if isToday {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 28, height: 28)
                            }
                            Text(day, format: .dateTime.day())
                                .font(.body.weight(isToday ? .bold : .regular))
                                .foregroundStyle(.primary)
                        }
                        Text(day, format: .dateTime.weekday(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(AppTheme.darkPurple)
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

// MARK: - Calendar Sessions Sheet
private struct CalendarSessionsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)) else { return [] }
        return range.compactMap { day -> Date? in
            cal.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    private var gridDays: [Date?] {
        let cal = Calendar.current
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)) else { return [] }
        let weekday = cal.component(.weekday, from: monthStart) // 1=Sun...
        let leading = (weekday + 5) % 7 // convert to Monday=0 leading count
        let leadingPlaceholders: [Date?] = Array(repeating: nil, count: leading)
        return leadingPlaceholders + daysInMonth.map { Optional($0) }
    }

    private var sessionDays: Set<Date> {
        let cal = Calendar.current
        return Set(workoutStore.sessionHistory.map { cal.startOfDay(for: $0.date) })
    }

    private func sessions(on date: Date) -> [WorkoutSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return workoutStore.sessionHistory.filter { cal.isDate($0.date, inSameDayAs: start) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Header with month navigation
                HStack {
                    Button { displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(monthTitle)
                        .font(.headline)
                    Spacer()
                    Button { displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .appEdgePadding()

                // Weekday symbols (Mon-Sun)
                HStack {
                    ForEach(["M", "D", "M", "D", "F", "S", "S"], id: \.self) { d in
                        Text(d)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .appEdgePadding()

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(gridDays.indices, id: \.self) { idx in
                        if let day = gridDays[idx] {
                            let cal = Calendar.current
                            let isToday = cal.isDateInToday(day)
                            let isSelected = cal.isDate(cal.startOfDay(for: day), inSameDayAs: selectedDate)
                            let hasSession = sessionDays.contains(cal.startOfDay(for: day))
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            isSelected ? Color.mossGreen.opacity(0.25) : (isToday ? Color(.systemGray4) : Color(.systemGray6))
                                        )
                                        .frame(width: 36, height: 36)
                                    Text(String(cal.component(.day, from: day)))
                                        .font(.subheadline.weight(.medium))
                                }
                                Circle()
                                    .fill(AppTheme.darkPurple)
                                    .frame(width: 6, height: 6)
                                    .opacity(hasSession ? 1 : 0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDate = cal.startOfDay(for: day)
                            }
                        } else {
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.name)
                                    .font(.subheadline.weight(.semibold))
                                HStack(spacing: 8) {
                                    Text(session.date, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("• \(session.exercises.count) Übungen")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
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
}

// MARK: - Date Helpers
private extension Calendar {
    func isDate(_ date1: Date, inSameDayAs startOfDay: Date) -> Bool {
        isDate(date1, equalTo: startOfDay, toGranularity: .day)
    }
}
