import SwiftUI
import PhotosUI
import HealthKit

struct ProfileEditView: View {
    @EnvironmentObject var workoutStore: WorkoutStoreCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name: String = ""
    @State private var birthDate: Date?
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var biologicalSex: HKBiologicalSex = .notSet
    @State private var healthKitSyncEnabled: Bool = false
    @State private var goal: FitnessGoal = .general
    @State private var experience: ExperienceLevel = .intermediate
    @State private var equipment: EquipmentPreference = .mixed
    @State private var preferredDuration: WorkoutDuration = .medium
    @State private var showingDatePicker = false
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var profileImage: UIImage?
    @State private var showingHealthKitImport = false
    @State private var isImportingFromHealthKit = false
    @State private var healthKitError: HealthKitError?
    @State private var showingHealthKitError = false
    
    private let maxNameLength = 50
    private let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Profile Picture Section
                    VStack(spacing: 12) {
                        Text("Profilbild")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            Button {
                                showingActionSheet = true
                            } label: {
                                ProfileImageView(image: selectedImage ?? profileImage, size: 120)
                            }
                            .buttonStyle(.plain)
                            
                            Text("Tippen zum Bearbeiten")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Personal Information
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Persönliche Informationen")
                                .font(.headline)
                            Spacer()
                            if workoutStore.healthKitManager.isHealthDataAvailable {
                                Button("HealthKit importieren") {
                                    importFromHealthKit()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .disabled(isImportingFromHealthKit || !workoutStore.healthKitManager.isAuthorized && workoutStore.healthKitManager.authorizationStatus == .sharingDenied)
                                .overlay {
                                    if isImportingFromHealthKit {
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                            Text("Importiere...")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        VStack(spacing: 16) {
                            HStack {
                                Text("Name")
                                Spacer()
                                TextField("Dein Name", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.plain)
                                    .frame(maxWidth: 200)
                                    .onChange(of: name) { oldValue, newValue in
                                        if newValue.count > maxNameLength {
                                            name = String(newValue.prefix(maxNameLength))
                                        }
                                    }
                            }
                            
                            HStack {
                                Text("Geburtsdatum")
                                Spacer()
                                Button {
                                    showingDatePicker.toggle()
                                } label: {
                                    Text(birthDate?.formatted(date: .abbreviated, time: .omitted) ?? "Nicht angegeben")
                                        .foregroundStyle(birthDate != nil ? .primary : .secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if let birthDate, let age = calculateAge(from: birthDate) {
                                HStack {
                                    Text("Alter")
                                    Spacer()
                                    Text("\(age) Jahre")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Gewicht")
                                Spacer()
                                HStack(spacing: 4) {
                                    TextField("kg", text: $weight)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(.plain)
                                        .frame(width: 80)
                                    Text("kg")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Größe")
                                Spacer()
                                HStack(spacing: 4) {
                                    TextField("cm", text: $height)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(.plain)
                                        .frame(width: 80)
                                    Text("cm")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Geschlecht")
                                Spacer()
                                Picker("Geschlecht", selection: $biologicalSex) {
                                    Text("Nicht angegeben").tag(HKBiologicalSex.notSet)
                                    Text("Weiblich").tag(HKBiologicalSex.female)
                                    Text("Männlich").tag(HKBiologicalSex.male)
                                    Text("Divers").tag(HKBiologicalSex.other)
                                }
                                .pickerStyle(.menu)
                            }
                            
                            if workoutStore.healthKitManager.isHealthDataAvailable {
                                HStack {
                                    Text("HealthKit Synchronisation")
                                    Spacer()
                                    Toggle("", isOn: $healthKitSyncEnabled)
                                }
                                
                                if healthKitSyncEnabled {
                                    Text("Workouts werden automatisch in die Health App übertragen.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Fitness Goal Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trainingsziel")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ForEach(FitnessGoal.allCases, id: \.self) { fitnessGoal in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: fitnessGoal.icon)
                                                .foregroundStyle(fitnessGoal.color)
                                                .frame(width: 20)
                                            
                                            Text(fitnessGoal.displayName)
                                                .font(.headline)
                                        }
                                        
                                        Text(fitnessGoal.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                    
                                    if goal == fitnessGoal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(fitnessGoal.color)
                                            .font(.title2)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(goal == fitnessGoal ? fitnessGoal.color.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(10)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        goal = fitnessGoal
                                    }
                                }
                            }
                        }
                        
                        Text("Wähle dein primäres Trainingsziel aus. Dies kann später jederzeit geändert werden.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Präferenzen für 1‑Klick-Workout")
                            .font(.headline)
                        
                        VStack(spacing: 16) {
                            HStack {
                                Text("Erfahrung")
                                Spacer()
                                Picker("Erfahrung", selection: $experience) {
                                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                                        Text(level.displayName).tag(level)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            HStack {
                                Text("Equipment")
                                Spacer()
                                Picker("Equipment", selection: $equipment) {
                                    ForEach(EquipmentPreference.allCases, id: \.self) { pref in
                                        Text(pref.displayName).tag(pref)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            HStack {
                                Text("Dauer")
                                Spacer()
                                Picker("Dauer", selection: $preferredDuration) {
                                    ForEach(WorkoutDuration.allCases, id: \.self) { d in
                                        Text(d.displayName).tag(d)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        Text("Diese Einstellungen nutzt der 1‑Klick‑Generator für schnelle Vorschläge.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .appEdgePadding()
            }
            .navigationTitle("Profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $birthDate)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(selectedImage: $selectedImage)
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Profilbild ändern"),
                buttons: [
                    .default(Text("Foto aufnehmen")) {
                        showingCamera = true
                    },
                    .default(Text("Aus Galerie wählen")) {
                        showingImagePicker = true
                    },
                    .destructive(Text("Bild entfernen")) {
                        selectedImage = nil
                        profileImage = nil
                    },
                    .cancel()
                ]
            )
        }
        .alert("HealthKit Fehler", isPresented: $showingHealthKitError, presenting: healthKitError) { error in
            Button("OK", role: .cancel) { healthKitError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        .scrollViewKeyboardDismissal() // Dismiss keyboard when tapping in scroll view
        .onAppear {
            // Initialize with current profile data
            let profile = workoutStore.userProfile
            name = profile.name
            birthDate = profile.birthDate
            weight = profile.weight?.formatted(.number.precision(.fractionLength(0...1))) ?? ""
            height = profile.height?.formatted(.number.precision(.fractionLength(0...1))) ?? ""
            biologicalSex = profile.biologicalSex ?? .notSet
            healthKitSyncEnabled = profile.healthKitSyncEnabled
            goal = profile.goal
            experience = profile.experience
            equipment = profile.equipment
            preferredDuration = profile.preferredDuration
            profileImage = profile.profileImage
            selectedImage = profile.profileImage // Initialize selectedImage with existing profile image
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileUpdatedFromHealthKit)) { _ in
            // Refresh profile data when HealthKit import completes
            Task { @MainActor in
                await refreshProfileData()
            }
        }
        .onReceive(workoutStore.healthKitManager.$isAuthorized) { isAuthorized in
            // Update UI when HealthKit authorization status changes
            if isAuthorized && !isImportingFromHealthKit {
                // Auto-import might have already happened in WorkoutStore, but refresh UI just in case
                Task { @MainActor in
                    await refreshProfileData()
                }
            }
        }
    }
    
    private func calculateAge(from birthDate: Date) -> Int? {
        let calendar = Calendar.current
        return calendar.dateComponents([.year], from: birthDate, to: Date()).year
    }
    
    private func importFromHealthKit() {
        guard workoutStore.healthKitManager.isHealthDataAvailable else { return }
        guard !isImportingFromHealthKit else { return } // Verhindere mehrfache gleichzeitige Importe
        
        isImportingFromHealthKit = true
        
        Task { @MainActor in
            do {
                // The WorkoutStore.requestHealthKitAuthorization now handles both authorization AND automatic import
                try await workoutStore.requestHealthKitAuthorization()
                
                // The data should already be imported and UI updated via notifications
                // But refresh once more to ensure consistency
                await refreshProfileData()
                
            } catch let error as HealthKitError {
                self.healthKitError = error
                self.showingHealthKitError = true
            } catch {
                self.healthKitError = HealthKitError.saveFailed
                self.showingHealthKitError = true
            }
            
            isImportingFromHealthKit = false
        }
    }
    
    private func refreshProfileData() async {
        // Ensure we're on the main actor
        await MainActor.run {
            // Get the latest profile data
            let profile = workoutStore.userProfile
            
            // Update UI with imported data
            if let birthDate = profile.birthDate {
                self.birthDate = birthDate
            }
            if let weight = profile.weight {
                self.weight = weight.formatted(.number.precision(.fractionLength(0...1)))
            }
            if let height = profile.height {
                self.height = height.formatted(.number.precision(.fractionLength(0...1)))
            }
            if let sex = profile.biologicalSex {
                self.biologicalSex = sex
            }
            self.healthKitSyncEnabled = true
            
            print("✅ UI updated with HealthKit data")
        }
    }
    
    private func saveProfile() {
        let weightValue = Double(weight.replacingOccurrences(of: ",", with: "."))
        let heightValue = Double(height.replacingOccurrences(of: ",", with: "."))

        workoutStore.updateProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: birthDate,
            weight: weightValue,
            height: heightValue,
            biologicalSex: biologicalSex != .notSet ? biologicalSex : nil,
            goal: goal,
            experience: experience,
            equipment: equipment,
            preferredDuration: preferredDuration,
            healthKitSyncEnabled: healthKitSyncEnabled
        )

        if selectedImage != profileImage {
            workoutStore.updateProfileImage(selectedImage)
        }

        // Mark onboarding step as completed: profile setup
        if !workoutStore.userProfile.hasSetupProfile {
            workoutStore.markOnboardingStep(hasSetupProfile: true)
        }

        // Request HealthKit authorization if sync is enabled but not yet authorized
        if healthKitSyncEnabled && !workoutStore.healthKitManager.isAuthorized {
            Task {
                do {
                    try await workoutStore.requestHealthKitAuthorization()
                } catch {
                    print("HealthKit authorization failed: \(error)")
                }
            }
        }
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var tempDate: Date = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                DatePicker(
                    "Geburtsdatum",
                    selection: $tempDate,
                    in: Calendar.current.date(byAdding: .year, value: -120, to: Date())!...Calendar.current.date(byAdding: .year, value: -10, to: Date())!,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                Spacer()
            }
            .navigationTitle("Geburtsdatum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        selectedDate = tempDate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempDate = selectedDate ?? Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ProfileEditView()
        .environmentObject(WorkoutStore())
}
