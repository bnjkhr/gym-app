import SwiftUI

/// View shown when the app cannot initialize the database
/// Provides diagnostics and recovery options instead of crashing
struct RecoveryModeView: View {
    let error: Error
    let retryAction: () -> Void

    @State private var showingDiagnostics = false
    @State private var showingLogs = false
    @Environment(\.openURL) private var openURL

    private var diagnosticInfo: String {
        """
        Fehlerdetails:
        \(error.localizedDescription)

        Geräteinformationen:
        iOS Version: \(UIDevice.current.systemVersion)
        Gerätemodell: \(UIDevice.current.model)
        Freier Speicher: \(availableStorageString)

        Mögliche Ursachen:
        • Zu wenig freier Speicherplatz
        • Fehlende Dateiberechtigungen
        • Beschädigte Datenbankdateien
        """
    }

    private var availableStorageString: String {
        if let storage = getAvailableStorage() {
            return String(format: "%.2f MB", Double(storage) / 1_048_576)
        }
        return "Unbekannt"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40)

                        // Error Icon
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.bottom, 8)

                        // Title
                        Text("Datenbank konnte nicht geladen werden")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Text("Die App kann nicht auf den Datenspeicher zugreifen. Bitte versuche die folgenden Schritte.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        // Recovery Options
                        VStack(spacing: 16) {
                            // Retry Button
                            Button {
                                retryAction()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("App neu starten")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [AppTheme.mossGreen, AppTheme.turquoiseBoost],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            // Diagnostics Button
                            Button {
                                showingDiagnostics = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Diagnose anzeigen")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(AppTheme.deepBlue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemGray6))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)

                        // Help Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Lösungsvorschläge:")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)

                            VStack(alignment: .leading, spacing: 12) {
                                HelpItem(
                                    icon: "externaldrive.badge.checkmark",
                                    title: "Speicherplatz freigeben",
                                    description: "Lösche ungenutzte Apps oder Fotos"
                                )

                                HelpItem(
                                    icon: "arrow.triangle.2.circlepath",
                                    title: "iPhone neu starten",
                                    description: "Ein Neustart kann Berechtigungsprobleme beheben"
                                )

                                HelpItem(
                                    icon: "trash",
                                    title: "App neu installieren",
                                    description: "Als letztes Mittel: App löschen und neu installieren"
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 8)

                        Spacer()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDiagnostics) {
                DiagnosticsView(diagnosticInfo: diagnosticInfo)
            }
        }
    }

    private func getAvailableStorage() -> Int64? {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            return nil
        }
    }
}

struct HelpItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppTheme.deepBlue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

struct DiagnosticsView: View {
    let diagnosticInfo: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingCopiedAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(diagnosticInfo)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                            )

                        Button {
                            UIPasteboard.general.string = diagnosticInfo
                            showingCopiedAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Diagnose kopieren")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.deepBlue)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
            .navigationTitle("Diagnose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
            .alert("Kopiert", isPresented: $showingCopiedAlert) {
                Button("OK") { }
            } message: {
                Text("Diagnose-Informationen wurden in die Zwischenablage kopiert.")
            }
        }
    }
}

#Preview {
    RecoveryModeView(
        error: NSError(domain: "GymBo", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create ModelContainer"]),
        retryAction: {}
    )
}
