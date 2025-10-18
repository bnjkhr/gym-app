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

    private var workoutActionService: WorkoutActionService {
        WorkoutActionService(modelContext: modelContext, workoutStore: workoutStore)
    }

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
                                EmptyWorkoutsView()
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
                AddWorkoutOptionsSheet(
                    workoutStore: workoutStore,
                    onWorkoutWizard: {
                        navigateToWorkoutWizard = true
                    },
                    onManualCreate: {
                        navigateToManualAdd = true
                    },
                    onQuickWorkout: { workout, name in
                        quickGeneratedWorkout = workout
                        quickWorkoutName = name
                        navigateToQuickWorkout = true
                    },
                    onDismiss: {
                        showingAddWorkout = false
                    },
                    onShowProfileAlert: {
                        showingProfileAlert = true
                    }
                )
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
        do {
            _ = try workoutActionService.deleteWorkout(id: id, in: Array(workoutEntities))
        } catch {
            print("❌ Fehler beim Löschen des Workouts: \(error)")
        }

        if selectedWorkout?.id == id { selectedWorkout = nil }
        if editingWorkoutSelection?.id == id {
            editingWorkoutSelection = nil
        }
    }

    private func duplicateWorkout(id: UUID) {
        do {
            try workoutActionService.duplicateWorkout(id: id, in: Array(workoutEntities))
            print("✅ Workout erfolgreich dupliziert")
        } catch {
            print("❌ Fehler beim Duplizieren des Workouts: \(error)")
        }
    }

    private func shareWorkout(id: UUID) {
        do {
            let fileURL = try workoutActionService.shareWorkout(id: id, in: Array(workoutEntities))
            shareItem = ShareItem(url: fileURL)
            print("✅ Workout bereit zum Teilen")
        } catch {
            print("❌ Fehler beim Exportieren des Workouts: \(error)")
        }
    }

    private func endActiveSession() {
        workoutActionService.endActiveSession()
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

#Preview {
    WorkoutsTabView()
        .environmentObject(WorkoutStoreCoordinator())
}
