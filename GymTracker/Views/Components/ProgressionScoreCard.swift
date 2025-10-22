import SwiftUI

/// Hero Card für den Progression Score - zeigt Gesamtfortschritt
struct ProgressionScoreCard: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @StateObject private var cache = StatisticsCache.shared
    let sessionEntities: [WorkoutSessionEntityV1]
    @State private var progressionScore: ProgressionScore?
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title3)
                                .foregroundStyle(.white)
                            Text("Dein Fortschritt")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    // Score Display
                    if let score = progressionScore {
                        HStack(alignment: .bottom, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(score.totalScore)")
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(score.interpretation)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white.opacity(0.95))
                            }

                            Spacer()

                            // Circular Progress
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 8)
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .trim(from: 0, to: CGFloat(score.totalScore) / 100.0)
                                    .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))

                                Text("\(score.totalScore)%")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    } else {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let score = progressionScore {
                Divider()
                    .background(.white.opacity(0.3))

                // Score Breakdown
                VStack(spacing: 12) {
                    ScoreBreakdownRow(
                        icon: "trophy.fill",
                        label: "Kraft",
                        current: score.strengthScore,
                        max: 25,
                        detail: "\(score.details.newPRs) neue PRs"
                    )

                    ScoreBreakdownRow(
                        icon: "scalemass.fill",
                        label: "Volumen",
                        current: score.volumeScore,
                        max: 25,
                        detail: String(format: "%+.1f%%", score.details.volumeChange)
                    )

                    ScoreBreakdownRow(
                        icon: "calendar",
                        label: "Konsistenz",
                        current: score.consistencyScore,
                        max: 30,
                        detail: String(format: "%.1f/Woche", score.details.trainingFrequency)
                    )

                    ScoreBreakdownRow(
                        icon: "figure.strengthtraining.traditional",
                        label: "Balance",
                        current: score.balanceScore,
                        max: 20,
                        detail: "Muskelverteilung"
                    )
                }
            }
        }
        .padding(AppLayout.Spacing.extraLarge)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: AppTheme.mossGreen.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            calculateProgressionScore()
        }
        .onChange(of: cache.cacheVersion) { _, _ in
            calculateProgressionScore()
        }
    }

    private var gradientColors: [Color] {
        guard let score = progressionScore else {
            return [AppTheme.mossGreen, AppTheme.deepBlue]
        }

        let colors = score.color
        let lightColor = colors.light == "mossGreen" ? AppTheme.mossGreen :
                        colors.light == "deepBlue" ? AppTheme.deepBlue :
                        colors.light == "powerOrange" ? AppTheme.powerOrange :
                        AppTheme.turquoiseBoost

        let darkColor = colors.dark == "turquoiseBoost" ? AppTheme.turquoiseBoost :
                       colors.dark == "mossGreen" ? AppTheme.mossGreen :
                       colors.dark == "powerOrange" ? AppTheme.powerOrange :
                       AppTheme.deepBlue

        return colorScheme == .dark ? [darkColor, lightColor] : [lightColor, darkColor]
    }

    private func calculateProgressionScore() {
        // Verwende gecachte Version wenn verfügbar
        if let cached = cache.getProgressionScore() {
            progressionScore = cached
            return
        }

        // Berechnung im Background
        Task.detached(priority: .userInitiated) {
            let records = await MainActor.run { workoutStore.getAllExerciseRecords() }
            let weeklyGoal = await MainActor.run { workoutStore.weeklyGoal }

            let score = ProgressionScore.calculate(
                sessions: sessionEntities,
                records: records,
                weeklyGoal: weeklyGoal,
                compareWeeks: 4
            )

            await MainActor.run {
                self.progressionScore = score
                cache.setProgressionScore(score)
            }
        }
    }
}

// MARK: - Score Breakdown Row

private struct ScoreBreakdownRow: View {
    let icon: String
    let label: String
    let current: Double
    let max: Double
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Progress Bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.3))
                    .frame(width: 80, height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .frame(width: CGFloat(current / max) * 80, height: 8)
            }

            Text("\(Int(current))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
