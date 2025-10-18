import SwiftUI

/// Large, touch-friendly set card for active workout sessions
///
/// Optimized for active workout use with large input fields, prominent rest timer controls,
/// and easy-to-tap completion button. Supports delete via long press.
///
/// **Features:**
/// - Large input fields (32pt font)
/// - Rest timer controls (pause/play, +15s, stop)
/// - Previous values comparison
/// - Long press to delete with confirmation
/// - Cardio vs. strength exercise support
/// - Haptic feedback on completion
///
/// **Layout:**
/// ```
/// SATZ #
/// [Large Reps Input] [Large Weight Input]
///   prev value         prev value
/// [⏳] [Timer] [Pause] [+15] [Stop] [✓]
/// ```
///
/// **Usage:**
/// Used exclusively in `ActiveWorkoutExerciseView` for active sessions.
struct ActiveWorkoutSetCard: View {
    let index: Int
    @Binding var set: ExerciseSet
    var isActiveRest: Bool
    var hasRestState: Bool
    var remainingSeconds: Int
    var previousReps: Int?
    var previousWeight: Double?
    let isLastSet: Bool
    var currentExercise: Exercise?
    var workoutStore: WorkoutStoreCoordinator?
    var onRestTimeUpdated: (Double) -> Void
    var onToggleCompletion: () -> Void
    var onDeleteSet: () -> Void

    @State private var showingRestEditor = false
    @State private var restMinutes: Int = 0
    @State private var restSeconds: Int = 0
    @State private var showingDeleteConfirmation = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Set header
            HStack(alignment: .firstTextBaseline) {
                Text("SATZ \(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Main input area
            HStack(spacing: 20) {
                // Reps input
                VStack(spacing: 8) {
                    Text("Wiederholungen")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    SelectAllTextField(
                        value: $set.reps,
                        placeholder: "0",
                        keyboardType: .numberPad,
                        uiFont: UIFont.systemFont(ofSize: 32, weight: .bold),
                        textColor: set.completed ? UIColor.systemGray3 : nil
                    )
                    .multilineTextAlignment(.center)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

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

                // Weight input
                VStack(spacing: 8) {
                    Text("Gewicht (kg)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    SelectAllTextField(
                        value: $set.weight,
                        placeholder: "0",
                        keyboardType: .decimalPad,
                        uiFont: UIFont.systemFont(ofSize: 32, weight: .bold),
                        textColor: set.completed ? UIColor.systemGray3 : nil
                    )
                    .multilineTextAlignment(.center)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                    // Previous weight value
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

            // Rest time and completion button
            HStack(spacing: 6) {
                // Rest time editor button (tapping on pause icon)
                Button {
                    restMinutes = Int(set.restTime) / 60
                    restSeconds = Int(set.restTime) % 60
                    showingRestEditor = true
                } label: {
                    Image(systemName: "hourglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5), in: Circle())
                }
                .buttonStyle(.plain)

                // Timer display (compact)
                if set.completed && hasRestState {
                    // Active rest timer
                    Text(formattedRemaining)
                        .font(.system(size: 16, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(colorScheme == .dark ? .white : AppTheme.deepBlue)
                        .contentTransition(.numericText())

                    // Timer control buttons (with more spacing)
                    HStack(spacing: 8) {
                        // Pause/Play button
                        if let restState = workoutStore?.restTimerStateManager.currentState,
                            restState.phase == .running
                        {
                            Button {
                                workoutStore?.pauseRest()
                            } label: {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(AppTheme.deepBlue, in: Circle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                workoutStore?.resumeRest()
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(AppTheme.mossGreen, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(remainingSeconds == 0)
                        }

                        // +15s button
                        Button {
                            workoutStore?.addRest(seconds: 15)
                        } label: {
                            Text("+15")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.deepBlue, in: Circle())
                        }
                        .buttonStyle(.plain)

                        // Stop button
                        Button {
                            workoutStore?.stopRest()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.powerOrange, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Static rest time display when not active
                    Text(formattedTime)
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Completion button (round checkmark)
                Button {
                    // Haptisches Feedback beim Tippen
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    onToggleCompletion()
                } label: {
                    if set.completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.mossGreen, in: Circle())
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18))
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.mossGreen)
                            .frame(width: 40, height: 40)
                            .background(
                                colorScheme == .dark ? Color(.systemGray6) : Color.white,
                                in: Circle()
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.mossGreen, lineWidth: 2)
                            )
                    }
                }
                .buttonStyle(.plain)
            }

        }
        .padding(20)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: set.completed)
        .overlay(alignment: .bottom) {
            // Add separator between sets (except for last set)
            if !isLastSet {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)
            }
        }
        .onLongPressGesture {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showingDeleteConfirmation = true
        }
        .confirmationDialog(
            "Satz \(index + 1) löschen?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                onDeleteSet()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
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
}
