import SwiftUI
import UniformTypeIdentifiers
import HealthKit

private struct SettingsScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum ImportFormat: String, CaseIterable {
    case custom = "Eigene CSV"
    case strong = "Strong"
    case hevy = "Hevy"
    
    var description: String {
        switch self {
        case .custom:
            return "Erstelle eine CSV mit 'Übung,Sätze,Wiederholungen,Gewicht' pro Zeile und importiere sie als Vorlage."
        case .strong:
            return "Importiere einen Export aus der Strong App (CSV Format)."
        case .hevy:
            return "Importiere einen Export aus der Hevy App (CSV Format). Erkennt automatisch Workout- und Messdaten."
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingImporter = false
    @State private var showingHealthKitSetup = false
    @State private var showingImportFormatSelection = false
    @State private var selectedImportFormat: ImportFormat = .custom

    @State private var showingBackupView = false
    @State private var alertMessage: String?
    @State private var isShowingAlert = false
    @State private var isImporting = false
    @State private var importProgress: String = ""
    
    // App Reset States
    @State private var showingFirstResetConfirmation = false
    @State private var showingSecondResetConfirmation = false

    // Max. Importgröße (z. B. 2 MB)
    private let maxImportBytes: Int = 2 * 1024 * 1024

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Profile Section
                ProfileView()
                
                // Trainingsziele Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trainingsziele")
                        .font(.headline)
                    
                    Stepper(value: $workoutStore.weeklyGoal, in: 1...14) {
                        Text("Wochenziel: \(workoutStore.weeklyGoal) Workouts")
                    }
                    
                    Text("Passe dein Wochenziel an, um den Fortschritt-Tab auf deine Planung abzustimmen.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Datensicherung Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Datensicherung")
                        .font(.headline)
                    
                    Button {
                        showingBackupView = true
                    } label: {
                        Label("Backup & Wiederherstellung", systemImage: "externaldrive")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                    
                    Text("Erstelle ein Backups deiner Trainingsdaten oder stelle sie aus einer Sicherungsdatei wieder her.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Workouts Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workouts")
                        .font(.headline)
                    
                    Button {
                        showingImportFormatSelection = true
                    } label: {
                        Label("Workouts importieren (CSV)", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                    
                    Text("Importiere Workouts aus verschiedenen Apps oder verwende dein eigenes CSV-Format.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // HealthKit Section
                if workoutStore.healthKitManager.isHealthDataAvailable {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HealthKit Integration")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Status")
                                    .font(.subheadline)
                                Text(workoutStore.healthKitManager.isAuthorized ? "Aktiviert" : "Nicht aktiviert")
                                    .font(.caption)
                                    .foregroundColor(workoutStore.healthKitManager.isAuthorized ? .green : .secondary)
                            }
                            
                            Spacer()
                            
                            Button(workoutStore.healthKitManager.isAuthorized ? "Einstellungen" : "Aktivieren") {
                                if workoutStore.healthKitManager.isAuthorized {
                                    // Open system settings for health permissions
                                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsUrl)
                                    }
                                } else {
                                    showingHealthKitSetup = true
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if workoutStore.healthKitManager.isAuthorized {
                            Text("Deine Workouts werden automatisch in der Health App gespeichert.")
                        } else {
                            Text("Verbinde dich mit HealthKit für automatische Synchronisation deiner Workouts und Profildaten.")
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }



                // Benachrichtigungen Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Benachrichtigungen")
                        .font(.headline)
                    
                    Toggle(isOn: $workoutStore.restNotificationsEnabled) {
                        Text("Pausen-Benachrichtigungen")
                    }
                    .onChange(of: workoutStore.restNotificationsEnabled) { _, newValue in
                        if newValue {
                            Task { await NotificationManager.shared.requestAuthorization() }
                        } else {
                            NotificationManager.shared.cancelRestEndNotification()
                        }
                    }
                    
                    Text("Informiert dich, wenn deine Satz-Pause endet.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Beispielworkouts laden
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        workoutStore.resetToSampleData()
                        showAlert(message: "Beispielworkouts geladen!")
                    } label: {
                        Label("Beispielworkouts laden", systemImage: "arrow.clockwise")
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // App zurücksetzen (ganz unten)
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showingFirstResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.white)
                            Text("App zurücksetzen")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Lösche alle Trainingsdaten, Workouts und Einstellungen. Diese Aktion kann nicht rückgängig gemacht werden.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .appEdgePadding()
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importWorkout(from: url, format: selectedImportFormat)
                } else {
                    showAlert(message: "Keine Datei ausgewählt.")
                }
            case .failure(let error):
                showAlert(message: "Import fehlgeschlagen: \(error.localizedDescription)")
            }
        }
        .confirmationDialog("Import Format wählen", isPresented: $showingImportFormatSelection) {
            ForEach(ImportFormat.allCases, id: \.self) { format in
                Button(format.rawValue) {
                    selectedImportFormat = format
                    showingImporter = true
                }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Wähle das Format deiner CSV-Datei:")
        }
        .sheet(isPresented: $showingHealthKitSetup) {
            HealthKitSetupView()
                .environmentObject(workoutStore)
        }
        .sheet(isPresented: $showingBackupView) {
            BackupView()
                .environmentObject(workoutStore)
        }
        .alert("Import", isPresented: $isShowingAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(alertMessage ?? "")
        })
        .alert("App zurücksetzen", isPresented: $showingFirstResetConfirmation, actions: {
            Button("Abbrechen", role: .cancel) {}
            Button("Weiter", role: .destructive) {
                showingSecondResetConfirmation = true
            }
        }, message: {
            Text("Möchtest du wirklich alle App-Daten löschen?\n\nDies umfasst:\n• Alle Workouts und Trainingsvorlagen\n• Übungshistorie und Statistiken\n• Persönliche Einstellungen\n\nEs wird empfohlen, vorher ein Backup zu erstellen.")
        })
        .alert("Letzte Warnung", isPresented: $showingSecondResetConfirmation, actions: {
            Button("Abbrechen", role: .cancel) {}
            Button("Alles löschen", role: .destructive) {
                resetApp()
            }
        }, message: {
            Text("Diese Aktion kann NICHT rückgängig gemacht werden!\n\nAlle deine Trainingsdaten gehen unwiderruflich verloren.\n\nBist du dir absolut sicher?")
        })
        .overlay(
            // Loading indicator overlay
            Group {
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            VStack(spacing: 8) {
                                Text("Import läuft...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if !importProgress.isEmpty {
                                    Text(importProgress)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.primary.opacity(0.8))
                        )
                        .padding(.horizontal, 40)
                    }
                }
            }
        )
    }

    private func importWorkout(from url: URL, format: ImportFormat) {
        // Show loading indicator
        isImporting = true
        importProgress = "Datei wird gelesen..."
        
        Task.detached(priority: .userInitiated) {
            // Access security-scoped resource INSIDE the detached task
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStop { 
                    url.stopAccessingSecurityScopedResource() 
                }
                // Hide loading indicator when done
                Task { @MainActor in
                    self.isImporting = false
                    self.importProgress = ""
                }
            }

            do {
                // Update progress
                await MainActor.run {
                    importProgress = "Dateigröße wird geprüft..."
                }
                
                // Prüfe Dateigröße
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                if let size = resourceValues.fileSize, size > maxImportBytes {
                    throw ImportError.tooLarge
                }

                // Update progress
                await MainActor.run {
                    importProgress = "Datei wird gelesen..."
                }

                // Lese Datei (Hintergrund)
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard let content = String(data: data, encoding: .utf8) else {
                    throw ImportError.invalidEncoding
                }

                // Update progress based on format
                await MainActor.run {
                    switch format {
                    case .strong:
                        importProgress = "Strong-Daten werden verarbeitet...\nBei großen Dateien kann dies einige Minuten dauern."
                    case .hevy:
                        importProgress = "Hevy-Daten werden verarbeitet..."
                    case .custom:
                        importProgress = "CSV-Daten werden verarbeitet..."
                    }
                }

                let workoutExercises: [WorkoutExercise]
                let workoutName: String
                
                switch format {
                case .custom:
                    let result = try await parseCustomCSV(content, url: url)
                    workoutExercises = result.exercises
                    workoutName = result.name
                case .strong:
                    // Strong-Daten werden direkt als Sessions gespeichert
                    try await parseStrongCSV(content, url: url)
                    return // Früher Rücksprung, da keine Workout-Vorlage erstellt wird
                case .hevy:
                    let result = try await parseHevyCSV(content, url: url)
                    workoutExercises = result.exercises
                    workoutName = result.name
                }

                guard !workoutExercises.isEmpty else { throw ImportError.emptyFile }

                // Update progress
                await MainActor.run {
                    importProgress = "Workout wird erstellt..."
                }

                let importedWorkout = Workout(
                    name: workoutName,
                    exercises: workoutExercises,
                    defaultRestTime: 90,
                    notes: "Importiert aus \(format.rawValue)"
                )

                await MainActor.run {
                    workoutStore.addWorkout(importedWorkout)
                    showAlert(message: "Workout \"\(workoutName)\" importiert (\(workoutExercises.count) Übungen).")
                }
            } catch let error as ImportError {
                await MainActor.run { 
                    if case .strongDataProcessed = error {
                        showAlert(message: error.localizedDescription)
                    } else if case .hevyWorkoutDataProcessed = error {
                        showAlert(message: error.localizedDescription)
                    } else if case .measurementDataProcessed = error {
                        showAlert(message: error.localizedDescription)
                    } else {
                        showAlert(message: error.localizedDescription)
                    }
                }
            } catch {
                await MainActor.run { showAlert(message: "Import fehlgeschlagen: \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - Parser-Funktionen
    
    private func parseCustomCSV(_ content: String, url: URL) async throws -> (exercises: [WorkoutExercise], name: String) {
        // Parse CSV robust (unterstützt "," und ";", Anführungszeichen, Escaping)
        let parseResult = parseCSV(content)
        var rows = parseResult.rows
        let delimiter = parseResult.delimiter

        // Filtere leere Zeilen
        rows = rows.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                   .filter { !$0.joined().isEmpty }

        guard !rows.isEmpty else { throw ImportError.emptyFile }

        // Kopfzeile erkennen (tolerant)
        if let first = rows.first, first.count >= 4 {
            let headerJoined = first.joined(separator: " ").lowercased()
            if headerJoined.contains("übung") || headerJoined.contains("uebung") || headerJoined.contains("exercise") {
                rows.removeFirst()
            }
        }

        var workoutExercises: [WorkoutExercise] = []
        var skipped: Int = 0

        for row in rows {
            // Wir erwarten mindestens 4 Spalten: name, sets, reps, weight
            guard row.count >= 4 else {
                skipped += 1
                continue
            }

            let name = row[0].trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse Ints robust
            let sets = Int(row[1].replacingOccurrences(of: " ", with: "")) ?? -1
            let reps = Int(row[2].replacingOccurrences(of: " ", with: "")) ?? -1

            // Gewicht: Dezimaltrennzeichen handhaben
            var weightString = row[3].trimmingCharacters(in: .whitespaces)
            // Wenn der Spaltentrenner ";" ist, ist "," als Dezimaltrennzeichen wahrscheinlich
            if delimiter == ";" {
                weightString = weightString.replacingOccurrences(of: ",", with: ".")
            } else {
                // Wenn kein Punkt vorhanden ist, aber ein Komma, interpretiere als Dezimal-Komma
                if weightString.contains(",") && !weightString.contains(".") {
                    weightString = weightString.replacingOccurrences(of: ",", with: ".")
                }
            }
            let weight = Double(weightString) ?? -1

            // Validierung (wie zuvor, aber skippen statt throw)
            guard !name.isEmpty && name.count <= 100,
                  sets > 0 && sets <= 50,
                  reps > 0 && reps <= 500,
                  weight >= 0 && weight <= 2000 else {
                skipped += 1
                continue
            }

            // Baue Übungen/Sätze
            let exercise = await workoutStore.exercise(named: name)
            let exerciseSets = (0..<sets).map { _ in
                ExerciseSet(reps: reps, weight: weight, restTime: 90, completed: false)
            }
            workoutExercises.append(WorkoutExercise(exercise: exercise, sets: exerciseSets))
        }

        let workoutName = url.deletingPathExtension().lastPathComponent
        return (exercises: workoutExercises, name: workoutName)
    }
    
    private func parseStrongCSV(_ content: String, url: URL) async throws -> (exercises: [WorkoutExercise], name: String) {
        // Progress update
        await MainActor.run {
            importProgress = "CSV wird analysiert..."
        }
        
        let parseResult = parseCSV(content)
        var rows = parseResult.rows
        
        // Filtere leere Zeilen
        rows = rows.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                   .filter { !$0.joined().isEmpty }

        guard !rows.isEmpty else { throw ImportError.emptyFile }

        // Entferne Header - Strong CSV hat immer einen Header
        if !rows.isEmpty {
            rows.removeFirst()
        }

        // Progress update
        await MainActor.run {
            importProgress = "Verarbeite \(rows.count) Datensätze..."
        }

        // Strong CSV Format: Datum, Workout-Name, Dauer, Name der Übung, Reihenfolge festlegen, Gewicht, Wiederh., Entfernung, Sekunden, Notizen, Workout-Notizen, RPE
        // Spalten: 0=Datum, 1=Workout-Name, 2=Dauer, 3=Name der Übung, 4=Reihenfolge, 5=Gewicht, 6=Wiederh., 7=Entfernung, 8=Sekunden, 9=Notizen, 10=Workout-Notizen, 11=RPE

        // Gruppiere Workouts nach Datum und Name
        var workoutsDict: [String: (date: Date, name: String, duration: TimeInterval?, exercises: [String: [ExerciseSet]])] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let totalRows = rows.count
        var processedRows = 0
        
        for row in rows {
            processedRows += 1
            
            // Update progress every 100 rows or at significant milestones
            if processedRows % 100 == 0 || processedRows == totalRows {
                await MainActor.run {
                    let percentage = Int((Double(processedRows) / Double(totalRows)) * 100)
                    importProgress = "Verarbeite Datensätze... (\(percentage)%)\n\(processedRows) von \(totalRows)"
                }
            }
            
            guard row.count >= 7 else { continue }
            
            // Skip rest periods (Ruhezeit) and warm-up sets
            let setOrder = row[4].trimmingCharacters(in: .whitespacesAndNewlines)
            if setOrder.lowercased().contains("ruhezeit") || setOrder.uppercased() == "W" { 
                continue 
            }
            
            // Parse Datum
            let dateString = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let workoutDate = dateFormatter.date(from: dateString) else { continue }
            
            let workoutName = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !workoutName.isEmpty else { continue }
            
            // Parse Dauer (falls vorhanden) - Strong verwendet Sekunden als Einheit
            let durationString = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let duration: TimeInterval?
            if durationString.isEmpty || durationString == "0" {
                duration = nil // Keine Dauer verfügbar
            } else {
                // Strong-Dauer ist in Sekunden, konvertiere zu TimeInterval
                duration = TimeInterval(durationString)
            }
            
            let exerciseName = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !exerciseName.isEmpty else { continue }
            
            // Parse Gewicht und Wiederholungen
            let weightString = row[5].replacingOccurrences(of: ",", with: ".")
            let weight = Double(weightString) ?? 0
            
            let repsString = row[6].replacingOccurrences(of: ",", with: ".")
            let reps = Int(Double(repsString) ?? 0)
            
            // Parse rest time from Sekunden column if available, default to 90 seconds
            let restTime = row.count > 8 && !row[8].isEmpty ? Int(Double(row[8]) ?? 90) : 90
            
            guard reps > 0 else { continue }
            
            let exerciseSet = ExerciseSet(
                reps: reps, 
                weight: weight, 
                restTime: Double(restTime), 
                completed: true // Strong-Daten sind abgeschlossen
            )
            
            // Erstelle eindeutigen Schlüssel für Workout
            let workoutKey = "\(workoutName)_\(workoutDate.timeIntervalSince1970)"
            
            if workoutsDict[workoutKey] == nil {
                workoutsDict[workoutKey] = (
                    date: workoutDate,
                    name: workoutName,
                    duration: duration,
                    exercises: [:]
                )
            }
            
            if workoutsDict[workoutKey]!.exercises[exerciseName] == nil {
                workoutsDict[workoutKey]!.exercises[exerciseName] = []
            }
            workoutsDict[workoutKey]!.exercises[exerciseName]?.append(exerciseSet)
        }
        
        // Progress update
        await MainActor.run {
            importProgress = "Erstelle Workout-Sessions..."
        }
        
        // Speichere alle gefundenen Workouts als abgeschlossene Sessions
        var importedCount = 0
        let totalWorkouts = workoutsDict.count
        
        for (_, workoutData) in workoutsDict {
            importedCount += 1
            
            // Progress update
            await MainActor.run {
                importProgress = "Speichere Workout \(importedCount) von \(totalWorkouts)...\n\"\(workoutData.name)\""
            }
            
            var workoutExercises: [WorkoutExercise] = []
            
            // Exercise-Auflösung außerhalb des MainActor-Blocks
            for (exerciseName, sets) in workoutData.exercises {
                let exercise = await workoutStore.exercise(named: exerciseName)
                let workoutExercise = WorkoutExercise(exercise: exercise, sets: sets)
                workoutExercises.append(workoutExercise)
            }
            
            let session = WorkoutSession(
                templateId: nil, // Strong-Imports haben keine Template-ID
                name: workoutData.name,
                date: workoutData.date,
                exercises: workoutExercises,
                defaultRestTime: 90,
                duration: workoutData.duration ?? estimateWorkoutDuration(for: workoutExercises),
                notes: "Importiert aus Strong"
            )
            
            // Direkt als abgeschlossene Session speichern
            await MainActor.run {
                guard let context = workoutStore.modelContext else { 
                    print("❌ ModelContext ist nil beim Speichern einer importierten Session")
                    return
                }
                
                do {
                    try DataManager.shared.recordSession(session, to: context)
                    workoutStore.invalidateCaches()
                    
                    // Debug information for statistics verification
                    let volume = session.exercises.reduce(0) { total, ex in
                        total + ex.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
                    }
                    let totalReps = session.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
                    let durationText = session.duration.map { "\(Int($0/60)) Min" } ?? "Unbekannt"
                    
                    print("✅ Importierte Session gespeichert: \(session.name)")
                    print("   📊 Statistik-Daten: Volumen: \(Int(volume))kg, Wiederholungen: \(totalReps), Dauer: \(durationText)")
                } catch {
                    print("❌ Fehler beim Speichern der importierten Session: \(error)")
                }
            }
        }
        
        // Gib leere Werte zurück, da wir keine Workout-Vorlage erstellen
        throw ImportError.strongDataProcessed(count: importedCount)
    }

    
    private func parseHevyCSV(_ content: String, url: URL) async throws -> (exercises: [WorkoutExercise], name: String) {
        // Progress update
        await MainActor.run {
            importProgress = "Analysiere Hevy-Datei..."
        }
        
        // Erkenne automatisch ob es Workout- oder Messdaten sind
        let dataType = detectHevyDataType(content)
        
        switch dataType {
        case .workoutData:
            return try await parseHevyWorkoutData(content, url: url)
        case .measurementData:
            try await parseHevyMeasurementData(content, url: url)
            // Messdaten werden direkt verarbeitet, keine Workout-Vorlage erstellt
            throw ImportError.measurementDataProcessed
        case .unknown:
            throw ImportError.unknownHevyFormat
        }
    }
    
    private enum HevyDataType {
        case workoutData
        case measurementData
        case unknown
    }
    
    private func detectHevyDataType(_ content: String) -> HevyDataType {
        let lines = content.components(separatedBy: CharacterSet.newlines)
        guard let firstLine = lines.first?.lowercased() else { return .unknown }
        
        // Erkenne Workout-Daten anhand charakteristischer Spalten
        if firstLine.contains("title") && firstLine.contains("exercise_title") && firstLine.contains("set_index") {
            return .workoutData
        }
        
        // Erkenne Messdaten anhand charakteristischer Spalten
        if firstLine.contains("date") && firstLine.contains("weight_kg") && firstLine.contains("fat_percent") {
            return .measurementData
        }
        
        return .unknown
    }
    
    private func parseHevyWorkoutData(_ content: String, url: URL) async throws -> (exercises: [WorkoutExercise], name: String) {
        await MainActor.run {
            importProgress = "Verarbeite Hevy-Workout-Daten..."
        }
        
        let parseResult = parseCSV(content)
        var rows = parseResult.rows
        
        // Filtere leere Zeilen
        rows = rows.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                   .filter { !$0.joined().isEmpty }

        guard !rows.isEmpty else { throw ImportError.emptyFile }

        // Entferne Header
        if !rows.isEmpty {
            rows.removeFirst()
        }

        // Hevy Workout CSV Format:
        // title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe
        // 0=title, 1=start_time, 2=end_time, 3=description, 4=exercise_title, 9=weight_kg, 10=reps, 8=set_type

        await MainActor.run {
            importProgress = "Verarbeite \(rows.count) Hevy-Datensätze..."
        }

        // Gruppiere Workouts nach Titel und Startzeit
        var workoutsDict: [String: (title: String, startTime: Date?, exercises: [String: [ExerciseSet]])] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy, HH:mm"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let totalRows = rows.count
        var processedRows = 0
        
        for row in rows {
            processedRows += 1
            
            // Progress update every 100 rows
            if processedRows % 100 == 0 || processedRows == totalRows {
                await MainActor.run {
                    let percentage = Int((Double(processedRows) / Double(totalRows)) * 100)
                    importProgress = "Verarbeite Hevy-Daten... (\(percentage)%)\n\(processedRows) von \(totalRows)"
                }
            }
            
            guard row.count >= 11 else { continue }
            
            let workoutTitle = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let startTimeString = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let exerciseTitle = row[4].trimmingCharacters(in: .whitespacesAndNewlines)
            let setType = row[8].trimmingCharacters(in: .whitespacesAndNewlines)
            let weightString = row[9].replacingOccurrences(of: ",", with: ".")
            let repsString = row[10].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip warm-up sets
            if setType.lowercased() == "warmup" { continue }
            
            guard !workoutTitle.isEmpty && !exerciseTitle.isEmpty else { continue }
            
            // Parse Startzeit
            let startTime = dateFormatter.date(from: startTimeString)
            
            // Parse Gewicht und Wiederholungen
            let weight = Double(weightString) ?? 0
            let reps = Int(repsString) ?? 0
            
            guard reps > 0 else { continue }
            
            let exerciseSet = ExerciseSet(
                reps: reps,
                weight: weight,
                restTime: 90, // Standard-Pausenzeit
                completed: true // Hevy-Daten sind abgeschlossen
            )
            
            // Erstelle eindeutigen Schlüssel für Workout
            let workoutKey = "\(workoutTitle)_\(startTimeString)"
            
            if workoutsDict[workoutKey] == nil {
                workoutsDict[workoutKey] = (
                    title: workoutTitle,
                    startTime: startTime,
                    exercises: [:]
                )
            }
            
            if workoutsDict[workoutKey]!.exercises[exerciseTitle] == nil {
                workoutsDict[workoutKey]!.exercises[exerciseTitle] = []
            }
            workoutsDict[workoutKey]!.exercises[exerciseTitle]?.append(exerciseSet)
        }
        
        await MainActor.run {
            importProgress = "Erstelle Hevy Workout-Sessions..."
        }
        
        // Speichere alle gefundenen Workouts als abgeschlossene Sessions
        var importedCount = 0
        let totalWorkouts = workoutsDict.count
        
        for (_, workoutData) in workoutsDict {
            importedCount += 1
            
            await MainActor.run {
                importProgress = "Speichere Workout \(importedCount) von \(totalWorkouts)...\n\"\(workoutData.title)\""
            }
            
            var workoutExercises: [WorkoutExercise] = []
            
            for (exerciseName, sets) in workoutData.exercises {
                let exercise = await workoutStore.exercise(named: exerciseName)
                let workoutExercise = WorkoutExercise(exercise: exercise, sets: sets)
                workoutExercises.append(workoutExercise)
            }
            
            let session = WorkoutSession(
                templateId: nil,
                name: workoutData.title,
                date: workoutData.startTime ?? Date(),
                exercises: workoutExercises,
                defaultRestTime: 90,
                duration: estimateWorkoutDuration(for: workoutExercises),
                notes: "Importiert aus Hevy"
            )
            
            await MainActor.run {
                guard let context = workoutStore.modelContext else {
                    print("❌ ModelContext ist nil beim Speichern einer Hevy-Session")
                    return
                }
                
                do {
                    try DataManager.shared.recordSession(session, to: context)
                    workoutStore.invalidateCaches()
                    
                    let volume = session.exercises.reduce(0) { total, ex in
                        total + ex.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
                    }
                    let totalReps = session.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
                    
                    print("✅ Hevy-Session importiert: \(session.name)")
                    print("   📊 Volumen: \(Int(volume))kg, Wiederholungen: \(totalReps)")
                } catch {
                    print("❌ Fehler beim Speichern der Hevy-Session: \(error)")
                }
            }
        }
        
        // Gib leere Werte zurück, da wir keine Workout-Vorlage erstellen
        throw ImportError.hevyWorkoutDataProcessed(count: importedCount)
    }
    
    private func parseHevyMeasurementData(_ content: String, url: URL) async throws {
        await MainActor.run {
            importProgress = "Verarbeite Hevy-Messdaten..."
        }
        
        let parseResult = parseCSV(content)
        var rows = parseResult.rows
        
        // Filtere leere Zeilen
        rows = rows.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                   .filter { !$0.joined().isEmpty }

        guard !rows.isEmpty else { throw ImportError.emptyFile }

        // Entferne Header
        if !rows.isEmpty {
            rows.removeFirst()
        }

        await MainActor.run {
            importProgress = "Verarbeite \(rows.count) Messdaten-Einträge..."
        }

        // Hevy Measurement CSV Format:
        // date,weight_kg,fat_percent,neck_cm,shoulder_cm,chest_cm,left_bicep_cm,right_bicep_cm,left_forearm_cm,right_forearm_cm,abdomen_cm,waist_cm,hips_cm,left_thigh_cm,right_thigh_cm,left_calf_cm,right_calf_cm
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy, HH:mm"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        var importedMeasurements = 0
        let totalRows = rows.count
        var processedRows = 0
        
        // Prüfe ob HealthKit verfügbar ist
        guard workoutStore.healthKitManager.isHealthDataAvailable else {
            throw ImportError.healthKitNotAvailable
        }
        
        // Prüfe HealthKit-Berechtigung
        guard workoutStore.healthKitManager.isAuthorized else {
            throw ImportError.healthKitNotAuthorized
        }
        
        for row in rows {
            processedRows += 1
            
            if processedRows % 50 == 0 || processedRows == totalRows {
                await MainActor.run {
                    let percentage = Int((Double(processedRows) / Double(totalRows)) * 100)
                    importProgress = "Verarbeite Messdaten... (\(percentage)%)\n\(processedRows) von \(totalRows)"
                }
            }
            
            guard row.count >= 3 else { continue }
            
            let dateString = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let weightString = row[1].replacingOccurrences(of: ",", with: ".")
            let fatPercentString = row[2].replacingOccurrences(of: ",", with: ".")
            
            guard !dateString.isEmpty else { continue }
            
            // Parse Datum
            guard let measurementDate = dateFormatter.date(from: dateString) else { continue }
            
            // Parse Gewicht
            if !weightString.isEmpty, let weight = Double(weightString), weight > 0 {
                do {
                    try await workoutStore.healthKitManager.saveWeight(weight, date: measurementDate)
                    importedMeasurements += 1
                } catch {
                    print("❌ Fehler beim Speichern des Gewichts für \(dateString): \(error)")
                }
            }
            
            // Parse Körperfettanteil
            if !fatPercentString.isEmpty, let fatPercent = Double(fatPercentString), fatPercent > 0 {
                do {
                    try await workoutStore.healthKitManager.saveBodyFatPercentage(fatPercent / 100.0, date: measurementDate) // Hevy verwendet Prozent (0-100), HealthKit verwendet Dezimal (0-1)
                } catch {
                    print("❌ Fehler beim Speichern des Körperfettanteils für \(dateString): \(error)")
                }
            }
            
            // Weitere Körpermaße könnten hier hinzugefügt werden (Körperumfänge, etc.)
        }
        
        print("✅ \(importedMeasurements) Messdaten aus Hevy importiert und in HealthKit gespeichert")
    }
    
    /// Einfache, robuste CSV-Parsing-Funktion, die "," oder ";" als Trennzeichen unterstützt
    /// sowie Anführungszeichen und doppelte Anführungszeichen (\"") innerhalb von Feldern behandelt.
    private func parseCSV(_ content: String) -> (rows: [[String]], delimiter: Character) {
        let lines = content.components(separatedBy: CharacterSet.newlines)

        // Heuristik zur Delimiter-Erkennung anhand der ersten nicht-leeren Zeile
        var detectedDelimiter: Character = ","
        if let sample = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            let commaCount = sample.filter { $0 == "," }.count
            let semicolonCount = sample.filter { $0 == ";" }.count
            detectedDelimiter = (semicolonCount > commaCount) ? ";" : ","
        }

        var rows: [[String]] = []
        rows.reserveCapacity(lines.count)

        for rawLine in lines {
            var line = rawLine
            // Überspringe komplett leere Zeilen
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            var fields: [String] = []
            var current = ""
            var inQuotes = false
            var i = line.startIndex

            while i < line.endIndex {
                let ch = line[i]
                if ch == "\"" { // Quote
                    if inQuotes {
                        // Prüfe auf escaped quote
                        let next = line.index(after: i)
                        if next < line.endIndex && line[next] == "\"" {
                            current.append("\"")
                            i = next
                        } else {
                            inQuotes = false
                        }
                    } else {
                        inQuotes = true
                    }
                } else if ch == detectedDelimiter && !inQuotes {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
                i = line.index(after: i)
            }
            fields.append(current)

            rows.append(fields)
        }

        return (rows, detectedDelimiter)
    }

    private func showAlert(message: String) {
        alertMessage = message
        isShowingAlert = true
    }
    
    private func resetApp() {
        // Reset all app data and settings
        Task { @MainActor in
            do {
                // Clear WorkoutStore data
                try await workoutStore.resetAllData()
                
                // Reset UserDefaults settings
                let defaults = UserDefaults.standard
                let domain = Bundle.main.bundleIdentifier!
                defaults.removePersistentDomain(forName: domain)
                defaults.synchronize()
                
                // Show success message
                showAlert(message: "App wurde erfolgreich zurückgesetzt. Alle Daten wurden gelöscht.")
            } catch {
                showAlert(message: "Fehler beim Zurücksetzen: \(error.localizedDescription)")
            }
        }
    }
    
    /// Schätzt die Workout-Dauer basierend auf Anzahl der Sätze und Pausen
    private func estimateWorkoutDuration(for exercises: [WorkoutExercise]) -> TimeInterval {
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let avgRestTime: Double = 90 // Sekunden
        let avgSetTime: Double = 45   // Sekunden pro Satz (inklusive Ausführung)
        let warmupTime: Double = 300  // 5 Minuten Aufwärmen
        
        let estimatedDuration = warmupTime + Double(totalSets) * (avgSetTime + avgRestTime)
        return estimatedDuration
    }

    private enum ImportError: LocalizedError {
        case invalidEncoding
        case emptyFile
        case invalidRow(String)
        case tooLarge
        case strongDataProcessed(count: Int)
        case hevyWorkoutDataProcessed(count: Int)
        case measurementDataProcessed
        case unknownHevyFormat
        case healthKitNotAvailable
        case healthKitNotAuthorized

        var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "Die Datei konnte nicht gelesen werden."
            case .emptyFile:
                return "Keine gültigen Zeilen gefunden."
            case .invalidRow(let row):
                return "Ungültige Zeile: \(row)"
            case .tooLarge:
                return "Die Datei ist zu groß. Bitte importiere eine kleinere CSV (max. 2 MB)."
            case .strongDataProcessed(let count):
                return "\(count) abgeschlossene Workout(s) aus Strong importiert und zur Historie hinzugefügt."
            case .hevyWorkoutDataProcessed(let count):
                return "\(count) abgeschlossene Workout(s) aus Hevy importiert und zur Historie hinzugefügt."
            case .measurementDataProcessed:
                return "Hevy-Messdaten erfolgreich importiert und in HealthKit gespeichert."
            case .unknownHevyFormat:
                return "Unbekanntes Hevy-Dateiformat. Bitte stelle sicher, dass es sich um eine gültige Hevy-Export-Datei handelt."
            case .healthKitNotAvailable:
                return "HealthKit ist nicht verfügbar. Messdaten können nicht importiert werden."
            case .healthKitNotAuthorized:
                return "HealthKit-Berechtigung erforderlich. Bitte aktiviere HealthKit in den Einstellungen, um Messdaten zu importieren."
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WorkoutStore())
}
