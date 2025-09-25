import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var isShowingAlert = false

    // Max. Importgröße (z. B. 2 MB)
    private let maxImportBytes: Int = 2 * 1024 * 1024

    var body: some View {
        Form {
            Section("Trainingsziele") {
                Stepper(value: $workoutStore.weeklyGoal, in: 1...14) {
                    Text("Wochenziel: \(workoutStore.weeklyGoal) Workouts")
                }

                Text("Passe dein Wochenziel an, um den Fortschritt-Tab auf deine Planung abzustimmen.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }

            Section("Workouts") {
                Button {
                    showingImporter = true
                } label: {
                    Label("Workouts importieren (CSV)", systemImage: "tray.and.arrow.down")
                }

                Button {
                    workoutStore.resetToSampleData()
                    showAlert(message: "Sample-Workouts geladen!")
                } label: {
                    Label("Sample-Workouts laden", systemImage: "arrow.clockwise")
                        .foregroundColor(.orange)
                }

                Text("Erstelle eine CSV mit 'Übung,Sätze,Wiederholungen,Gewicht' pro Zeile und importiere sie als Vorlage.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 96)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                Text("Einstellungen")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
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
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Dateigröße prüfen
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = resourceValues.fileSize, size > maxImportBytes {
                throw ImportError.tooLarge
            }

            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard let content = String(data: data, encoding: .utf8) else {
                throw ImportError.invalidEncoding
            }

            var lines = content.components(separatedBy: CharacterSet.newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !lines.isEmpty else { throw ImportError.emptyFile }

            if let first = lines.first,
               first.localizedCaseInsensitiveContains("übung") ||
               first.localizedCaseInsensitiveContains("uebung") ||
               first.localizedCaseInsensitiveContains("exercise") {
                lines.removeFirst()
            }

            var workoutExercises: [WorkoutExercise] = []

            for line in lines {
                let parts = line.components(separatedBy: CharacterSet(charactersIn: ",;"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                guard parts.count >= 4 else {
                    throw ImportError.invalidRow(line)
                }

                let name = parts[0]
                let sets = Int(parts[1]) ?? 0
                let reps = Int(parts[2]) ?? 0
                let weightString = parts[3].replacingOccurrences(of: ",", with: ".")
                let weight = Double(weightString) ?? 0

                // ✅ Erweiterte Validierung
                guard sets > 0 && sets <= 50,
                      reps > 0 && reps <= 500,
                      weight >= 0 && weight <= 2000,
                      !name.isEmpty && name.count <= 100 else {
                    continue
                }

                let exercise = workoutStore.exercise(named: name)
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

            workoutStore.addWorkout(importedWorkout)
            showAlert(message: "Workout \"\(workoutName)\" importiert.")
        } catch let error as ImportError {
            showAlert(message: error.localizedDescription)
        } catch {
            showAlert(message: "Import fehlgeschlagen: \(error.localizedDescription)")
        }
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
