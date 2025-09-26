import SwiftUI
import UniformTypeIdentifiers

private struct SettingsScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SettingsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var isShowingAlert = false

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
                
                // Workouts Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workouts")
                        .font(.headline)
                    
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Workouts importieren (CSV)", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        workoutStore.resetToSampleData()
                        showAlert(message: "Sample-Workouts geladen!")
                    } label: {
                        Label("Sample-Workouts laden", systemImage: "arrow.clockwise")
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Erstelle eine CSV mit 'Übung,Sätze,Wiederholungen,Gewicht' pro Zeile und importiere sie als Vorlage.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
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
            }
            .padding(.horizontal)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importWorkout(from: url)
                } else {
                    showAlert(message: "Keine Datei ausgewählt.")
                }
            case .failure(let error):
                showAlert(message: "Import fehlgeschlagen: \(error.localizedDescription)")
            }
        }
        .alert("Import", isPresented: $isShowingAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(alertMessage ?? "")
        })
    }

    private func importWorkout(from url: URL) {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop { url.stopAccessingSecurityScopedResource() }
        }

        Task.detached(priority: .userInitiated) {
            do {
                // Prüfe Dateigröße
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                if let size = resourceValues.fileSize, size > maxImportBytes {
                    throw ImportError.tooLarge
                }

                // Lese Datei (Hintergrund)
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard let content = String(data: data, encoding: .utf8) else {
                    throw ImportError.invalidEncoding
                }

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

                guard !workoutExercises.isEmpty else { throw ImportError.emptyFile }

                let workoutName = url.deletingPathExtension().lastPathComponent
                let importedWorkout = Workout(
                    name: workoutName,
                    exercises: workoutExercises,
                    defaultRestTime: 90,
                    notes: "Importiert aus CSV"
                )

                await MainActor.run {
                    workoutStore.addWorkout(importedWorkout)
                    let info = skipped > 0 ? " (\(workoutExercises.count) Übungen, \(skipped) Zeilen übersprungen)" : " (\(workoutExercises.count) Übungen)"
                    showAlert(message: "Workout \"\(workoutName)\" importiert\(info).")
                }
            } catch let error as ImportError {
                await MainActor.run { showAlert(message: error.localizedDescription) }
            } catch {
                await MainActor.run { showAlert(message: "Import fehlgeschlagen: \(error.localizedDescription)") }
            }
        }
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

    private enum ImportError: LocalizedError {
        case invalidEncoding
        case emptyFile
        case invalidRow(String)
        case tooLarge

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
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WorkoutStore())
}
