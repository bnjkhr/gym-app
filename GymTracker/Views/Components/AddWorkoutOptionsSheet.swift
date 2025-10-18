import SwiftUI

/// Sheet for selecting workout creation method
///
/// Displays three options for creating a new workout:
/// 1. Workout Assistant (Wizard) - Personalized based on goals
/// 2. Manual Creation - Self-assembled workout
/// 3. 1-Click Workout - Quick generation from profile
///
/// **Features:**
/// - Profile validation for 1-Click option
/// - Navigation to different workout creation flows
/// - Visual distinction between options
///
/// **Usage:**
/// ```swift
/// .sheet(isPresented: $showingAddWorkout) {
///     AddWorkoutOptionsSheet(
///         onWorkoutWizard: { navigateToWorkoutWizard = true },
///         onManualCreate: { navigateToManualAdd = true },
///         onQuickWorkout: { workout in
///             quickGeneratedWorkout = workout
///             navigateToQuickWorkout = true
///         },
///         onDismiss: { showingAddWorkout = false }
///     )
/// }
/// ```
struct AddWorkoutOptionsSheet: View {
    let workoutStore: WorkoutStoreCoordinator
    let onWorkoutWizard: () -> Void
    let onManualCreate: () -> Void
    let onQuickWorkout: (Workout, String) -> Void
    let onDismiss: () -> Void
    let onShowProfileAlert: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Neues Workout erstellen")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)

                VStack(spacing: 16) {
                    workoutAssistantButton
                    manualWorkoutButton
                    quickWorkoutButton
                }
                .padding()

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Option Buttons

    private var workoutAssistantButton: some View {
        Button {
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onWorkoutWizard()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout-Assistent")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Personalisiertes Workout basierend auf deinen Zielen")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(.customBlue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.customBlue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.customBlue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var manualWorkoutButton: some View {
        Button {
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onManualCreate()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manuell erstellen")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Selbst zusammengestelltes Workout")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

    private var quickWorkoutButton: some View {
        Button {
            let profile = workoutStore.userProfile
            let isProfileMissing =
                profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && profile.weight == nil && profile.birthDate == nil

            if isProfileMissing {
                onShowProfileAlert()
                return
            }

            let goal = profile.goal
            let freq = max(1, min(workoutStore.weeklyGoal, 7))
            let preferences = WorkoutPreferences(
                experience: profile.experience,
                goal: goal,
                frequency: freq,
                equipment: profile.equipment,
                duration: profile.preferredDuration
            )

            let generatedWorkout = workoutStore.generateWorkout(from: preferences)
            let workoutName = "Mein \(goal.displayName) Workout"

            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onQuickWorkout(generatedWorkout, workoutName)
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1-Klick-Workout mit Profil erstellen")
                        .font(.headline)
                        .foregroundColor(.primary)
                    if workoutStore.userProfile.name.isEmpty
                        && workoutStore.userProfile.weight == nil
                        && workoutStore.userProfile.birthDate == nil
                    {
                        Text(
                            "Hinweis: Lege zuerst dein Profil an, um optimale Ergebnisse zu erhalten."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    } else {
                        Text("Ziel und Trainingsfrequenz werden aus deinem Profil übernommen.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                Image(systemName: "bolt.badge.a.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.mossGreen)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((AppTheme.mossGreen).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((AppTheme.mossGreen).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
