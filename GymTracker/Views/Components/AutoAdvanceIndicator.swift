import SwiftUI

/// Overlay indicator for automatic exercise navigation
///
/// Displays a floating overlay when automatically advancing to the next exercise
/// after completing the last set of the current exercise.
///
/// **Features:**
/// - Animated arrow icon
/// - Next exercise name preview
/// - Blur background with shadow
/// - Auto-dismisses after animation
///
/// **Usage:**
/// ```swift
/// ZStack {
///     // Main content
///
///     if showingAutoAdvanceIndicator {
///         AutoAdvanceIndicator(
///             nextExerciseName: "Bizeps Curls"
///         )
///     }
/// }
/// ```
///
/// **Triggered by:** NavigateToNextExercise and NavigateToWorkoutCompletion notifications
struct AutoAdvanceIndicator: View {
    let nextExerciseName: String

    private var titleText: String {
        return nextExerciseName == "Workout abschließen" ? "Workout" : "Nächste Übung"
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Arrow icon with animation
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.mossGreen)
                        .scaleEffect(1.2)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: true
                        )

                    Text(titleText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                Text(nextExerciseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .scaleEffect(1.0)
            .opacity(1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: true)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
