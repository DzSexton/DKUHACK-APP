import Foundation

// MARK: - 性别枚举

enum PatientGender: String {
    case male   = "男"
    case female = "女"
}

// MARK: - PatientProfile 数据模型

/// 本地脱敏患者档案，用于"小红书式"瀑布流网格展示
///
/// - **摘要字段**（卡片缩略显示）：匿名姓名、性别、年龄、匹配度
/// - **详情字段**（点击跳转详情页）：发病情况、治疗手段、治疗结果等
struct PatientProfile: Identifiable, Hashable {
    let id: UUID

    // MARK: 摘要字段
    /// 匿名化姓名，仅使用"X先生"或"X女士"格式
    let anonymizedName: String
    let gender: PatientGender
    let age: Int
    /// 与当前用户的匹配百分比（0 ~ 100）
    let matchPercentage: Int

    // MARK: 详情字段
    /// 主要发病时间段
    let onsetPeriod: String
    /// 发病情况描述（震颤幅度、时长、受影响部位等）
    let symptomsDescription: String
    /// 就诊 / 治疗地点（现实存在的三甲医院）
    let treatmentLocation: String
    /// 治疗手段
    let treatmentMethod: String
    /// 治疗结果与改善情况
    let treatmentOutcome: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PatientProfile, rhs: PatientProfile) -> Bool { lhs.id == rhs.id }
}

// MARK: - Mock 数据库

/// 本地脱敏患者档案数据库（完全 Mock，不含任何真实个人信息）
enum PatientProfileDatabase {

    static let mockProfiles: [PatientProfile] = [

        // ── 1 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "李女士",
            gender: .female,
            age: 68,
            matchPercentage: 91,
            onsetPeriod: "清晨、餐前",
            symptomsDescription: "双侧手部静止性震颤，幅度约 6~8 mm，持续 2~3 小时；OFF 期出现于早晨服药前，伴轻度僵直感。",
            treatmentLocation: "北京协和医院神经科",
            treatmentMethod: "将早晨左旋多巴剂量提前 30 分钟服用，并将单次剂量从 250 mg 拆分为 2 × 125 mg 分次给药。",
            treatmentOutcome: "OFF 期平均时长由 2.8 小时缩短至 1.9 小时（缩短约 32%），日常书写和用餐活动明显改善。"
        ),

