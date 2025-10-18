import SwiftUI
import Charts
import SwiftData
import HealthKit
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Color Extensions (deprecated - use AppTheme instead)

private struct StatisticsScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct StatisticsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @StateObject private var cache = StatisticsCache.shared
    @State private var showingCalendar: Bool = false
    @State private var expandedVolumeCard: Bool = false
    @State private var expandedHealthCard: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    // Filter out active/incomplete workouts - only show completed sessions
    private var completedSessions: [WorkoutSessionEntity] {
        sessionEntities.filter { session in
            // Only include sessions with a duration (completed workouts)
            session.duration != nil && session.duration! > 0
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    // Cache invalidieren bei Datenänderungen
                    Color.clear
                        .frame(height: 0)
                        .onAppear {
                            cache.invalidateIfNeeded(
                                sessionCount: completedSessions.count,
                                recordsCount: workoutStore.getAllExerciseRecords().count
                            )
                        }
                        .onChange(of: completedSessions.count) { _, newCount in
                            cache.invalidateIfNeeded(
                                sessionCount: newCount,
                                recordsCount: workoutStore.getAllExerciseRecords().count
                            )
                        }
                    // Floating Glassmorphism Header
                    FloatingInsightsHeader(showCalendar: { showingCalendar = true })
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // 🆕 PHASE 1: Progression Score Hero Card
                    ProgressionScoreCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    // Hero-Card: Streak/Konsistenz
                    HeroStreakCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    // Smart Tips Card (AI-Coach)
                    SmartTipsCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    // Quick-Stats Grid (2x2)
                    QuickStatsGrid(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    // 🆕 PHASE 2: Wochenvergleich
                    WeekComparisonCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    // 🆕 PHASE 1: Top 5 Kraft-PRs
                    TopPRsCard()
                        .padding(.horizontal, 20)

                    // 🆕 PHASE 1: Muskelbalance (Volumen-Verteilung)
                    MuscleDistributionCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    // 🆕 PHASE 1: Sets pro Muskelgruppe mit Empfehlungen
                    WeeklySetsCard(sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    // Volumen-Chart Card (expandierbar)
                    VolumeChartCard(isExpanded: $expandedVolumeCard, sessionEntities: completedSessions)
                        .padding(.horizontal, 20)

                    // Personal Records Card (kompakt)
                    CompactPersonalRecordsCard()
                        .padding(.horizontal, 20)

                    // 🆕 PHASE 1: Recovery Index (HealthKit)
                    if workoutStore.healthKitManager.isAuthorized {
                        RecoveryCard(sessionEntities: completedSessions)
                            .padding(.horizontal, 20)
                    }

                    // Health Cards (optional, nur wenn Daten vorhanden)
                    if workoutStore.healthKitManager.isAuthorized {
                        CompactHealthCard(isExpanded: $expandedHealthCard, sessionEntities: completedSessions)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCalendar) {
            CalendarSessionsView()
        }
    }
}

// MARK: - New Modern Statistics Cards

// MARK: - Floating Glassmorphism Header
private struct FloatingInsightsHeader: View {
    let showCalendar: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)

            Text("Insights")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                showCalendar()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Hero Streak Card
private struct HeroStreakCard: View {
    let sessionEntities: [WorkoutSessionEntity]
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator

    @State private var cachedConsistencyWeeks: Int = 0
    @State private var cachedWorkoutsThisWeek: Int = 0
    @State private var cachedHeroText: (title: String, subtitle: String) = ("", "")
    @State private var updateTask: Task<Void, Never>?

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private func calculateStreakData() {
        // Calculate consistency weeks
        let calendar = Calendar.current
        let today = Date()
        var consecutiveWeeks = 0
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today

        for i in 0..<12 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: currentWeekStart) ?? currentWeekStart
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

            let hasSessionInWeek = sessionEntities.contains { session in
                session.date >= weekStart && session.date <= weekEnd
            }

            if hasSessionInWeek {
                consecutiveWeeks += 1
            } else {
                break
            }
        }

        cachedConsistencyWeeks = consecutiveWeeks

        // Calculate workouts this week
        cachedWorkoutsThisWeek = sessionEntities.filter { $0.date >= weekStart }.count

        // Calculate hero text
        if cachedConsistencyWeeks == 0 {
            cachedHeroText = ("Zeit für einen Neustart!", "Starte dein nächstes Training")
        } else if cachedConsistencyWeeks == 1 {
            cachedHeroText = ("1 Woche Streak! 🔥", "Dranbleiben lohnt sich!")
        } else {
            cachedHeroText = ("\(cachedConsistencyWeeks) Wochen Streak! 🔥", "Unglaublich konstant!")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(cachedHeroText.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(cachedHeroText.subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 12) {
                // Wochen-Visualisierung
                HStack(spacing: 4) {
                    ForEach(0..<min(cachedConsistencyWeeks, 8), id: \.self) { _ in
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                    }
                    if cachedConsistencyWeeks < 8 {
                        ForEach(0..<(8 - cachedConsistencyWeeks), id: \.self) { _ in
                            Circle()
                                .fill(.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                Spacer()
            }

            Divider()
                .background(.white.opacity(0.3))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diese Woche")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("\(cachedWorkoutsThisWeek)/\(workoutStore.weeklyGoal) Trainings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if cachedWorkoutsThisWeek >= workoutStore.weeklyGoal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(AppLayout.Spacing.extraLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.mossGreen, AppTheme.turquoiseBoost],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: AppTheme.mossGreen.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            scheduleUpdate()
        }
        .onChange(of: sessionEntities.count) { _, _ in
            scheduleUpdate()
        }
        .onDisappear {
            updateTask?.cancel()
        }
    }

    // Debounced update to prevent constant recalculations
    private func scheduleUpdate() {
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            guard !Task.isCancelled else { return }
            await MainActor.run {
                calculateStreakData()
            }
        }
    }
}

// MARK: - Quick Stats Grid
private struct QuickStatsGrid: View {
    let sessionEntities: [WorkoutSessionEntity]
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var cachedTrainingsThisMonth: Int = 0
    @State private var cachedTotalVolumeThisWeek: Double = 0
    @State private var cachedNewPRsThisWeek: Int = 0
    @State private var cachedPreviousWeekVolume: Double = 0
    @State private var cachedVolumeTrend: String = "→"
    @State private var updateTask: Task<Void, Never>?

    private var monthStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private func calculateStats() {
        // Trainings this month
        cachedTrainingsThisMonth = sessionEntities.filter { $0.date >= monthStart }.count

        // Volume this week
        cachedTotalVolumeThisWeek = sessionEntities
            .filter { $0.date >= weekStart }
            .reduce(0.0) { total, session in
                total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                    exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                        setTotal + (Double(set.reps) * set.weight)
                    }
                }
            }

        // PRs this week
        let allRecords = workoutStore.getAllExerciseRecords()
        cachedNewPRsThisWeek = allRecords.filter { record in
            Calendar.current.isDate(record.updatedAt, equalTo: Date(), toGranularity: .weekOfYear)
        }.count

        // Previous week volume
        let calendar = Calendar.current
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
        let previousWeekEnd = calendar.date(byAdding: .day, value: 6, to: previousWeekStart) ?? previousWeekStart

        cachedPreviousWeekVolume = sessionEntities
            .filter { $0.date >= previousWeekStart && $0.date <= previousWeekEnd }
            .reduce(0.0) { total, session in
                total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                    exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                        setTotal + (Double(set.reps) * set.weight)
                    }
                }
            }

        // Volume trend
        guard cachedPreviousWeekVolume > 0 else {
            cachedVolumeTrend = "Neu"
            return
        }
        let change = ((cachedTotalVolumeThisWeek - cachedPreviousWeekVolume) / cachedPreviousWeekVolume) * 100
        if change > 5 {
            cachedVolumeTrend = "↗ Steigend"
        } else if change < -5 {
            cachedVolumeTrend = "↘ Fallend"
        } else {
            cachedVolumeTrend = "→ Stabil"
        }
    }

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Volumen
            QuickStatCard(
                icon: "scalemass.fill",
                iconColor: AppTheme.mossGreen,
                value: String(format: "%.1ft", cachedTotalVolumeThisWeek / 1000),
                label: "Volumen",
                subtitle: cachedVolumeTrend
            )
            .equatable()

            // Neue PRs
            QuickStatCard(
                icon: "trophy.fill",
                iconColor: AppTheme.powerOrange,
                value: "\(cachedNewPRsThisWeek)",
                label: "Neue PRs",
                subtitle: "diese Woche"
            )
            .equatable()

            // Trainings
            QuickStatCard(
                icon: "dumbbell.fill",
                iconColor: colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue,
                value: "\(cachedTrainingsThisMonth)",
                label: "Trainings",
                subtitle: "diesen Monat"
            )
            .equatable()

            // Trend
            QuickStatCard(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: AppTheme.turquoiseBoost,
                value: cachedVolumeTrend.components(separatedBy: " ").last ?? "→",
                label: "Trend",
                subtitle: "vs. Vorwoche"
            )
            .equatable()
        }
        .onAppear {
            scheduleUpdate()
        }
        .onChange(of: sessionEntities.count) { _, _ in
            scheduleUpdate()
        }
        .onDisappear {
            updateTask?.cancel()
        }
    }

    // Debounced update to prevent constant recalculations
    private func scheduleUpdate() {
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            guard !Task.isCancelled else { return }
            await MainActor.run {
                calculateStats()
            }
        }
    }
}

