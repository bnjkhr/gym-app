import SwiftUI
import Charts

/// Card zeigt die Volumen-Verteilung nach Muskelgruppen
struct MuscleDistributionCard: View {
    let sessionEntities: [WorkoutSessionEntity]
    @State private var isExpanded: Bool = false
    @State private var cachedDistribution: [MuscleGroupVolume] = []
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
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(AppTheme.mossGreen)
                        Text("Muskelbalance")
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
                // Expanded: Detailed Pie Chart
                if !cachedDistribution.isEmpty {
                    Chart(cachedDistribution) { item in
                        SectorMark(
                            angle: .value("Volumen", item.volume),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.muscleGroup.color)
                        .opacity(0.9)
                    }
                    .frame(height: 200)
                    .chartLegend(position: .bottom, spacing: 8)

                    // Legende mit Prozenten
                    VStack(spacing: 8) {
                        ForEach(cachedDistribution.prefix(5)) { item in
                            HStack {
                                Circle()
                                    .fill(item.muscleGroup.color)
                                    .frame(width: 12, height: 12)

                                Text(item.muscleGroup.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("\(Int(item.percentage))%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("Noch keine Daten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                }
            } else {
                // Compact: Mini Bar Chart
                if !cachedDistribution.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(cachedDistribution.prefix(7)) { item in
                            VStack(spacing: 2) {
                                Rectangle()
                                    .fill(item.muscleGroup.color)
                                    .frame(width: 20, height: CGFloat(item.percentage) * 0.6)
                                    .cornerRadius(2)

                                Text(item.muscleGroup.shortName)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 70)
                } else {
                    Text("Trainiere, um Balance zu sehen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
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
            scheduleUpdate()
        }
        .onChange(of: sessionEntities.count) { _, _ in
            scheduleUpdate()
        }
        .onDisappear {
            updateTask?.cancel()
        }
    }

    // Debounced update
    private func scheduleUpdate() {
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            guard !Task.isCancelled else { return }
            await MainActor.run {
                calculateDistribution()
            }
        }
    }

    private func calculateDistribution() {
        var muscleGroupVolumes: [MuscleGroup: Double] = [:]

        // Volumen pro Muskelgruppe sammeln (letzte 4 Wochen)
        let calendar = Calendar.current
        let fourWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
        let recentSessions = sessionEntities.filter { $0.date >= fourWeeksAgo }

        for session in recentSessions {
            for exercise in session.exercises {
                guard let exerciseEntity = exercise.exercise else { continue }

                let volume = exercise.sets.reduce(0.0) { total, set in
                    total + (Double(set.reps) * set.weight)
                }

                // Zu allen Muskelgruppen der Übung hinzufügen
                for muscleGroupRaw in exerciseEntity.muscleGroupsRaw {
                    if let muscleGroup = MuscleGroup(rawValue: muscleGroupRaw),
                       muscleGroup != .cardio { // Cardio ausschließen
                        muscleGroupVolumes[muscleGroup, default: 0] += volume
                    }
                }
            }
        }

        // Konvertieren in Array und sortieren
        let totalVolume = muscleGroupVolumes.values.reduce(0, +)
        guard totalVolume > 0 else {
            cachedDistribution = []
            return
        }

        cachedDistribution = muscleGroupVolumes
            .map { (muscleGroup, volume) in
                MuscleGroupVolume(
                    muscleGroup: muscleGroup,
                    volume: volume,
                    percentage: (volume / totalVolume) * 100
                )
            }
            .sorted { $0.volume > $1.volume }
    }
}

// MARK: - Supporting Types

struct MuscleGroupVolume: Identifiable {
    let id = UUID()
    let muscleGroup: MuscleGroup
    let volume: Double
    let percentage: Double
}

// MARK: - MuscleGroup Extension

extension MuscleGroup {
    var shortName: String {
        switch self {
        case .chest: return "Brust"
        case .back: return "Rücken"
        case .shoulders: return "Schulter"
        case .biceps: return "Bizeps"
        case .triceps: return "Trizeps"
        case .legs: return "Beine"
        case .glutes: return "Gesäß"
        case .abs: return "Bauch"
        case .cardio: return "Cardio"
        case .forearms: return "U-Arm"
        case .calves: return "Waden"
        case .trapezius: return "Trapez"
        case .lowerBack: return "U-Rücken"
        case .upperBack: return "O-Rücken"
        case .fullBody: return "Ganz"
        case .hips: return "Hüfte"
        case .core: return "Core"
        case .hamstrings: return "B-Beuger"
        case .lats: return "Lat"
        case .grip: return "Griff"
        case .arms: return "Arme"
        case .adductors: return "Add."
        case .obliques: return "Schräg"
        case .hipFlexors: return "H-Beuger"
        case .traps: return "Trapez"
        case .coordination: return "Koordi"
        }
    }
}
