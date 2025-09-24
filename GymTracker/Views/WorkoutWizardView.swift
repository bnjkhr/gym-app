import SwiftUI

struct WorkoutWizardView: View {
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

    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            VStack {
                // Progress Bar
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .progressViewStyle(.linear)
                    .padding()

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
                    }

                    Spacer()

                    if currentStep < totalSteps - 1 {
                        Button("Weiter") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
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
                        .disabled(isGenerating)
                    }
                }
                .padding()
            }
            .navigationTitle("Workout-Assistent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let workout = generatedWorkout {
                GeneratedWorkoutPreviewView(
                    workout: workout,
                    workoutName: $workoutName,
                    onSave: saveWorkout,
                    onDismiss: { showingPreview = false }
                )
                .environmentObject(workoutStore)
            }
        }
    }

    private var experienceSelectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Wie viel Erfahrung hast du?")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Deine Erfahrung hilft uns, die Intensität anzupassen")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ForEach(ExperienceLevel.allCases) { level in
                    SelectionCard(
                        title: level.displayName,
                        subtitle: level.description,
                        isSelected: experience == level
                    ) {
                        experience = level
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private var goalSelectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Was ist dein Hauptziel?")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Wir passen dein Workout an deine Ziele an")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ForEach(FitnessGoal.allCases) { goalOption in
                    SelectionCard(
                        title: goalOption.displayName,
                        subtitle: goalOption.description,
                        isSelected: goal == goalOption
                    ) {
                        goal = goalOption
                    }
                }
            }

            Spacer()
        }
        .padding()
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
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Welche Geräte bevorzugst du?")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Wähle deine bevorzugte Trainingsart")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ForEach(EquipmentPreference.allCases) { equipmentOption in
                    SelectionCard(
                        title: equipmentOption.displayName,
                        subtitle: equipmentOption.description,
                        isSelected: equipment == equipmentOption
                    ) {
                        equipment = equipmentOption
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private var durationSelectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Wie lange soll ein Workout dauern?")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Inklusive Aufwärmen und Pausen")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ForEach(WorkoutDuration.allCases) { durationOption in
                    SelectionCard(
                        title: durationOption.displayName,
                        subtitle: durationOption.description,
                        isSelected: duration == durationOption
                    ) {
                        duration = durationOption
                    }
                }
            }

            Spacer()
        }
        .padding()
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

    private func generateWorkout() {
        isGenerating = true

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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkoutWizardView()
        .environmentObject(WorkoutStore())
}