import Foundation

/// Stores user-specific calibration data, preferences, and personal profile information.
struct UserProfile: Codable {

    // MARK: - Calibration

    var id: UUID
    var varianceThreshold: Double
    var isCalibrated: Bool
    var calibrationReadings: [Double]
    var lastCalibrationDate: Date?

    // MARK: - Personal Profile

    var displayName: String
    var biologicalSex: String
    var birthYear: Int?
    var diagnosisYear: Int?
    /// Dynamic field — auto-updated by the assessment pipeline after each check.
    var conditionSummary: String

    // MARK: - CodingKeys (backward-compatible)

    enum CodingKeys: String, CodingKey {
        case id, varianceThreshold, isCalibrated, calibrationReadings, lastCalibrationDate
        case displayName, biologicalSex, birthYear, diagnosisYear, conditionSummary
    }

    // MARK: - Initialisers

    init(
        id: UUID = UUID(),
        varianceThreshold: Double = 0.60,
        isCalibrated: Bool = false,
        calibrationReadings: [Double] = [],
        lastCalibrationDate: Date? = nil,
        displayName: String = "My Profile",
        biologicalSex: String = "Not set",
        birthYear: Int? = nil,
        diagnosisYear: Int? = nil,
        conditionSummary: String = "No assessments yet"
    ) {
        self.id = id
        self.varianceThreshold = varianceThreshold
        self.isCalibrated = isCalibrated
        self.calibrationReadings = calibrationReadings
        self.lastCalibrationDate = lastCalibrationDate
        self.displayName = displayName
        self.biologicalSex = biologicalSex
        self.birthYear = birthYear
        self.diagnosisYear = diagnosisYear
        self.conditionSummary = conditionSummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(UUID.self,    forKey: .id)
        varianceThreshold   = try c.decode(Double.self,  forKey: .varianceThreshold)
        isCalibrated        = try c.decode(Bool.self,    forKey: .isCalibrated)
        calibrationReadings = try c.decode([Double].self, forKey: .calibrationReadings)
        lastCalibrationDate = try c.decodeIfPresent(Date.self, forKey: .lastCalibrationDate)
        // New fields — use defaults when loading old stored data
        displayName         = try c.decodeIfPresent(String.self, forKey: .displayName)  ?? "My Profile"
        biologicalSex       = try c.decodeIfPresent(String.self, forKey: .biologicalSex) ?? "Not set"
        birthYear           = try c.decodeIfPresent(Int.self,    forKey: .birthYear)
        diagnosisYear       = try c.decodeIfPresent(Int.self,    forKey: .diagnosisYear)
        conditionSummary    = try c.decodeIfPresent(String.self, forKey: .conditionSummary) ?? "No assessments yet"
    }

    // MARK: - Computed display helpers

    /// True once the user has entered enough data to run a meaningful match calculation.
    var isReadyForMatching: Bool {
        birthYear != nil || diagnosisYear != nil || displayName != "My Profile"
    }

    var ageDisplay: String {
        guard let year = birthYear else { return "Not set" }
        let age = Calendar.current.component(.year, from: Date()) - year
        return "\(age) yrs"
    }

    var diagnosisDurationDisplay: String {
        guard let year = diagnosisYear else { return "Not set" }
        let years = Calendar.current.component(.year, from: Date()) - year
        return years <= 0 ? "< 1 yr" : "~\(years) yrs"
    }

    // MARK: - Calibration helpers

    /// Recomputes τ from the stored calibration readings.
    mutating func recalibrate(using sigmaReadings: [Double]) {
        guard !sigmaReadings.isEmpty else { return }
        calibrationReadings.append(contentsOf: sigmaReadings)

        let n       = Double(calibrationReadings.count)
        let mean    = calibrationReadings.reduce(0, +) / n
        let variance = calibrationReadings.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / n
        let stdDev  = sqrt(variance)

        // Ethical AI – Bias Mitigation:
        // Personal calibration adapts τ to the individual user to reduce
        // population-level bias from one-size-fits-all thresholds.
        varianceThreshold   = mean + stdDev
        isCalibrated        = true
        lastCalibrationDate = Date()
    }
}
