//
//  BottomActionBar.swift
//  GymTracker
//
//  Fixed bottom action bar for Active Workout View - matches screenshot design
//

import SwiftUI

struct BottomActionBar: View {
    // MARK: - Constants

    private enum Layout {
        static let barHeight: CGFloat = 80
        static let iconSize: CGFloat = 24
        static let centerIconSize: CGFloat = 40
        static let horizontalPadding: CGFloat = 20
    }

    // MARK: - Properties

    var onRepeat: (() -> Void)?
    var onAdd: (() -> Void)?
    var onReorder: (() -> Void)?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Left: History/Repeat
            Button {
                onRepeat?()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: Layout.iconSize))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Spacer()

            // Right: Reorder
            Button {
                onReorder?()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: Layout.iconSize))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(height: Layout.barHeight)
        .padding(.horizontal, Layout.horizontalPadding)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 8, y: -2)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        // Simulated content
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)

            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
        }
        .padding()

        // Action Bar
        BottomActionBar(
            onRepeat: {
                print("History tapped")
            },
            onAdd: {
                print("Add tapped")
            },
            onReorder: {
                print("Reorder tapped")
            }
        )
    }
    .background(Color(.systemGroupedBackground))
    .ignoresSafeArea(edges: .bottom)
}
