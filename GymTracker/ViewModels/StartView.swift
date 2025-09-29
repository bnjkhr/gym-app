import SwiftUI

struct StartView: View {
    @State private var searchText: String = ""

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Color(white: 0.08), Color.black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerCard
                        .padding(.horizontal)
                        .padding(.top)

                    // Dark section resembling the messages list
                    VStack(spacing: 0) {
                        ForEach(sampleItems) { item in
                            itemRow(item)
                            if item.id != sampleItems.last?.id {
                                Divider().background(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .tint(AppTheme.darkPurple)
    }

    private var headerCard: some View {
        ZStack(alignment: .topLeading) {
            GradientCardBackground(cornerRadius: 36)
                .frame(height: 300)
                .overlay(
                    VStack(alignment: .leading, spacing: 16) {
                        // Search pill
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.white.opacity(0.9))
                            Text("Search…")
                                .foregroundStyle(Color.white.opacity(0.9))
                                .font(.callout)
                                .padding(.leading, 2)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(Color.white.opacity(0.9))
                        }
                        .pillSearchFieldStyle()

                        Text("Workouts")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))

                        // Big Apple-style title
                        Text("Starte deine\nTrainingsreise")
                            .bigAppleTitleStyle()
                            .padding(.top, 4)

                        avatarsRow
                            .padding(.top, 6)
                    }
                    .padding(20)
                )
        }
    }

    private var avatarsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                addChip
                ForEach(sampleAvatars, id: \.self) { symbol in
                    VStack(spacing: 8) {
                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
                            .foregroundStyle(.white)
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var addChip: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .overlay(Circle().stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(Color.white.opacity(0.35)))
                    .frame(width: 68, height: 68)
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Text("Add")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func itemRow(_ item: SampleItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer()
            Text(item.trailing)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }

    // MARK: - Mock Data

    struct SampleItem: Identifiable { let id = UUID(); let symbol: String; let title: String; let subtitle: String; let trailing: String }

    private var sampleItems: [SampleItem] {
        [
            .init(symbol: "figure.strengthtraining.traditional", title: "Oberkörper – Push", subtitle: "Brust, Schulter, Trizeps – 6 Übungen", trailing: "Heute"),
            .init(symbol: "figure.run", title: "Cardio Intervall", subtitle: "20 Min. HIIT auf dem Laufband", trailing: "3:24 PM"),
            .init(symbol: "dumbbell", title: "Beine – Maschinen", subtitle: "Press, Curl, Extension, Waden", trailing: "Gestern")
        ]
    }

    private let sampleAvatars: [String] = [
        "person.circle.fill",
        "figure.run.circle.fill",
        "dumbbell.fill",
        "heart.circle.fill",
        "flame.circle.fill"
    ]
}

#Preview {
    StartView()
}
