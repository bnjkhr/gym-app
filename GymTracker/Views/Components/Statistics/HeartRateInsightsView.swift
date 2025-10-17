import Charts
import HealthKit
import SwiftData
import SwiftUI

/// Zeigt HealthKit Herzfrequenz-Insights mit Charts und Statistiken an.
///
/// Diese View ist Teil der StatisticsView-Modularisierung (Phase 3).
/// Sie präsentiert Herzfrequenzdaten aus HealthKit mit interaktiven Charts,
/// Zeitraum-Auswahl und detaillierten Statistiken (Durchschnitt, Max, Min).
///
/// **Verantwortlichkeiten:**
/// - HealthKit Authorization Handling
/// - Herzfrequenzdaten laden (24h, Woche, Monat)
/// - Statistiken berechnen (Durchschnitt, Max, Min)
/// - Chart-Visualisierung mit LineMark + AreaMark
/// - Error Handling und Empty States
/// - Loading States mit ProgressView
///
/// **Design:**
/// - Segmented Picker für Zeitraum-Auswahl (24h/Woche/Monat)
/// - Stat Boxes für Ø/Max/Min Herzfrequenz
/// - Swift Charts mit Gradient-Area
/// - Empty States für fehlende Daten
/// - Authorization Flow für HealthKit
///
/// **Performance:**
/// - Async/await für HealthKit Queries
/// - Limitierung auf 20 Datenpunkte im Chart
/// - Lazy Loading on appear
///
/// **Verwendung:**
/// ```swift
/// HeartRateInsightsView()
///     .environmentObject(workoutStore)
/// ```
///
/// **Voraussetzungen:**
/// - HealthKit Authorization erforderlich
/// - WorkoutStoreCoordinator als @EnvironmentObject
/// - iOS 16.0+ für Charts
///
/// - Version: 1.0
/// - SeeAlso: `StatisticsView`, `BodyMetricsInsightsView`, `HealthKitManager`
struct HeartRateInsightsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @Environment(\.colorScheme) private var colorScheme
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
            case .month: return 2_629_746
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
                            heartRateStatBox(title: "Ø", value: Int(averageHeartRate), color: .gray)
                            heartRateStatBox(
                                title: "Max", value: Int(maxHeartRate),
                                color: colorScheme == .dark
                                    ? AppTheme.turquoiseBoost : AppTheme.deepBlue)
                            heartRateStatBox(
                                title: "Min", value: Int(minHeartRate), color: AppTheme.mossGreen)
                        }

                        // Compact Chart
                        Chart(heartRateReadings.prefix(20)) { reading in
                            let chartColor =
                                colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue
                            LineMark(
                                x: .value("Zeit", reading.timestamp),
                                y: .value("Herzfrequenz", reading.heartRate)
                            )
                            .foregroundStyle(chartColor)
                            .interpolationMethod(.cardinal)

                            AreaMark(
                                x: .value("Zeit", reading.timestamp),
                                y: .value("Herzfrequenz", reading.heartRate)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [chartColor.opacity(0.3), chartColor.opacity(0.1)],
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

    // MARK: - Private Helpers

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
                let readings = try await workoutStore.readHeartRateData(
                    from: startDate, to: endDate)

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

// MARK: - Preview

#Preview {
    HeartRateInsightsView()
        .environmentObject(WorkoutStoreCoordinator())
}
