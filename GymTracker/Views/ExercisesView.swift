import SwiftUI
import SwiftData
import Combine

struct ExercisesView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddExercise = false
    @State private var searchText = ""
    @State private var debouncedSearch: String = ""
    @State private var editingExercise: Exercise?
    @State private var pendingDeletion: [Exercise] = []
    @State private var showingDeleteAlert = false
    @State private var selectedGroups: Set<MuscleGroup> = []
    @State private var selectedEquipment: Set<EquipmentType> = []
    @State private var showingFilterSheet = false

    // Performance: Combine-based debouncing for search
    @State private var searchCancellable: AnyCancellable?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ExerciseEntity.name, order: .forward)])
    private var exerciseEntities: [ExerciseEntity]

    private var sourceExercises: [Exercise] {
        // Fresh fetch to avoid touching potentially invalid @Query snapshots
        let descriptor = FetchDescriptor<ExerciseEntity>(sortBy: [SortDescriptor(\.name, order: .forward)])
        
        do {
            let freshEntities = try modelContext.fetch(descriptor)
            return freshEntities.compactMap { entity in
                // Use safe access to muscle groups and equipment type
                let groups: [MuscleGroup] = entity.muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
                let equipmentType = EquipmentType(rawValue: entity.equipmentTypeRaw) ?? .mixed
                return Exercise(
                    id: entity.id,
                    name: entity.name,
                    muscleGroups: groups,
                    equipmentType: equipmentType,
                    description: entity.descriptionText,
                    instructions: entity.instructions,
                    createdAt: entity.createdAt
                )
            }
        } catch {
            print("❌ Fehler beim Laden der Übungen: \(error)")
            return []
        }
    }

    // Performance: Single-pass filtering instead of 3 separate iterations
    var filteredExercises: [Exercise] {
        let query = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasGroupFilter = !selectedGroups.isEmpty
        let hasEquipmentFilter = !selectedEquipment.isEmpty
        let hasSearchQuery = !query.isEmpty

        // Early return if no filters active
        if !hasGroupFilter && !hasEquipmentFilter && !hasSearchQuery {
            return sourceExercises
        }

        // Single pass through all exercises - O(n) instead of O(3n)
        return sourceExercises.filter { exercise in
            // Check muscle group filter
            if hasGroupFilter {
                let groupMatch = exercise.muscleGroups.contains { selectedGroups.contains($0) }
                if !groupMatch { return false }
            }

            // Check equipment filter
            if hasEquipmentFilter {
                if !selectedEquipment.contains(exercise.equipmentType) {
                    return false
                }
            }

            // Check search query
            if hasSearchQuery {
                let nameMatch = exercise.name.lowercased().contains(query)
                let groupMatch = exercise.muscleGroups.contains { $0.rawValue.lowercased().contains(query) }
                let equipmentMatch = exercise.equipmentType.rawValue.lowercased().contains(query)
                if !(nameMatch || groupMatch || equipmentMatch) {
                    return false
                }
            }

            // All active filters passed
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Übungsanzahl Header
            HStack {
                Text("\(sourceExercises.count) Übungen hinterlegt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Bestehende ScrollView
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Exercise list
                    LazyVStack(spacing: 8) {
                        ForEach(filteredExercises) { exercise in
                            Button {
                                editingExercise = exercise
                            } label: {
                                ExerciseRowView(exercise: exercise)
                                    .appEdgePadding()
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    requestDeletion(for: [exercise])
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100) // Space for search bar
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            LiquidGlassSearchBar(
                text: $searchText,
                showingFilterSheet: $showingFilterSheet,
                hasActiveFilters: !selectedGroups.isEmpty || !selectedEquipment.isEmpty
            )
                .appEdgePadding()
                .padding(.bottom, 12)
        }
        .toolbar(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddExercise = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            // Cancel previous search operation
            searchCancellable?.cancel()

            // Create new debounced search
            searchCancellable = Just(newValue)
                .delay(for: .seconds(0.2), scheduler: DispatchQueue.main)
                .sink { debouncedValue in
                    debouncedSearch = debouncedValue
                }
        }
        .onAppear {
            // Set initial value
            debouncedSearch = searchText
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView()
                .environmentObject(workoutStore)
        }
        .sheet(item: $editingExercise) { exercise in
            NavigationStack {
                EditExerciseView(exercise: exercise) { updatedExercise in
                    if let entity = exerciseEntities.first(where: { $0.id == updatedExercise.id }) {
                        entity.name = updatedExercise.name
                        entity.muscleGroupsRaw = updatedExercise.muscleGroups.map { $0.rawValue }
                        entity.equipmentTypeRaw = updatedExercise.equipmentType.rawValue
                        entity.descriptionText = updatedExercise.description
                        entity.instructions = updatedExercise.instructions
                        entity.createdAt = updatedExercise.createdAt
                        try? modelContext.save()
                    }
                } deleteAction: {
                    requestDeletion(for: [exercise])
                }
            }
        }
        .alert("Wirklich löschen?", isPresented: $showingDeleteAlert) {
            Button("Löschen", role: .destructive) {
                performDeletion()
            }
            Button("Abbrechen", role: .cancel) {
                pendingDeletion = []
            }
        } message: {
            if pendingDeletion.count == 1 {
                Text("\(pendingDeletion.first?.name ?? "") wird entfernt.")
            } else {
                Text("\(pendingDeletion.count) Übungen werden entfernt.")
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedGroups: $selectedGroups,
                selectedEquipment: $selectedEquipment
            )
        }
    }

    private func requestDeletion(for exercises: [Exercise]) {
        guard !exercises.isEmpty else { return }
        pendingDeletion = exercises
        showingDeleteAlert = true
    }

    private func performDeletion() {
        defer { showingDeleteAlert = false }
        for exercise in pendingDeletion {
            if let entity = exerciseEntities.first(where: { $0.id == exercise.id }) {
                modelContext.delete(entity)
            }
        }
        try? modelContext.save()
        pendingDeletion = []
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.headline)

            if !exercise.description.isEmpty {
                Text(exercise.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                HStack(spacing: 6) {
                    ForEach(exercise.muscleGroups, id: \.self) { muscleGroup in
                        Text(muscleGroup.rawValue)
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: exercise.equipmentType.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(exercise.equipmentType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct LiquidGlassSearchBar: View {
    @Binding var text: String
    @Binding var showingFilterSheet: Bool
    let hasActiveFilters: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Search field capsule
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Übung oder Muskelgruppe", text: $text)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                if !text.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { text = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Eingabe löschen")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 18, x: 0, y: 8)

            // Filter button
            Button {
                showingFilterSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 18, x: 0, y: 8)

                    ZStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(hasActiveFilters ? AppTheme.darkPurple : .primary)
                        
                        // Badge for active filters
                        if hasActiveFilters {
                            Circle()
                                .fill(AppTheme.powerOrange)
                                .frame(width: 8, height: 8)
                                .offset(x: 10, y: -10)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter öffnen")
        }
        .padding(.top, 8)
    }
}

struct FilterSheet: View {
    @Binding var selectedGroups: Set<MuscleGroup>
    @Binding var selectedEquipment: Set<EquipmentType>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Muscle Groups Section
                Section("Muskelgruppen") {
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        HStack {
                            Text(group.rawValue)
                                .font(.body)
                                .foregroundStyle(.primary.opacity(0.8))
                            
                            Spacer()
                            
                            if selectedGroups.contains(group) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.darkPurple)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedGroups.contains(group) {
                                    selectedGroups.remove(group)
                                } else {
                                    selectedGroups.insert(group)
                                }
                            }
                        }
                    }
                    
                    if !selectedGroups.isEmpty {
                        Button("Alle Muskelgruppen löschen") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedGroups.removeAll()
                            }
                        }
                        .foregroundStyle(AppTheme.powerOrange)
                    }
                }
                
                // Equipment Section
                Section("Equipment") {
                    ForEach([EquipmentType.freeWeights, .machine, .bodyweight, .cable, .mixed], id: \.self) { equipment in
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: equipment.icon)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                
                                Text(equipment.rawValue)
                                    .font(.body)
                                    .foregroundStyle(.primary.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            if selectedEquipment.contains(equipment) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.darkPurple)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedEquipment.contains(equipment) {
                                    selectedEquipment.remove(equipment)
                                } else {
                                    selectedEquipment.insert(equipment)
                                }
                            }
                        }
                    }
                    
                    if !selectedEquipment.isEmpty {
                        Button("Alle Equipment-Filter löschen") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedEquipment.removeAll()
                            }
                        }
                        .foregroundStyle(AppTheme.powerOrange)
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Alle löschen") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedGroups.removeAll()
                            selectedEquipment.removeAll()
                        }
                    }
                    .foregroundStyle(.red)
                    .disabled(selectedGroups.isEmpty && selectedEquipment.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}



private struct FloatingPlusButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: 10)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Neue Übung hinzufügen")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ExerciseEntity.self, configurations: config)
    // Seed a few exercises
    let ex1 = ExerciseEntity(id: UUID(), name: "Bankdrücken", muscleGroupsRaw: ["chest"], descriptionText: "", instructions: [], createdAt: Date())
    let ex2 = ExerciseEntity(id: UUID(), name: "Kniebeugen", muscleGroupsRaw: ["legs"], descriptionText: "", instructions: [], createdAt: Date())
    container.mainContext.insert(ex1)
    container.mainContext.insert(ex2)
    return ExercisesView()
        .environmentObject(WorkoutStore())
        .modelContainer(container)
}
