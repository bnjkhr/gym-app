import SwiftUI

struct WorkoutActionButton<Label: View>: View {
    let workout: Workout
    let startAction: (Workout) -> Void
    let detailAction: (Workout) -> Void
    let editAction: ((Workout) -> Void)?
    let deleteAction: (Workout) -> Void
    @ViewBuilder var label: () -> Label

    @State private var isConfirmingDelete = false

    var body: some View {
        // Der Label-Inhalt bleibt interaktiv (z.B. Play-Button in WorkoutRow)
        // Tippen auf die Zeile öffnet Details, Long-Press öffnet Kontextmenü.
        label()
            .contentShape(Rectangle())
            .onTapGesture {
                detailAction(workout)
            }
            .contextMenu {
                Button("Workout starten") { startAction(workout) }
                Button("Details ansehen") { detailAction(workout) }
                if let editAction {
                    Button("Bearbeiten") { editAction(workout) }
                }
                Button("Löschen", role: .destructive) { isConfirmingDelete = true }
            }
            .buttonStyle(.plain)
            .alert("Wirklich löschen?", isPresented: $isConfirmingDelete) {
                Button("Löschen", role: .destructive) { deleteAction(workout) }
                Button("Abbrechen", role: .cancel) { isConfirmingDelete = false }
            } message: {
                Text("\(workout.name) wird dauerhaft entfernt.")
            }
    }
}
