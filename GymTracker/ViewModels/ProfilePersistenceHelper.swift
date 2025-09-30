import Foundation

/// Helper class for persisting UserProfile to UserDefaults as a backup mechanism
class ProfilePersistenceHelper {
    private static let userProfileKey = "UserProfile_Backup"
    
    /// Save UserProfile to UserDefaults as backup
    static func saveToUserDefaults(_ profile: UserProfile) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)
            UserDefaults.standard.set(data, forKey: userProfileKey)
            print("✅ UserProfile in UserDefaults gespeichert")
        } catch {
            print("❌ Fehler beim Speichern des UserProfile in UserDefaults: \(error)")
        }
    }
    
    /// Load UserProfile from UserDefaults backup
    static func loadFromUserDefaults() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: userProfileKey) else {
            print("ℹ️ Kein UserProfile-Backup in UserDefaults gefunden, verwende Standard-Profil")
            return UserProfile()
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let profile = try decoder.decode(UserProfile.self, from: data)
            print("✅ UserProfile aus UserDefaults-Backup geladen")
            return profile
        } catch {
            print("❌ Fehler beim Laden des UserProfile aus UserDefaults: \(error), verwende Standard-Profil")
            return UserProfile()
        }
    }
    
    /// Remove UserProfile backup from UserDefaults
    static func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: userProfileKey)
        print("🗑️ UserProfile-Backup aus UserDefaults entfernt")
    }
    
    /// Check if a UserProfile backup exists in UserDefaults
    static func hasUserDefaultsBackup() -> Bool {
        return UserDefaults.standard.data(forKey: userProfileKey) != nil
    }
}