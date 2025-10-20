//
//  DraggableExerciseSheet.swift
//  GymTracker
//
//  Draggable sheet for exercise list that sits on top of timer
//

import SwiftUI

struct DraggableExerciseSheet<Content: View>: View {
    let content: Content
    @State private var offset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0
    @GestureState private var gestureOffset: CGFloat = 0

    // Detent positions (as offset from top)
    private let expandedOffset: CGFloat = 200  // Shows timer (header + timer section)
    private let collapsedOffset: CGFloat = 380  // Shows timer, buttons stay visible

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Grabber Handle
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                // Content
                content
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(39)
            .offset(y: offset + gestureOffset)
            .gesture(
                DragGesture()
                    .updating($gestureOffset) { value, state, _ in
                        // Clamp gesture to valid range during dragging
                        let proposedOffset = offset + value.translation.height
                        state = value.translation.height

                        // Prevent dragging beyond bounds
                        if proposedOffset < expandedOffset {
                            state = expandedOffset - offset
                        } else if proposedOffset > collapsedOffset {
                            state = collapsedOffset - offset
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndLocation.y - value.location.y
                        let currentOffset = offset + value.translation.height
                        let midpoint = (expandedOffset + collapsedOffset) / 2

                        // Determine target based on position and velocity
                        let targetOffset: CGFloat
                        if abs(velocity) > 100 {
                            // Fast swipe - use velocity to determine direction
                            targetOffset = velocity > 0 ? collapsedOffset : expandedOffset
                        } else {
                            // Slow drag - snap to nearest
                            targetOffset =
                                currentOffset < midpoint ? expandedOffset : collapsedOffset
                        }

                        // Ultra smooth animation - no bounce, no spring
                        withAnimation(.timingCurve(0.2, 0.0, 0.0, 1.0, duration: 0.35)) {
                            offset = targetOffset
                        }
                    }
            )
            .onAppear {
                // Start in collapsed state (timer visible)
                offset = collapsedOffset
            }
        }
    }
}

#Preview {
    ZStack {
        // Background (Timer)
        Color.black
            .ignoresSafeArea()

        // Foreground (Draggable sheet)
        DraggableExerciseSheet {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<10, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 120)
                            .overlay(
                                Text("Exercise \(index + 1)")
                                    .font(.headline)
                            )
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
}
