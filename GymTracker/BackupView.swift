import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var backupManager = BackupManager.shared
    @State private var isCreatingBackup = false
    @State private var isRestoringBackup = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingRestoreConfirmation = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var backupFileToExport: URL?
    @State private var selectedBackupFile: URL?
    @State private var selectedMergeStrategy: BackupMergeStrategy = .merge
    @State private var lastBackupInfo: String?
    @State private var backupStats: BackupStats?
    
    var body: some View {
        NavigationView {
            List {
                // Backup Creation Section
                Section(header: Text("Backup erstellen")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.customBlue)
                            Text("Backup exportieren")
                                .font(.headline)
                            
                            Spacer()
                            
                            if isCreatingBackup {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        Text("Erstellt eine Sicherungsdatei mit allen deinen Workouts, Übungen, Trainingsverlauf und Profildaten.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let stats = backupStats {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("📋 Workouts:")
                                    Spacer()
                                    Text("\(stats.workoutCount)")
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("💪 Übungen:")
                                    Spacer()
                                    Text("\(stats.exerciseCount)")
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("📊 Trainingssessions:")
                                    Spacer()
                                    Text("\(stats.sessionCount)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.caption)
                            .padding(.top, 4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        createBackup()
                    }
                    
                    if let lastBackup = lastBackupInfo {
                        Text("Letztes Backup: \(lastBackup)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Backup Restoration Section
                Section(header: Text("Backup wiederherstellen")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(Color(red: 0/255, green: 95/255, blue: 86/255))
                            Text("Backup importieren")
                                .font(.headline)
                            
                            Spacer()
                            
                            if isRestoringBackup {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        Text("Lädt eine Sicherungsdatei und stellt deine Daten wieder her.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingImporter = true
                    }
                    
                    // Merge Strategy Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wiederherstellungsmodus")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        ForEach(BackupMergeStrategy.allCases, id: \.self) { strategy in
                            HStack {
                                Button(action: {
                                    selectedMergeStrategy = strategy
                                }) {
                                    HStack {
                                        Image(systemName: selectedMergeStrategy == strategy ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedMergeStrategy == strategy ? .accentColor : .secondary)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(strategy.displayName)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                            Text(strategy.description)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Safety Warning Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.customOrange)
                            Text("Wichtige Hinweise")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Backups enthalten alle deine Trainingsdaten")
                            Text("• Der Modus 'Alle Daten ersetzen' löscht alle vorhandenen Daten")
                            Text("• Erstelle regelmäßig Backups für maximale Sicherheit")
                            Text("• Backup-Dateien sind im JSON-Format und können groß sein")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Bewahre deine Backup-Dateien sicher auf. Bei Problemen mit der Wiederherstellung wende dich an den Support.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Datensicherung")
            .onAppear {
                loadBackupStats()
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: backupFileToExport.map(BackupDocument.init),
            contentType: .json,
            defaultFilename: generateBackupFilename()
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Backup wiederherstellen", isPresented: $showingRestoreConfirmation) {
            Button("Abbrechen", role: .cancel) {
                selectedBackupFile = nil
            }
            Button("Wiederherstellen", role: .destructive) {
                if let file = selectedBackupFile {
                    restoreBackup(from: file)
                }
            }
        } message: {
            VStack(alignment: .leading) {
                Text("Möchtest du das Backup wirklich wiederherstellen?")
                Text("\nModus: \(selectedMergeStrategy.displayName)")
                Text(selectedMergeStrategy.description)
            }
        }
        .alert("Backup Status", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Actions
    
    private func createBackup() {
        guard let context = workoutStore.modelContext else {
            showAlert("Fehler: Kein Datenbankkontext verfügbar.")
            return
        }
        
        isCreatingBackup = true
        
        Task {
            do {
                let backup = try backupManager.createBackup(from: context)
                let fileURL = try backupManager.exportBackupToFile(backup)
                
                await MainActor.run {
                    self.backupFileToExport = fileURL
                    self.isCreatingBackup = false
                    self.showingExporter = true
                    
                    // Update last backup info
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    self.lastBackupInfo = formatter.string(from: Date())
                }
            } catch {
                await MainActor.run {
                    self.isCreatingBackup = false
                    self.showAlert("Backup-Erstellung fehlgeschlagen: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func restoreBackup(from url: URL) {
        guard let context = workoutStore.modelContext else {
            showAlert("Fehler: Kein Datenbankkontext verfügbar.")
            return
        }
        
        isRestoringBackup = true
        selectedBackupFile = nil
        
        Task {
            do {
                try await backupManager.restoreBackup(
                    from: url,
                    to: context,
                    mergeStrategy: selectedMergeStrategy
                )
                
                await MainActor.run {
                    self.isRestoringBackup = false
                    self.loadBackupStats()
                    self.showAlert("Backup erfolgreich wiederhergestellt! Die App wird aktualisiert...")
                    
                    // Notify the workout store to refresh data
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        // Trigger UI refresh by updating the profile trigger
                        self.workoutStore.profileUpdateTrigger = UUID()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isRestoringBackup = false
                    self.showAlert("Backup-Wiederherstellung fehlgeschlagen: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadBackupStats() {
        guard let context = workoutStore.modelContext else { return }
        
        Task {
            do {
                let workouts = try context.fetch(FetchDescriptor<WorkoutEntity>())
                let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                let sessions = try context.fetch(FetchDescriptor<WorkoutSessionEntity>())
                
                await MainActor.run {
                    self.backupStats = BackupStats(
                        workoutCount: workouts.count,
                        exerciseCount: exercises.count,
                        sessionCount: sessions.count
                    )
                }
            } catch {
                print("❌ Fehler beim Laden der Backup-Statistiken: \(error)")
            }
        }
    }
    
    // MARK: - File Handling
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("✅ Backup erfolgreich exportiert nach: \(url)")
            showAlert("Backup erfolgreich erstellt und gespeichert!")
        case .failure(let error):
            print("❌ Export fehlgeschlagen: \(error)")
            showAlert("Export fehlgeschlagen: \(error.localizedDescription)")
        }
        
        // Clean up temporary file
        if let tempFile = backupFileToExport {
            try? FileManager.default.removeItem(at: tempFile)
            backupFileToExport = nil
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                selectedBackupFile = url
                showingRestoreConfirmation = true
            } else {
                showAlert("Keine Datei ausgewählt.")
            }
        case .failure(let error):
            showAlert("Import fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    private func generateBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "workout_backup_\(timestamp).json"
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Supporting Types

struct BackupStats {
    let workoutCount: Int
    let exerciseCount: Int
    let sessionCount: Int
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        // This won't be used for export, but required by protocol
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("temp_backup.json")
        try data.write(to: tempFile)
        self.url = tempFile
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    BackupView()
        .environmentObject(WorkoutStore())
}