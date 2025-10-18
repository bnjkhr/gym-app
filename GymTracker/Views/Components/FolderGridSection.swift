import SwiftData
import SwiftUI

/// Folder section with collapsible workout grid
///
/// Displays a folder header with expand/collapse functionality and a grid of workouts
/// contained in that folder. Supports folder management and workout actions.
///
/// **Features:**
/// - Collapsible folder with chevron indicator
/// - Colored folder icon
/// - Workout count badge
/// - Folder options (delete)
/// - 2-column grid of workouts
/// - Workout actions (edit, delete, share, etc.)
///
/// **Layout:**
/// ```
/// [>] 📁 Folder Name (3)  [•••]
///     [Workout 1] [Workout 2]
///     [Workout 3]
/// ```
///
/// **Usage:**
/// ```swift
/// FolderGridSection(
///     folder: folderEntity,
///     workouts: workoutsInFolder,
///     isExpanded: expandedFolders.contains(folder.id),
///     onToggle: { toggleFolder(folder.id) },
///     onTap: { startWorkout(with: $0) },
///     ...
/// )
/// ```
struct FolderGridSection: View {
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
