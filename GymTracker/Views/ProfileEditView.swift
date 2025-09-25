import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name: String = ""
    @State private var birthDate: Date?
    @State private var weight: String = ""
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
            Form {
                // Profile Picture Section
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showingActionSheet = true
                        } label: {
                            ProfileImageView(image: selectedImage ?? profileImage, size: 120)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Spacer()
                        Text("Tippen zum Bearbeiten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } header: {
                    Text("Profilbild")
                }
                
                // Personal Information
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Dein Name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: name) { oldValue, newValue in
                                if newValue.count > maxNameLength {
                                    name = String(newValue.prefix(maxNameLength))
                                }
                            }
                    }
                    
                    HStack {
                        Text("Geburtsdatum")
                        Spacer()
                        if let birthDate {
                            Button {
                                showingDatePicker.toggle()
                            } label: {
                                Text(birthDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            Button {
                                showingDatePicker.toggle()
                            } label: {
                                Text("Nicht angegeben")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if let birthDate, let age = workoutStore.userProfile.age {
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
                        TextField("kg", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Persönliche Informationen")
                }
                
                // Fitness Goal Section
                Section {
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                goal = fitnessGoal
                            }
                        }
                    }
                } header: {
                    Text("Trainingsziel")
                } footer: {
                    Text("Wähle dein primäres Trainingsziel aus. Dies kann später jederzeit geändert werden.")
                }
                
                Section {
                    Picker("Erfahrung", selection: $experience) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }

                    Picker("Equipment", selection: $equipment) {
                        ForEach(EquipmentPreference.allCases, id: \.self) { pref in
                            Text(pref.displayName).tag(pref)
                        }
                    }

                    Picker("Dauer", selection: $preferredDuration) {
                        ForEach(WorkoutDuration.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                } header: {
                    Text("Präferenzen für 1‑Klick-Workout")
                } footer: {
                    Text("Diese Einstellungen nutzt der 1‑Klick‑Generator für schnelle Vorschläge.")
                }
            }
            .navigationTitle("Profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
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
        .onAppear {
            // Initialize with current profile data
            let profile = workoutStore.userProfile
            name = profile.name
            birthDate = profile.birthDate
            weight = profile.weight?.formatted(.number.precision(.fractionLength(0...1))) ?? ""
            goal = profile.goal
            experience = profile.experience
            equipment = profile.equipment
            preferredDuration = profile.preferredDuration
            profileImage = profile.profileImage
        }
    }
    
    private func saveProfile() {
        let weightValue = Double(weight.replacingOccurrences(of: ",", with: "."))
        
        workoutStore.updateProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: birthDate,
            weight: weightValue,
            goal: goal,
            experience: experience,
            equipment: equipment,
            preferredDuration: preferredDuration
        )
        
        if selectedImage != profileImage {
            workoutStore.updateProfileImage(selectedImage)
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
                    Button("Abbrechen") {
                        dismiss()
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
