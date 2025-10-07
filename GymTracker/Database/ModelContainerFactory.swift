import SwiftData
import Foundation
import OSLog

/// Factory for creating ModelContainer with robust fallback strategy
/// Prevents app crashes by trying multiple storage locations and configurations
enum ModelContainerFactory {

    /// Result of container creation attempt
    enum ContainerResult {
        case success(ModelContainer, location: StorageLocation)
        case failure(Error)
    }

    /// Available storage locations in fallback order
    enum StorageLocation: String {
        case applicationSupport = "Application Support"
        case documents = "Documents"
        case temporary = "Temporary"
        case inMemory = "In-Memory (Temporary)"

        var isPersistent: Bool {
            self != .inMemory
        }
    }

    /// Creates a ModelContainer with comprehensive fallback strategy
    /// - Parameter schema: The SwiftData schema to use (deprecated, use migrationPlan instead)
    /// - Returns: ContainerResult with either success or failure
    static func createContainer(schema: Schema) -> ContainerResult {
        // Try each fallback location in order
        let fallbackChain: [(StorageLocation, () throws -> ModelContainer)] = [
            (.applicationSupport, { try createApplicationSupportContainer(schema: schema) }),
            (.documents, { try createDocumentsContainer(schema: schema) }),
            (.temporary, { try createTemporaryContainer(schema: schema) }),
            (.inMemory, { try createInMemoryContainer(schema: schema) })
        ]

        for (location, createAttempt) in fallbackChain {
            do {
                let container = try createAttempt()
                logSuccess(location: location)
                return .success(container, location: location)
            } catch {
                logFailure(location: location, error: error)
                continue
            }
        }

        // This should never happen since in-memory container should always work
        let finalError = NSError(
            domain: "com.gymbo.modelcontainer",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All ModelContainer creation attempts failed"]
        )
        AppLogger.app.critical("All container creation methods failed - this should be impossible!")
        return .failure(finalError)
    }

    /// Creates a ModelContainer with migration plan support
    /// - Parameter migrationPlan: The migration plan type to use
    /// - Returns: ContainerResult with either success or failure
    static func createContainer<T: SchemaMigrationPlan>(migrationPlan: T.Type) -> ContainerResult {
        // Try each fallback location in order
        let fallbackChain: [(StorageLocation, () throws -> ModelContainer)] = [
            (.applicationSupport, { try createApplicationSupportContainer(migrationPlan: migrationPlan) }),
            (.documents, { try createDocumentsContainer(migrationPlan: migrationPlan) }),
            (.temporary, { try createTemporaryContainer(migrationPlan: migrationPlan) }),
            (.inMemory, { try createInMemoryContainer(migrationPlan: migrationPlan) })
        ]

        for (location, createAttempt) in fallbackChain {
            do {
                let container = try createAttempt()
                logSuccess(location: location)
                return .success(container, location: location)
            } catch {
                logFailure(location: location, error: error)
                continue
            }
        }

        // This should never happen since in-memory container should always work
        let finalError = NSError(
            domain: "com.gymbo.modelcontainer",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All ModelContainer creation attempts failed"]
        )
        AppLogger.app.critical("All container creation methods failed - this should be impossible!")
        return .failure(finalError)
    }

    // MARK: - Container Creation Methods

    private static func createApplicationSupportContainer(schema: Schema) throws -> ModelContainer {
        // Create Application Support directory if needed
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        }

