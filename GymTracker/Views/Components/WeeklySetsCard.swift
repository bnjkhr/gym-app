import SwiftUI

/// Card zeigt Sets pro Muskelgruppe mit wissenschaftlichen Empfehlungen
struct WeeklySetsCard: View {
    @StateObject private var cache = StatisticsCache.shared
    let sessionEntities: [WorkoutSessionEntity]
    @State private var isExpanded: Bool = false
    @State private var cachedSetsData: [MuscleGroupSets] = []
    @State private var updateTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme

    // Wissenschaftliche Empfehlungen (10-20 Sets pro Muskelgruppe pro Woche)
    private let minRecommended = 10
    private let maxRecommended = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "list.number")
                            .foregroundStyle(colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue)
                        Text("Wöchentliches Volumen")
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
                // Expanded: Detailed List
                if !cachedSetsData.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(cachedSetsData) { data in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(data.muscleGroup.color)
                                        .frame(width: 12, height: 12)

                                    Text(data.muscleGroup.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Spacer()

                                    Text("\(data.sets) Sets")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(setsStatusColor(sets: data.sets))
                                }

                                // Progress Bar
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(progressGradient(sets: data.sets))
                                        .frame(width: progressWidth(sets: data.sets), height: 8)
                                }

                                // Empfehlung
                                HStack {
                                    Image(systemName: data.statusIcon)
                                        .font(.caption2)
                                        .foregroundStyle(setsStatusColor(sets: data.sets))

                                    Text(data.recommendation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)

                            if data.id != cachedSetsData.last?.id {
                                Divider()
                            }
                        }
                    }

                    // Legend
                    Divider()

                    HStack(spacing: 16) {
                        LegendItem(color: Color(red: 0/255, green: 95/255, blue: 86/255), label: "Optimal")
                        LegendItem(color: .customOrange, label: "Wenig")
                        LegendItem(color: .red, label: "Zu viel")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Noch keine Daten diese Woche")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                }
            } else {
                // Compact: Mini Summary
                if !cachedSetsData.isEmpty {
                    let optimal = cachedSetsData.filter { $0.sets >= minRecommended && $0.sets <= maxRecommended }.count
                    let total = cachedSetsData.count

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color(red: 0/255, green: 95/255, blue: 86/255))
                            Text("\(optimal)/\(total) optimal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Mini Bars
                        HStack(spacing: 3) {
                            ForEach(cachedSetsData.prefix(7)) { data in
                                Rectangle()
                                    .fill(setsStatusColor(sets: data.sets))
                                    .frame(width: 6, height: CGFloat(min(data.sets, 30)) * 1.5)
                                    .cornerRadius(2)
                            }
                        }
                        .frame(height: 40)
                    }
                } else {
                    Text("Trainiere, um Volumen zu tracken")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
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
            calculateWeeklySets()
        }
        .onChange(of: cache.cacheVersion) { _, _ in
            scheduleUpdate()
        }
        .onDisappear {
            updateTask?.cancel()
        }
    }

    // MARK: - Helpers

    private func setsStatusColor(sets: Int) -> Color {
        if sets >= minRecommended && sets <= maxRecommended {
            return Color(red: 0/255, green: 95/255, blue: 86/255)
        } else if sets < minRecommended {
            return .customOrange
        } else {
            return .red
        }
    }

    private func progressWidth(sets: Int) -> CGFloat {
        let maxWidth: CGFloat = 200 // Max width of bar
        let progress = min(Double(sets) / Double(maxRecommended * 2), 1.0)
        return maxWidth * CGFloat(progress)
    }

    private func progressGradient(sets: Int) -> LinearGradient {
        let greenColor = Color(red: 0/255, green: 95/255, blue: 86/255)
        if sets >= minRecommended && sets <= maxRecommended {
            return LinearGradient(colors: [greenColor.opacity(0.7), greenColor], startPoint: .leading, endPoint: .trailing)
        } else if sets < minRecommended {
            return LinearGradient(colors: [.customOrange.opacity(0.7), .customOrange], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red.opacity(0.7), .red], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func scheduleUpdate() {
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                calculateWeeklySets()
            }
        }
    }

    private func calculateWeeklySets() {
        // Verwende gecachte Version wenn verfügbar
        if !cache.getWeeklySets().isEmpty {
            cachedSetsData = cache.getWeeklySets()
            return
        }

        // Berechnung im Background
        Task.detached(priority: .userInitiated) {
            var muscleGroupSets: [MuscleGroup: Int] = [:]

            // Aktuelle Woche
            let calendar = Calendar.current
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            let weeklySessions = sessionEntities.filter { $0.date >= weekStart }

            // Sets pro Muskelgruppe zählen
            for session in weeklySessions {
                for exercise in session.exercises {
                    guard let exerciseEntity = exercise.exercise else { continue }

                    let completedSets = exercise.sets.filter { $0.completed }.count

                    // Zu allen Muskelgruppen der Übung hinzufügen
                    for muscleGroupRaw in exerciseEntity.muscleGroupsRaw {
                        if let muscleGroup = MuscleGroup(rawValue: muscleGroupRaw),
                           muscleGroup != .cardio { // Cardio ausschließen
                            muscleGroupSets[muscleGroup, default: 0] += completedSets
                        }
                    }
                }
            }

            // Konvertieren in Array und sortieren
            let setsData = muscleGroupSets
                .map { (muscleGroup, sets) in
                    MuscleGroupSets(
                        muscleGroup: muscleGroup,
                        sets: sets
                    )
                }
                .sorted { $0.sets > $1.sets }

            await MainActor.run {
                cachedSetsData = setsData
                cache.setWeeklySets(setsData)
            }
        }
    }
}

// MARK: - Supporting Types

struct MuscleGroupSets: Identifiable {
    let id = UUID()
    let muscleGroup: MuscleGroup
    let sets: Int

    var recommendation: String {
        if sets >= 10 && sets <= 20 {
            return "Optimal für Hypertrophie"
        } else if sets < 5 {
            return "Zu wenig für Wachstum"
        } else if sets < 10 {
            return "Unteres Ende, mehr wäre besser"
        } else if sets <= 25 {
            return "Oberes Ende, gut für erfahrene Athleten"
        } else {
            return "Evtl. zu viel, Risiko für Übertraining"
        }
    }

    var statusIcon: String {
        if sets >= 10 && sets <= 20 {
            return "checkmark.circle.fill"
        } else if sets < 10 {
            return "arrow.up.circle"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Legend Component

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}
