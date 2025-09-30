import SwiftUI

// MARK: - Keyboard Dismissal Usage Examples

/// Comprehensive examples of how to use keyboard dismissal throughout your app
struct KeyboardDismissalExamples: View {
    @State private var textFieldContent = ""
    @State private var textEditorContent = "Hier ist etwas Text zum Bearbeiten..."
    @State private var searchText = ""
    @StateObject private var keyboardMonitor = KeyboardMonitor()
    
    var body: some View {
        NavigationStack {
            TabView {
                // MARK: - Example 1: Basic Usage
                basicUsageExample
                    .tabItem {
                        Image(systemName: "1.circle")
                        Text("Basic")
                    }
                
                // MARK: - Example 2: ScrollView with Forms
                scrollViewExample
                    .tabItem {
                        Image(systemName: "2.circle")
                        Text("ScrollView")
                    }
                
                // MARK: - Example 3: Advanced Features
                advancedExample
                    .tabItem {
                        Image(systemName: "3.circle")
                        Text("Advanced")
                    }
                
                // MARK: - Example 4: Keyboard Monitoring
                keyboardMonitoringExample
                    .tabItem {
                        Image(systemName: "4.circle")
                        Text("Monitor")
                    }
            }
            .navigationTitle("Keyboard Dismissal")
        }
        // Global keyboard dismissal for the entire TabView
        .dismissKeyboard()
    }
    
    // MARK: - Basic Usage Example
    private var basicUsageExample: some View {
        VStack(spacing: 20) {
            Text("Basic Keyboard Dismissal")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tippe irgendwo außerhalb der Textfelder, um die Tastatur zu schließen.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                TextField("Name eingeben", text: $textFieldContent)
                    .textFieldStyle(.roundedBorder)
                
                TextField("E-Mail eingeben", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                
                TextEditor(text: $textEditorContent)
                    .frame(height: 100)
                    .border(Color.gray, width: 1)
                    .cornerRadius(8)
            }
            .padding()
            
            Spacer()
        }
        .padding()
        // This view automatically inherits keyboard dismissal from parent
    }
    
    // MARK: - ScrollView Example
    private var scrollViewExample: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Text("ScrollView mit Textfeldern")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Text("ScrollViews benötigen spezielle Behandlung für Keyboard-Dismissal")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Create multiple text fields to test scrolling behavior
                ForEach(1...10, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feld \(index)")
                            .font(.headline)
                        TextField("Eingabe für Feld \(index)", text: .constant(""))
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                }
                
                TextEditor(text: $textEditorContent)
                    .frame(height: 120)
                    .border(Color.gray, width: 1)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
        // Special ScrollView keyboard dismissal
        .scrollViewKeyboardDismissal()
    }
    
    // MARK: - Advanced Example
    private var advancedExample: some View {
        VStack(spacing: 20) {
            Text("Erweiterte Funktionen")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Example with conditional keyboard dismissal
                ConditionalKeyboardDismissalDemo()
                
                // Example with UIKit integration
                UIKitKeyboardDismissalDemo()
                
                // Manual keyboard dismissal button
                Button("Tastatur manuell schließen") {
                    hideKeyboard()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Keyboard Monitoring Example
    private var keyboardMonitoringExample: some View {
        VStack(spacing: 20) {
            Text("Keyboard Status Monitoring")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Tastatur Status:")
                    Spacer()
                    Text(keyboardMonitor.isKeyboardVisible ? "Sichtbar" : "Versteckt")
                        .foregroundColor(keyboardMonitor.isKeyboardVisible ? .green : .red)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                HStack {
                    Text("Tastatur Höhe:")
                    Spacer()
                    Text("\(Int(keyboardMonitor.keyboardHeight)) Punkte")
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                TextField("Tippe hier zum Testen", text: $textFieldContent)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
        }
        .padding()
        .padding(.bottom, keyboardMonitor.keyboardHeight) // Adjust for keyboard
        .animation(.easeInOut(duration: 0.3), value: keyboardMonitor.keyboardHeight)
    }
}

// MARK: - Supporting Demo Views

struct ConditionalKeyboardDismissalDemo: View {
    @State private var enableDismissal = true
    @State private var sampleText = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Conditional Dismissal Demo")
                .font(.headline)
            
            Toggle("Keyboard Dismissal aktiviert", isOn: $enableDismissal)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            TextField("Test hier...", text: $sampleText)
                .textFieldStyle(.roundedBorder)
        }
        .smartKeyboardDismissal()
        .environment(\.keyboardDismissalEnabled, enableDismissal)
    }
}

struct UIKitKeyboardDismissalDemo: View {
    @State private var testText = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Text("UIKit Integration Demo")
                .font(.headline)
            
            Text("Verwendet UIKit für präzisere Kontrolle")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("UIKit basierte Dismissal", text: $testText)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .uiKitKeyboardDismissal() // Uses UIKit approach
    }
}

// MARK: - Real-World Usage Examples

struct LoginFormExample: View {
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Login Formular")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                TextField("E-Mail", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Passwort", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Angemeldet bleiben", isOn: $rememberMe)
            }
            
            Button("Anmelden") {
                // Login logic here
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty)
            
            Spacer()
        }
        .padding()
        .dismissKeyboard() // Dismisses keyboard when tapping outside
    }
}

struct ContactFormExample: View {
    @State private var name = ""
    @State private var email = ""
    @State private var message = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("E-Mail", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                    
                    VStack(alignment: .leading) {
                        Text("Nachricht")
                            .font(.headline)
                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .border(Color.gray, width: 1)
                            .cornerRadius(8)
                    }
                    
                    Button("Senden") {
                        // Send logic
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || email.isEmpty || message.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Kontakt")
            .scrollViewKeyboardDismissal() // Special handling for ScrollView
        }
    }
}

// MARK: - Preview

#Preview {
    KeyboardDismissalExamples()
}

#Preview("Login Form") {
    LoginFormExample()
}

#Preview("Contact Form") {
    ContactFormExample()
}