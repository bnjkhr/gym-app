import SwiftUI
import SwiftData

struct AddFolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var folderName: String = ""
    @State private var selectedColor: String = "#8B5CF6" // Purple

    let folder: WorkoutFolderEntity?
    let onSave: (() -> Void)?

    init(folder: WorkoutFolderEntity? = nil, onSave: (() -> Void)? = nil) {
        self.folder = folder
        self.onSave = onSave
        if let folder = folder {
            _folderName = State(initialValue: folder.name)
            _selectedColor = State(initialValue: folder.color)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ordnername") {
                    TextField("z.B. Oberkörper, Beintraining...", text: $folderName)
                }

                Section("Farbe") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(colorOptions, id: \.self) { color in
                            ColorButton(color: color, isSelected: selectedColor == color) {
                                selectedColor = color
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(folder == nil ? "Neuer Ordner" : "Ordner bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveFolder()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveFolder() {
        if let folder = folder {
            // Edit existing folder
            folder.name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
            folder.color = selectedColor
        } else {
            // Create new folder
            let descriptor = FetchDescriptor<WorkoutFolderEntity>(
                sortBy: [SortDescriptor(\.order, order: .reverse)]
            )
            let maxOrder = (try? modelContext.fetch(descriptor).first?.order) ?? -1

            let newFolder = WorkoutFolderEntity(
                name: folderName.trimmingCharacters(in: .whitespacesAndNewlines),
                color: selectedColor,
                order: maxOrder + 1
            )
            modelContext.insert(newFolder)
        }

        try? modelContext.save()
        onSave?()
        dismiss()
    }

    private let colorOptions = [
        "#8B5CF6", // Purple
        "#3B82F6", // Blue
        "#10B981", // Green
        "#F59E0B", // Orange
        "#EF4444", // Red
        "#EC4899", // Pink
        "#6366F1", // Indigo
        "#14B8A6", // Teal
        "#F97316", // Orange-Red
        "#8B5A00", // Brown
        "#64748B", // Slate
        "#6B7280"  // Gray
    ]
}

struct ColorButton: View {
    let color: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 44, height: 44)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 3)
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// Color extension to support hex strings
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

#Preview {
    AddFolderView()
        .modelContainer(for: [WorkoutFolderEntity.self])
}