private struct QuickStatCard: View, Equatable {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    static func == (lhs: QuickStatCard, rhs: QuickStatCard) -> Bool {
        lhs.icon == rhs.icon &&
        lhs.value == rhs.value &&
        lhs.label == rhs.label &&
        lhs.subtitle == rhs.subtitle
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppLayout.Spacing.standard)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Volume Chart Card (Expandable)
private struct VolumeChartCard: View {
    @StateObject private var cache = StatisticsCache.shared
    @Binding var isExpanded: Bool
    let sessionEntities: [WorkoutSessionEntity]
    @Environment(\.colorScheme) private var colorScheme

    @State private var cachedLast4WeeksData: [(week: String, volume: Double)] = []
    @State private var updateTask: Task<Void, Never>?

    private func calculateChartData() {
        let calendar = Calendar.current
        var data: [(String, Double)] = []

        for weekOffset in (0..<4).reversed() {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) ?? Date()
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

            let volume = sessionEntities
                .filter { $0.date >= weekStart && $0.date <= weekEnd }
                .reduce(0.0) { total, session in
                    total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                        exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                            setTotal + (Double(set.reps) * set.weight)
                        }
                    }
                }

            let weekNumber = calendar.component(.weekOfYear, from: weekStart)
            data.append(("KW\(weekNumber)", volume))
        }

        cachedLast4WeeksData = data
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)
                        Text("Volumen-Verlauf")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Chart(cachedLast4WeeksData, id: \.week) { item in
                    BarMark(
                        x: .value("Woche", item.week),
                        y: .value("Volumen", item.volume / 1000)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.deepBlue, AppTheme.mossGreen],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let vol = value.as(Double.self) {
                                Text("\(vol, specifier: "%.1f")t")
                            }
                        }
                        AxisGridLine()
                    }
                }
            } else {
                // Mini-Chart Preview
                Chart(cachedLast4WeeksData, id: \.week) { item in
                    BarMark(
                        x: .value("Woche", item.week),
                        y: .value("Volumen", item.volume / 1000)
                    )
                    .foregroundStyle(AppTheme.deepBlue.opacity(0.6))
                    .cornerRadius(4)
                }
                .frame(height: 60)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(AppLayout.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 4)
        .onAppear {
            calculateChartData()
        }
        .onChange(of: cache.cacheVersion) { _, _ in
            scheduleUpdate()
        }
        .onDisappear {
            updateTask?.cancel()
        }
    }

    // Debounced update to prevent constant recalculations
    private func scheduleUpdate() {
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            guard !Task.isCancelled else { return }
            await MainActor.run {
                calculateChartData()
            }
        }
    }
}

