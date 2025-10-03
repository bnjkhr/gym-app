import SwiftUI

import SwiftUI
import SwiftData

// MARK: - Personal Records Badge
struct PersonalRecordBadge: View {
    let recordType: RecordType
    
    var body: some View {
        HStack(spacing: 4) {
            Text(recordType.emoji)
                .font(.caption)
            Text(recordType.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
        .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Exercise Records List View
struct ExerciseRecordsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var searchText = ""
    
    private var filteredRecords: [ExerciseRecord] {
        let records = workoutStore.getAllExerciseRecords()
        if searchText.isEmpty {
            return records
        } else {
            return records.filter { $0.exerciseName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredRecords.isEmpty {
                    ContentUnavailableView(
                        "Keine Personal Records",
                        systemImage: "trophy",
                        description: Text("Führe Trainings aus, um deine ersten Personal Records zu erzielen!")
                    )
                } else {
                    ForEach(filteredRecords, id: \.id) { record in
                        ExerciseRecordRow(record: record)
                    }
                }
            }
            .navigationTitle("Personal Records")
            .searchable(text: $searchText, prompt: "Übungen suchen...")
        }
    }
}

// MARK: - Exercise Record Row
struct ExerciseRecordRow: View {
    let record: ExerciseRecord
    @State private var showingDetails = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(record.exerciseName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    RecordStat(
                        title: "Höchstes Gewicht",
                        value: "\(String(format: "%.0f", record.maxWeight)) kg",
                        subtitle: "\(record.maxWeightReps) Wdh.",
                        color: .blue
                    )
                    
                    RecordStat(
                        title: "Meiste Wdh.",
                        value: "\(record.maxReps)",
                        subtitle: "\(String(format: "%.0f", record.maxRepsWeight)) kg",
                        color: .green
                    )
                    
                    RecordStat(
                        title: "Beste 1RM",
                        value: "\(String(format: "%.0f", record.bestEstimatedOneRepMax)) kg",
                        subtitle: "geschätzt",
                        color: .purple
                    )
                }
                
                Text("Zuletzt aktualisiert: \(dateFormatter.string(from: record.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetails) {
            ExerciseRecordDetailView(record: record)
        }
    }
}

// MARK: - Record Stat
struct RecordStat: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Exercise Record Detail View
struct ExerciseRecordDetailView: View {
    let record: ExerciseRecord
    @Environment(\.dismiss) private var dismiss
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Übung") {
                    Text(record.exerciseName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Section("Höchstes Gewicht") {
                    DetailRow(
                        title: "Gewicht",
                        value: "\(String(format: "%.1f", record.maxWeight)) kg",
                        icon: "scalemass"
                    )
                    DetailRow(
                        title: "Wiederholungen",
                        value: "\(record.maxWeightReps)",
                        icon: "repeat"
                    )
                    DetailRow(
                        title: "Datum",
                        value: dateFormatter.string(from: record.maxWeightDate),
                        icon: "calendar"
                    )
                }
                
                Section("Meiste Wiederholungen") {
                    DetailRow(
                        title: "Wiederholungen",
                        value: "\(record.maxReps)",
                        icon: "repeat"
                    )
                    DetailRow(
                        title: "Gewicht",
                        value: "\(String(format: "%.1f", record.maxRepsWeight)) kg",
                        icon: "scalemass"
                    )
                    DetailRow(
                        title: "Datum",
                        value: dateFormatter.string(from: record.maxRepsDate),
                        icon: "calendar"
                    )
                }
                
                Section("Beste geschätzte 1RM") {
                    DetailRow(
                        title: "1RM",
                        value: "\(String(format: "%.1f", record.bestEstimatedOneRepMax)) kg",
                        icon: "crown"
                    )
                    DetailRow(
                        title: "Basierend auf",
                        value: "\(String(format: "%.1f", record.bestOneRepMaxWeight)) kg × \(record.bestOneRepMaxReps)",
                        icon: "equal"
                    )
                    DetailRow(
                        title: "Datum",
                        value: dateFormatter.string(from: record.bestOneRepMaxDate),
                        icon: "calendar"
                    )
                }
                
                Section("Formel") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1RM Schätzung nach Brzycki:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("1RM = Gewicht ÷ (1.0278 - 0.0278 × Wiederholungen)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                
                Section {
                    HStack {
                        Text("Erstellt")
                        Spacer()
                        Text(dateFormatter.string(from: record.createdAt))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Zuletzt aktualisiert")
                        Spacer()
                        Text(dateFormatter.string(from: record.updatedAt))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Personal Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    let sampleRecord = ExerciseRecord(
        exerciseId: UUID(),
        exerciseName: "Bankdrücken",
        maxWeight: 100.0,
        maxWeightReps: 5,
        maxWeightDate: Date(),
        maxReps: 15,
        maxRepsWeight: 60.0,
        maxRepsDate: Date(),
        bestEstimatedOneRepMax: 112.5,
        bestOneRepMaxWeight: 90.0,
        bestOneRepMaxReps: 8,
        bestOneRepMaxDate: Date()
    )
    
    ExerciseRecordDetailView(record: sampleRecord)
}