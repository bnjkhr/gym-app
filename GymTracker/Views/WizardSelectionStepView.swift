import SwiftUI

struct WizardSelectionStepView<Option: WizardSelectableOption>: View {
    let title: String
    let subtitle: String
    @Binding var selection: Option

    var body: some View {
        VStack(spacing: 24) {
            // Header mit Titel und Untertitel
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Liste der Auswahlkarten
            VStack(spacing: 16) {
                ForEach(Option.allCases) { option in
                    SelectionCard(
                        title: option.displayName,
                        subtitle: option.description,
                        isSelected: selection == option
                    ) {
                        selection = option
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}