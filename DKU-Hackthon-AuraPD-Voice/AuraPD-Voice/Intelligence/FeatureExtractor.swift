import Foundation

/// Extracts statistical features from a `SensorWindow` for downstream classification.
///
/// Features computed:
/// - **Mean** of the accelerometer magnitude signal
/// - **Variance (σ²)** – population variance of the accelerometer magnitude signal
/// - **Signal Energy** – sum of squared magnitudes normalised by sample count
struct FeatureExtractor {

    // MARK: – Public API

    /// Extracts features from the given sensor window.
    /// - Returns: `nil` when the window contains fewer than 2 samples.
    func extract(from window: SensorWindow) -> SensorFeatures? {
        let samples = window.samples
        guard samples.count >= 2 else { return nil }

        let magnitudes = samples.map { $0.accelerometerMagnitude }
        let n = Double(magnitudes.count)

        let mean = magnitudes.reduce(0, +) / n
        // Ethical AI – Interpretability:
        // We deliberately use transparent, auditable statistics instead of opaque features,
        // so users and clinicians can understand why the model responded as it did.
        let variance = magnitudes.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / n
        let signalEnergy = magnitudes.map { $0 * $0 }.reduce(0, +) / n

        return SensorFeatures(mean: mean, variance: variance, signalEnergy: signalEnergy)
    }
}
