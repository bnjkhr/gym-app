import SwiftUI

/// Card zeigt Vergleich: Diese Woche vs. Letzte Woche
struct WeekComparisonCard: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @StateObject private var cache = StatisticsCache.shared
    let sessionEntities: [WorkoutSessionEntityV1]
    @State private var comparison: WeekComparison?
    @State private var isExpanded: Bool = false
    @State private var updateTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)
                        Text("Wochenvergleich")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    if let comp = comparison {
                        // Overall Trend Indicator
                        Image(systemName: comp.volumeTrend.icon)
                            .font(.caption)
                            .foregroundStyle(trendColor(comp.volumeTrend))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if let comp = comparison {
                if isExpanded {
                    // Expanded: Detaillierte Ansicht
                    VStack(spacing: 16) {
                        // 4-Felder Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ComparisonStatCard(
                                icon: "scalemass.fill",
                                label: "Volumen",
                                currentValue: comp.currentWeek.formattedVolume,
                                change: comp.volumeChange,
                                trend: comp.volumeTrend,
                                colorScheme: colorScheme
                            )

                            ComparisonStatCard(
                                icon: "trophy.fill",
                                label: "Neue PRs",
                                currentValue: "\(comp.currentWeek.newPRs)",
                                change: Double(comp.prCountChange),
                                trend: comp.prTrend,
                                colorScheme: colorScheme,
                                showPercentage: false
                            )

                            ComparisonStatCard(
                                icon: "dumbbell.fill",
                                label: "Trainings",
                                currentValue: "\(comp.currentWeek.workoutCount)",
                                change: Double(comp.frequencyChange),
                                trend: comp.frequencyTrend,
                                colorScheme: colorScheme,
                                showPercentage: false
                            )

                            ComparisonStatCard(
                                icon: "clock.fill",
                                label: "Ø Dauer",
                                currentValue: comp.currentWeek.formattedDuration,
                                change: (comp.avgDurationChange / 60), // Minuten
                                trend: comp.durationTrend,
                                colorScheme: colorScheme,
                                showPercentage: false,
                                unit: "min"
                            )
                        }

                        // Detaillierte Breakdown (optional)
                        if !comp.currentWeek.muscleGroupBreakdown.isEmpty {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Volumen nach Muskelgruppe")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                let topMuscleGroups = comp.currentWeek.muscleGroupBreakdown
                                    .sorted { $0.value > $1.value }
                                    .prefix(3)

                                ForEach(Array(topMuscleGroups), id: \.key) { muscleGroup, volume in
                                    HStack {
                                        Circle()
                                            .fill(muscleGroup.color)
                                            .frame(width: 8, height: 8)

                                        Text(muscleGroup.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        Text(String(format: "%.1ft", volume / 1000))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)

                                        // Änderung vs. letzte Woche
                                        if let lastVolume = comp.lastWeek.muscleGroupBreakdown[muscleGroup] {
                                            let change = ((volume - lastVolume) / lastVolume) * 100
                                            if abs(change) > 5 {
                                                Text(change >= 0 ? "+\(Int(change))%" : "\(Int(change))%")
                                                    .font(.caption2)
                                                    .foregroundStyle(change >= 0 ? AppTheme.mossGreen : AppTheme.powerOrange)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Compact: Nur wichtigste Metrics
                    HStack(spacing: 16) {
                        CompactMetric(
                            label: "Volumen",
                            value: comp.currentWeek.formattedVolume,
                            trend: comp.volumeTrend,
                            change: comp.volumeChange,
                            colorScheme: colorScheme
                        )

                        Divider()
                            .frame(height: 30)

                        CompactMetric(
                            label: "PRs",
                            value: "\(comp.currentWeek.newPRs)",
                            trend: comp.prTrend,
                            change: Double(comp.prCountChange),
                            colorScheme: colorScheme,
                            showPercentage: false
                        )

                        Divider()
                            .frame(height: 30)

                        CompactMetric(
                            label: "Trainings",
                            value: "\(comp.currentWeek.workoutCount)",
                            trend: comp.frequencyTrend,
                            change: Double(comp.frequencyChange),
                            colorScheme: colorScheme,
                            showPercentage: false
                        )
                    }
                }
            } else {
                // Loading State
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
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
            calculateComparison()
        }
        .onChange(of: cache.cacheVersion) { _, _ in
            scheduleUpdate()
        }
        .onDisappear {
            updateTask?.cancel()
        }
    }

    // MARK: - Helpers

    private func trendColor(_ trend: WeekComparison.Trend) -> Color {
        let colors = trend.color
        return colorScheme == .dark ?
            (colors.dark == "turquoiseBoost" ? AppTheme.turquoiseBoost :
             colors.dark == "mossGreen" ? AppTheme.mossGreen :
             AppTheme.powerOrange) :
            (colors.light == "mossGreen" ? AppTheme.mossGreen :
             colors.light == "deepBlue" ? AppTheme.deepBlue :
             AppTheme.powerOrange)
    }

    private func scheduleUpdate() {
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                calculateComparison()
            }
        }
    }

    private func calculateComparison() {
        // Verwende gecachte Version wenn verfügbar
        if let cached = cache.getWeekComparison() {
            comparison = cached
            return
        }

        // Berechnung im Background
        Task.detached(priority: .userInitiated) {
            let records = await MainActor.run { workoutStore.getAllExerciseRecords() }
            let comp = WeekComparison.calculate(sessions: sessionEntities, records: records)

            await MainActor.run {
                self.comparison = comp
                cache.setWeekComparison(comp)
            }
        }
    }
}

// MARK: - Comparison Stat Card (Expanded)

private struct ComparisonStatCard: View {
    let icon: String
    let label: String
    let currentValue: String
    let change: Double
    let trend: WeekComparison.Trend
    let colorScheme: ColorScheme
    let showPercentage: Bool
    let unit: String

    init(icon: String, label: String, currentValue: String, change: Double, trend: WeekComparison.Trend, colorScheme: ColorScheme, showPercentage: Bool = true, unit: String = "") {
        self.icon = icon
        self.label = label
        self.currentValue = currentValue
        self.change = change
        self.trend = trend
        self.colorScheme = colorScheme
        self.showPercentage = showPercentage
        self.unit = unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: trend.icon)
                    .font(.caption2)
                    .foregroundStyle(trendColor)
            }

            Text(currentValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Change Indicator
            HStack(spacing: 4) {
                if abs(change) > 0.1 {
                    Text(formatChange)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(trendColor)
                } else {
                    Text("→ Stabil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppLayout.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 0.3 : 0.5))
        )
    }

    private var formatChange: String {
        let prefix = change >= 0 ? "+" : ""
        if showPercentage {
            return "\(prefix)\(Int(change))%"
        } else {
            return "\(prefix)\(Int(change))\(unit)"
        }
    }

    private var trendColor: Color {
        let colors = trend.color
        return colorScheme == .dark ?
            (colors.dark == "turquoiseBoost" ? AppTheme.turquoiseBoost :
             colors.dark == "mossGreen" ? AppTheme.mossGreen :
             AppTheme.powerOrange) :
            (colors.light == "mossGreen" ? AppTheme.mossGreen :
             colors.light == "deepBlue" ? AppTheme.deepBlue :
             AppTheme.powerOrange)
    }
}

// MARK: - Compact Metric

private struct CompactMetric: View {
    let label: String
    let value: String
    let trend: WeekComparison.Trend
    let change: Double
    let colorScheme: ColorScheme
    let showPercentage: Bool

    init(label: String, value: String, trend: WeekComparison.Trend, change: Double, colorScheme: ColorScheme, showPercentage: Bool = true) {
        self.label = label
        self.value = value
        self.trend = trend
        self.change = change
        self.colorScheme = colorScheme
        self.showPercentage = showPercentage
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: trend.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(trendColor)

                if abs(change) > 0.1 {
                    Text(formatChange)
                        .font(.caption2)
                        .foregroundStyle(trendColor)
                }
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formatChange: String {
        let prefix = change >= 0 ? "+" : ""
        if showPercentage {
            return "\(prefix)\(Int(change))%"
        } else {
            return "\(prefix)\(Int(change))"
        }
    }

    private var trendColor: Color {
        let colors = trend.color
        return colorScheme == .dark ?
            (colors.dark == "turquoiseBoost" ? AppTheme.turquoiseBoost :
             colors.dark == "mossGreen" ? AppTheme.mossGreen :
             AppTheme.powerOrange) :
            (colors.light == "mossGreen" ? AppTheme.mossGreen :
             colors.light == "deepBlue" ? AppTheme.deepBlue :
             AppTheme.powerOrange)
    }
}
