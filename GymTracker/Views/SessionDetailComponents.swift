import SwiftUI
import Charts

// MARK: - Session Detail UI Components

struct SessionStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 1.5)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct ExerciseDetailCard: View {
    let statistic: ExerciseStatistic
    let sets: [ExerciseSet]
    @State private var isExpanded: Bool = false

    private var progressionColor: Color {
        guard let progression = statistic.progressionPercentage else { return .gray }
        if progression > 0 { return AppTheme.mossGreen }
        if progression < 0 { return .red }
        return .gray
    }

    private var progressionIcon: String {
        guard let progression = statistic.progressionPercentage else { return "minus" }
        if progression > 0 { return "arrow.up.right" }
        if progression < 0 { return "arrow.down.right" }
        return "minus"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.deepBlue)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppTheme.deepBlue.opacity(0.1))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(statistic.exerciseName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            // Progression Badge
                            if let progression = statistic.progressionPercentage {
                                HStack(spacing: 4) {
                                    Image(systemName: progressionIcon)
                                        .font(.system(size: 10, weight: .bold))
                                    Text(String(format: "%.1f%%", abs(progression)))
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(progressionColor)
                                )
                            }
                        }

                        Text("\(statistic.completedSets)/\(statistic.totalSets) Sätze • \(Int(statistic.totalVolume)) kg Volumen")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Expandable Details
            if isExpanded {
                VStack(spacing: 8) {
                    // Stats Summary
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max Gewicht")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("\(Int(statistic.maxWeight)) kg")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                        }

                        Divider()
                            .frame(height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ø Wiederholungen")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", statistic.averageReps))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )

                    // Sets Table
                    VStack(spacing: 6) {
                        // Table Header
                        HStack {
                            Text("Set")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)

                            Text("Gewicht")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Wdh.")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)

                            Text("Status")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .center)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)

                        Divider()

                        // Table Rows
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .leading)

                                Text("\(Int(set.weight)) kg")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text("\(set.reps)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 50, alignment: .leading)

                                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(set.completed ? AppTheme.mossGreen : Color(.systemGray4))
                                    .frame(width: 50, alignment: .center)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppLayout.Spacing.standard)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(statistic.exerciseName), \(statistic.completedSets) von \(statistic.totalSets) Sätzen abgeschlossen")
        .accessibilityHint(isExpanded ? "Doppeltippen zum Ausblenden der Details" : "Doppeltippen zum Anzeigen der Details")
    }
}

struct VolumeChart: View {
    let dataPoints: [VolumeDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volumenverteilung")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            if dataPoints.isEmpty {
                Text("Keine Daten verfügbar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                Chart {
                    ForEach(dataPoints) { point in
                        BarMark(
                            x: .value("Übung", point.exerciseName),
                            y: .value("Volumen", point.volume)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.deepBlue, AppTheme.turquoiseBoost],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(AppLayout.CornerRadius.small)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue)) kg")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(orientation: .verticalReversed) {
                            if let name = value.as(String.self) {
                                Text(name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .frame(height: 240)
            }
        }
        .padding(AppLayout.Spacing.standard)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Volumenverteilung Diagramm")
    }
}
