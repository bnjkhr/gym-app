import SwiftUI

/// Workout completion summary sheet
///
/// Displays a celebration sheet after completing a workout with summary statistics.
/// Shown as a modal sheet with `.medium` presentation detent.
///
/// **Features:**
/// - Success icon (checkmark seal)
/// - Workout name
/// - Duration, volume, and progress delta
/// - Dismiss action
///
/// **Usage:**
/// ```swift
/// .sheet(isPresented: $showingCompletionSheet) {
///     WorkoutCompletionSummaryView(
///         name: "Push Day",
///         durationText: "45 min",
///         totalVolumeText: "2,500 kg",
///         progressText: "+150 kg vs. letzte Session"
///     ) {
///         dismiss()
///     }
///     .presentationDetents([.medium])
/// }
/// ```
struct WorkoutCompletionSummaryView: View {
    let name: String
    let durationText: String
    let totalVolumeText: String
    let progressText: String
    let dismissAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.mossGreen)

                VStack(spacing: 12) {
                    Text(name)
                        .font(.title2.weight(.semibold))
                    Text("Workout gespeichert")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 18) {
                    summaryRow(title: "Dauer", value: durationText)
                    summaryRow(title: "Volumen", value: totalVolumeText)
                    summaryRow(title: "Veränderung", value: progressText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

                Button("Zur Übersicht") {
                    dismissAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.mossGreen)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .toolbar(.hidden)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
