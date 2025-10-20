//
//  DraggableSheetDemo.swift
//  GymTracker
//
//  Demo view to test the draggable sheet behavior
//

import SwiftUI

/// Standalone demo view to test draggable sheet over timer
struct DraggableSheetDemo: View {
    var body: some View {
        ZStack {
            // Background: Timer (black)
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        // Back
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Text("3 / 6")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    Button {
                        // Menu
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(Color.black)

                // Timer Display
                VStack(spacing: 16) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("REST")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))

                        Text("01:30")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Timer controls
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                            Text("15s")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.8))

                        VStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 32))
                            Text("Skip")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)

                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                            Text("15s")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, 40)
                }
                .frame(height: 350)
                .background(
                    Color.black
                        .ignoresSafeArea(edges: .top)
                )

                Spacer()
            }
            .background(Color.black)

            // Foreground: Draggable Exercise Sheet
            DraggableExerciseSheet {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(0..<5, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Bench Press")
                                    .font(.headline)

                                ForEach(0..<3, id: \.self) { setIndex in
                                    HStack {
                                        Text("Set \(setIndex + 1)")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("100 kg × 8")
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }

                // Bottom bar
                HStack(spacing: 40) {
                    Button {
                        // History
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                    }

                    Button {
                        // Add
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 56))
                    }

                    Button {
                        // Reorder
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.title2)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Draggable Sheet Demo") {
    DraggableSheetDemo()
}
