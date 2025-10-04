import SwiftUI

struct WorkoutsTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "figure.strengthtraining.functional")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Workouts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("This is the Workouts tab")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    WorkoutsTabView()
}