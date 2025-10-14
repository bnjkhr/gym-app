import SwiftData
import SwiftUI

struct WorkoutsTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStoreCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: SortOrder.reverse)
    ])
    private var workoutEntities: [WorkoutEntity]

    @Query(sort: [
        SortDescriptor(\WorkoutFolderEntity.order, order: .forward)
    ])
    private var folders: [WorkoutFolderEntity]

    @State private var showingAddWorkout = false
    @State private var showingAddFolder = false
    @State private var showingProfileAlert = false
    @State private var showingProfileEditor = false
    @State private var navigateToManualAdd = false
    @State private var navigateToWorkoutWizard = false
    @State private var navigateToQuickWorkout = false
    @State private var expandedFolders: Set<UUID> = []
    @State private var draggedWorkout: WorkoutEntity?

    @State private var selectedWorkout: WorkoutSelection?
    @State private var editingWorkoutSelection: WorkoutSelection?
    @State private var workoutToDelete: Workout?
    @State private var shareItem: ShareItem?
    @State private var quickGeneratedWorkout: Workout?
    @State private var quickWorkoutName: String = ""
    @State private var showingHomeLimitAlert = false

    private func mapWorkoutEntity(_ entity: WorkoutEntity) -> Workout? {
        return Workout(entity: entity, in: modelContext)
    }

    private var displayWorkouts: [Workout] {
        workoutEntities.compactMap { mapWorkoutEntity($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        // Ordner-Sections
                        ForEach(folders) { folder in
                            FolderGridSection(
                                folder: folder,
                                workouts: workoutsInFolder(folder),
                                isExpanded: expandedFolders.contains(folder.id),
                                onToggle: {
                                    withAnimation {
                                        if expandedFolders.contains(folder.id) {
                                            expandedFolders.remove(folder.id)
                                        } else {
                                            expandedFolders.insert(folder.id)
                                        }
                                    }
                                },
                                onTap: { id in startWorkout(with: id) },
                                onEdit: { id in editWorkout(id: id) },
                                onDelete: { workout in workoutToDelete = workout },
                                onToggleHome: { id in toggleHomeFavorite(workoutID: id) },
                                onDuplicate: { id in duplicateWorkout(id: id) },
                                onShare: { id in shareWorkout(id: id) },
                                onRemoveFromFolder: { entity in
                                    entity.folder = nil
                                    try? modelContext.save()
                                },
                                onDeleteFolder: {
                                    // Move workouts out before deleting
                                    for workout in folder.workouts {
                                        workout.folder = nil
                                    }
                                    modelContext.delete(folder)
                                    try? modelContext.save()
                                }
                            )
                        }

                        // Workouts ohne Ordner
                        VStack(alignment: .leading, spacing: 16) {
                            if !folders.isEmpty && !workoutsWithoutFolder.isEmpty {
                                Text("Workouts")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 16)
                            }

                            if displayWorkouts.isEmpty && folders.isEmpty {
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
                            } else if !workoutsWithoutFolder.isEmpty {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8),
                                    ],
                                    spacing: 12
                                ) {
                                    ForEach(
                                        workoutsWithoutFolder.compactMap { mapWorkoutEntity($0) },
                                        id: \.id
                                    ) { workout in
                                        WorkoutTileCard(
                                            workout: workout,
                                            isHomeFavorite: workout.isFavorite,
                                            onTap: { startWorkout(with: workout.id) },
                                            onEdit: { editWorkout(id: workout.id) },
                                            onStart: { startWorkout(with: workout.id) },
                                            onDelete: { workoutToDelete = workout },
                                            onToggleHome: {
                                                toggleHomeFavorite(workoutID: workout.id)
                                            },
                                            onDuplicate: { duplicateWorkout(id: workout.id) },
                                            onShare: { shareWorkout(id: workout.id) },
                                            onMoveToFolder: { folder in
                                                moveWorkoutToFolder(
                                                    workoutID: workout.id, folder: folder)
                                            },
                                            isInFolder: false
                                        )
                                        .id(workout.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAddFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                createAddWorkoutSheet()
            }
            .sheet(isPresented: $showingAddFolder) {
                AddFolderView()
            }
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditView()
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
            .navigationDestination(isPresented: $navigateToManualAdd) {
                AddWorkoutView()
                    .environmentObject(workoutStore)
            }
            .navigationDestination(isPresented: $navigateToWorkoutWizard) {
                WorkoutWizardView(isManualStart: true)
                    .environmentObject(workoutStore)
            }
            .navigationDestination(isPresented: $navigateToQuickWorkout) {
                if let workout = quickGeneratedWorkout {
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
                            navigateToQuickWorkout = false
                        },
                        onDismiss: {
                            quickGeneratedWorkout = nil
                            navigateToQuickWorkout = false
                        }
                    )
                    .environmentObject(workoutStore)
                } else {
                    Text("Fehler beim Laden des Workouts")
                        .onAppear {
                            navigateToQuickWorkout = false
                        }
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
                    .environment(\.isInWorkoutDetail, true)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            workoutStore.isShowingWorkoutDetail = true
                        }
                    }
                    .onDisappear {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            workoutStore.isShowingWorkoutDetail = false
                        }
                    }
                } else {
                    ErrorWorkoutView()
                }
            }
            .alert(
                "Wirklich löschen?",
                isPresented: Binding(
                    get: { workoutToDelete != nil },
                    set: { if !$0 { workoutToDelete = nil } }
                )
            ) {
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
            .alert("Home-Favoriten voll", isPresented: $showingHomeLimitAlert) {
                Button("Verstanden") {}
            } message: {
                Text(
                    "Du kannst maximal 4 Workouts als Home-Favoriten speichern.\n\nEntferne zuerst ein anderes Workout aus dem Home-Tab, um Platz zu schaffen."
                )
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .confirmationDialog(
            "Workout löschen?",
            isPresented: Binding(
                get: { workoutToDelete != nil },
                set: { if !$0 { workoutToDelete = nil } }
            ),
            presenting: workoutToDelete
        ) { workout in
            Button("Löschen", role: .destructive) {
                deleteWorkout(id: workout.id)
                workoutToDelete = nil
            }
            Button("Abbrechen", role: .cancel) {
                workoutToDelete = nil
            }
        } message: { workout in
            Text("'\(workout.name)' wird unwiderruflich gelöscht.")
        }
        .onAppear {
            if workoutStore.modelContext == nil {
                workoutStore.modelContext = modelContext
            }
        }
    }

    // MARK: - Helper Functions

    private var workoutsWithoutFolder: [WorkoutEntity] {
        workoutEntities.filter { $0.folder == nil }
    }

    private func workoutsInFolder(_ folder: WorkoutFolderEntity) -> [WorkoutEntity] {
        workoutEntities
            .filter { $0.folder?.id == folder.id }
            .sorted { $0.orderInFolder < $1.orderInFolder }
    }

    private func createWorkoutAssistantButton() -> some View {
        Button {
            showingAddWorkout = false  // Schließe erst das Sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToWorkoutWizard = true  // Dann navigiere
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

    private func createManualWorkoutButton() -> some View {
        Button {
            showingAddWorkout = false  // Schließe erst das Sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToManualAdd = true  // Dann navigiere
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

    private func createQuickWorkoutButton() -> some View {
        Button {
            let profile = workoutStore.userProfile
            let isProfileMissing =
                profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && profile.weight == nil && profile.birthDate == nil
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

            // Navigation statt Sheet
            showingAddWorkout = false  // Schließe erst das Sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToQuickWorkout = true  // Dann navigiere
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
                    Button {
                        showingAddWorkout = false
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

    private func startWorkout(with id: UUID) {
        do {
            try modelContext.save()
        } catch {
            // Error handled silently
        }

        if workoutStore.activeSessionID == id {
            selectedWorkout = WorkoutSelection(id: id)
            if let entity = workoutEntities.first(where: { $0.id == id }) {
                WorkoutLiveActivityController.shared.start(
                    workoutId: entity.id, workoutName: entity.name)
            }
            return
        }

        workoutStore.startSession(for: id)
        if workoutStore.activeSessionID == id {
            selectedWorkout = WorkoutSelection(id: id)
            if let entity = workoutEntities.first(where: { $0.id == id }) {
                WorkoutLiveActivityController.shared.start(
                    workoutId: entity.id, workoutName: entity.name)
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

    private func duplicateWorkout(id: UUID) {
        guard let originalEntity = workoutEntities.first(where: { $0.id == id }) else { return }

        // Erstelle neue WorkoutEntity als Kopie
        let duplicatedEntity = WorkoutEntity(
            name: "\(originalEntity.name) (Kopie)",
            date: Date(),
            exercises: [],
            defaultRestTime: originalEntity.defaultRestTime,
            duration: nil,
            notes: originalEntity.notes,
            isFavorite: false,  // Nicht als Favorit markieren
            isSampleWorkout: false  // Benutzer-Workout
        )

        // Kopiere alle Übungen mit Sets, sortiere nach order
        let sortedExercises = originalEntity.exercises.sorted { $0.order < $1.order }
        for (index, originalWorkoutExercise) in sortedExercises.enumerated() {
            let copiedWorkoutExercise = WorkoutExerciseEntity(
                exercise: originalWorkoutExercise.exercise,
                order: index
            )

            // Kopiere alle Sets
            for originalSet in originalWorkoutExercise.sets {
                let copiedSet = ExerciseSetEntity(
                    reps: originalSet.reps,
                    weight: originalSet.weight,
                    restTime: originalSet.restTime,
                    completed: false
                )
                copiedWorkoutExercise.sets.append(copiedSet)
                modelContext.insert(copiedSet)
            }

            duplicatedEntity.exercises.append(copiedWorkoutExercise)
            modelContext.insert(copiedWorkoutExercise)
        }

        // Speichere in SwiftData
        modelContext.insert(duplicatedEntity)
        try? modelContext.save()

        print("✅ Workout '\(originalEntity.name)' erfolgreich dupliziert")
    }

    private func shareWorkout(id: UUID) {
        guard let entity = workoutEntities.first(where: { $0.id == id }) else { return }

        do {
            // Workout in ShareableWorkout konvertieren
            let shareable = ShareableWorkout.from(entity: entity)

            // Als JSON-Datei exportieren
            let fileURL = try shareable.exportToFile()

            // Share-Sheet öffnen
            shareItem = ShareItem(url: fileURL)

            print("✅ Workout '\(entity.name)' bereit zum Teilen")
        } catch {
            print("❌ Fehler beim Exportieren des Workouts: \(error)")
        }
    }

    private func endActiveSession() {
        workoutStore.stopRest()
        workoutStore.activeSessionID = nil
        WorkoutLiveActivityController.shared.end()
    }

    private func toggleHomeFavorite(workoutID: UUID) {
        let success = workoutStore.toggleHomeFavorite(workoutID: workoutID)
        if !success {
            showingHomeLimitAlert = true
        } else {
            // Force a UI refresh by processing changes immediately
            modelContext.processPendingChanges()
            try? modelContext.save()
        }
    }

    private func moveWorkoutToFolder(workoutID: UUID, folder: WorkoutFolderEntity) {
        guard let entity = workoutEntities.first(where: { $0.id == workoutID }) else { return }

        entity.folder = folder
        let maxOrder = workoutsInFolder(folder).map(\.orderInFolder).max() ?? -1
        entity.orderInFolder = maxOrder + 1

        try? modelContext.save()
    }
}

// MARK: - Supporting Types

private struct WorkoutSelection: Identifiable, Hashable {
    let id: UUID
}

// MARK: - FolderGridSection

private struct FolderGridSection: View {
    let folder: WorkoutFolderEntity
    let workouts: [WorkoutEntity]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onTap: (UUID) -> Void
    let onEdit: (UUID) -> Void
    let onDelete: (Workout) -> Void
    let onToggleHome: (UUID) -> Void
    let onDuplicate: (UUID) -> Void
    let onShare: (UUID) -> Void
    let onRemoveFromFolder: (WorkoutEntity) -> Void
    let onDeleteFolder: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showingFolderOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Folder Header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: folder.color))
                        .frame(width: 20)

                    Image(systemName: "folder.fill")
                        .foregroundColor(Color(hex: folder.color))

                    Text(folder.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("(\(workouts.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        showingFolderOptions = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            // Workouts Grid
            if isExpanded && !workouts.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 12
                ) {
                    ForEach(workouts.compactMap { Workout(entity: $0, in: modelContext) }, id: \.id)
                    { workout in
                        WorkoutTileCard(
                            workout: workout,
                            isHomeFavorite: workout.isFavorite,
                            onTap: { onTap(workout.id) },
                            onEdit: { onEdit(workout.id) },
                            onStart: { onTap(workout.id) },
                            onDelete: { onDelete(workout) },
                            onToggleHome: { onToggleHome(workout.id) },
                            onDuplicate: { onDuplicate(workout.id) },
                            onShare: { onShare(workout.id) },
                            onRemoveFromFolder: {
                                if let entity = workouts.first(where: { $0.id == workout.id }) {
                                    onRemoveFromFolder(entity)
                                }
                            },
                            isInFolder: true
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .confirmationDialog("Ordner verwalten", isPresented: $showingFolderOptions) {
            Button("Ordner löschen", role: .destructive) {
                onDeleteFolder()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Workouts in diesem Ordner werden nicht gelöscht.")
        }
    }
}

#Preview {
    WorkoutsTabView()
        .environmentObject(WorkoutStoreCoordinator())
}
