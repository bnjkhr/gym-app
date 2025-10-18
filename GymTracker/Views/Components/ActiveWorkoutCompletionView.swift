import SwiftUI

/// Workout completion screen for active sessions
///
/// Final page in the active workout TabView that shows summary statistics
/// and allows the user to complete the workout.
///
/// **Features:**
/// - Completion icon and header
/// - Summary stats (exercises, completed sets, total volume)
/// - Two-step confirmation (button → confirmation dialog)
/// - Haptic feedback on completion
///
/// **Layout:**
/// ```
/// 🏁 Workout abschließen
/// Du bist fast fertig!
///
/// [Summary Card]
/// - Übungen: 5
/// - Abgeschlossene Sätze: 20 / 25
/// - Gesamtvolumen: 2,500 kg
///
/// [Workout abschließen Button]
/// ```
///
/// **Usage:**
/// Used as the last page in `ActiveWorkoutNavigationView` TabView.
struct ActiveWorkoutCompletionView: View {
    let workout: Workout
    @Binding var showingConfirmation: Bool
    let completeAction: () -> Void

    private var totalVolume: Double {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private var completedSets: Int {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.filter { $0.completed }.count
        }
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.count
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Completion header
                VStack(spacing: 12) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.mossGreen)

                    Text("Workout abschließen")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Du bist fast fertig!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Summary stats
                VStack(spacing: 16) {
                    StatRow(label: "Übungen", value: "\(workout.exercises.count)")
                    StatRow(label: "Abgeschlossene Sätze", value: "\(completedSets) / \(totalSets)")
                    StatRow(label: "Gesamtvolumen", value: "\(Int(totalVolume)) kg")
                }
                .padding(AppLayout.Spacing.large)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

                if showingConfirmation {
                    VStack(spacing: 16) {
                        Text("Workout wirklich abschließen?")
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        Text("Die Session wird gespeichert und das Template zurückgesetzt.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button("Abbrechen") {
                                showingConfirmation = false
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Button("Abschließen") {
                                // Starkes haptisches Feedback für finale Bestätigung
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
                                showingConfirmation = false
                                completeAction()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.mossGreen)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(AppLayout.Spacing.large)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                } else {
                    Button {
                        // Haptisches Feedback beim Workout-Abschluss
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        showingConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                            Text("Workout abschließen")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.mossGreen, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.mossGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

/// Helper view for displaying a stat row
private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}
