import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditProfile = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image and Basic Info
            HStack(spacing: 16) {
                ProfileImageView(
                    image: workoutStore.userProfile.profileImage,
                    size: 80
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    if !workoutStore.userProfile.name.isEmpty {
                        Text(workoutStore.userProfile.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    } else {
                        Text("Noch kein Name hinterlegt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let age = workoutStore.userProfile.age {
                        Text("\(age) Jahre")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    
                    if let weight = workoutStore.userProfile.weight {
                        Text("\(weight.formatted(.number.precision(.fractionLength(0...1)))) kg")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                Button {
                    showingEditProfile = true
                } label: {
                    Text("Bearbeiten")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.mossGreen, in: Capsule())
                }
            }
            
            // Fitness Goal
            HStack(spacing: 12) {
                Image(systemName: workoutStore.userProfile.goal.icon)
                    .foregroundStyle(workoutStore.userProfile.goal.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutStore.userProfile.goal.displayName)
                        .font(.headline)
                    
                    Text(workoutStore.userProfile.goal.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(workoutStore.userProfile.goal.color.opacity(0.2), lineWidth: 1)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.mossGreen, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    colorScheme == .dark 
                    ? Color.white.opacity(0.08) 
                    : Color.black.opacity(0.06), 
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), 
            radius: 18, 
            x: 0, 
            y: 8
        )
        .sheet(isPresented: $showingEditProfile) {
            ProfileEditView()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(WorkoutStore())
        .padding()
}