// MARK: - Compact Personal Records Card
private struct CompactPersonalRecordsCard: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @State private var showingAllRecords = false
    @Environment(\.colorScheme) private var colorScheme

    private var recentRecords: [ExerciseRecord] {
        let allRecords = workoutStore.getAllExerciseRecords()
        return Array(allRecords
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(AppTheme.powerOrange)
                    Text("Personal Records")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button("Alle →") {
                    showingAllRecords = true
                }
                .font(.caption)
                .foregroundStyle(colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)
            }

            if recentRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("Noch keine Records")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentRecords, id: \.id) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.exerciseName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                HStack(spacing: 8) {
                                    if record.maxWeight > 0 {
                                        Text("\(String(format: "%.0f", record.maxWeight)) kg")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.turquoiseBoost)
                                    }

                                    if record.maxReps > 0 {
                                        Text("\(record.maxReps) Wdh.")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.mossGreen)
                                    }
                                }
                            }

                            Spacer()

                            Text(timeAgo(record.updatedAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if record.id != recentRecords.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(AppLayout.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 4)
        .sheet(isPresented: $showingAllRecords) {
            ExerciseRecordsView()
                .environmentObject(workoutStore)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Heute"
        } else if calendar.isDateInYesterday(date) {
            return "Gestern"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return "vor \(days)d"
            } else {
                let weeks = days / 7
                return "vor \(weeks)w"
            }
        }
    }
}

