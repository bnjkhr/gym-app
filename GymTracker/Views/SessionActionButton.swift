import SwiftUI

typealias WorkoutSessionHandler = (WorkoutSessionV1) -> Void

struct SessionActionButton<Label: View>: View {
    let session: WorkoutSessionV1
    let startAction: WorkoutSessionHandler
    let detailAction: WorkoutSessionHandler
    let deleteAction: WorkoutSessionHandler
    @ViewBuilder var label: () -> Label

    @State private var isConfirmingDelete = false

    var body: some View {
        Menu {
            Button("Workout erneut starten") { startAction(session) }
            Button("Details ansehen") { detailAction(session) }
            Button("Session löschen", role: .destructive) { isConfirmingDelete = true }
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .alert("Wirklich löschen?", isPresented: $isConfirmingDelete) {
            Button("Löschen", role: .destructive) { deleteAction(session) }
            Button("Abbrechen", role: .cancel) { isConfirmingDelete = false }
        } message: {
            Text("Die aufgezeichnete Session \(session.name) wird entfernt – gespeicherte Workouts bleiben erhalten.")
        }
    }
}
