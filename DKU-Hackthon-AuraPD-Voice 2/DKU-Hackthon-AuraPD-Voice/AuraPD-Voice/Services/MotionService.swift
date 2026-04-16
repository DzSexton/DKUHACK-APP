import Foundation
import CoreMotion

/// Captures accelerometer and gyroscope data using `CoreMotion` at ~50 Hz.
///
/// Data is accumulated in a `SensorWindow` (default 2.5 s).  Whenever a new sample
/// arrives, the `onWindowUpdate` closure is called with the latest window snapshot.
/// No raw sensor data is persisted or transmitted; only derived features leave this layer.
final class MotionService: ObservableObject {

    // MARK: – Published state
    @Published private(set) var isCapturing = false
    /// Latest raw IMU sample, updated at ~50 Hz while capturing.
    @Published private(set) var latestSample: SensorSample?

    // MARK: – Callbacks
    /// Called on the main thread each time the sliding window is updated.
    var onWindowUpdate: ((SensorWindow) -> Void)?

    // MARK: – Private
    private let motionManager = CMMotionManager()
    private var window = SensorWindow(duration: 2.5)
    private let updateInterval: TimeInterval = 1.0 / 50.0   // 50 Hz

    // MARK: – Public API

    /// Starts IMU data collection.  Does nothing if already capturing.
    func startCapturing() {
        guard !isCapturing else { return }
        guard motionManager.isDeviceMotionAvailable else {
            print("[MotionService] Device motion is not available on this device.")
            return
        }

        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion, error == nil else { return }

            let sample = SensorSample(
                timestamp:      motion.timestamp,
                accelerometerX: motion.userAcceleration.x,
                accelerometerY: motion.userAcceleration.y,
                accelerometerZ: motion.userAcceleration.z,
                gyroscopeX:     motion.rotationRate.x,
                gyroscopeY:     motion.rotationRate.y,
                gyroscopeZ:     motion.rotationRate.z
            )

            self.window.append(sample)
            self.latestSample = sample
            self.onWindowUpdate?(self.window)
        }

        isCapturing = true
    }

    /// Stops IMU data collection and resets the sliding window.
    func stopCapturing() {
        motionManager.stopDeviceMotionUpdates()
        window = SensorWindow(duration: 2.5)
        latestSample = nil
        isCapturing = false
    }

    /// Takes a snapshot of the current window contents (thread-safe copy).
    func currentWindow() -> SensorWindow { window }
}
