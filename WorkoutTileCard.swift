import SwiftUI
import SwiftData

struct WorkoutTileCard: View {
    let workout: Workout
    let isHomeFavorite: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onStart: () -> Void
    let onDelete: () -> Void
    let onToggleHome: () -> Void
    let onDuplicate: () -> Void
    let onShare: () -> Void
    var onMoveToFolder: ((WorkoutFolderEntity) -> Void)? = nil
    var onRemoveFromFolder: (() -> Void)? = nil
    var isInFolder: Bool = false

    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var allSessions: [WorkoutSessionEntity]

    @Query(sort: [SortDescriptor(\WorkoutFolderEntity.order, order: .forward)])
    private var folders: [WorkoutFolderEntity]

    @Environment(\.modelContext) private var modelContext
    @State private var showingFolderPicker = false

    private var displayLevel: String {
        guard let level = workout.level else { return "" }
        switch level.lowercased() {
        case "beginner": return "Anfänger"
        case "intermediate": return "Fortgeschritten"
        case "advanced", "profi": return "Profi"
        default: return level.capitalized
        }
    }

    private var lastCompletedDate: String? {
        // Find the most recent session for this workout template
        let workoutSessions = allSessions.filter { $0.templateId == workout.id }
        guard let lastSession = workoutSessions.first else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastSession.date, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Content area - workout name and last completed date
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let lastDate = lastCompletedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("Zuletzt: \(lastDate)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    } else {
                        Text("Noch nicht absolviert")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Push content to top with spacer
                Spacer()
                
                // Footer area - exercises count and home button
                HStack {
                    Text("\(workout.exercises.count) Übungen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: onToggleHome) {
                        Image(systemName: isHomeFavorite ? "house.fill" : "house")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isHomeFavorite ? AppTheme.turquoiseBoost : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .confirmationDialog("Ordner auswählen", isPresented: $showingFolderPicker, titleVisibility: .visible) {
            ForEach(folders) { folder in
                Button(folder.name) {
                    onMoveToFolder?(folder)
                }
            }
            Button("Abbrechen", role: .cancel) { }
        }
        .contextMenu {
            // Performance: Grouped menu items for faster rendering
            Group {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    onStart()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }

            Divider()

            Group {
                Button {
                    onToggleHome()
                } label: {
                    Label("Zur Startseite", systemImage: isHomeFavorite ? "checkmark.square.fill" : "square")
                }

                Button {
                    onDuplicate()
                } label: {
                    Label("Duplizieren", systemImage: "doc.on.doc")
                }

                Button {
                    onShare()
                } label: {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
            }

            // Ordner-Optionen
            if isInFolder, let onRemove = onRemoveFromFolder {
                Divider()
                Button {
                    onRemove()
                } label: {
                    Label("Aus Ordner entfernen", systemImage: "folder.badge.minus")
                }
            } else if !folders.isEmpty, onMoveToFolder != nil {
                Divider()
                Button {
                    showingFolderPicker = true
                } label: {
                    Label("In Ordner verschieben", systemImage: "folder")
                }
            }
        } preview: {
            // Performance: Simple preview for instant visual feedback
            VStack(alignment: .leading, spacing: 8) {
                Text(workout.name)
                    .font(.headline)
                Text("\(workout.exercises.count) Übungen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    let sampleExercise = Exercise(
        id: UUID(),
        name: "Bankdrücken",
        muscleGroups: [.chest, .shoulders],
        equipmentType: .freeWeights,
        description: "Klassische Brustübung",
        instructions: ["Lege dich auf die Bank"],
        createdAt: Date()
    )
    
    let sampleWorkout = Workout(
        id: UUID(),
        name: "Ganzkörper",
        date: Date(),
        exercises: [
            WorkoutExercise(exercise: sampleExercise, sets: [
                ExerciseSet(reps: 10, weight: 80.0, restTime: 90, completed: false),
                ExerciseSet(reps: 8, weight: 85.0, restTime: 90, completed: false),
                ExerciseSet(reps: 6, weight: 90.0, restTime: 90, completed: false)
            ])
        ],
        defaultRestTime: 90,
        duration: nil,
        notes: "",
        isFavorite: false
    )
    
    return WorkoutTileCard(
        workout: sampleWorkout,
        isHomeFavorite: true,
        onTap: { },
        onEdit: { },
        onStart: { },
        onDelete: { },
        onToggleHome: { },
        onDuplicate: { },
        onShare: { }
    )
    .padding()
}