import Foundation

// MARK: - PatientGender

enum PatientGender: String, Codable {
    case male   = "先生"
    case female = "女士"
}

// MARK: - PatientProfile（含 GNN 节点嵌入）

struct PatientProfile: Identifiable, Hashable {
    let id: UUID
    let anonymizedName: String
    let gender: PatientGender
    let age: Int
    let onsetPeriod: String
    let symptomsDescription: String
    let treatmentLocation: String
    let treatmentMethod: String
    let treatmentOutcome: String

    /// GNN 图节点嵌入向量（供 GNNPatientMatcher 计算节点间距离）
    let embedding: PatientEmbedding

    /// GNN 计算得出的多维匹配分数（由 PatientProfileDatabase.mockProfiles 批量计算填充）
    var gnnScores: GNNMatchScores?

    /// 治疗启发价值（TIV）：GNN 多维融合分数
    var treatmentInspirationValue: Double { gnnScores?.treatmentInspirationValue ?? 0.5 }
    /// 向后兼容
    var matchPercentage: Int { Int(treatmentInspirationValue * 100) }

    static func == (lhs: PatientProfile, rhs: PatientProfile) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - PatientProfileDatabase

enum PatientProfileDatabase {

    // 原始档案（嵌入向量已定义，GNN 分数待计算）
    private static let rawProfiles: [PatientProfile] = [

        // ── 1. 张先生，62，震颤主导，与参考高度相似 ─────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "张",
            gender: .male,
            age: 62,
            onsetPeriod: "约 4 年前（57 岁发病）",
            symptomsDescription: "以静止性震颤为主，双手明显，伴轻度肌肉僵直与运动迟缓，姿势尚稳定。",
            treatmentLocation: "北京协和医院",
            treatmentMethod: "美多巴 250mg 每日三次 + 普拉克索 0.5mg 辅助",
            treatmentOutcome: "震颤控制良好，ON 期占全天约 70%，偶有轻度剂末衰退。",
            embedding: PatientEmbedding(
                symptomVector:     [0.78, 0.44, 0.62, 0.28],
                treatmentVector:   [0.82, 0.26, 0.50],
                progressionVector: [0.713, 0.200]
            )
        ),

        // ── 2. 李女士，58，僵直主导型，症状模式不同 ─────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "李",
            gender: .female,
            age: 58,
            onsetPeriod: "约 3 年前（55 岁发病）",
            symptomsDescription: "以肌肉僵直为主，上肢铅管样僵硬，静止性震颤不明显，步态略有拖曳。",
            treatmentLocation: "上海交通大学医学院附属瑞金医院",
            treatmentMethod: "信尼麦 100/25mg 每日两次 + 金刚烷胺 100mg",
            treatmentOutcome: "僵直症状改善约 50%，运动功能基本维持日常生活，无明显异动症。",
            embedding: PatientEmbedding(
                symptomVector:     [0.22, 0.86, 0.55, 0.42],
                treatmentVector:   [0.60, 0.18, 0.45],
                progressionVector: [0.688, 0.150]
            )
        ),

