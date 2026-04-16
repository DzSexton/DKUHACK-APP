import Foundation

/// Stores user-specific calibration data and preferences.
struct UserProfile: Codable {
    /// Unique identifier for the user profile.
    var id: UUID

    /// The personalised variance threshold (τ). Defaults to 0.60 until calibrated.
    var varianceThreshold: Double

    /// Whether the user has completed an initial calibration session.
    var isCalibrated: Bool

    /// Historical σ readings collected during calibration.
    var calibrationReadings: [Double]

    /// Date of the most recent calibration.
    var lastCalibrationDate: Date?

    // MARK: – Initialisation

    init(
        id: UUID = UUID(),
        varianceThreshold: Double = 0.60,
        isCalibrated: Bool = false,
        calibrationReadings: [Double] = [],
        lastCalibrationDate: Date? = nil
    ) {
        self.id = id
        self.varianceThreshold = varianceThreshold
        self.isCalibrated = isCalibrated
        self.calibrationReadings = calibrationReadings
        self.lastCalibrationDate = lastCalibrationDate
    }

    // MARK: – Calibration helpers

    /// Recomputes τ from the stored calibration readings.
    /// τ is set to (mean σ + 1 × standard deviation) so that normal ON-state
    /// variability sits comfortably below the decision boundary.
    mutating func recalibrate(using sigmaReadings: [Double]) {
        guard !sigmaReadings.isEmpty else { return }
        calibrationReadings.append(contentsOf: sigmaReadings)

        let n = Double(calibrationReadings.count)
        let mean = calibrationReadings.reduce(0, +) / n
        let variance = calibrationReadings.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / n
        let stdDev = sqrt(variance)

        // Ethical AI – Bias Mitigation:
        // Personal calibration adapts τ to the individual user to reduce
        // population-level bias from one-size-fits-all thresholds.
        varianceThreshold = mean + stdDev
        isCalibrated = true
        lastCalibrationDate = Date()
    }
}
