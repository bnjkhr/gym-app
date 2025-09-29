import SwiftUI

struct WorkoutWizardView: View {
    var isManualStart: Bool = false

    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var experience: ExperienceLevel = .beginner
    @State private var goal: FitnessGoal = .muscleBuilding
    @State private var frequency = 3
    @State private var equipment: EquipmentPreference = .mixed
    @State private var duration: WorkoutDuration = .medium
    @State private var generatedWorkout: Workout?
    @State private var isGenerating = false
    @State private var workoutName = ""
    @State private var showingPreview = false
    @State private var usedProfilePrefill = false
    @State private var usedProfileForGeneration = false

    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            VStack {
                if usedProfilePrefill {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.check")
                            .font(.title3)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aus Profil vorausgefüllt")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("Wir haben Ziel und Trainingsfrequenz aus deinem Profil übernommen.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                }

                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .progressViewStyle(.linear)
                    .padding()

                if !isManualStart {
                    Button {
                        quickGenerateFromProfile()
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Schnellstart mit Profil")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.mossGreen)
                    .padding(.horizontal)
                }

                TabView(selection: $currentStep) {
                    experienceSelectionView.tag(0)
                    goalSelectionView.tag(1)
                    frequencySelectionView.tag(2)
                    equipmentSelectionView.tag(3)
                    durationSelectionView.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation Buttons
                HStack {
                    if currentStep > 0 {
                        Button("Zurück") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.mossGreen)
                    }

                    Spacer()

                    if currentStep < totalSteps - 1 {
                        Button("Weiter") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.mossGreen)
                    } else {
                        Button(action: generateWorkout) {
                            if isGenerating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 20, height: 20)
                            } else {
                                Text("Workout erstellen")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.mossGreen)
                        .disabled(isGenerating)
                    }
                }
                .padding()
            }
            .appEdgePadding()
            .navigationTitle("Workout-Assistent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                let profile = workoutStore.userProfile
                var didPrefill = false
                // Prefill goal from profile if different
                if goal != profile.goal {
                    goal = profile.goal
                    didPrefill = true
                }
                // Prefill frequency from weeklyGoal if available and within 1...7
                let freq = max(1, min(workoutStore.weeklyGoal, 7))
                if frequency != freq {
                    frequency = freq
                    didPrefill = true
                }
                usedProfilePrefill = didPrefill
            }
        }
        .sheet(item: $generatedWorkout) { workout in
            GeneratedWorkoutPreviewView(
                workout: workout,
                workoutName: $workoutName,
                usedProfileInfo: usedProfileForGeneration,
                onSave: { 
                    saveWorkout()
                    generatedWorkout = nil
                },
                onDismiss: { generatedWorkout = nil }
            )
            .environmentObject(workoutStore)
        }
    }

    private var experienceSelectionView: some View {
        WizardSelectionStepView(
            title: "Wie viel Erfahrung hast du?",
            subtitle: "Deine Erfahrung hilft uns, die Intensität anzupassen",
            selection: $experience
        )
    }

    private var goalSelectionView: some View {
        WizardSelectionStepView(
            title: "Was ist dein Hauptziel?",
            subtitle: "Wir passen dein Workout an deine Ziele an",
            selection: $goal
        )
    }

    private var frequencySelectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Wie oft willst du trainieren?")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Trainings pro Woche")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 20) {
                Text("\(frequency)x pro Woche")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Stepper(value: $frequency, in: 1...7) {
                    EmptyView()
                }
                .labelsHidden()

                Text(frequencyDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }

    private var equipmentSelectionView: some View {
        WizardSelectionStepView(
            title: "Welche Geräte bevorzugst du?",
            subtitle: "Wähle deine bevorzugte Trainingsart",
            selection: $equipment
        )
    }

    private var durationSelectionView: some View {
        WizardSelectionStepView(
            title: "Wie lange soll ein Workout dauern?",
            subtitle: "Inklusive Aufwärmen und Pausen",
            selection: $duration
        )
    }

    private var frequencyDescription: String {
        switch frequency {
        case 1: return "Perfekt für den Einstieg oder bei wenig Zeit"
        case 2: return "Ideal für Anfänger und Berufstätige"
        case 3: return "Optimaler Sweet Spot für Fortschritte"
        case 4: return "Ambitioniert - gute Balance zwischen Training und Erholung"
        case 5: return "Intensives Training für schnelle Fortschritte"
        case 6: return "Sehr intensiv - nur für Erfahrene empfohlen"
        case 7: return "Maximale Intensität - erfordert viel Disziplin"
        default: return ""
        }
    }

    private func quickGenerateFromProfile() {
        isGenerating = true
        usedProfileForGeneration = true

        // Build preferences using current (prefilled) selections
        let preferences = WorkoutPreferences(
            experience: experience, // bleibt wie gewählt
            goal: goal,             // aus Profil vorbefüllt
            frequency: frequency,   // aus Profil/Weekly Goal vorbefüllt
            equipment: equipment,
            duration: duration
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            generatedWorkout = workoutStore.generateWorkout(from: preferences)
            workoutName = "Mein \(goal.displayName) Workout"
            isGenerating = false
            showingPreview = true
        }
    }

    private func generateWorkout() {
        isGenerating = true
        usedProfileForGeneration = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let preferences = WorkoutPreferences(
                experience: experience,
                goal: goal,
                frequency: frequency,
                equipment: equipment,
                duration: duration
            )

            generatedWorkout = workoutStore.generateWorkout(from: preferences)
            workoutName = "Mein \(goal.displayName) Workout"
            isGenerating = false
            showingPreview = true
        }
    }

    private func saveWorkout() {
        guard var workout = generatedWorkout else { return }
        workout.name = workoutName
        workoutStore.addWorkout(workout)
        dismiss()
    }
}

struct SelectionCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkoutWizardView(isManualStart: false)
        .environmentObject(WorkoutStore())
}
