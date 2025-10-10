import SwiftUI
import HealthKit
import Charts

struct HeartRateView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var heartRateReadings: [HeartRateReading] = []
    @State private var isLoading = false
    @State private var error: HealthKitError?
    @State private var showingError = false
    @State private var selectedTimeRange: TimeRange = .day
    
    enum TimeRange: String, CaseIterable {
        case hour = "1h"
        case day = "24h" 
        case week = "Woche"
        case month = "Monat"
        
        var displayName: String { rawValue }
        
        var timeInterval: TimeInterval {
            switch self {
            case .hour: return 3600
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
        NavigationStack {
            VStack(spacing: 0) {
                if !workoutStore.healthKitManager.isHealthDataAvailable {
                    ContentUnavailableView(
                        "HealthKit nicht verfügbar",
                        systemImage: "heart.slash",
                        description: Text("HealthKit ist auf diesem Gerät nicht verfügbar.")
                    )
                } else if !workoutStore.healthKitManager.isAuthorized {
                    ContentUnavailableView {
                        Label("HealthKit-Berechtigung erforderlich", systemImage: "heart.text.square")
                    } description: {
                        Text("Gewähre der App Zugriff auf HealthKit, um Herzfrequenzdaten anzuzeigen.")
                    } actions: {
                        Button("Berechtigung erteilen") {
                            requestAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Time Range Picker
                            timeRangePicker
                            
                            // Stats Cards
                            if !heartRateReadings.isEmpty {
                                statsCards
                                
                                // Heart Rate Chart
                                heartRateChart
                            } else if !isLoading {
                                ContentUnavailableView(
                                    "Keine Herzfrequenzdaten",
                                    systemImage: "heart",
                                    description: Text("Für den gewählten Zeitraum sind keine Herzfrequenzdaten verfügbar.")
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        loadHeartRateData()
                    }
                }
            }
            .navigationTitle("Herzfrequenz")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .onAppear {
                if workoutStore.healthKitManager.isAuthorized {
                    loadHeartRateData()
                }
            }
            .alert("Fehler", isPresented: $showingError, presenting: error) { error in
                Button("OK", role: .cancel) { self.error = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
        }
    }
    
    private var timeRangePicker: some View {
        Picker("Zeitraum", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedTimeRange) { _, _ in
            loadHeartRateData()
        }
    }
    
    private var statsCards: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Durchschnitt",
                value: Int(averageHeartRate),
                unit: "bpm",
                color: .customBlue
            )
            
            StatCard(
                title: "Maximum",
                value: Int(maxHeartRate),
                unit: "bpm",
                color: .red
            )
            
            StatCard(
                title: "Minimum",
                value: Int(minHeartRate),
                unit: "bpm",
                color: .green
            )
        }
    }
    
    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verlauf")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(heartRateReadings) { reading in
                LineMark(
                    x: .value("Zeit", reading.timestamp),
                    y: .value("Herzfrequenz", reading.heartRate)
                )
                .foregroundStyle(.red)
                .interpolationMethod(.cardinal)
                
                AreaMark(
                    x: .value("Zeit", reading.timestamp),
                    y: .value("Herzfrequenz", reading.heartRate)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red.opacity(0.3), .red.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.cardinal)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(
                                selectedTimeRange == .hour ? .dateTime.hour().minute() : 
                                selectedTimeRange == .day ? .dateTime.hour() :
                                .dateTime.month().day()
                            ))
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
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
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private func requestAuthorization() {
        Task {
            do {
                try await workoutStore.requestHealthKitAuthorization()
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

struct StatCard: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    HeartRateView()
        .environmentObject(WorkoutStore())
}