//
//  SimpleSheetTest.swift
//  GymTracker
//
//  Minimal test view for draggable sheet
//

import SwiftUI

struct SimpleSheetTest: View {
    var body: some View {
        ZStack {
            // Background: Black with timer
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("←")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("3 / 6")
                        .foregroundStyle(.white)
                    Spacer()
                    Text("⋯")
                        .foregroundStyle(.orange)
                }
                .padding()
                .background(Color.black)

                // Timer
                VStack {
                    Spacer()
                    Text("REST")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("01:30")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .frame(height: 300)
                .background(Color.black.ignoresSafeArea(edges: .top))

                Spacer()
            }
            .background(Color.black)

            // Foreground: Draggable sheet
            DraggableExerciseSheet {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(0..<10, id: \.self) { i in
                                Text("Exercise \(i + 1)")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }

                    // Bottom bar
                    Text("Bottom Bar")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                }
            }
        }
    }
}

#Preview {
    SimpleSheetTest()
}
