import Charts
import HealthKit
import SwiftData
import SwiftUI

/// Zeigt HealthKit Körpermetriken (Gewicht, Körperfett) mit Charts und Trends an.
///
/// Diese View ist Teil der StatisticsView-Modularisierung (Phase 3).
/// Sie präsentiert Gewichts- und Körperfett-Daten aus HealthKit mit interaktiven Charts,
/// Zeitraum-Auswahl (Monat bis Jahr) und Trend-Analysen.
///
/// **Verantwortlichkeiten:**
/// - HealthKit Authorization Handling
/// - Gewichts- und Körperfettdaten laden (Monat/3M/6M/Jahr)
/// - Trend-Analyse (steigend/fallend/stabil)
/// - Chart-Visualisierung mit LineMark + AreaMark
/// - Error Handling und Empty States
/// - Loading States mit ProgressView
///
/// **Design:**
/// - Segmented Picker für Zeitraum-Auswahl
/// - Stat Boxes für aktuelle Werte + Trends
/// - Separate Charts für Gewicht und Körperfett
/// - Swift Charts mit farbigen Gradienten
/// - Empty States für fehlende Daten
/// - Authorization Flow für HealthKit
///
/// **Trend-Logik:**
/// - **Gewicht**: >1kg Änderung = Trend, sonst stabil
/// - **Körperfett**: >2% Änderung = Trend, sonst stabil
/// - Berechnung über letzte 5 Messwerte
/// - Farben: Abnehmend=Grün, Steigend=Grau, Stabil=Blau
///
/// **Performance:**
/// - Async/await für HealthKit Queries
/// - Limitierung auf 30 Datenpunkte pro Chart
/// - Lazy Loading on appear
/// - Parallel loading von Weight + BodyFat
///
/// **Verwendung:**
/// ```swift
/// BodyMetricsInsightsView()
///     .environmentObject(workoutStore)
/// ```
///
/// **Voraussetzungen:**
/// - HealthKit Authorization erforderlich
/// - WorkoutStoreCoordinator als @EnvironmentObject
/// - iOS 16.0+ für Charts
///
/// - Version: 1.0
/// - SeeAlso: `StatisticsView`, `HeartRateInsightsView`, `HealthKitManager`
struct BodyMetricsInsightsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @Environment(\.colorScheme) private var colorScheme
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
        guard let first = recent.first?.weight, let last = recent.last?.weight else {
            return .stable
        }

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
        guard let first = recent.first?.bodyFatPercentage, let last = recent.last?.bodyFatPercentage
        else { return .stable }

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

        func color(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .increasing: return .gray
            case .decreasing: return AppTheme.mossGreen
            case .stable: return colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue
            }
        }

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

        func color(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .increasing: return .gray
            case .decreasing: return AppTheme.mossGreen
            case .stable: return colorScheme == .dark ? AppTheme.turquoiseBoost : AppTheme.deepBlue
            }
        }

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
                .cornerRadius(AppLayout.CornerRadius.medium)
            } else if !workoutStore.healthKitManager.isAuthorized {
                VStack(spacing: 12) {
                    Image(systemName: "figure.stand.line.dotted.figure.stand")
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
                .cornerRadius(AppLayout.CornerRadius.medium)
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
                                    value:
                                        "\(weight.formatted(.number.precision(.fractionLength(1)))) kg",
                                    trend: weightTrend.description,
                                    trendIcon: weightTrend.icon,
                                    color: weightTrend.color(for: colorScheme)
                                )
                            }

                            if let bodyFat = currentBodyFat {
                                bodyMetricStatBox(
                                    title: "Körperfett",
                                    value:
                                        "\((bodyFat * 100).formatted(.number.precision(.fractionLength(1))))%",
                                    trend: bodyFatTrend.description,
                                    trendIcon: bodyFatTrend.icon,
                                    color: bodyFatTrend.color(for: colorScheme)
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
                                            colors: [
                                                AppTheme.mossGreen.opacity(0.3),
                                                AppTheme.mossGreen.opacity(0.1),
                                            ],
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
                                                Text(
                                                    "\(weight.formatted(.number.precision(.fractionLength(0))))kg"
                                                )
                                            }
                                        }
                                        AxisGridLine()
                                        AxisTick()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(AppLayout.CornerRadius.small)
                        }

                        // Body Fat Chart
                        if !bodyFatReadings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Körperfettverlauf")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Chart(bodyFatReadings.suffix(30)) { reading in
                                    let chartColor =
                                        colorScheme == .dark
                                        ? AppTheme.turquoiseBoost : AppTheme.deepBlue
                                    LineMark(
                                        x: .value("Datum", reading.date),
                                        y: .value("Körperfett", reading.bodyFatPercentage * 100)
                                    )
                                    .foregroundStyle(chartColor)
                                    .interpolationMethod(.cardinal)

                                    AreaMark(
                                        x: .value("Datum", reading.date),
                                        y: .value("Körperfett", reading.bodyFatPercentage * 100)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                chartColor.opacity(0.3), chartColor.opacity(0.1),
                                            ],
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
                                                Text(
                                                    "\(bodyFat.formatted(.number.precision(.fractionLength(0))))%"
                                                )
                                            }
                                        }
                                        AxisGridLine()
                                        AxisTick()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(AppLayout.CornerRadius.small)
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
                .padding(AppLayout.Spacing.medium)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(AppLayout.CornerRadius.medium)
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
        .padding(AppLayout.Spacing.large)
    }

    // MARK: - Private Helpers

    private func bodyMetricStatBox(
        title: String, value: String, trend: String, trendIcon: String, color: Color
    ) -> some View {
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

// MARK: - Preview

#Preview {
    BodyMetricsInsightsView()
        .environmentObject(WorkoutStoreCoordinator())
}