        // ── 2 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "赵先生",
            gender: .male,
            age: 70,
            matchPercentage: 88,
            onsetPeriod: "清晨及饭前",
            symptomsDescription: "双手震颤伴书写困难，清晨 OFF 期尤为明显；服药后约 45 分钟起效，ON 期持续约 2 小时。",
            treatmentLocation: "上海交通大学医学院附属瑞金医院",
            treatmentMethod: "引入分次给药方案（每日 5 次，每次小剂量），结合夜间 COMT 抑制剂恩他卡朋辅助。",
            treatmentOutcome: "ON 期延长约 1.5 小时/天，书写功能评分（MDS-UPDRS Part II）提升 18 分。"
        ),

        // ── 3 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "王先生",
            gender: .male,
            age: 72,
            matchPercentage: 85,
            onsetPeriod: "下午 15:00—18:00",
            symptomsDescription: "右侧为主的静止性震颤，幅度 4~6 mm，下午药效减退时加剧；偶发异动症（剂峰期）。",
            treatmentLocation: "复旦大学附属华山医院神经内科",
            treatmentMethod: "加用恩他卡朋 200 mg 随每次左旋多巴同服，同时将下午剂量提前 20 分钟。",
            treatmentOutcome: "下午 OFF 期发作频率减少 60%，异动症未加重，患者主观生活质量评分提升显著。"
        ),

        // ── 4 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "吴女士",
            gender: .female,
            age: 58,
            matchPercentage: 83,
            onsetPeriod: "运动后及傍晚",
            symptomsDescription: "以姿势性震颤为主，运动后加剧；同时存在轻度面部表情减少（面具脸）和步态缓慢。",
            treatmentLocation: "四川大学华西医院神经内科",
            treatmentMethod: "起始采用多巴胺受体激动剂普拉克索单药治疗，缓慢滴定至有效剂量，延迟引入左旋多巴。",
            treatmentOutcome: "震颤幅度减少约 45%，步速评估提升，6 个月内未出现异动症并发症。"
        ),

        // ── 5 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "孙先生",
            gender: .male,
            age: 66,
            matchPercentage: 80,
            onsetPeriod: "全天，以上午为重",
            symptomsDescription: "左侧手部静止性震颤起病，后逐渐累及左下肢；伴有嗅觉减退及便秘（非运动症状）。",
            treatmentLocation: "华中科技大学同济医学院附属同济医院神经内科",
            treatmentMethod: "左旋多巴/卡比多巴联合方案，同时加用莫沙必利改善胃肠道症状，加速药物吸收。",
            treatmentOutcome: "运动症状控制良好，UPDRS Part III 评分改善 28 分，非运动症状亦有所缓解。"
        ),

        // ── 6 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "刘女士",
            gender: .female,
            age: 61,
            matchPercentage: 79,
            onsetPeriod: "夜间及清晨",
            symptomsDescription: "夜间静止性震颤影响入睡，伴 REM 睡眠行为障碍；清晨起床时下肢僵直感明显，步态不稳。",
            treatmentLocation: "中山大学附属第一医院神经科",
            treatmentMethod: "睡前加用罗匹尼罗缓释片 2 mg，同时配合睡眠卫生指导与规律有氧运动计划。",
            treatmentOutcome: "夜间觉醒次数由平均 3.2 次降至 1.1 次，匹兹堡睡眠质量指数 (PSQI) 改善 6 分，晨间步态改善。"
        ),

        // ── 7 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "林女士",
            gender: .female,
            age: 73,
            matchPercentage: 76,
            onsetPeriod: "餐后 1~2 小时",
            symptomsDescription: "餐后血糖波动期震颤加剧，以右手为主；合并轻度认知障碍（MCI），对药物调整较敏感。",
            treatmentLocation: "浙江大学医学院附属第二医院神经内科",
            treatmentMethod: "调整饮食结构（低蛋白早餐，减少与左旋多巴吸收的竞争），联合认知训练与物理治疗。",
            treatmentOutcome: "餐后震颤发作频率减少约 40%，MoCA 认知评估维持稳定，跌倒风险等级由中降至低。"
        ),

        // ── 8 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "郑先生",
            gender: .male,
            age: 69,
            matchPercentage: 73,
            onsetPeriod: "下午至傍晚",
            symptomsDescription: "双侧上肢震颤伴颈部肌张力增高，下午症状明显重于上午；合并抑郁症状影响服药依从性。",
            treatmentLocation: "中南大学湘雅医院神经内科",
            treatmentMethod: "神经科与精神科联合门诊，在优化左旋多巴方案的同时加用舍曲林改善抑郁，心理辅导同步介入。",
            treatmentOutcome: "抑郁量表 (PHQ-9) 评分从 14 降至 6，服药依从性显著提升，运动症状控制随之改善约 35%。"
        ),

        // ── 9 ──────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "陈先生",
            gender: .male,
            age: 78,
            matchPercentage: 68,
            onsetPeriod: "全天波动，以下午为重",
            symptomsDescription: "ON/OFF 波动剧烈，OFF 期四肢僵直、语速减慢；左旋多巴疗效显著减退，剂末效应明显。",
            treatmentLocation: "首都医科大学附属北京天坛医院功能神经外科",
            treatmentMethod: "经多学科评估后行双侧丘脑底核 (STN) 脑深部电刺激 (DBS) 手术，术后调参 3 个月。",
            treatmentOutcome: "UPDRS Part III 运动评分提升 42%，左旋多巴等效日剂量减少约 35%，生活自理能力显著恢复。"
        ),

        // ── 10 ─────────────────────────────────────────────────
        PatientProfile(
            id: UUID(),
            anonymizedName: "黄先生",
            gender: .male,
            age: 64,
            matchPercentage: 65,
            onsetPeriod: "清晨空腹时",
            symptomsDescription: "以头部震颤（点头样）为主要表现，伴轻度双手震颤；空腹时症状最重，进食后短暂缓解。",
            treatmentLocation: "北京大学第三医院神经内科",
            treatmentMethod: "调整服药时机至餐前 40 分钟（空腹促进吸收），并联合金刚烷胺减轻震颤，增加康复训练频次。",
            treatmentOutcome: "头部震颤幅度减少约 50%，空腹期症状显著改善，患者社交活动参与度明显提高。"
        ),
    ]
}
