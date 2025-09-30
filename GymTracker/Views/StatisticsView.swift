import SwiftUI
import Charts
import SwiftData
import HealthKit
#if canImport(ActivityKit)
import ActivityKit
#endif

private struct StatisticsScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct StatisticsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
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

                // Neue Übersicht (letztes Workout)
                ProgressOverviewCardView()

                // Neue Infobox: Veränderungen (Gewicht/Volumen & Wiederholungen)
                ProgressDeltaInfoCardView()

                // Herzfrequenz-Bereich
                HeartRateInsightsView()
                    .environmentObject(workoutStore)

                // Bestehende Bereiche
                MostUsedExercisesView()

                RecentActivityView()
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
        }
    }
}

// MARK: - Neue Karten

private struct ProgressOverviewCardView: View {
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    private var lastSession: WorkoutSession? {
        sessionEntities.first.map { WorkoutSession(entity: $0) }
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
            HStack {
                Text("Übersicht")
                    .font(.headline)
                
                Spacer()
            }

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
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    private var lastTwoSessions: [WorkoutSession] {
        sessionEntities.prefix(2).map { WorkoutSession(entity: $0) }
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
    @Query(sort: [SortDescriptor(\WorkoutEntity.date, order: .reverse)])
    private var workoutEntities: [WorkoutEntity]
    @Query(sort: [SortDescriptor(\ExerciseEntity.name, order: .forward)])
    private var exerciseEntities: [ExerciseEntity]

    @Environment(\.modelContext) private var modelContext

    private var displayWorkouts: [Workout] {
        workoutEntities.map { Workout(entity: $0) }
    }

    var exerciseUsage: [(Exercise, Int)] {
        let workouts = displayWorkouts
        let catalog: [Exercise] = {
            // Fresh fetch to avoid invalid snapshots
            let descriptor = FetchDescriptor<ExerciseEntity>(sortBy: [SortDescriptor(\.name, order: .forward)])
            let freshList = (try? modelContext.fetch(descriptor)) ?? []
            return safeMapExercises(freshList, in: modelContext)
        }()
        var usage: [UUID: Int] = [:]
        for workout in workouts {
            for workoutExercise in workout.exercises {
                usage[workoutExercise.exercise.id, default: 0] += 1
            }
        }
        return catalog
            .map { exercise in (exercise, usage[exercise.id] ?? 0) }
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
    @Query(sort: [SortDescriptor(\WorkoutEntity.date, order: .reverse)])
    private var workoutEntities: [WorkoutEntity]
    
    @Environment(\.modelContext) private var modelContext

    var recentWorkouts: [Workout] {
        workoutEntities.prefix(5).map { Workout(entity: $0) }
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
    let showCalendar: () -> Void

    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    private var last7Days: [Date] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: Date())
        }
    }

    private var sessionDays: Set<Date> {
        let cal = Calendar.current
        return Set(sessionEntities.map { cal.startOfDay(for: $0.date) })
    }
    
    private func germanWeekdayAbbreviation(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return "So" // Sunday
        case 2: return "Mo" // Monday
        case 3: return "Di" // Tuesday
        case 4: return "Mi" // Wednesday
        case 5: return "Do" // Thursday
        case 6: return "Fr" // Friday
        case 7: return "Sa" // Saturday
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
                        Text(germanWeekdayAbbreviation(for: day))
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
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

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
        return Set(sessionEntities.map { cal.startOfDay(for: $0.date) })
    }

    private func sessions(on date: Date) -> [WorkoutSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let sameDay = sessionEntities.filter { cal.isDate($0.date, inSameDayAs: start) }
        return sameDay.map { WorkoutSession(entity: $0) }.sorted { $0.date > $1.date }
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

                // Weekday symbols (Mon-Sun in German)
                HStack {
                    ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { d in
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ExerciseEntity.self, ExerciseSetEntity.self, WorkoutExerciseEntity.self, WorkoutEntity.self, WorkoutSessionEntity.self, UserProfileEntity.self, configurations: config)

    // Seed exercises
    let bench = ExerciseEntity(id: UUID(), name: "Bankdrücken", muscleGroupsRaw: ["chest"], descriptionText: "", instructions: [], createdAt: Date())
    let squat = ExerciseEntity(id: UUID(), name: "Kniebeugen", muscleGroupsRaw: ["legs"], descriptionText: "", instructions: [], createdAt: Date())

    // Seed a workout with sets
    let benchSet1 = ExerciseSetEntity(id: UUID(), reps: 10, weight: 60, restTime: 90, completed: false)
    let benchSet2 = ExerciseSetEntity(id: UUID(), reps: 8, weight: 65, restTime: 90, completed: false)
    let benchWE = WorkoutExerciseEntity(id: UUID(), exercise: bench, sets: [benchSet1, benchSet2])

    let squatSet1 = ExerciseSetEntity(id: UUID(), reps: 8, weight: 80, restTime: 120, completed: false)
    let squatWE = WorkoutExerciseEntity(id: UUID(), exercise: squat, sets: [squatSet1])

    let w1 = WorkoutEntity(id: UUID(), name: "Push Day", date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, exercises: [benchWE], defaultRestTime: 90, duration: 3600, notes: "")
    let w2 = WorkoutEntity(id: UUID(), name: "Leg Day", date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, exercises: [squatWE], defaultRestTime: 120, duration: 3000, notes: "")

    // Seed two recent sessions for delta calc
    let s1BenchSet = ExerciseSetEntity(id: UUID(), reps: 10, weight: 60, restTime: 90, completed: true)
    let s1BenchWE = WorkoutExerciseEntity(id: UUID(), exercise: bench, sets: [s1BenchSet])
    let session1 = WorkoutSessionEntity(id: UUID(), templateId: w1.id, name: "Push Day", date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, exercises: [s1BenchWE], defaultRestTime: 90, duration: 3200, notes: "")

    let s2BenchSet = ExerciseSetEntity(id: UUID(), reps: 12, weight: 62.5, restTime: 90, completed: true)
    let s2BenchWE = WorkoutExerciseEntity(id: UUID(), exercise: bench, sets: [s2BenchSet])
    let session2 = WorkoutSessionEntity(id: UUID(), templateId: w1.id, name: "Push Day", date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, exercises: [s2BenchWE], defaultRestTime: 90, duration: 3300, notes: "")

    container.mainContext.insert(bench)
    container.mainContext.insert(squat)
    container.mainContext.insert(w1)
    container.mainContext.insert(w2)
    container.mainContext.insert(session1)
    container.mainContext.insert(session2)

    return NavigationStack { StatisticsView() }
        .modelContainer(container)
        .environmentObject(WorkoutStore())
}

// MARK: - Heart Rate Insights
struct HeartRateInsightsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var heartRateReadings: [HeartRateReading] = []
    @State private var isLoading = false
    @State private var error: HealthKitError?
    @State private var showingError = false
    @State private var selectedTimeRange: HeartRateTimeRange = .day
    
    enum HeartRateTimeRange: String, CaseIterable {
        case day = "24h"
        case week = "Woche"
        case month = "Monat"
        
        var displayName: String { rawValue }
        
        var timeInterval: TimeInterval {
            switch self {
            case .day: return 86400
            case .week: return 604800
            case .month: return 2629746
            }
        }
    }
    
    private var averageHeartRate: Double {
        guard !heartRateReadings.isEmpty else { return 0 }
        return heartRateReadings.reduce(0) { $0 + $1.heartRate } / Double(heartRateReadings.count)
    }
    
    private var maxHeartRate: Double {
        heartRateReadings.max { $0.heartRate < $1.heartRate }?.heartRate ?? 0
    }
    
    private var minHeartRate: Double {
        heartRateReadings.min { $0.heartRate < $1.heartRate }?.heartRate ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Herzfrequenz")
                .font(.headline)
            
            if !workoutStore.healthKitManager.isHealthDataAvailable {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("HealthKit nicht verfügbar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            } else if !workoutStore.healthKitManager.isAuthorized {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("HealthKit-Berechtigung erforderlich")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Berechtigung erteilen") {
                        requestAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    // Time Range Picker
                    Picker("Zeitraum", selection: $selectedTimeRange) {
                        ForEach(HeartRateTimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTimeRange) { _, _ in
                        loadHeartRateData()
                    }
                    
                    if !heartRateReadings.isEmpty {
                        // Stats
                        HStack(spacing: 12) {
                            heartRateStatBox(title: "Ø", value: Int(averageHeartRate), color: .blue)
                            heartRateStatBox(title: "Max", value: Int(maxHeartRate), color: .red)
                            heartRateStatBox(title: "Min", value: Int(minHeartRate), color: .green)
                        }
                        
                        // Compact Chart
                        Chart(heartRateReadings.prefix(20)) { reading in
                            LineMark(
                                x: .value("Zeit", reading.timestamp),
                                y: .value("Herzfrequenz", reading.heartRate)
                            )
                            .foregroundStyle(.red)
                            .interpolationMethod(.cardinal)
                            
                            AreaMark(
                                x: .value("Zeit", reading.timestamp),
                                y: .value("Herzfrequenz", reading.heartRate)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red.opacity(0.3), .red.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.cardinal)
                        }
                        .frame(height: 120)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let heartRate = value.as(Double.self) {
                                        Text("\(Int(heartRate))")
                                    }
                                }
                                AxisGridLine()
                                AxisTick()
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    } else if !isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "heart")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Keine Herzfrequenzdaten")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Für den gewählten Zeitraum sind keine Daten verfügbar.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Lade Herzfrequenzdaten...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .onAppear {
                    loadHeartRateData()
                }
                .alert("Fehler", isPresented: $showingError, presenting: error) { error in
                    Button("OK", role: .cancel) { self.error = nil }
                } message: { error in
                    Text(error.localizedDescription)
                }
            }
        }
        .appEdgePadding()
    }
    
    private func heartRateStatBox(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                
                Text("bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }
    
    private func requestAuthorization() {
        Task {
            do {
                try await workoutStore.requestHealthKitAuthorization()
                loadHeartRateData()
            } catch let healthKitError as HealthKitError {
                await MainActor.run {
                    self.error = healthKitError
                    self.showingError = true
                }
            } catch {
                await MainActor.run {
                    self.error = HealthKitError.notAuthorized
                    self.showingError = true
                }
            }
        }
    }
    
    private func loadHeartRateData() {
        guard workoutStore.healthKitManager.isAuthorized else { return }
        
        isLoading = true
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-selectedTimeRange.timeInterval)
        
        Task {
            do {
                let readings = try await workoutStore.readHeartRateData(from: startDate, to: endDate)
                
                await MainActor.run {
                    self.heartRateReadings = readings
                    self.isLoading = false
                }
            } catch let healthKitError as HealthKitError {
                await MainActor.run {
                    self.error = healthKitError
                    self.showingError = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = HealthKitError.notAuthorized
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
}