        // ── 3. 王先生，71，晚期混合，药效复杂 ───────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "王",
            gender: .male,
            age: 71,
            onsetPeriod: "约 11 年前（60 岁发病）",
            symptomsDescription: "四肢均有震颤，肌肉僵直明显，步态冻结，姿势反射受损，合并轻度认知波动。",
            treatmentLocation: "四川大学华西医院",
            treatmentMethod: "DBS 术后 + 美多巴维持剂量 + 恩他卡朋 200mg",
            treatmentOutcome: "DBS 术后运动功能改善约 40%，但仍有冻结步态，需步行辅助器。",
            embedding: PatientEmbedding(
                symptomVector:     [0.90, 0.86, 0.88, 0.78],
                treatmentVector:   [0.28, 0.84, 0.90],
                progressionVector: [0.750, 0.550]
            )
        ),

        // ── 4. 陈女士，55，震颤主导且应答极佳（高启发价值）──────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "陈",
            gender: .female,
            age: 55,
            onsetPeriod: "约 4 年前（51 岁发病）",
            symptomsDescription: "以右手静止性震颤起病，逐渐双侧累及，僵直轻微，ADL 基本自理。",
            treatmentLocation: "复旦大学附属华山医院",
            treatmentMethod: "美多巴 125mg + 普拉克索 0.75mg，精细化三次给药时间调优",
            treatmentOutcome: "左旋多巴应答优秀，ON 期占 85%，震颤基本消失，无异动并发症。",
            embedding: PatientEmbedding(
                symptomVector:     [0.84, 0.32, 0.46, 0.20],
                treatmentVector:   [0.94, 0.14, 0.30],
                progressionVector: [0.638, 0.200]
            )
        ),

        // ── 5. 刘先生，67，姿势不稳为主，难治性 ─────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "刘",
            gender: .male,
            age: 67,
            onsetPeriod: "约 8 年前（59 岁发病）",
            symptomsDescription: "以姿势不稳和步态障碍为核心，反复跌倒，震颤相对轻，合并吞咽困难。",
            treatmentLocation: "华中科技大学同济医学院附属同济医院",
            treatmentMethod: "美多巴 + 雷沙吉兰 1mg + 物理康复治疗",
            treatmentOutcome: "步态改善有限，跌倒频率减少约 30%，需步行辅助器，疗效低于预期。",
            embedding: PatientEmbedding(
                symptomVector:     [0.30, 0.65, 0.74, 0.94],
                treatmentVector:   [0.35, 0.55, 0.80],
                progressionVector: [0.738, 0.400]
            )
        ),

        // ── 6. 赵女士，63，运动认知混合型 ───────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "赵",
            gender: .female,
            age: 63,
            onsetPeriod: "约 6 年前（57 岁发病）",
            symptomsDescription: "震颤与僵直并重，伴认知执行功能轻度下降，情绪波动与睡眠障碍突出。",
            treatmentLocation: "中山大学附属第一医院",
            treatmentMethod: "美多巴 + 卡巴拉汀（认知改善）+ 褪黑素（睡眠）",
            treatmentOutcome: "运动症状控制中等，认知症状稳定未进展，睡眠质量显著提升。",
            embedding: PatientEmbedding(
                symptomVector:     [0.65, 0.55, 0.72, 0.48],
                treatmentVector:   [0.72, 0.40, 0.56],
                progressionVector: [0.713, 0.300]
            )
        ),

        // ── 7. 孙先生，69，运动并发症/异动症 ────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "孙",
            gender: .male,
            age: 69,
            onsetPeriod: "约 9 年前（60 岁发病）",
            symptomsDescription: "症状全面，以震颤和运动迟缓为主，长期服药后出现明显异动症与剂末效应。",
            treatmentLocation: "浙江大学医学院附属第二医院",
            treatmentMethod: "美多巴 + 恩他卡朋 + 金刚烷胺（抗异动），评估 DBS 中",
            treatmentOutcome: "异动症通过多药联用有所控制，但 ON/OFF 波动频繁，DBS 评估通过。",
            embedding: PatientEmbedding(
                symptomVector:     [0.76, 0.60, 0.70, 0.52],
                treatmentVector:   [0.68, 0.74, 0.80],
                progressionVector: [0.750, 0.450]
            )
        ),

        // ── 8. 周女士，61，早发型优秀应答（高启发价值）──────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "周",
            gender: .female,
            age: 61,
            onsetPeriod: "约 6 年前（55 岁发病）",
            symptomsDescription: "早发型 PD，震颤为首发，双侧逐渐累及，日常功能维持良好，情绪积极。",
            treatmentLocation: "中南大学湘雅医院",
            treatmentMethod: "低剂量美多巴 125mg 每日三次（精准给药时间调优），配合规律有氧运动",
            treatmentOutcome: "药效峰期控制极佳（ON 期占全天 88%），无异动，保持职业活动。",
            embedding: PatientEmbedding(
                symptomVector:     [0.68, 0.38, 0.55, 0.24],
                treatmentVector:   [0.95, 0.16, 0.28],
                progressionVector: [0.688, 0.300]
            )
        ),

        // ── 9. 吴先生，73，晚期复杂，多系统受累 ─────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "吴",
            gender: .male,
            age: 73,
            onsetPeriod: "约 14 年前（59 岁发病）",
            symptomsDescription: "PD 晚期，全身僵直、震颤重度，合并直立性低血压、尿频、轻度痴呆。",
            treatmentLocation: "首都医科大学附属北京天坛医院",
            treatmentMethod: "DBS 术后 + 肠道左旋多巴凝胶泵 + 多系统对症治疗",
            treatmentOutcome: "DBS 仍有效但效果逐年减弱，护理依赖程度高，生活质量评分低。",
            embedding: PatientEmbedding(
                symptomVector:     [0.94, 0.90, 0.92, 0.86],
                treatmentVector:   [0.22, 0.90, 0.95],
                progressionVector: [0.738, 0.700]
            )
        ),

        // ── 10. 郑女士，60，僵直疲劳为主 ────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "郑",
            gender: .female,
            age: 60,
            onsetPeriod: "约 5 年前（55 岁发病）",
            symptomsDescription: "僵直和疲劳为主要表现，震颤轻微，日常动作明显减慢，情绪低落突出。",
            treatmentLocation: "北京大学第三医院",
            treatmentMethod: "卡左双多巴控释片 + 艾司西酞普兰（抑郁）+ 心理康复",
            treatmentOutcome: "运动功能改善中等，抑郁症状显著好转，整体生活质量评分提升。",
            embedding: PatientEmbedding(
                symptomVector:     [0.35, 0.88, 0.70, 0.60],
                treatmentVector:   [0.62, 0.32, 0.62],
                progressionVector: [0.688, 0.250]
            )
        ),
    ]

    /// 返回经 GNN 距离引擎计算 TIV 后、按治疗启发价值降序排列的档案列表。
    /// GNN 节点距离计算在首次访问时批量执行（lazy static），体现图节点相似度逻辑。
    static let mockProfiles: [PatientProfile] = {
        let matcher = GNNPatientMatcher.shared
        var result = rawProfiles
        for i in result.indices {
            result[i].gnnScores = matcher.calculateGraphNodeDistance(
                referenceNode: matcher.referenceEmbedding,
                candidateNode: result[i].embedding
            )
        }
        return result.sorted { $0.treatmentInspirationValue > $1.treatmentInspirationValue }
    }()
}
