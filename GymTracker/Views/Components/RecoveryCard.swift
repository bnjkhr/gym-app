import SwiftUI

/// Card zeigt den Recovery Index basierend auf HealthKit-Daten
struct RecoveryCard: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    let sessionEntities: [WorkoutSessionEntity]
    @State private var recoveryIndex: RecoveryIndex?
    @State private var isExpanded: Bool = false
    @State private var isLoading: Bool = false
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
                        Image(systemName: recoveryIndex?.status.icon ?? "heart.fill")
                            .foregroundStyle(statusColor)
                        Text("Erholung")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    if let recovery = recoveryIndex {
                        Text("\(recovery.score)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(statusColor)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if let recovery = recoveryIndex {
                if isExpanded {
                    // Expanded: Detailed View
                    VStack(alignment: .leading, spacing: 16) {
                        // Status & Empfehlung
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 12, height: 12)

                                Text(recovery.status.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            Text(recovery.recommendation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(statusColor.opacity(0.1))
                        )

                        Divider()

                        // Details
                        VStack(spacing: 12) {
                            if let resting = recovery.details.restingHR {
                                RecoveryDetailRow(
                                    icon: "heart.fill",
                                    label: "Ruhepuls",
                                    value: "\(Int(resting)) bpm",
                                    status: recovery.details.hrStatus
                                )
                            }

                            if let sleep = recovery.details.sleepHours {
                                RecoveryDetailRow(
                                    icon: "bed.double.fill",
                                    label: "Schlaf",
                                    value: String(format: "%.1fh", sleep),
                                    status: recovery.details.sleepStatus
                                )
                            }

                            RecoveryDetailRow(
                                icon: "dumbbell.fill",
                                label: "Trainings (7d)",
                                value: "\(recovery.details.trainingsThisWeek)",
                                status: recovery.details.trainingsThisWeek <= workoutStore.weeklyGoal ? "Gut" : "Viel"
                            )
                        }

                        // Score Breakdown (optional)
                        if !recovery.details.factors.isEmpty {
                            Divider()

                            VStack(spacing: 8) {
                                Text("Score-Faktoren")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(Array(recovery.details.factors.sorted(by: { $0.value > $1.value })), id: \.key) { key, value in
                                    HStack {
                                        Text(key)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color(.systemGray5))
                                                .frame(width: 60, height: 8)

                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(statusColor)
                                                .frame(width: CGFloat(value / 30.0) * 60, height: 8)
                                        }

                                        Text("\(Int(value))")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                            .frame(width: 25, alignment: .trailing)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Compact: Mini Status
                    HStack(spacing: 12) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(recovery.status.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let resting = recovery.details.restingHR {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                Text("\(Int(resting))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let sleep = recovery.details.sleepHours {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.indigo)
                                Text(String(format: "%.1f", sleep))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                // No Data State
                VStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("Keine HealthKit-Daten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !workoutStore.healthKitManager.isAuthorized {
                        Text("Aktiviere HealthKit in den Einstellungen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
            calculateRecoveryIndex()
        }
        .onChange(of: sessionEntities.count) { _, _ in
            calculateRecoveryIndex()
        }
    }

    private var statusColor: Color {
        guard let recovery = recoveryIndex else { return .gray }
        let colors = recovery.status.color
        return colorScheme == .dark ?
            (colors.dark == "turquoiseBoost" ? AppTheme.turquoiseBoost :
             colors.dark == "mossGreen" ? AppTheme.mossGreen :
             colors.dark == "powerOrange" ? AppTheme.powerOrange :
             colors.dark == "deepBlue" ? AppTheme.deepBlue : .red) :
            (colors.light == "turquoiseBoost" ? AppTheme.turquoiseBoost :
             colors.light == "mossGreen" ? AppTheme.mossGreen :
             colors.light == "powerOrange" ? AppTheme.powerOrange :
             colors.light == "deepBlue" ? AppTheme.deepBlue : .red)
    }

    private func calculateRecoveryIndex() {
        guard workoutStore.healthKitManager.isAuthorized else {
            recoveryIndex = nil
            return
        }

        isLoading = true

        Task {
            do {
                // Hole HealthKit-Daten (letzte 7 Tage)
                let endDate = Date()
                let startDate = endDate.addingTimeInterval(-7 * 24 * 3600)

                // ✅ RUHEPULS (nicht normaler Herzschlag während Training!)
                let restingHRReadings = try await workoutStore.healthKitManager.readRestingHeartRate(from: startDate, to: endDate)
                let restingHR = restingHRReadings.isEmpty ? nil : restingHRReadings.map(\.heartRate).reduce(0, +) / Double(restingHRReadings.count)

                // Baseline (30 Tage VOR den letzten 7 Tagen)
                let baselineEnd = startDate
                let baselineStart = endDate.addingTimeInterval(-37 * 24 * 3600) // 30 Tage vor den letzten 7 Tagen
                let baselineHRReadings = try await workoutStore.healthKitManager.readRestingHeartRate(from: baselineStart, to: baselineEnd)
                let baselineHR = baselineHRReadings.isEmpty ? nil : baselineHRReadings.map(\.heartRate).reduce(0, +) / Double(baselineHRReadings.count)

                // Schlaf (simuliert - HealthKit Schlaf-Integration wäre komplex)
                // Für jetzt: Random zwischen 6-8 Stunden als Platzhalter
                let sleepHours: Double? = nil // TODO: Echte Schlaf-Daten aus HealthKit

                // Sessions der letzten 7 Tage
                let recentSessions = sessionEntities.filter { $0.date >= startDate }

                await MainActor.run {
                    self.recoveryIndex = RecoveryIndex.calculate(
                        restingHeartRate: restingHR,
                        baselineRestingHR: baselineHR,
                        sleepHours: sleepHours,
                        recentSessions: recentSessions,
                        weeklyGoal: workoutStore.weeklyGoal
                    )
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.recoveryIndex = nil
                }
            }
        }
    }
}

// MARK: - Detail Row Component

private struct RecoveryDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let status: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}
