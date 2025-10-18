import SwiftUI

struct HealthKitSetupView: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingPermission = false
    @State private var showingError = false
    @State private var error: HealthKitError?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.red)
                    
                    Text("HealthKit Integration")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Verbinde deine Workout-App mit Apple Health für eine bessere Trainingserfassung.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "person.circle",
                        title: "Profildaten importieren",
                        description: "Übernehme automatisch deine Körperdaten aus der Health App"
                    )
                    
                    FeatureRow(
                        icon: "figure.strengthtraining.traditional",
                        title: "Workouts synchronisieren",
                        description: "Deine Trainings werden automatisch in der Health App gespeichert"
                    )
                    
                    FeatureRow(
                        icon: "heart.fill",
                        title: "Herzfrequenz anzeigen",
                        description: "Verfolge deine Herzfrequenz während und nach dem Training"
                    )
                }
                .padding(.horizontal, 8)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        requestHealthKitPermission()
                    } label: {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "heart.fill")
                            }
                            Text(isRequestingPermission ? "Berechtigung wird angefragt..." : "HealthKit aktivieren")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequestingPermission)
                    
                    Button("Später einrichten") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding(AppLayout.Spacing.extraLarge)
            .navigationTitle("HealthKit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Überspringen") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Fehler", isPresented: $showingError, presenting: error) { error in
            Button("OK", role: .cancel) { self.error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    private func requestHealthKitPermission() {
        guard workoutStore.healthKitManager.isHealthDataAvailable else {
            error = HealthKitError.notAvailable
            showingError = true
            return
        }
        
        isRequestingPermission = true
        
        Task {
            do {
                try await workoutStore.requestHealthKitAuthorization()
                
                await MainActor.run {
                    isRequestingPermission = false
                    dismiss()
                }
            } catch let healthKitError as HealthKitError {
                await MainActor.run {
                    self.error = healthKitError
                    self.showingError = true
                    self.isRequestingPermission = false
                }
            } catch {
                await MainActor.run {
                    self.error = HealthKitError.notAuthorized
                    self.showingError = true
                    self.isRequestingPermission = false
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.customBlue)
                .frame(width: 24, alignment: .center)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HealthKitSetupView()
        .environmentObject(WorkoutStore())
}