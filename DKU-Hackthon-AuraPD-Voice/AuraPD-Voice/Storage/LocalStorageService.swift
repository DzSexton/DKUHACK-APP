import Foundation

/// Persists assessment results and user profile data locally on device.
///
/// **Privacy guarantee**: No data is written to any location accessible outside the
/// app sandbox, and no network requests are made from this layer.
final class LocalStorageService {

    // MARK: – Singleton
    static let shared = LocalStorageService()
    private init() {}

    // MARK: – Constants
    private let resultsKey = "aura_pd_assessment_results"
    private let profileKey = "aura_pd_user_profile"

    // MARK: – User Profile

    /// Loads the stored user profile, or returns a default one if none exists.
    func loadUserProfile() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        return profile
    }

    /// Persists the user profile to `UserDefaults`.
    func saveUserProfile(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

    // MARK: – Assessment Results

    /// Returns all stored assessment results, newest first.
    func loadResults() -> [AssessmentResult] {
        guard let data = UserDefaults.standard.data(forKey: resultsKey),
              let results = try? JSONDecoder().decode([AssessmentResult].self, from: data) else {
            return []
        }
        return results.sorted { $0.timestamp > $1.timestamp }
    }

    /// Appends a new result to the stored list and persists it.
    func save(result: AssessmentResult) {
        var existing = loadResults()
        existing.append(result)
        // Ethical AI – Privacy:
        // Store only high-level assessment outputs locally.
        // Raw motion streams are intentionally excluded from persistence.
        // Keep only the most recent 500 entries to avoid unbounded growth.
        if existing.count > 500 {
            existing = Array(existing.sorted { $0.timestamp > $1.timestamp }.prefix(500))
        }
        guard let data = try? JSONEncoder().encode(existing) else { return }
        UserDefaults.standard.set(data, forKey: resultsKey)
    }

    /// Deletes all stored assessment results.
    func clearResults() {
        UserDefaults.standard.removeObject(forKey: resultsKey)
    }
}
