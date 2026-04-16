import Foundation

// MARK: - 队列匹配结果

/// 本地"伪"相似病例匹配结果，供 InsightView 直接展示
struct CohortMatchResult {
    /// 与相似患者群体的匹配百分比（0 ~ 100）
    let matchPercentage: Int
    /// 完整的匹配描述文案（包含队列特征说明）
    let matchDescription: String
    /// 基于匹配结果给出的用药/生活改善建议
    let recommendation: String
    /// 规则引擎分析所用的近期数据摘要（展示给医生的统计概况）
    let dataSummary: String
}

// MARK: - ProfileManager

/// 完全离线的本地患者档案管理器与"伪"相似病例匹配引擎
///
/// **核心设计原则**：
/// - 100% 离线：所有匹配逻辑基于硬编码的本地脱敏队列数据，不含任何网络请求
/// - 简单规则引擎：通过计算近期记录的平均震颤幅度，映射到 4 个梯度队列档案
/// - 隐私保护：ProfileManager 不持久化任何用户数据，仅在内存中进行计算
final class ProfileManager {

    static let shared = ProfileManager()
    private init() {}

    // MARK: - 本地脱敏队列数据库（硬编码 Mock）

    /// 代表一个本地脱敏患者队列的特征档案
    private struct CohortProfile {
        /// 此队列适用的平均震颤幅度区间
        let intensityRange: ClosedRange<Double>
        /// 匹配到此队列时显示的百分比
        let matchPercentage: Int
        /// 队列患者的临床特征描述（已脱敏）
        let cohortDescription: String
        /// 针对此类患者的改善建议
        let recommendation: String
    }

    /// 四档梯度队列数据库：从轻微到重度，覆盖全幅度范围
    private let cohortDatabase: [CohortProfile] = [
        CohortProfile(
            intensityRange: 0.00...0.25,
            matchPercentage: 91,
            cohortDescription: "轻度稳定型震颤，左旋多巴响应良好，日常活动基本不受影响",
            recommendation: "当前状态与此类患者高度匹配，建议维持现有用药方案，并保持每月复诊监测。"
        ),
        CohortProfile(
            intensityRange: 0.25...0.50,
            matchPercentage: 82,
            cohortDescription: "中度波动型震颤，具有明显的 ON/OFF 周期，震颤峰值多出现于晨间服药前",
            recommendation: "数据显示，此类情况调整用药时间（早晨提前 30 分钟服药）后可能有显著改善。"
        ),
        CohortProfile(
            intensityRange: 0.50...0.75,
            matchPercentage: 74,
            cohortDescription: "中重度震颤，服药后峰值效应明显，OFF 期持续约 2～3 小时",
            recommendation: "建议与神经科医生讨论是否将单次剂量拆分为多次小剂量给药，以平滑血药浓度曲线。"
        ),
        CohortProfile(
            intensityRange: 0.75...1.00,
            matchPercentage: 68,
            cohortDescription: "重度震颤，药效消退期（OFF 期）症状显著，严重影响日常生活质量",
            recommendation: "强烈建议在下次复诊时携带此份震颤记录，与医生讨论是否引入 COMT 抑制剂或进行 DBS 术前评估。"
        )
    ]

    // MARK: - 规则引擎

    /// 基于最近的震颤记录执行本地规则匹配，返回洞察结果
    ///
    /// 算法步骤：
    /// 1. 取最近 12 条记录（不足则全取）
    /// 2. 计算平均震颤幅度
    /// 3. 在队列数据库中查找幅度区间匹配的档案
    /// 4. 组装结果文案
    ///
    /// - Parameter records: 近期震颤历史记录（按时间排序）
    /// - Returns: 本地队列匹配结果
    func match(against records: [TremorRecord]) -> CohortMatchResult {
        guard !records.isEmpty else {
            return CohortMatchResult(
                matchPercentage: 0,
                matchDescription: "暂无足够数据进行匹配",
                recommendation: "请先完成至少一次震颤评估以启用智能洞察功能。",
                dataSummary: "无数据"
            )
        }

        // 取最近 12 条记录进行统计分析
        let recent = Array(records.suffix(12))
        let avgIntensity = recent.map(\.tremorIntensity).reduce(0, +) / Double(recent.count)
        let tremorCount  = recent.filter { $0.state == .tremor }.count
        let offCount     = recent.filter { $0.state == .off }.count
        let onCount      = recent.filter { $0.state == .on }.count

        // 按平均幅度查找最匹配的队列档案（无匹配则取最后一档）
        let matched = cohortDatabase.first { $0.intensityRange.contains(avgIntensity) }
                   ?? cohortDatabase.last!

        // 数据摘要：显示给医生的统计概况
        let dataSummary = String(format:
            "近 %d 次 · 平均幅度 %.0f%% · 震颤 %d 次 · OFF %d 次 · ON %d 次",
            recent.count, avgIntensity * 100, tremorCount, offCount, onCount
        )

        // 完整匹配描述文案
        let matchDescription = String(format:
            "根据您的近期震颤数据，您与本地脱敏数据库中 %d%% 的类似患者匹配。\n患者特征：%@",
            matched.matchPercentage, matched.cohortDescription
        )

        return CohortMatchResult(
            matchPercentage: matched.matchPercentage,
            matchDescription: matchDescription,
            recommendation: matched.recommendation,
            dataSummary: dataSummary
        )
    }
}
