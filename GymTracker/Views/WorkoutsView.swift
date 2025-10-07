import SwiftUI
import SwiftData

struct WorkoutsView: View {
    init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: .reverse)
    ])
    private var workoutEntities: [WorkoutEntity]

    @Query(sort: [
        SortDescriptor(\WorkoutFolderEntity.order, order: .forward)
    ])
    private var folders: [WorkoutFolderEntity]

    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddWorkout = false
    @State private var showingAddFolder = false
    @State private var expandedFolders: Set<UUID> = []
    @State private var draggedWorkout: WorkoutEntity?

    var body: some View {
        List {
            // Folders section
            ForEach(folders) { folder in
                FolderSectionView(
                    folder: folder,
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
                    workouts: workoutsInFolder(folder),
                    modelContext: modelContext,
                    workoutStore: workoutStore,
                    draggedWorkout: $draggedWorkout
                )
            }

            // Workouts without folder
            if !workoutsWithoutFolder.isEmpty {
                Section {
                    ForEach(workoutsWithoutFolder) { entity in
                        WorkoutEntityRow(entity: entity, modelContext: modelContext, workoutStore: workoutStore)
                            .onDrag {
                                draggedWorkout = entity
                                return NSItemProvider(object: entity.id.uuidString as NSString)
                            }
                    }
                    .onDelete { offsets in
                        deleteWorkouts(offsets, from: workoutsWithoutFolder)
                    }
                } header: {
                    Text("Workouts")
                }
            }
        }
        .padding(.bottom, 96)
        .toolbar(.hidden, for: .navigationBar)
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 0.5)

                HStack(spacing: 12) {
                    Button {
                        showingAddFolder = true
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Ordner")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.darkPurple.opacity(0.8))

                    Button {
                        showingAddWorkout = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Workout")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.darkPurple)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .padding(.bottom, 6)
            }
            .background(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 0)
            .zIndex(1)
        }
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutView()
                .environmentObject(workoutStore)
        }
        .sheet(isPresented: $showingAddFolder) {
            AddFolderView()
        }
        .onAppear {
            // Load expanded state from UserDefaults
            if let savedExpanded = UserDefaults.standard.array(forKey: "expandedFolders") as? [String] {
                expandedFolders = Set(savedExpanded.compactMap { UUID(uuidString: $0) })
            }
        }
        .onChange(of: expandedFolders) { _, newValue in
            // Save expanded state
            UserDefaults.standard.set(newValue.map { $0.uuidString }, forKey: "expandedFolders")
        }
    }

    private var workoutsWithoutFolder: [WorkoutEntity] {
        workoutEntities.filter { $0.folder == nil }
    }

    private func workoutsInFolder(_ folder: WorkoutFolderEntity) -> [WorkoutEntity] {
        workoutEntities
            .filter { $0.folder?.id == folder.id }
            .sorted { $0.orderInFolder < $1.orderInFolder }
    }

    private func deleteWorkouts(_ offsets: IndexSet, from workouts: [WorkoutEntity]) {
        for index in offsets {
            let entity = workouts[index]
            modelContext.delete(entity)
        }
        try? modelContext.save()
    }
}

// MARK: - FolderSectionView
struct FolderSectionView: View {
    let folder: WorkoutFolderEntity
    let isExpanded: Bool
    let onToggle: () -> Void
    let workouts: [WorkoutEntity]
    let modelContext: ModelContext
    let workoutStore: WorkoutStore
    @Binding var draggedWorkout: WorkoutEntity?

    @State private var showingEditFolder = false
    @State private var isTargeted = false

    var body: some View {
        Section {
            if isExpanded {
                ForEach(workouts) { entity in
                    WorkoutEntityRow(entity: entity, modelContext: modelContext, workoutStore: workoutStore)
                        .onDrag {
                            draggedWorkout = entity
                            return NSItemProvider(object: entity.id.uuidString as NSString)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(entity)
                                try? modelContext.save()
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }

                            Button {
                                entity.folder = nil
                                try? modelContext.save()
                            } label: {
                                Label("Aus Ordner", systemImage: "folder.badge.minus")
                            }
                            .tint(.orange)
                        }
                }
            }
        } header: {
            Button {
                onToggle()
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: folder.color))

                    Image(systemName: "folder.fill")
                        .foregroundColor(Color(hex: folder.color))

                    Text(folder.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("(\(workouts.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        showingEditFolder = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let workout = draggedWorkout else { return false }

            workout.folder = folder
            let maxOrder = workouts.map(\.orderInFolder).max() ?? -1
            workout.orderInFolder = maxOrder + 1

            try? modelContext.save()
            draggedWorkout = nil
            return true
        }
        .listRowBackground(isTargeted ? Color(hex: folder.color).opacity(0.1) : nil)
        .sheet(isPresented: $showingEditFolder) {
            FolderEditSheet(folder: folder, modelContext: modelContext)
        }
    }
}

// MARK: - WorkoutEntityRow
struct WorkoutEntityRow: View {
    let entity: WorkoutEntity
    let modelContext: ModelContext
    let workoutStore: WorkoutStore

    var body: some View {
        NavigationLink {
            WorkoutDetailView(entity: entity)
                .environmentObject(workoutStore)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entity.name)
                        .font(.headline)

                    Text(entity.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(entity.exercises.count) Übungen")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - FolderEditSheet
struct FolderEditSheet: View {
    let folder: WorkoutFolderEntity
    let modelContext: ModelContext

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    dismiss()
                    // Small delay to allow dismiss animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Present edit sheet
                    }
                } label: {
                    Label("Umbenennen", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Ordner löschen", systemImage: "trash")
                }
            }
            .navigationTitle("Ordner bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Ordner löschen?", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                // Move workouts out of folder before deleting
                for workout in folder.workouts {
                    workout.folder = nil
                }
                modelContext.delete(folder)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Die Workouts in diesem Ordner werden nicht gelöscht.")
        }
    }
}

struct WorkoutRowView: View {
    let workout: Workout

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline)

                Text(workout.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(workout.exercises.count) Übungen")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutEntity.self, WorkoutExerciseEntity.self, ExerciseSetEntity.self, ExerciseEntity.self, WorkoutSessionEntity.self, UserProfileEntity.self, WorkoutFolderEntity.self, configurations: config)
    // Seed one workout
    let exercise = ExerciseEntity(id: UUID(), name: "Kniebeugen")
    let set = ExerciseSetEntity(id: UUID(), reps: 8, weight: 80, restTime: 120, completed: false)
    let we = WorkoutExerciseEntity(id: UUID(), exercise: exercise, sets: [set])
    let workout = WorkoutEntity(id: UUID(), name: "Leg Day", exercises: [we], defaultRestTime: 90)
    container.mainContext.insert(workout)
    return WorkoutsView()
        .environmentObject(WorkoutStore())
        .modelContainer(container)
}

