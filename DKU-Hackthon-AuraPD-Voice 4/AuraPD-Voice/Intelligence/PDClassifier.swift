import Foundation

/// Rule-based Parkinson's disease motor-state classifier.
///
/// Classification rule (from the project proposal, extended to three states):
/// ```
/// if σ > 2τ         →  State = Tremor   (high variability)
/// else if σ > τ     →  State = OFF       (elevated variability)
/// else              →  State = ON        (normal variability)
/// ```
/// where σ = sqrt(variance) of the accelerometer magnitude window and τ is the
/// user-specific personalised threshold stored in `UserProfile`.
struct PDClassifier {

    // MARK: – Public API

    /// Classifies the extracted features against the user's personalised threshold.
    ///
    /// - Parameters:
    ///   - features: Statistical features extracted from the current sensor window.
    ///   - threshold: The user's personalised variance threshold τ.
    /// - Returns: An `AssessmentResult` containing the state, explanation and metadata.
    func classify(features: SensorFeatures, threshold: Double) -> AssessmentResult {
        let sigma = features.sigma
        let state: MotorState

        // Ethical AI – Bias Mitigation:
        // We use each user's personalized threshold (τ) rather than a single global cutoff,
        // reducing systematic misclassification from inter-person variability.
        if sigma > threshold * 2.0 {
            state = .tremor
        } else if sigma > threshold {
            state = .off
        } else {
            state = .on
        }

        // Ethical AI – Interpretability:
        // Every prediction is paired with a plain-language rationale.
        let explanation = state.voiceExplanation(sigma: sigma, threshold: threshold)

        return AssessmentResult(
            state: state,
            sigma: sigma,
            threshold: threshold,
            voiceExplanation: explanation
        )
    }
}
