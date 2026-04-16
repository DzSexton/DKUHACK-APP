import Foundation
import CoreMotion

/// A single timestamped IMU sample containing accelerometer and gyroscope readings.
struct SensorSample {
    let timestamp: TimeInterval
    let accelerometerX: Double
    let accelerometerY: Double
    let accelerometerZ: Double
    let gyroscopeX: Double
    let gyroscopeY: Double
    let gyroscopeZ: Double

    /// Computes the combined accelerometer magnitude (3-axis Euclidean norm).
    var accelerometerMagnitude: Double {
        sqrt(accelerometerX * accelerometerX
           + accelerometerY * accelerometerY
           + accelerometerZ * accelerometerZ)
    }

    /// Computes the combined gyroscope magnitude (3-axis Euclidean norm).
    var gyroscopeMagnitude: Double {
        sqrt(gyroscopeX * gyroscopeX
           + gyroscopeY * gyroscopeY
           + gyroscopeZ * gyroscopeZ)
    }
}

/// A fixed-length sliding window of `SensorSample` values.
struct SensorWindow {
    /// Duration of the window in seconds (default: 2.5 s).
    let duration: TimeInterval
    private(set) var samples: [SensorSample] = []

    init(duration: TimeInterval = 2.5) {
        self.duration = duration
    }

    /// Appends a new sample and drops any samples that fall outside the window.
    mutating func append(_ sample: SensorSample) {
        samples.append(sample)
        let cutoff = sample.timestamp - duration
        samples.removeAll { $0.timestamp < cutoff }
    }

    /// Returns `true` when the window contains at least one second of data.
    var isReady: Bool {
        guard let first = samples.first, let last = samples.last else { return false }
        return (last.timestamp - first.timestamp) >= 1.0
    }
}