        // Try default location (Application Support)
        return try ModelContainer(for: schema)
    }

    private static func createDocumentsContainer(schema: Schema) throws -> ModelContainer {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeURL = documentsURL.appendingPathComponent("GymTracker.sqlite")

        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func createTemporaryContainer(schema: Schema) throws -> ModelContainer {
        let tempURL = FileManager.default.temporaryDirectory
        let storeURL = tempURL.appendingPathComponent("GymTracker.sqlite")

        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func createInMemoryContainer(schema: Schema) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Container Creation Methods with Migration Plan

    private static func createApplicationSupportContainer<T: SchemaMigrationPlan>(migrationPlan: T.Type) throws -> ModelContainer {
        // Create Application Support directory if needed
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        }

        // Try default location (Application Support) with migration plan
        return try ModelContainer(for: migrationPlan)
    }

    private static func createDocumentsContainer<T: SchemaMigrationPlan>(migrationPlan: T.Type) throws -> ModelContainer {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeURL = documentsURL.appendingPathComponent("GymTracker.sqlite")

        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: migrationPlan, configurations: [config])
    }

    private static func createTemporaryContainer<T: SchemaMigrationPlan>(migrationPlan: T.Type) throws -> ModelContainer {
        let tempURL = FileManager.default.temporaryDirectory
        let storeURL = tempURL.appendingPathComponent("GymTracker.sqlite")

        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: migrationPlan, configurations: [config])
    }

    private static func createInMemoryContainer<T: SchemaMigrationPlan>(migrationPlan: T.Type) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: migrationPlan, configurations: [config])
    }

    // MARK: - Diagnostics

    /// Check storage health before attempting container creation
    static func checkStorageHealth() -> StorageHealth {
        var issues: [String] = []
        var warnings: [String] = []

        // Check available storage
        if let availableBytes = getAvailableStorage() {
            let availableMB = Double(availableBytes) / 1_048_576

            if availableMB < 50 {
                issues.append("Kritisch wenig Speicherplatz: \(String(format: "%.1f", availableMB)) MB")
            } else if availableMB < 100 {
                warnings.append("Wenig Speicherplatz: \(String(format: "%.1f", availableMB)) MB")
            }
        }

        // Check write permissions for common directories
        let fileManager = FileManager.default
        let testDirs: [(String, URL?)] = [
            ("Application Support", fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first),
            ("Documents", fileManager.urls(for: .documentDirectory, in: .userDomainMask).first),
            ("Temporary", URL(fileURLWithPath: NSTemporaryDirectory()))
        ]

        for (name, url) in testDirs {
            guard let url = url else {
                issues.append("\(name)-Verzeichnis nicht verfügbar")
                continue
            }

            if !fileManager.isWritableFile(atPath: url.path) {
                issues.append("Keine Schreibrechte für \(name)")
            }
        }

        // Check for corrupted database files
        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dbURL = docsURL.appendingPathComponent("GymTracker.sqlite")
            if fileManager.fileExists(atPath: dbURL.path) {
                // Check if file is readable
                if !fileManager.isReadableFile(atPath: dbURL.path) {
                    issues.append("Datenbank-Datei beschädigt oder nicht lesbar")
                }
            }
        }

        return StorageHealth(issues: issues, warnings: warnings)
    }

    /// Get available storage in bytes
    private static func getAvailableStorage() -> Int64? {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            AppLogger.app.error("Failed to check storage: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Logging

    private static func logSuccess(location: StorageLocation) {
        AppLogger.app.info("✅ ModelContainer created at: \(location.rawValue)")

        if !location.isPersistent {
            AppLogger.app.warning("⚠️ Using non-persistent storage - data will be lost on restart!")
        }
    }

    private static func logFailure(location: StorageLocation, error: Error) {
        AppLogger.app.error("❌ Failed to create container at \(location.rawValue): \(error.localizedDescription)")
    }
}

// MARK: - Supporting Types

struct StorageHealth {
    let issues: [String]
    let warnings: [String]

    var isHealthy: Bool {
        issues.isEmpty
    }

    var hasCriticalIssues: Bool {
        !issues.isEmpty
    }

    var summary: String {
        var lines: [String] = []

        if issues.isEmpty && warnings.isEmpty {
            lines.append("✅ Speicher ist gesund")
        }

        if !issues.isEmpty {
            lines.append("❌ Probleme:")
            lines.append(contentsOf: issues.map { "  • \($0)" })
        }

        if !warnings.isEmpty {
            lines.append("⚠️ Warnungen:")
            lines.append(contentsOf: warnings.map { "  • \($0)" })
        }

        return lines.joined(separator: "\n")
    }
}
