import SwiftUI

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

    var filteredExercises: [Exercise] {
        let query = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = workoutStore.exercises
        if !selectedGroups.isEmpty {
            result = result.filter { exercise in
                exercise.muscleGroups.contains { selectedGroups.contains($0) }
            }
        }
        if !query.isEmpty {
            result = result.filter { exercise in
                let nameMatch = exercise.name.lowercased().contains(query)
                let groupMatch = exercise.muscleGroups.contains { $0.rawValue.lowercased().contains(query) }
                return nameMatch || groupMatch
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Filter header
                MuscleGroupFilterBar(selected: $selectedGroups)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                
                // Exercise list
                LazyVStack(spacing: 8) {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            editingExercise = exercise
                        } label: {
                            ExerciseRowView(exercise: exercise)
                                .padding(.horizontal)
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
        .safeAreaInset(edge: .bottom) {
            LiquidGlassSearchBar(text: $searchText)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .overlay(alignment: .topTrailing) {
            FloatingPlusButton {
                showingAddExercise = true
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: searchText, initial: true) { oldValue, newValue in
            let current = newValue
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.searchText == current {
                    self.debouncedSearch = current
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView()
                .environmentObject(workoutStore)
        }
        .sheet(item: $editingExercise) { exercise in
            NavigationStack {
                EditExerciseView(exercise: exercise) { updatedExercise in
                    workoutStore.updateExercise(updatedExercise)
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
    }

    private func requestDeletion(for exercises: [Exercise]) {
        guard !exercises.isEmpty else { return }
        pendingDeletion = exercises
        showingDeleteAlert = true
    }

    private func performDeletion() {
        defer {
            showingDeleteAlert = false
        }
        for exercise in pendingDeletion {
            if let index = workoutStore.exercises.firstIndex(where: { $0.id == exercise.id }) {
                workoutStore.deleteExercise(at: IndexSet(integer: index))
            }
            if editingExercise?.id == exercise.id {
                editingExercise = nil
            }
        }
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
                ForEach(exercise.muscleGroups, id: \.self) { muscleGroup in
                    Text(muscleGroup.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(muscleGroup.color.opacity(0.2))
                        .foregroundColor(muscleGroup.color)
                        .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

struct LiquidGlassSearchBar: View {
    @Binding var text: String

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

            // Big circular close button
            Button {
                text = ""
                #if canImport(UIKit)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
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

                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Suche schließen")
        }
        .padding(.top, 8)
    }
}

private struct MuscleGroupFilterBar: View {
    @Binding var selected: Set<MuscleGroup>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Alle", color: .gray, isSelected: selected.isEmpty) {
                    selected.removeAll()
                }
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    FilterChip(title: group.rawValue, color: group.color, isSelected: selected.contains(group)) {
                        if selected.contains(group) {
                            selected.remove(group)
                        } else {
                            selected.insert(group)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
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
    ExercisesView()
        .environmentObject(WorkoutStore())
}
