import SwiftUI

// MARK: - App Icon Artwork
/// The core vector artwork for the app icon. Keeps it simple and bold.
struct AppIconArtwork: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                // Subtle vignette for depth
                RadialGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.25)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 600
                )
            )

            // Decorative rings to suggest motion/energy
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 12)
                    .frame(width: 520, height: 520)
                    .blur(radius: 0.5)
                Circle()
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 8)
                    .frame(width: 420, height: 420)
                    .blur(radius: 0.5)
                Circle()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 6)
                    .frame(width: 320, height: 320)
                    .blur(radius: 0.5)
            }
            .offset(y: 10)

            // Central symbol (dumbbell)
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
                    .frame(width: 280, height: 280)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 150, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
            }
        }
        .clipped()
    }
}

// MARK: - App Icon View (Sized)
/// Wraps the artwork in an icon-shaped mask with continuous corners.
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        AppIconArtwork()
            .frame(width: size, height: size)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: max(1, size * 0.004))
            )
    }
}

// MARK: - Exporter
/// A helper view to export the icon as a PNG using ImageRenderer and share it.
struct AppIconExporterView: View {
    @State private var exportedURL: URL?
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("App-Icon Vorschau")
                .font(.title2.weight(.semibold))

            AppIconView(size: 240)
                .shadow(radius: 8)

            VStack(spacing: 12) {
                Button(action: export1024) {
                    HStack { Image(systemName: "square.and.arrow.up"); Text("1024×1024 PNG exportieren") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)

                if let url = exportedURL {
                    ShareLink(item: url) {
                        Label("Exportierte PNG teilen/speichern", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                if let error = exportError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Text("Tipp: Exportiere 1024×1024 und füge die Datei in den AppIcon Asset-Katalog ein. Xcode generiert die übrigen Größen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private func export1024() {
        exportError = nil
        isExporting = true
        let size: CGFloat = 1024
        let view = AppIconView(size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1 // 1024 points -> 1024 px

        // Render to PNG data
        #if os(iOS) || os(visionOS)
        if let uiImage = renderer.uiImage, let data = uiImage.pngData() {
            do {
                let url = try writePNG(data: data, suggestedName: "AppIcon-1024.png")
                exportedURL = url
            } catch {
                exportError = error.localizedDescription
            }
        } else {
            exportError = "Konnte Bild nicht rendern."
        }
        #elseif os(macOS)
        if let nsImage = renderer.nsImage, let data = nsImage.pngData() {
            do {
                let url = try writePNG(data: data, suggestedName: "AppIcon-1024.png")
                exportedURL = url
            } catch {
                exportError = error.localizedDescription
            }
        } else {
            exportError = "Konnte Bild nicht rendern."
        }
        #else
        exportError = "Export auf dieser Plattform nicht unterstützt."
        #endif

        isExporting = false
    }

    private func writePNG(data: Data, suggestedName: String) throws -> URL {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
        let url = temp.appendingPathComponent(suggestedName)
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Platform helpers
#if os(macOS)
extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let data = rep.representation(using: .png, properties: [:]) else { return nil }
        return data
    }
}
#endif

// MARK: - Previews
#Preview("Artwork") {
    AppIconArtwork()
        .frame(width: 300, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
        .padding()
}

#Preview("App Icon 1024") {
    AppIconView(size: 320) // Scaled-down preview for convenience
        .padding()
}

#Preview("Exporter") {
    AppIconExporterView()
}
