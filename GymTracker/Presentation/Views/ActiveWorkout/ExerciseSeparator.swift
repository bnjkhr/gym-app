import SwiftUI

/// Separator zwischen Übungen mit Timer-Anzeige
///
/// Zeigt einen Separator zwischen zwei Übungen mit optionalem Timer an.
/// Der Timer zeigt die empfohlene Pause zwischen den Übungen (z.B. "03:00").
///
/// **Features:**
/// - Plus-Icon (links) - zum Hinzufügen einer neuen Übung zwischen zwei Übungen
/// - Timer-Anzeige (mittig) - zeigt restTimeToNext an
/// - Minimales Design
///
/// **Layout:**
/// ```
/// [+]       03:00
/// ```
///
/// **Usage:**
/// ```swift
/// ExerciseSeparator(
///     restTime: 180, // 3 Minuten
///     onAddExercise: {
///         // Add exercise after this one
///     }
/// )
/// ```
struct ExerciseSeparator: View {
    var restTime: TimeInterval?
    var onAddExercise: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            // Plus Button (optional - nur wenn onAddExercise != nil)
            if onAddExercise != nil {
                Button {
                    onAddExercise?()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Rest Time Display
            if let restTime = restTime, restTime > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatTime(restTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }

    /// Formatiert TimeInterval zu MM:SS String
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Previews

#Preview("With Rest Time") {
    VStack(spacing: 0) {
        // Exercise 1
        VStack(alignment: .leading) {
            Text("Squat")
                .font(.headline)
            Text("4 sets completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))

        // Separator
        ExerciseSeparator(
            restTime: 180,
            onAddExercise: {
                print("Add exercise")
            }
        )

        // Exercise 2
        VStack(alignment: .leading) {
            Text("Bench Press")
                .font(.headline)
            Text("3 sets remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview("Without Rest Time") {
    VStack(spacing: 0) {
        // Exercise 1
        VStack(alignment: .leading) {
            Text("Squat")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))

        // Separator (no rest time)
        ExerciseSeparator(
            restTime: nil,
            onAddExercise: {
                print("Add exercise")
            }
        )

        // Exercise 2
        VStack(alignment: .leading) {
            Text("Bench Press")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview("Different Rest Times") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach([30.0, 60.0, 90.0, 120.0, 180.0, 300.0], id: \.self) { restTime in
                Text("Exercise")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemBackground))

                ExerciseSeparator(restTime: restTime)
            }

            Text("Final Exercise")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
        }
    }
}

#Preview("No Add Button") {
    VStack(spacing: 0) {
        Text("Exercise 1")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))

        // Separator without add button
        ExerciseSeparator(
            restTime: 120,
            onAddExercise: nil  // No button
        )

        Text("Exercise 2")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
    }
}
