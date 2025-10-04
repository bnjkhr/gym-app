import SwiftUI
import SwiftData

struct WorkoutsTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: SortOrder.reverse)
    ])
    private var workoutEntities: [WorkoutEntity]
    
    @State private var showingAddWorkout = false
    @State private var showingWorkoutWizard = false
    @State private var showingManualAdd = false
    @State private var showingProfileAlert = false
    @State private var showingProfileEditor = false
    
    @State private var selectedWorkout: WorkoutSelection?
    @State private var editingWorkoutSelection: WorkoutSelection?
    @State private var workoutToDelete: Workout?
    @State private var quickGeneratedWorkout: Workout?
    @State private var quickWorkoutName: String = ""
    
    private func mapWorkoutEntity(_ entity: WorkoutEntity) -> Workout? {
        return Workout(entity: entity, in: modelContext)
    }
    
    private var displayWorkouts: [Workout] {
        workoutEntities.compactMap { mapWorkoutEntity($0) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        // Add workout section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Neues Workout erstellen")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                createWorkoutAssistantButton()
                                createManualWorkoutButton()
                                createQuickWorkoutButton()
                            }
                        }
                        
                        // Workouts list section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Meine Workouts")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            if displayWorkouts.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "figure.strengthtraining.functional")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("Noch keine Workouts erstellt")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Erstelle dein erstes Workout oben.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8)
                                    ],
                                    spacing: 12
                                ) {
                                    ForEach(displayWorkouts, id: \.id) { workout in
                                        WorkoutTileWithMenu(
                                            workout: workout,
                                            onStart: { startWorkout(with: workout.id) },
                                            onEdit: { editWorkout(id: workout.id) },
                                            onDelete: { workoutToDelete = workout }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAddWorkout) {
                createAddWorkoutSheet()
            }
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditView()
                    .environmentObject(workoutStore)
            }
            .sheet(isPresented: $showingWorkoutWizard) {
                WorkoutWizardView(isManualStart: true)
                    .environmentObject(workoutStore)
            }
            .sheet(isPresented: $showingManualAdd) {
                AddWorkoutView()
                    .environmentObject(workoutStore)
            }
            .sheet(item: $quickGeneratedWorkout) { workout in
                GeneratedWorkoutPreviewView(
                    workout: workout,
                    workoutName: $quickWorkoutName,
                    usedProfileInfo: true,
                    onSave: {
                        if var w = quickGeneratedWorkout {
                            w.name = quickWorkoutName
                            
                            if workoutStore.modelContext == nil {
                                workoutStore.modelContext = modelContext
                            }
                            
                            workoutStore.addWorkout(w)
                        }
                        quickGeneratedWorkout = nil
                    },
                    onDismiss: { quickGeneratedWorkout = nil }
                )
                .environmentObject(workoutStore)
            }
            .sheet(item: $editingWorkoutSelection) { selection in
                if let entity = workoutEntities.first(where: { $0.id == selection.id }) {
                    EditWorkoutView(entity: entity)
                        .environmentObject(workoutStore)
                } else {
                    Text("Workout konnte nicht geladen werden")
                }
            }
            .navigationDestination(item: $selectedWorkout) { selection in
                if let entity = workoutEntities.first(where: { $0.id == selection.id }) {
                    WorkoutDetailView(
                        entity: entity,
                        isActiveSession: workoutStore.activeSessionID == selection.id,
                        onActiveSessionEnd: { 
                            endActiveSession() 
                        }
                    )
                    .environmentObject(workoutStore)
                } else {
                    ErrorWorkoutView()
                }
            }
            .alert("Wirklich löschen?", isPresented: Binding(
                get: { workoutToDelete != nil },
                set: { if !$0 { workoutToDelete = nil } }
            )) {
                Button("Löschen", role: .destructive) {
                    if let id = workoutToDelete?.id {
                        deleteWorkout(id: id)
                    }
                    workoutToDelete = nil
                }
                Button("Abbrechen", role: .cancel) {
                    workoutToDelete = nil
                }
            } message: {
                Text("\(workoutToDelete?.name ?? "Workout") wird dauerhaft entfernt.")
            }
            .alert("Bitte lege zuerst ein Profil an", isPresented: $showingProfileAlert) {
                Button("Profil anlegen") { showingProfileEditor = true }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Damit wir dein 1‑Klick‑Workout optimal erstellen können.")
            }
        }
        .onAppear {
            if workoutStore.modelContext == nil {
                workoutStore.modelContext = modelContext
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func createWorkoutAssistantButton() -> some View {
        Button {
            showingWorkoutWizard = true
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
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func createManualWorkoutButton() -> some View {
        Button {
            showingManualAdd = true
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
    
    private func createQuickWorkoutButton() -> some View {
        Button {
            let profile = workoutStore.userProfile
            let isProfileMissing = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && profile.weight == nil && profile.birthDate == nil
            if isProfileMissing {
                showingProfileAlert = true
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
            quickGeneratedWorkout = workoutStore.generateWorkout(from: preferences)
            quickWorkoutName = "Mein \(goal.displayName) Workout"
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1-Klick-Workout mit Profil erstellen")
                        .font(.headline)
                        .foregroundColor(.primary)
                    if workoutStore.userProfile.name.isEmpty && workoutStore.userProfile.weight == nil && workoutStore.userProfile.birthDate == nil {
                        Text("Hinweis: Lege zuerst dein Profil an, um optimale Ergebnisse zu erhalten.")
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
                    .foregroundColor(colorScheme == .dark ? Color.green : Color.mossGreen)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((colorScheme == .dark ? Color.green : Color.mossGreen).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((colorScheme == .dark ? Color.green : Color.mossGreen).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func createAddWorkoutSheet() -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Neues Workout erstellen")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)

                VStack(spacing: 16) {
                    createWorkoutAssistantButton()
                    createManualWorkoutButton()
                    createQuickWorkoutButton()
                }
                .padding()

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        showingAddWorkout = false
                    }
                }
            }
        }
    }
    
    private func startWorkout(with id: UUID) {
        do {
            try modelContext.save()
        } catch {
            // Error handled silently
        }
        
        if workoutStore.activeSessionID == id {
            selectedWorkout = WorkoutSelection(id: id)
            if let entity = workoutEntities.first(where: { $0.id == id }) {
                WorkoutLiveActivityController.shared.start(workoutName: entity.name)
            }
            return
        }
        
        workoutStore.startSession(for: id)
        if workoutStore.activeSessionID == id {
            selectedWorkout = WorkoutSelection(id: id)
            if let entity = workoutEntities.first(where: { $0.id == id }) {
                WorkoutLiveActivityController.shared.start(workoutName: entity.name)
            }
        }
    }
    
    private func editWorkout(id: UUID) {
        editingWorkoutSelection = WorkoutSelection(id: id)
    }
    
    private func deleteWorkout(id: UUID) {
        if let entity = workoutEntities.first(where: { $0.id == id }) {
            modelContext.delete(entity)
            try? modelContext.save()
        }
        if selectedWorkout?.id == id { selectedWorkout = nil }
        if workoutStore.activeSessionID == id {
            workoutStore.activeSessionID = nil
            WorkoutLiveActivityController.shared.end()
        }
        if editingWorkoutSelection?.id == id {
            editingWorkoutSelection = nil
        }
    }
    
    private func endActiveSession() {
        workoutStore.stopRest()
        workoutStore.activeSessionID = nil
        WorkoutLiveActivityController.shared.end()
    }
}

// MARK: - Supporting Types

private struct WorkoutSelection: Identifiable, Hashable {
    let id: UUID
}



#Preview {
    WorkoutsTabView()
        .environmentObject(WorkoutStore())
}