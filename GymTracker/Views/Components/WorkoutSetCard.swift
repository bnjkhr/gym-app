import SwiftUI

/// Compact set card for template/standard workout view
///
/// Displays a single exercise set with inline editing for reps, weight/duration, and rest time.
/// Shows previous values for comparison and provides quick completion toggle.
///
/// **Features:**
/// - Inline editing with `SelectAllTextField`
/// - Rest timer integration with active state display
/// - Previous values comparison
/// - Cardio vs. strength exercise support (duration vs. weight)
/// - Completion toggle with haptic feedback
/// - Swipe-to-delete support
///
/// **Layout:**
/// ```
/// [Set #] | [Reps] | [Weight/Duration] | [✓]
///           prev     prev
/// ```
///
/// **Usage:**
/// ```swift
/// WorkoutSetCard(
///     index: 0,
///     set: $set,
///     isActiveRest: false,
///     remainingSeconds: 0,
///     previousReps: 10,
///     previousWeight: 60.0,
///     currentExercise: exercise,
///     workoutStore: workoutStore,
///     onRestTimeUpdated: { newTime in },
///     onToggleCompletion: { }
/// )
/// ```
struct WorkoutSetCard: View {
    let index: Int
    @Binding var set: ExerciseSet
    var isActiveRest: Bool
    var remainingSeconds: Int
    var previousReps: Int?
    var previousWeight: Double?
    var currentExercise: Exercise?
    var workoutStore: WorkoutStoreCoordinator?
    var onRestTimeUpdated: (Double) -> Void
    var onToggleCompletion: () -> Void

    @State private var showingRestEditor = false
    @State private var restMinutes: Int = 0
    @State private var restSeconds: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 28, weight: .semibold))

                verticalSeparator

                HStack(spacing: 6) {
                    VStack(spacing: 2) {
                        ZStack(alignment: .center) {
                            // Hidden baseline provider to align with large numbers
                            Text("0")
                                .font(.system(size: 28, weight: .semibold))
                                .opacity(0)
                            SelectAllTextField(
                                value: $set.reps,
                                placeholder: "0",
                                keyboardType: .numberPad,
                                uiFont: UIFont.systemFont(ofSize: 28, weight: .semibold),
                                textColor: set.completed ? UIColor.systemGray3 : nil
                            )
                            .multilineTextAlignment(.center)
                            .frame(width: 80)
                        }

                        // Previous reps value
                        if let prevReps = previousReps {
                            Text("zuletzt: \(prevReps)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ")
                                .font(.caption2)
                        }
                    }
                }

                verticalSeparator

                // Zweites Eingabefeld: Gewicht ODER Zeit (abhängig vom Übungstyp)
                VStack(spacing: 2) {
                    ZStack(alignment: .center) {
                        // Hidden baseline provider to align with large numbers
                        Text("0")
                            .font(.system(size: 28, weight: .semibold))
                            .opacity(0)

                        if currentExercise?.isCardio == true {
                            // Cardio: Zeit in Minuten
                            SelectAllTextField(
                                value: Binding(
                                    get: { Int(set.duration ?? 0) / 60 },
                                    set: { set.duration = TimeInterval($0 * 60) }
                                ),
                                placeholder: "0",
                                keyboardType: .numberPad,
                                uiFont: UIFont.systemFont(ofSize: 28, weight: .semibold),
                                textColor: set.completed ? UIColor.systemGray3 : nil
                            )
                            .multilineTextAlignment(.center)
                            .frame(width: 104)
                        } else {
                            // Kraft: Gewicht in kg
                            SelectAllTextField(
                                value: $set.weight,
                                placeholder: "0",
                                keyboardType: .decimalPad,
                                uiFont: UIFont.systemFont(ofSize: 28, weight: .semibold),
                                textColor: set.completed ? UIColor.systemGray3 : nil
                            )
                            .multilineTextAlignment(.center)
                            .frame(width: 104)
                        }
                    }
                    .overlay(alignment: .trailing) {
                        Text(currentExercise?.isCardio == true ? "min" : "kg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 2)
                    }

                    // Previous value
                    if currentExercise?.isCardio == true {
                        // Cardio: vorherige Zeit
                        if let prevDuration = set.duration, prevDuration > 0 {
                            Text("zuletzt: \(Int(prevDuration / 60)) min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ")
                                .font(.caption2)
                        }
                    } else {
                        // Kraft: vorheriges Gewicht
                        if let prevWeight = previousWeight, prevWeight > 0 {
                            Text("zuletzt: \(prevWeight, specifier: "%.1f") kg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ")
                                .font(.caption2)
                        }
                    }
                }

                Spacer(minLength: 8)

                verticalSeparator

                Button(action: onToggleCompletion) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(set.completed ? Color.white : AppTheme.mossGreen)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(
                                    set.completed
                                        ? AppTheme.mossGreen : AppTheme.mossGreen.opacity(0.15))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppTheme.mossGreen, lineWidth: set.completed ? 0 : 1)
                        )
                        .accessibilityLabel(
                            set.completed ? "Satz zurücksetzen" : "Satz abschließen")
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: set.completed)
            }

        }
        .padding(.vertical, 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: set.completed)
        .sheet(isPresented: $showingRestEditor) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Pausenzeit")
                        .font(.headline)

                    HStack(spacing: 24) {
                        VStack {
                            Text("Min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Minuten", selection: $restMinutes) {
                                ForEach(0..<11, id: \.self) { m in
                                    Text("\(m)").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        VStack {
                            Text("Sek")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Sekunden", selection: $restSeconds) {
                                ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self)
                                { s in
                                    Text("\(s)").tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 160)

                    Button("Übernehmen") {
                        let total = Double(restMinutes * 60 + restSeconds)
                        set.restTime = max(0, min(total, 600))
                        onRestTimeUpdated(set.restTime)
                        showingRestEditor = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.mossGreen)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            showingRestEditor = false
                        }
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    private var formattedTime: String {
        let seconds = Int(set.restTime)
        let minutes = seconds / 60
        let remaining = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remaining)
        } else {
            return "\(seconds) s"
        }
    }

    private var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 22)
    }
}
