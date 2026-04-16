import Foundation

/// The extracted statistical features from a sensor window.
struct SensorFeatures {
    let mean: Double
    let variance: Double
    let signalEnergy: Double

    /// The σ value used for classification (standard deviation = sqrt(variance)).
    var sigma: Double { sqrt(variance) }
}

/// A complete motor-state assessment result persisted to the local log.
struct AssessmentResult: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let state: MotorState
    let sigma: Double
    let threshold: Double
    let voiceExplanation: String

    init(
        state: MotorState,
        sigma: Double,
        threshold: Double,
        voiceExplanation: String,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.state = state
        self.sigma = sigma
        self.threshold = threshold
        self.voiceExplanation = voiceExplanation
    }

    /// Formatted timestamp for display in the history list.
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}
