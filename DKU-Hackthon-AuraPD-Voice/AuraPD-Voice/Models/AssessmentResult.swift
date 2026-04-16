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
///
/// `confidence` and `mlExplanation` are added by `PDMonitoringAgent` and are
/// backward-compatible: legacy records stored without these fields decode safely
/// using default values.
struct AssessmentResult: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let state: MotorState
    let sigma: Double
    let threshold: Double
    let voiceExplanation: String

    // MARK: - 🧠 Agent 新增字段

    /// Agent 置信度 ∈ [0, 1]，由 sigmoid(距决策边界距离) 计算
    var confidence: Double

    /// Agent 生成的可解释性文本（含公式数值与置信度）
    var mlExplanation: String

    // MARK: - Backward-compatible Codable

    enum CodingKeys: String, CodingKey {
        case id, timestamp, state, sigma, threshold, voiceExplanation
        case confidence, mlExplanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,       forKey: .id)
        timestamp      = try c.decode(Date.self,       forKey: .timestamp)
        state          = try c.decode(MotorState.self, forKey: .state)
        sigma          = try c.decode(Double.self,     forKey: .sigma)
        threshold      = try c.decode(Double.self,     forKey: .threshold)
        voiceExplanation = try c.decode(String.self,   forKey: .voiceExplanation)
        // 旧版本数据缺少这两个字段时，使用合理默认值
        confidence     = try c.decodeIfPresent(Double.self, forKey: .confidence)     ?? 0.75
        mlExplanation  = try c.decodeIfPresent(String.self, forKey: .mlExplanation)  ?? ""
    }

    // MARK: - Memberwise init

    init(
        state: MotorState,
        sigma: Double,
        threshold: Double,
        voiceExplanation: String,
        confidence: Double = 0.75,
        mlExplanation: String = "",
        timestamp: Date = Date()
    ) {
        self.id               = UUID()
        self.timestamp        = timestamp
        self.state            = state
        self.sigma            = sigma
        self.threshold        = threshold
        self.voiceExplanation = voiceExplanation
        self.confidence       = confidence
        self.mlExplanation    = mlExplanation
    }

    /// Formatted timestamp for display in the history list.
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}
