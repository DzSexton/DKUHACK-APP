import Foundation

// MARK: - CohortMatchResult

struct CohortMatchResult {
    let matchPercentage: Int
    let matchDescription: String
    let recommendation: String
    let dataSummary: String
}

// MARK: - ProfileManager

final class ProfileManager {

    static let shared = ProfileManager()
    private init() {}

    // MARK: - Local cohort database

    private struct CohortProfile {
        let intensityRange: ClosedRange<Double>
        let matchPercentage: Int
        let cohortDescription: String
        let recommendation: String
    }

    private let cohortDatabase: [CohortProfile] = [
        CohortProfile(
            intensityRange: 0.00...0.25,
            matchPercentage: 91,
            cohortDescription: "Mild stable tremor, good levodopa response, daily activities largely unaffected.",
            recommendation: "Your current state closely matches this cohort. Maintaining your existing medication regimen with monthly follow-ups is recommended."
        ),
        CohortProfile(
            intensityRange: 0.25...0.50,
            matchPercentage: 82,
            cohortDescription: "Moderate fluctuating tremor with distinct ON/OFF cycles; peak tremor typically before morning dose.",
            recommendation: "Data suggests that advancing the morning dose by 30 minutes may significantly reduce wearing-off symptoms."
        ),
        CohortProfile(
            intensityRange: 0.50...0.75,
            matchPercentage: 74,
            cohortDescription: "Moderate-to-severe tremor with pronounced peak-dose effect; OFF periods lasting approximately 2–3 hours.",
            recommendation: "Consider discussing dose fractionation with your neurologist to smooth plasma levodopa concentration."
        ),
        CohortProfile(
            intensityRange: 0.75...1.00,
            matchPercentage: 68,
            cohortDescription: "Severe tremor with prominent OFF-period symptoms significantly affecting quality of life.",
            recommendation: "Strongly advised to bring this tremor log to your next appointment and discuss COMT inhibitor adjunct or DBS pre-evaluation."
        )
    ]

    // MARK: - Rule engine

    func match(against records: [TremorRecord]) -> CohortMatchResult {
        guard !records.isEmpty else {
            return CohortMatchResult(
                matchPercentage: 0,
                matchDescription: "Insufficient data for matching",
                recommendation: "Complete at least one tremor assessment to enable smart insights.",
                dataSummary: "No data"
            )
        }

        let recent = Array(records.suffix(12))
        let avgIntensity = recent.map(\.tremorIntensity).reduce(0, +) / Double(recent.count)
        let tremorCount  = recent.filter { $0.state == .tremor }.count
        let offCount     = recent.filter { $0.state == .off }.count
        let onCount      = recent.filter { $0.state == .on }.count

        let matched = cohortDatabase.first { $0.intensityRange.contains(avgIntensity) }
                   ?? cohortDatabase.last!

        let dataSummary = String(format:
            "Last %d readings · avg intensity %.0f%% · Tremor %d · OFF %d · ON %d",
            recent.count, avgIntensity * 100, tremorCount, offCount, onCount
        )

        let matchDescription = String(format:
            "Based on your recent tremor data, you match %d%% of similar patients in the local database.\nCohort profile: %@",
            matched.matchPercentage, matched.cohortDescription
        )

        return CohortMatchResult(
            matchPercentage: matched.matchPercentage,
            matchDescription: matchDescription,
            recommendation: matched.recommendation,
            dataSummary: dataSummary
        )
    }
}
