import Foundation

// MARK: - TremorRecord

/// A single tremor assessment record, used for timeline playback and local cohort matching.
/// Codable for local persistence; Identifiable for SwiftUI List/ForEach.
struct TremorRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    /// Normalised tremor amplitude: 0.0 (no tremor) to 1.0 (maximum tremor)
    let tremorIntensity: Double
    /// Motor state at the time of recording (ON / OFF / Tremor / Unknown)
    let state: MotorState

    init(
        id: UUID = UUID(),
        timestamp: Date,
        tremorIntensity: Double,
        state: MotorState
    ) {
        self.id = id
        self.timestamp = timestamp
        self.tremorIntensity = max(0.0, min(1.0, tremorIntensity))
        self.state = state
    }

    // MARK: - Display helpers

    /// Short time format (HH:mm) for timeline labels
    var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: timestamp)
    }

    /// Full date-time format for detail views
    var formattedDateTime: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: timestamp)
    }

    /// Human-readable intensity label
    var intensityLabel: String {
        switch tremorIntensity {
        case 0.0..<0.25: return "Minimal"
        case 0.25..<0.50: return "Mild"
        case 0.50..<0.75: return "Moderate"
        default:          return "Severe"
        }
    }
}

// MARK: - Mock history generator

/// Generates a simulated 24-hour tremor history for demo use (fully offline).
///
/// Pattern is based on a typical Parkinson's patient day:
/// - Pre-morning-dose (8–10h): tremor peak
/// - Post-dose (11–14h): significant improvement (ON period)
/// - Afternoon wearing-off (16–18h): tremor rises again
enum TremorRecordGenerator {

    /// Generates 24 mock records (one per hour), ending at the current moment.
    static func generateMockHistory() -> [TremorRecord] {
        let now = Date()

        // Baseline tremor intensity per hour (00–23h)
        let hourlyIntensities: [Double] = [
            0.30, 0.28, 0.25, 0.22,   // 00–03h night, stable
            0.20, 0.18, 0.25, 0.55,   // 04–07h early morning, medication wearing off
            0.82, 0.88, 0.85, 0.75,   // 08–11h pre-morning-dose tremor peak
            0.35, 0.28, 0.22, 0.30,   // 12–15h post-dose ON period, improved
            0.52, 0.68, 0.75, 0.72,   // 16–19h afternoon wearing-off, tremor rises
            0.60, 0.50, 0.42, 0.35,   // 20–23h post-evening-dose, gradually settling
        ]

        return hourlyIntensities.enumerated().map { hour, baseIntensity in
            let hoursAgo = Double(23 - hour)
            let timestamp = now.addingTimeInterval(-hoursAgo * 3600)
            let jitter = Double.random(in: -0.05...0.05)
            let intensity = max(0.0, min(1.0, baseIntensity + jitter))
            let state: MotorState = intensity > 0.65 ? .tremor : (intensity > 0.35 ? .off : .on)
            return TremorRecord(timestamp: timestamp, tremorIntensity: intensity, state: state)
        }
        .sorted { $0.timestamp < $1.timestamp }
    }
}
