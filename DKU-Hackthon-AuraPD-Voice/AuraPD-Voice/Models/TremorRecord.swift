import Foundation

// MARK: - TremorRecord 数据模型

/// 单次震颤评估记录，用于时间轴回放和本地队列匹配
///
/// 数据结构遵循 Prompt 要求：包含 timestamp、tremorIntensity 和 state。
/// Codable 支持本地持久化；Identifiable 支持 SwiftUI List/ForEach。
struct TremorRecord: Identifiable, Codable {
    let id: UUID
    /// 记录时间戳
    let timestamp: Date
    /// 震颤幅度，归一化区间 0.0（无震颤）~ 1.0（最强震颤）
    let tremorIntensity: Double
    /// 患者当时的运动状态（ON / OFF / Tremor / Unknown）
    let state: MotorState

    init(
        id: UUID = UUID(),
        timestamp: Date,
        tremorIntensity: Double,
        state: MotorState
    ) {
        self.id = id
        self.timestamp = timestamp
        // 保证幅度值在合法区间，防止越界
        self.tremorIntensity = max(0.0, min(1.0, tremorIntensity))
        self.state = state
    }

    // MARK: - 格式化辅助属性

    /// 短时间格式（HH:mm），用于时间轴标签
    var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: timestamp)
    }

    /// 完整时间格式，用于详情显示
    var formattedDateTime: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: timestamp)
    }

    /// 震颤幅度的人类可读描述
    var intensityLabel: String {
        switch tremorIntensity {
        case 0.0..<0.25: return "轻微"
        case 0.25..<0.50: return "轻度"
        case 0.50..<0.75: return "中度"
        default:          return "重度"
        }
    }
}

// MARK: - Mock 历史数据生成器

/// 用于 Demo 演示的本地模拟历史数据生成器（完全离线）
///
/// 生成一段模拟的 24 小时震颤历史，模式基于帕金森患者典型的一天：
/// - 早晨服药前（8-10h）：震颤峰值
/// - 服药后（11-14h）：显著改善（ON 期）
/// - 下午药效减退（16-18h）：震颤再次升高
enum TremorRecordGenerator {

    /// 生成 24 条模拟历史记录（每小时一条），以当前时刻为终点向前推 24 小时
    static func generateMockHistory() -> [TremorRecord] {
        let now = Date()

        // 每小时对应的基准震颤幅度（0 ~ 23 时）
        let hourlyIntensities: [Double] = [
            0.30, 0.28, 0.25, 0.22,   // 00-03h 深夜，平稳
            0.20, 0.18, 0.25, 0.55,   // 04-07h 清晨，药效开始消退
            0.82, 0.88, 0.85, 0.75,   // 08-11h 早晨服药前，震颤峰值
            0.35, 0.28, 0.22, 0.30,   // 12-15h 服药后 ON 期，显著改善
            0.52, 0.68, 0.75, 0.72,   // 16-19h 药效减退，震颤再升
            0.60, 0.50, 0.42, 0.35,   // 20-23h 晚间服药后，逐渐平稳
        ]

        return hourlyIntensities.enumerated().map { hour, baseIntensity in
            // 以"当前时间 - (23 - hour) 小时"作为时间戳
            let hoursAgo = Double(23 - hour)
            let timestamp = now.addingTimeInterval(-hoursAgo * 3600)
            // 加入 ±5% 随机抖动，使数据更贴近真实
            let jitter = Double.random(in: -0.05...0.05)
            let intensity = max(0.0, min(1.0, baseIntensity + jitter))
            // 按幅度阈值自动判断运动状态
            let state: MotorState = intensity > 0.65 ? .tremor : (intensity > 0.35 ? .off : .on)
            return TremorRecord(timestamp: timestamp, tremorIntensity: intensity, state: state)
        }
        // 按时间正序排列（最旧 → 最新），与时间轴方向一致
        .sorted { $0.timestamp < $1.timestamp }
    }
}