// MARK: - Compact Health Card (Expandable)
private struct CompactHealthCard: View {
    @Binding var isExpanded: Bool
    let sessionEntities: [WorkoutSessionEntity]
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @State private var heartRateReadings: [HeartRateReading] = []
    @State private var weightReadings: [BodyWeightReading] = []
    @State private var isLoading = false
    @Environment(\.colorScheme) private var colorScheme

    private var averageHeartRate: Double {
        guard !heartRateReadings.isEmpty else { return 0 }
        return heartRateReadings.reduce(0) { $0 + $1.heartRate } / Double(heartRateReadings.count)
    }

    private var currentWeight: Double? {
        weightReadings.last?.weight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("Gesundheitsdaten")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if !isExpanded {
                // Compact View
                HStack(spacing: 16) {
                    if averageHeartRate > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text("\(Int(averageHeartRate)) bpm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let weight = currentWeight {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.stand")
                                .font(.caption)
                                .foregroundStyle(colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)
                            Text("\(weight, specifier: "%.1f") kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            } else {
                // Expanded View
                VStack(alignment: .leading, spacing: 12) {
                    if averageHeartRate > 0 {
                        HStack {
                            Text("Ø Herzfrequenz (7d)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(averageHeartRate)) bpm")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }

                    if let weight = currentWeight {
                        HStack {
                            Text("Gewicht")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(weight, specifier: "%.1f") kg")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }

                    if heartRateReadings.isEmpty && weightReadings.isEmpty && !isLoading {
                        Text("Keine Daten verfügbar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(AppLayout.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 4)
        .onAppear {
            loadHealthData()
        }
    }

    private func loadHealthData() {
        guard workoutStore.healthKitManager.isAuthorized else { return }

        isLoading = true
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-7 * 24 * 3600) // 7 days

        Task {
            do {
                async let heartData = workoutStore.readHeartRateData(from: startDate, to: endDate)
                async let weightData = workoutStore.readWeightData(from: startDate, to: endDate)

                let (hr, wt) = try await (heartData, weightData)

                await MainActor.run {
                    self.heartRateReadings = hr
                    self.weightReadings = wt
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Old Statistics Cards (kept for reference, will be removed later)

// 1. Consistency / Wochenfortschritt
private struct ConsistencyCardView: View {
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    
    private var consistencyWeeks: Int {
        let calendar = Calendar.current
        let today = Date()
        var consecutiveWeeks = 0
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        for i in 0..<12 { // Maximal 12 Wochen zurückschauen
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: currentWeekStart) ?? currentWeekStart
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            
            let hasSessionInWeek = sessionEntities.contains { session in
                session.date >= weekStart && session.date <= weekEnd
            }
            
            if hasSessionInWeek {
                consecutiveWeeks += 1
            } else {
                break
            }
        }
        
        return consecutiveWeeks
    }
    
    private var consistencyText: (title: String, subtitle: String) {
        switch consistencyWeeks {
        case 0:
            return ("Zeit für einen Neustart!", "Los geht's mit dem Training.")
        case 1:
            return ("Du bist 1 Woche dabei.", "Dranbleiben lohnt sich!")
        case 2:
            return ("Du bist 2 Wochen in Folge", "im Training. Super Anfang!")
        case 3...4:
            return ("Du bist \(consistencyWeeks) Wochen in Folge", "im Training. Gewohnheit bildet sich!")
        case 5...8:
            return ("Du bist \(consistencyWeeks) Wochen in Folge", "im Training. Starke Routine!")
        case 9...12:
            return ("Du bist \(consistencyWeeks) Wochen in Folge", "im Training. Beeindruckend!")
        default:
            return ("Du bist \(consistencyWeeks) Wochen in Folge", "im Training. Unglaublich konstant!")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Removed emoji Text here
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(consistencyText.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(consistencyText.subtitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Mini Kalender-Indikator
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(0..<4) { week in
                            Circle()
                                .fill(week < min(consistencyWeeks, 4) ? AppTheme.mossGreen : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    HStack(spacing: 2) {
                        ForEach(0..<3) { week in
                            Circle()
                                .fill((week + 4) < min(consistencyWeeks, 7) ? AppTheme.mossGreen : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                        Circle()
                            .fill(.clear)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(AppLayout.Spacing.large)
    }
}

// 2. Personal Records
private struct PersonalRecordCardView: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAllRecords = false
    
    private var recentRecords: [ExerciseRecord] {
        let allRecords = workoutStore.getAllExerciseRecords()
        return Array(allRecords
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3))
    }
    
    private var totalRecordsCount: Int {
        workoutStore.getAllExerciseRecords().count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(AppTheme.powerOrange)
                        .font(.title3)
                    
                    Text("Personal Records")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button("Alle anzeigen") {
                    showingAllRecords = true
                }
                .font(.caption)
                .foregroundStyle(Color.customBlue)
            }
            
            if recentRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    Text("Keine Personal Records")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Führe Trainings aus, um deine ersten Records zu erzielen!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentRecords, id: \.id) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.exerciseName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack(spacing: 12) {
                                    if record.maxWeight > 0 {
                                        Text("\(String(format: "%.0f", record.maxWeight)) kg")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.turquoiseBoost)
                                    }
                                    
                                    if record.maxReps > 0 {
                                        Text("\(record.maxReps) Wdh.")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.mossGreen)
                                    }
                                    
                                    if record.bestEstimatedOneRepMax > 0 {
                                        Text("1RM: \(String(format: "%.0f", record.bestEstimatedOneRepMax)) kg")
                                            .font(.caption)
                                            .foregroundStyle(colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Text(timeAgo(record.updatedAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        
                        if record.id != recentRecords.last?.id {
                            Divider()
                        }
                    }
                    
                    if totalRecordsCount > 3 {
                        HStack {
                            Spacer()
                            Text("und \(totalRecordsCount - 3) weitere...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(AppLayout.Spacing.large)
        .background(
            LinearGradient(
                colors: [AppTheme.deepBlue.opacity(0.1), AppTheme.mossGreen.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .sheet(isPresented: $showingAllRecords) {
            ExerciseRecordsView()
                .environmentObject(workoutStore)
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Heute"
        } else if calendar.isDateInYesterday(date) {
            return "Gestern"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return "vor \(days)d"
            } else {
                let weeks = days / 7
                return "vor \(weeks)w"
            }
        }
    }
}

// 3. Weekly Volume
private struct WeeklyVolumeCardView: View {
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    
    private var weeklyData: (currentVolume: Double, previousVolume: Double, weekNumber: Int) {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekNumber = calendar.component(.weekOfYear, from: now)
        
        // Aktuelle Woche
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let currentWeekEnd = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
        
        // Vorwoche
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
        let previousWeekEnd = calendar.date(byAdding: .day, value: 6, to: previousWeekStart) ?? previousWeekStart
        
        let currentVolume = sessionEntities
            .filter { $0.date >= currentWeekStart && $0.date <= currentWeekEnd }
            .reduce(0.0) { total, session in
                total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                    exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                        setTotal + (Double(set.reps) * set.weight)
                    }
                }
            }
        
        let previousVolume = sessionEntities
            .filter { $0.date >= previousWeekStart && $0.date <= previousWeekEnd }
            .reduce(0.0) { total, session in
                total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                    exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                        setTotal + (Double(set.reps) * set.weight)
                    }
                }
            }
        
        return (currentVolume, previousVolume, currentWeekNumber)
    }
    
    private var percentageChange: Double {
        let data = weeklyData
        guard data.previousVolume > 0 else { return 0 }
        return ((data.currentVolume - data.previousVolume) / data.previousVolume) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Removed emoji Text here
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gesamtvolumen in KW \(weeklyData.weekNumber)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(weeklyData.currentVolume.formatted(.number.precision(.fractionLength(1)))) kg")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    if weeklyData.previousVolume > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: percentageChange >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                                .foregroundStyle(percentageChange >= 0 ? AppTheme.mossGreen : .gray)
                            Text("\(abs(percentageChange).formatted(.number.precision(.fractionLength(0))))% zur Vorwoche")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Mini-Chart (vereinfacht)
                VStack(spacing: 2) {
                    ForEach(0..<7) { day in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.mossGreen.opacity(Double.random(in: 0.3...1.0)))
                            .frame(width: 6, height: CGFloat.random(in: 8...24))
                    }
                }
            }
        }
        .padding(AppLayout.Spacing.large)
    }
}

// 4. Muscle Group Balance
private struct MuscleGroupBalanceCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    
    private var muscleBalance: (push: Double, pull: Double, legs: Double, isBalanced: Bool) {
        let recentSessions = sessionEntities.prefix(10) // Letzte 10 Sessions
        
        var pushVolume = 0.0
        var pullVolume = 0.0
        var legVolume = 0.0
        
        for session in recentSessions {
            for exercise in session.exercises {
                let volume = exercise.sets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
                
                // Korrekte Muskelgruppen-Zuordnung basierend auf tatsächlichen Muskelgruppen
                guard let exerciseEntity = exercise.exercise else { continue }
                let muscleGroupsRaw = exerciseEntity.muscleGroupsRaw
                
                // Konvertiere raw strings zu MuscleGroup enums
                let muscleGroups = muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
                
                // Bestimme primäre Kategorie basierend auf Muskelgruppen
                let category = categorizeExercise(muscleGroups: muscleGroups)
                switch category {
                case "push":
                    pushVolume += volume
                case "pull":
                    pullVolume += volume
                case "legs":
                    legVolume += volume
                default:
                    pushVolume += volume // Fallback
                }
            }
        }
        
        let total = pushVolume + pullVolume + legVolume
        guard total > 0 else { return (0, 0, 0, true) }
        
        let pushRatio = pushVolume / total
        let pullRatio = pullVolume / total
        let legRatio = legVolume / total
        
        // Balance-Check: Keine Kategorie sollte < 20% oder > 50% haben
        let isBalanced = pushRatio >= 0.2 && pushRatio <= 0.5 &&
                        pullRatio >= 0.2 && pullRatio <= 0.5 &&
                        legRatio >= 0.2 && legRatio <= 0.5
        
        return (pushRatio, pullRatio, legRatio, isBalanced)
    }
    
    // MARK: - Hilfsfunktion für Push/Pull/Legs Zuordnung
    
    private func categorizeExercise(muscleGroups: [MuscleGroup]) -> String {
        // Prioritätsreihenfolge für gemischte Übungen
        
        // Spezielle Fälle zuerst:
        // Kreuzheben und ähnliche (back+legs+glutes) → Pull
        // Thrusters und ähnliche (shoulders+legs ohne back) → Push
        
        // 1. Pull-Übungen haben Vorrang
        if muscleGroups.contains(.back) || muscleGroups.contains(.biceps) {
            return "pull"
        }
        // 2. Push-Übungen (Brust, Trizeps, oder Schultern ohne Rücken)
        else if muscleGroups.contains(.chest) || muscleGroups.contains(.triceps) ||
                (muscleGroups.contains(.shoulders) && !muscleGroups.contains(.back)) {
            return "push"
        }
        // 3. Reine Bein-Übungen (Legs/Glutes ohne Back)
        else if (muscleGroups.contains(.legs) || muscleGroups.contains(.glutes)) &&
                !muscleGroups.contains(.back) {
            return "legs"
        }
        // 4. Fallback für Übungen wie reine Abs, Cardio
        else {
            return "push" // Default zu Push für neutrale Übungen
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Push/Pull/Legs Balance")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(muscleBalance.isBalanced ? AppTheme.mossGreen : .gray)
                    .frame(width: 12, height: 12)
            }
            
            // Donut Chart (vereinfacht mit Balken)
            VStack(spacing: 8) {
                balanceBar(title: "Push", ratio: muscleBalance.push, color: colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)
                balanceBar(title: "Pull", ratio: muscleBalance.pull, color: AppTheme.mossGreen)
                balanceBar(title: "Legs", ratio: muscleBalance.legs, color: .gray)
            }
            
            Text(muscleBalance.isBalanced ? "Ausgewogenes Training" : "Unausgewogen - mehr Varianz")
                .font(.caption)
                .foregroundStyle(muscleBalance.isBalanced ? AppTheme.mossGreen : .gray)
        }
        .padding(AppLayout.Spacing.large)
    }
    
    private func balanceBar(title: String, ratio: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .frame(width: 40, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * ratio, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(ratio * 100))%")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// 5. Average Weight per Exercise
private struct AverageWeightCardView: View {
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    
    private var topExercises: [(name: String, avgWeight: Double, change: Double)] {
        let recentSessions = sessionEntities.prefix(20) // Letzte 20 Sessions
        let olderSessions = sessionEntities.dropFirst(20).prefix(20) // Davor liegende 20 Sessions
        
        var recentWeights: [String: [Double]] = [:]
        var olderWeights: [String: [Double]] = [:]
        
        // Sammle Gewichte für jede Übung
        for session in recentSessions {
            for exercise in session.exercises {
                let name = exercise.exercise?.name ?? "Unbekannt"
                let weights = exercise.sets.map { $0.weight }
                recentWeights[name, default: []].append(contentsOf: weights)
            }
        }
        
        for session in olderSessions {
            for exercise in session.exercises {
                let name = exercise.exercise?.name ?? "Unbekannt"
                let weights = exercise.sets.map { $0.weight }
                olderWeights[name, default: []].append(contentsOf: weights)
            }
        }
        
        // Berechne Durchschnitte und Veränderungen
        var results: [(name: String, avgWeight: Double, change: Double)] = []
        
        for (name, weights) in recentWeights {
            guard !weights.isEmpty else { continue }
            let avgWeight = weights.reduce(0, +) / Double(weights.count)
            
            let change: Double
            if let oldWeights = olderWeights[name], !oldWeights.isEmpty {
                let oldAvg = oldWeights.reduce(0, +) / Double(oldWeights.count)
                change = ((avgWeight - oldAvg) / oldAvg) * 100
            } else {
                change = 0
            }
            
            let namedResult = (name: name, avgWeight: avgWeight, change: change)
            results.append(namedResult)
        }
        
        // Sort by weight (descending)
        results.sort { first, second in
            return first.avgWeight > second.avgWeight
        }
        
        // Take only first 3 results
        let limitedResults = Array(results.prefix(3))
        
        return limitedResults
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {

                Text("Durchschnitt Gewicht pro Übung")
                    .font(.headline)
            }
            
            if topExercises.isEmpty {
                VStack(spacing: 8) {
                    Text("Keine Daten verfügbar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Trainiere mehr, um Statistiken zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topExercises.enumerated()), id: \.offset) { index, exercise in
                        exerciseRow(exercise: exercise, isLast: index == topExercises.count - 1)
                    }
                }
            }
        }
        .padding(AppLayout.Spacing.large)
    }
    
    private func exerciseRow(exercise: (name: String, avgWeight: Double, change: Double), isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Spacer()
                
                Text("Ø \(exercise.avgWeight.formatted(.number.precision(.fractionLength(1)))) kg")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                changeIndicator(change: exercise.change)
            }
            .padding(.vertical, 4)
            
            if !isLast {
                Divider()
            }
        }
    }
    
    private func changeIndicator(change: Double) -> some View {
        let isPositive = change >= 0
        let color = isPositive ? AppTheme.mossGreen : Color.gray
        let icon = isPositive ? "arrow.up" : "arrow.down"
        
        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text("\(abs(change).formatted(.number.precision(.fractionLength(0))))%")
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(width: 44)
    }
}

// 6. Session Intensity
private struct SessionIntensityCardView: View {
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    
    private var latestSessionScore: Int {
        guard let latestSession = sessionEntities.first else { return 0 }
        
        // Vereinfachte Intensitäts-Berechnung
        let totalSets = latestSession.exercises.reduce(0) { $0 + $1.sets.count }
        let avgWeight = latestSession.exercises.reduce(0.0) { sessionTotal, exercise in
            let exerciseAvg = exercise.sets.reduce(0.0) { $0 + $1.weight } / Double(max(exercise.sets.count, 1))
            return sessionTotal + exerciseAvg
        } / Double(max(latestSession.exercises.count, 1))
        
        let duration = latestSession.duration ?? 0
        
        // Score basierend auf Sätzen, Gewicht und Effizienz
        let setsScore = min(Double(totalSets) * 5, 50) // Max 50 Punkte für Sätze
        let weightScore = min(avgWeight / 2, 30) // Max 30 Punkte für Gewicht
        let efficiencyScore = duration > 0 ? min(Double(totalSets) / (duration / 3600) * 10, 20) : 0 // Max 20 Punkte für Effizienz
        
        return Int(setsScore + weightScore + efficiencyScore)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Removed emoji Text here
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Letzte Session")
                        .font(.headline)
                    Text("\(latestSessionScore)/100 Intensität")
                        .font(.headline)
                }
                
                Spacer()
                
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: Double(latestSessionScore) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.mossGreen, AppTheme.deepBlue, .gray, .gray],
                                startPoint: .trailing,
                                endPoint: .leading
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(latestSessionScore)")
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
        }
        .padding(AppLayout.Spacing.large)
    }
}

// 7. Plateau Check
private struct PlateauCheckCardView: View {
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    
    private var plateauAlert: (exercise: String, weeks: Int)? {
        let recentSessions = sessionEntities.prefix(30) // Letzte 30 Sessions
        
        var exerciseProgress: [String: [Double]] = [:]
        
        // Sammle max Gewichte pro Übung über Zeit
        for session in recentSessions {
            for exercise in session.exercises {
                let name = exercise.exercise?.name ?? "Unbekannt"
                let maxWeight = exercise.sets.map { $0.weight }.max() ?? 0
                exerciseProgress[name, default: []].append(maxWeight)
            }
        }
        
        // Suche nach Stagnation (4+ Sessions ohne Verbesserung)
        for (name, weights) in exerciseProgress {
            guard weights.count >= 4 else { continue }
            
            let recentWeights = Array(weights.prefix(8)) // Letzte 8 Einträge
            let maxRecent = recentWeights.max() ?? 0
            
            // Check ob in den letzten 4+ Sessions keine Verbesserung
            var stagnantCount = 0
            for weight in recentWeights {
                if weight < maxRecent * 0.95 { // 5% Toleranz
                    stagnantCount += 1
                } else {
                    break
                }
            }
            
            if stagnantCount >= 4 {
                let estimatedWeeks = stagnantCount / 2 // Grobe Schätzung
                return (name, estimatedWeeks)
            }
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Removed emoji status Text here
                
                VStack(alignment: .leading, spacing: 4) {
                    if let alert = plateauAlert {
                        Text("Dein \(alert.exercise) stagniert")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("seit \(alert.weeks) Wochen.")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Zeit für Variation?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Alles läuft super!")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Kein Plateau erkannt.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding(AppLayout.Spacing.large)
        .overlay(
            Rectangle()
                .stroke(plateauAlert != nil ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 2)
                .padding(.horizontal, 20)
        )
    }
}

private struct ProgressOverviewCardView: View {
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    private var lastSession: WorkoutSession? {
        let session = sessionEntities.first.map { WorkoutSession(entity: $0) }
        // Debug information to verify imported sessions are included
        if let session = session {
            let isImported = session.notes.contains("Importiert aus")
            print("Letzte Session für Statistik: \(session.name) (Importiert: \(isImported ? "Ja" : "Nein"))")
        }
        return session
    }

    private var lastVolume: Double? {
        guard let session = lastSession else { return nil }
        return session.exercises.reduce(0) { partial, ex in
            partial + ex.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private var lastDateText: String {
        guard let session = lastSession else { return "–" }
        let formatter = DateFormatter()
        // Always use German for this app
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("ddMM")
        return formatter.string(from: session.date)
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
                statBox(title: "Gewicht", value: lastVolumeText, icon: "scalemass.fill", tint: AppTheme.mossGreen)
                statBox(title: "Datum", value: lastDateText, icon: "calendar", tint: .gray)
                statBox(title: "Übungen", value: lastExerciseCountText, icon: "list.bullet", tint: .gray)
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
        let sessions = sessionEntities.prefix(2).map { WorkoutSession(entity: $0) }
        // Debug information
        let importedCount = sessions.filter { $0.notes.contains("Importiert aus") }.count
        if importedCount > 0 {
            print("Delta-Berechnung nutzt \(importedCount) importierte Sessions von \(sessions.count) Gesamt-Sessions")
        }
        return sessions
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
            .padding(AppLayout.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .appEdgePadding()
    }
}

// MARK: - Bestehende Bereiche (unverändert)

