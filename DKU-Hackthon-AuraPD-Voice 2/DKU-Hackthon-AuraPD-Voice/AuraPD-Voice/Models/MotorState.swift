import Foundation

/// Represents the Parkinson's disease motor state classification result.
enum MotorState: String, Codable, CaseIterable {
    case on      = "ON"
    case off     = "OFF"
    case tremor  = "Tremor"
    case unknown = "Unknown"

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .on:      return "ON State"
        case .off:     return "OFF State"
        case .tremor:  return "Tremor Detected"
        case .unknown: return "Assessing…"
        }
    }

    /// SF Symbol name used for visual indicator in the UI.
    var symbolName: String {
        switch self {
        case .on:      return "checkmark.circle.fill"
        case .off:     return "exclamationmark.triangle.fill"
        case .tremor:  return "waveform.path.ecg"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Plain-language explanation template used by the TTS engine.
    /// `%@` is replaced by the concrete σ and τ values at runtime.
    func voiceExplanation(sigma: Double, threshold: Double) -> String {
        let sigStr = String(format: "%.2f", sigma)
        let tauStr = String(format: "%.2f", threshold)
        switch self {
        case .on:
            return "You appear to be in an ON state. Your motion variability is \(sigStr), "
                 + "which is within your personal baseline of \(tauStr). "
                 + "Your motor control looks stable right now."
        case .off:
            return "You may be in an OFF state due to increased motion variability. "
                 + "Your current variability is \(sigStr), above your baseline of \(tauStr). "
                 + "Consider contacting your care team if this persists."
        case .tremor:
            return "Tremor activity has been detected. "
                 + "Your motion variability is \(sigStr), above your baseline of \(tauStr). "
                 + "Please rest if possible, and notify your care team if symptoms continue."
        case .unknown:
            return "The assessment is still in progress. Please remain still for a moment."
        }
    }
}
