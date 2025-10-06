import SwiftUI
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
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var showingCalendar: Bool = false
    @State private var expandedVolumeCard: Bool = false
    @State private var expandedBalanceCard: Bool = false
    @State private var expandedHealthCard: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    private var displaySessions: [WorkoutSession] {
        sessionEntities.map { WorkoutSession(entity: $0) }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Floating Glassmorphism Header
                    FloatingInsightsHeader(showCalendar: { showingCalendar = true })
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Hero-Card: Streak/Konsistenz
                    HeroStreakCard()
                        .padding(.horizontal, 20)

                    // Quick-Stats Grid (2x2)
                    QuickStatsGrid()
                        .padding(.horizontal, 20)

                    // Volumen-Chart Card (expandierbar)
                    VolumeChartCard(isExpanded: $expandedVolumeCard)
                        .padding(.horizontal, 20)

                    // Personal Records Card (kompakt)
                    CompactPersonalRecordsCard()
                        .padding(.horizontal, 20)

                    // Balance Card (expandierbar)
                    BalanceCard(isExpanded: $expandedBalanceCard)
                        .padding(.horizontal, 20)

                    // Health Cards (optional, nur wenn Daten vorhanden)
                    if workoutStore.healthKitManager.isAuthorized {
                        CompactHealthCard(isExpanded: $expandedHealthCard)
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
                .foregroundStyle(AppTheme.deepBlue)

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
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    private var consistencyWeeks: Int {
        let calendar = Calendar.current
        let today = Date()
        var consecutiveWeeks = 0
        var currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today

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

        return consecutiveWeeks
    }

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var workoutsThisWeek: Int {
        sessionEntities.filter { $0.date >= weekStart }.count
    }

    @EnvironmentObject private var workoutStore: WorkoutStore

    private var weeklyGoal: Int {
        workoutStore.weeklyGoal
    }

    private var heroText: (title: String, subtitle: String) {
        if consistencyWeeks == 0 {
            return ("Zeit für einen Neustart!", "Starte dein nächstes Training")
        } else if consistencyWeeks == 1 {
            return ("1 Woche Streak! 🔥", "Dranbleiben lohnt sich!")
        } else {
            return ("\(consistencyWeeks) Wochen Streak! 🔥", "Unglaublich konstant!")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(heroText.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(heroText.subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 12) {
                // Wochen-Visualisierung
                HStack(spacing: 4) {
                    ForEach(0..<min(consistencyWeeks, 8), id: \.self) { _ in
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                    }
                    if consistencyWeeks < 8 {
                        ForEach(0..<(8 - consistencyWeeks), id: \.self) { _ in
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

                    Text("\(workoutsThisWeek)/\(weeklyGoal) Trainings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if workoutsThisWeek >= weeklyGoal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(24)
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
    }
}

// MARK: - Quick Stats Grid
private struct QuickStatsGrid: View {
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    @EnvironmentObject private var workoutStore: WorkoutStore

    private var monthStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var trainingsThisMonth: Int {
        sessionEntities.filter { $0.date >= monthStart }.count
    }

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var totalVolumeThisWeek: Double {
        sessionEntities
            .filter { $0.date >= weekStart }
            .reduce(0.0) { total, session in
                total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                    exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                        setTotal + (Double(set.reps) * set.weight)
                    }
                }
            }
    }

    private var newPRsThisWeek: Int {
        let allRecords = workoutStore.getAllExerciseRecords()
        return allRecords.filter { record in
            Calendar.current.isDate(record.updatedAt, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    private var previousWeekVolume: Double {
        let calendar = Calendar.current
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
        let previousWeekEnd = calendar.date(byAdding: .day, value: 6, to: previousWeekStart) ?? previousWeekStart

        return sessionEntities
            .filter { $0.date >= previousWeekStart && $0.date <= previousWeekEnd }
            .reduce(0.0) { total, session in
                total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
                    exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
                        setTotal + (Double(set.reps) * set.weight)
                    }
                }
            }
    }

    private var volumeTrend: String {
        guard previousWeekVolume > 0 else { return "Neu" }
        let change = ((totalVolumeThisWeek - previousWeekVolume) / previousWeekVolume) * 100
        if change > 5 {
            return "↗ Steigend"
        } else if change < -5 {
            return "↘ Fallend"
        } else {
            return "→ Stabil"
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
                value: String(format: "%.1ft", totalVolumeThisWeek / 1000),
                label: "Volumen",
                subtitle: volumeTrend
            )

            // Neue PRs
            QuickStatCard(
                icon: "trophy.fill",
                iconColor: AppTheme.powerOrange,
                value: "\(newPRsThisWeek)",
                label: "Neue PRs",
                subtitle: "diese Woche"
            )

            // Trainings
            QuickStatCard(
                icon: "dumbbell.fill",
                iconColor: AppTheme.deepBlue,
                value: "\(trainingsThisMonth)",
                label: "Trainings",
                subtitle: "diesen Monat"
            )

            // Trend
            QuickStatCard(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: AppTheme.turquoiseBoost,
                value: volumeTrend.components(separatedBy: " ").last ?? "→",
                label: "Trend",
                subtitle: "vs. Vorwoche"
            )
        }
    }
}

private struct QuickStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

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
        .padding(16)
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
    @Binding var isExpanded: Bool
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    @Environment(\.colorScheme) private var colorScheme

    private var last4WeeksData: [(week: String, volume: Double)] {
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

        return data
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
                            .foregroundStyle(AppTheme.deepBlue)
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
                Chart(last4WeeksData, id: \.week) { item in
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
                Chart(last4WeeksData, id: \.week) { item in
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Compact Personal Records Card
private struct CompactPersonalRecordsCard: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
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
                .foregroundStyle(AppTheme.deepBlue)
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
        .padding(20)
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

// MARK: - Balance Card (Expandable)
private struct BalanceCard: View {
    @Binding var isExpanded: Bool
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]
    @Environment(\.colorScheme) private var colorScheme

    private var muscleBalance: (push: Double, pull: Double, legs: Double, isBalanced: Bool) {
        let recentSessions = sessionEntities.prefix(10)

        var pushVolume = 0.0
        var pullVolume = 0.0
        var legVolume = 0.0

        for session in recentSessions {
            for exercise in session.exercises {
                let volume = exercise.sets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }

                guard let exerciseEntity = exercise.exercise else { continue }
                let muscleGroupsRaw = exerciseEntity.muscleGroupsRaw
                let muscleGroups = muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }

                let category = categorizeExercise(muscleGroups: muscleGroups)
                switch category {
                case "push":
                    pushVolume += volume
                case "pull":
                    pullVolume += volume
                case "legs":
                    legVolume += volume
                default:
                    pushVolume += volume
                }
            }
        }

        let total = pushVolume + pullVolume + legVolume
        guard total > 0 else { return (0, 0, 0, true) }

        let pushRatio = pushVolume / total
        let pullRatio = pullVolume / total
        let legRatio = legVolume / total

        let isBalanced = pushRatio >= 0.2 && pushRatio <= 0.5 &&
                        pullRatio >= 0.2 && pullRatio <= 0.5 &&
                        legRatio >= 0.2 && legRatio <= 0.5

        return (pushRatio, pullRatio, legRatio, isBalanced)
    }

    private func categorizeExercise(muscleGroups: [MuscleGroup]) -> String {
        if muscleGroups.contains(.back) || muscleGroups.contains(.biceps) {
            return "pull"
        } else if muscleGroups.contains(.chest) || muscleGroups.contains(.triceps) ||
                (muscleGroups.contains(.shoulders) && !muscleGroups.contains(.back)) {
            return "push"
        } else if (muscleGroups.contains(.legs) || muscleGroups.contains(.glutes)) &&
                !muscleGroups.contains(.back) {
            return "legs"
        } else {
            return "push"
        }
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
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(muscleBalance.isBalanced ? AppTheme.mossGreen : .orange)
                        Text("Push/Pull/Legs Balance")
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

            VStack(spacing: isExpanded ? 12 : 8) {
                balanceBar(title: "Push", ratio: muscleBalance.push, color: AppTheme.deepBlue)
                balanceBar(title: "Pull", ratio: muscleBalance.pull, color: AppTheme.mossGreen)
                balanceBar(title: "Legs", ratio: muscleBalance.legs, color: AppTheme.powerOrange)
            }

            if isExpanded {
                HStack {
                    Image(systemName: muscleBalance.isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(muscleBalance.isBalanced ? AppTheme.mossGreen : .orange)
                    Text(muscleBalance.isBalanced ? "Ausgewogenes Training" : "Unausgewogen - mehr Varianz empfohlen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: 0, y: 4)
    }

    private func balanceBar(title: String, ratio: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
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
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Compact Health Card (Expandable)
private struct CompactHealthCard: View {
    @Binding var isExpanded: Bool
    @EnvironmentObject private var workoutStore: WorkoutStore
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
                                .foregroundStyle(AppTheme.deepBlue)
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
        .padding(20)
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
        var currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
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
        .padding(20)
    }
}

// 2. Personal Records
private struct PersonalRecordCardView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
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
                .foregroundStyle(.blue)
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
                                            .foregroundStyle(AppTheme.deepBlue)
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
        .padding(20)
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
        .padding(20)
    }
}

// 4. Muscle Group Balance
private struct MuscleGroupBalanceCardView: View {
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
                balanceBar(title: "Push", ratio: muscleBalance.push, color: AppTheme.deepBlue)
                balanceBar(title: "Pull", ratio: muscleBalance.pull, color: AppTheme.mossGreen)
                balanceBar(title: "Legs", ratio: muscleBalance.legs, color: .gray)
            }
            
            Text(muscleBalance.isBalanced ? "Ausgewogenes Training" : "Unausgewogen - mehr Varianz")
                .font(.caption)
                .foregroundStyle(muscleBalance.isBalanced ? AppTheme.mossGreen : .gray)
        }
        .padding(20)
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
        .padding(20)
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
        .padding(20)
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
        .padding(20)
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
                            .foregroundColor(AppTheme.deepBlue)

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

                            Text({
                                let formatter = DateFormatter()
                                formatter.locale = Locale(identifier: "de_DE")
                                formatter.dateStyle = .medium
                                formatter.timeStyle = .none
                                return formatter.string(from: workout.date)
                            }())
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
                            Text("\(cal.component(.day, from: day))")
                                .font(.body.weight(isToday ? .bold : .regular))
                                .foregroundStyle(.primary)
                        }
                        Text(germanWeekdayAbbreviation(for: day))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(AppTheme.deepBlue)
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
        let formatter = DateFormatter()
        // Always use German for this app
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: displayedMonth)
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

                // Weekday symbols (German)
                HStack {
                    ForEach({
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "de_DE")
                        return formatter.veryShortWeekdaySymbols ?? ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
                    }(), id: \.self) { d in
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
                                            isSelected ? AppTheme.deepBlue.opacity(0.25) : (isToday ? Color(.systemGray4) : Color(.systemGray6))
                                        )
                                        .frame(width: 36, height: 36)
                                    Text(String(cal.component(.day, from: day)))
                                        .font(.subheadline.weight(.medium))
                                }
                                Circle()
                                    .fill(AppTheme.deepBlue)
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
                                    Text({
                                        let formatter = DateFormatter()
                                        formatter.locale = Locale(identifier: "de_DE")
                                        formatter.timeStyle = .short
                                        formatter.dateStyle = .none
                                        return formatter.string(from: session.date)
                                    }())
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

// 0. Last Workout Summary
private struct LastWorkoutCardView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    @State private var avgHeartRate: Int?
    @State private var isLoadingHR = false

    private var latestSession: WorkoutSessionEntity? { sessionEntities.first }

    private var sessionDateText: String {
        guard let date = latestSession?.date else { return "–" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var durationText: String {
        guard let dur = latestSession?.duration, dur > 0 else { return "–" }
        let minutes = Int(dur) / 60
        let seconds = Int(dur) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var exerciseCountText: String {
        guard let s = latestSession else { return "–" }
        return "\(s.exercises.count)"
    }

    private var totalVolumeKg: Double {
        guard let s = latestSession else { return 0 }
        return s.exercises.reduce(0) { partial, ex in
            partial + ex.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private var totalVolumeText: String {
        let kg = totalVolumeKg
        if kg >= 1000 { // show tons for very large
            let tons = kg / 1000.0
            return tons.formatted(.number.precision(.fractionLength(2))) + " t"
        } else {
            return kg.formatted(.number.precision(.fractionLength(0))) + " kg"
        }
    }

    // Gewicht pro Übung (innerhalb der letzten Session)
    private var perExerciseWeights: [(name: String, weight: Double)] {
        guard let s = latestSession else { return [] }
        var dict: [String: Double] = [:]
        for ex in s.exercises {
            let name = ex.exercise?.name ?? "Übung"
            let w = ex.sets.reduce(0.0) { partial, set in partial + (Double(set.reps) * set.weight) }
            dict[name, default: 0] += w
        }
        return dict.map { (name: $0.key, weight: $0.value) }
            .sorted(by: { a, b in a.weight > b.weight })
    }

    // Potentielle Rekorde: Wenn das Max-Gewicht in der letzten Session >= historisches Max davor
    private var potentialPRs: [String] {
        guard let latest = latestSession else { return [] }
        let latestDate = latest.date
        var prs: [String] = []
        for ex in latest.exercises {
            let name = ex.exercise?.name ?? "Übung"
            let latestMax = ex.sets.map { $0.weight }.max() ?? 0
            // Historisches Max vor dieser Session
            var historicalMax: Double = 0
            for s in sessionEntities.dropFirst() { // alle älteren Sessions
                if s.date >= latestDate { continue }
                if let match = s.exercises.first(where: { $0.exercise?.id == ex.exercise?.id }) {
                    let m = match.sets.map { $0.weight }.max() ?? 0
                    if m > historicalMax { historicalMax = m }
                }
            }
            if latestMax >= historicalMax && latestMax > 0 {
                prs.append(name)
            }
        }
        // Dedupe
        return Array(Set(prs))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Removed emoji Text here
                Text("Letztes Workout")
                    .font(.headline)
                Spacer()
                Text(sessionDateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if latestSession == nil {
                VStack(spacing: 8) {
                    Text("Noch keine Workouts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Starte ein Training, um Statistiken zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                // Top stats row
                HStack(spacing: 12) {
                    statBox(title: "Dauer", value: durationText, icon: "clock", tint: .gray)
                    statBox(title: "Übungen", value: exerciseCountText, icon: "list.bullet", tint: .gray)
                    statBox(title: "Gewicht", value: totalVolumeText, icon: "scalemass.fill", tint: AppTheme.mossGreen)
                    statBox(title: "Ø HF", value: avgHeartRateText, icon: "heart.fill", tint: .gray)
                }

                // Gewicht pro Übung
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gewicht pro Übung")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if perExerciseWeights.isEmpty {
                        Text("Keine Sätze in der letzten Session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(perExerciseWeights.enumerated()), id: \.offset) { idx, item in
                            HStack {
                                Text(item.name)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.weight.formatted(.number.precision(.fractionLength(0)))) kg")
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                            .font(.caption)
                            if idx < perExerciseWeights.count - 1 { Divider() }
                        }
                    }
                }

                // Mögliche Rekorde
                HStack(spacing: 6) {
                    Image(systemName: potentialPRs.isEmpty ? "trophy" : "trophy.fill")
                        .foregroundStyle(potentialPRs.isEmpty ? Color.secondary : AppTheme.deepBlue)
                    if potentialPRs.isEmpty {
                        Text("Keine neuen Rekorde erkannt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Mögliche Rekorde: \(potentialPRs.count)")
                            .font(.caption.weight(.semibold))
                        if let first = potentialPRs.first { Text("• \(first)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .onAppear { loadAverageHeartRate() }
    }

    private var avgHeartRateText: String {
        if isLoadingHR { return "…" }
        guard let hr = avgHeartRate else { return "–" }
        return "\(hr) bpm"
    }

    private func statBox(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.caption.weight(.semibold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }

    private func loadAverageHeartRate() {
        guard avgHeartRate == nil, let session = latestSession else { return }
        guard workoutStore.healthKitManager.isHealthDataAvailable, workoutStore.healthKitManager.isAuthorized else { return }

        let start = session.date
        let duration = session.duration ?? 60 * 60 // Fallback 60 Min
        let end = start.addingTimeInterval(duration)
        isLoadingHR = true
        Task {
            do {
                let readings = try await workoutStore.readHeartRateData(from: start, to: end)
                let avg = readings.isEmpty ? nil : Int((readings.reduce(0.0) { $0 + $1.heartRate }) / Double(readings.count))
                await MainActor.run {
                    self.avgHeartRate = avg
                    self.isLoadingHR = false
                }
            } catch {
                await MainActor.run {
                    self.avgHeartRate = nil
                    self.isLoadingHR = false
                }
            }
        }
    }
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
                    
                    VStack(spacing: 8) {
                        Button("Berechtigung erteilen") {
                            requestAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        NavigationLink("Debug-Informationen") {
                            HealthKitDebugView()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
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
                            heartRateStatBox(title: "Ø", value: Int(averageHeartRate), color: .gray)
                            heartRateStatBox(title: "Max", value: Int(maxHeartRate), color: AppTheme.deepBlue)
                            heartRateStatBox(title: "Min", value: Int(minHeartRate), color: AppTheme.mossGreen)
                        }
                        
                        // Compact Chart
                        Chart(heartRateReadings.prefix(20)) { reading in
                            LineMark(
                                x: .value("Zeit", reading.timestamp),
                                y: .value("Herzfrequenz", reading.heartRate)
                            )
                            .foregroundStyle(AppTheme.deepBlue)
                            .interpolationMethod(.cardinal)
                            
                            AreaMark(
                                x: .value("Zeit", reading.timestamp),
                                y: .value("Herzfrequenz", reading.heartRate)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.deepBlue.opacity(0.3), AppTheme.deepBlue.opacity(0.1)],
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
        .padding(20)
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
                // Status explizit aktualisieren nach Autorisierung
                await MainActor.run {
                    workoutStore.healthKitManager.updateAuthorizationStatus()
                }
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

// MARK: - Body Metrics Insights
struct BodyMetricsInsightsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var weightReadings: [BodyWeightReading] = []
    @State private var bodyFatReadings: [BodyFatReading] = []
    @State private var isLoading = false
    @State private var error: HealthKitError?
    @State private var showingError = false
    @State private var selectedTimeRange: BodyMetricsTimeRange = .month
    
    enum BodyMetricsTimeRange: String, CaseIterable {
        case month = "Monat"
        case threeMonths = "3 Monate"
        case sixMonths = "6 Monate"
        case year = "Jahr"
        
        var displayName: String { rawValue }
        
        var timeInterval: TimeInterval {
            switch self {
            case .month: return 30 * 24 * 3600
            case .threeMonths: return 90 * 24 * 3600
            case .sixMonths: return 180 * 24 * 3600
            case .year: return 365 * 24 * 3600
            }
        }
    }
    
    private var currentWeight: Double? {
        weightReadings.last?.weight
    }
    
    private var currentBodyFat: Double? {
        bodyFatReadings.last?.bodyFatPercentage
    }
    
    private var weightTrend: WeightTrend {
        guard weightReadings.count >= 2 else { return .stable }
        
        let recent = weightReadings.suffix(5)
        guard let first = recent.first?.weight, let last = recent.last?.weight else { return .stable }
        
        let difference = last - first
        if difference > 1.0 {
            return .increasing
        } else if difference < -1.0 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private var bodyFatTrend: BodyFatTrend {
        guard bodyFatReadings.count >= 2 else { return .stable }
        
        let recent = bodyFatReadings.suffix(5)
        guard let first = recent.first?.bodyFatPercentage, let last = recent.last?.bodyFatPercentage else { return .stable }
        
        let difference = last - first
        if difference > 2.0 {
            return .increasing
        } else if difference < -2.0 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    enum WeightTrend {
        case increasing, decreasing, stable

        var color: Color {
            switch self {
            case .increasing: return .gray
            case .decreasing: return AppTheme.mossGreen
            case .stable: return AppTheme.deepBlue
            }
        }
        
        var icon: String {
            switch self {
            case .increasing: return "arrow.up.right"
            case .decreasing: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var description: String {
            switch self {
            case .increasing: return "Steigend"
            case .decreasing: return "Fallend"
            case .stable: return "Stabil"
            }
        }
    }
    
    enum BodyFatTrend {
        case increasing, decreasing, stable

        var color: Color {
            switch self {
            case .increasing: return .gray
            case .decreasing: return AppTheme.mossGreen
            case .stable: return AppTheme.deepBlue
            }
        }
        
        var icon: String {
            switch self {
            case .increasing: return "arrow.up.right"
            case .decreasing: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var description: String {
            switch self {
            case .increasing: return "Steigend"
            case .decreasing: return "Fallend"
            case .stable: return "Stabil"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Körperdaten")
                .font(.headline)
            
            if !workoutStore.healthKitManager.isHealthDataAvailable {
                VStack(spacing: 12) {
                    Image(systemName: "figure.stand")
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
                    Image(systemName: "figure.stand.line.dotted.figure.stand")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("HealthKit-Berechtigung erforderlich")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 8) {
                        Button("Berechtigung erteilen") {
                            requestAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        NavigationLink("Debug-Informationen") {
                            HealthKitDebugView()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    // Time Range Picker
                    Picker("Zeitraum", selection: $selectedTimeRange) {
                        ForEach(BodyMetricsTimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTimeRange) { _, _ in
                        loadBodyMetricsData()
                    }
                    
                    if !weightReadings.isEmpty || !bodyFatReadings.isEmpty {
                        // Current Values and Trends
                        HStack(spacing: 12) {
                            if let weight = currentWeight {
                                bodyMetricStatBox(
                                    title: "Gewicht",
                                    value: "\(weight.formatted(.number.precision(.fractionLength(1)))) kg",
                                    trend: weightTrend.description,
                                    trendIcon: weightTrend.icon,
                                    color: weightTrend.color
                                )
                            }
                            
                            if let bodyFat = currentBodyFat {
                                bodyMetricStatBox(
                                    title: "Körperfett",
                                    value: "\((bodyFat * 100).formatted(.number.precision(.fractionLength(1))))%",
                                    trend: bodyFatTrend.description,
                                    trendIcon: bodyFatTrend.icon,
                                    color: bodyFatTrend.color
                                )
                            }
                        }
                        
                        // Weight Chart
                        if !weightReadings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Gewichtsverlauf")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Chart(weightReadings.suffix(30)) { reading in
                                    LineMark(
                                        x: .value("Datum", reading.date),
                                        y: .value("Gewicht", reading.weight)
                                    )
                                    .foregroundStyle(AppTheme.mossGreen)
                                    .interpolationMethod(.cardinal)
                                    
                                    AreaMark(
                                        x: .value("Datum", reading.date),
                                        y: .value("Gewicht", reading.weight)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppTheme.mossGreen.opacity(0.3), AppTheme.mossGreen.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.cardinal)
                                }
                                .frame(height: 100)
                                .chartXAxis(.hidden)
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let weight = value.as(Double.self) {
                                                Text("\(weight.formatted(.number.precision(.fractionLength(0))))kg")
                                            }
                                        }
                                        AxisGridLine()
                                        AxisTick()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                        
                        // Body Fat Chart
                        if !bodyFatReadings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Körperfettverlauf")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Chart(bodyFatReadings.suffix(30)) { reading in
                                    LineMark(
                                        x: .value("Datum", reading.date),
                                        y: .value("Körperfett", reading.bodyFatPercentage * 100)
                                    )
                                    .foregroundStyle(AppTheme.deepBlue)
                                    .interpolationMethod(.cardinal)
                                    
                                    AreaMark(
                                        x: .value("Datum", reading.date),
                                        y: .value("Körperfett", reading.bodyFatPercentage * 100)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppTheme.deepBlue.opacity(0.3), AppTheme.deepBlue.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.cardinal)
                                }
                                .frame(height: 100)
                                .chartXAxis(.hidden)
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let bodyFat = value.as(Double.self) {
                                                Text("\(bodyFat.formatted(.number.precision(.fractionLength(0))))%")
                                            }
                                        }
                                        AxisGridLine()
                                        AxisTick()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                        
                    } else if !isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "figure.stand")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Keine Körperdaten")
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
                            Text("Lade Körperdaten...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .onAppear {
                    loadBodyMetricsData()
                }
                .alert("Fehler", isPresented: $showingError, presenting: error) { error in
                    Button("OK", role: .cancel) { self.error = nil }
                } message: { error in
                    Text(error.localizedDescription)
                }
            }
        }
        .padding(20)
    }
    
    private func bodyMetricStatBox(title: String, value: String, trend: String, trendIcon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            
            HStack(spacing: 2) {
                Image(systemName: trendIcon)
                    .font(.caption2)
                Text(trend)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
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
                // Status explizit aktualisieren nach Autorisierung
                await MainActor.run {
                    workoutStore.healthKitManager.updateAuthorizationStatus()
                }
                loadBodyMetricsData()
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
    
    private func loadBodyMetricsData() {
        guard workoutStore.healthKitManager.isAuthorized else { return }
        
        isLoading = true
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-selectedTimeRange.timeInterval)
        
        Task {
            do {
                async let weightData = workoutStore.readWeightData(from: startDate, to: endDate)
                async let bodyFatData = workoutStore.readBodyFatData(from: startDate, to: endDate)
                
                let (weights, bodyFats) = try await (weightData, bodyFatData)
                
                await MainActor.run {
                    self.weightReadings = weights
                    self.bodyFatReadings = bodyFats
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

