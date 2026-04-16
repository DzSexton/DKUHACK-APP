import Foundation

// MARK: - PatientEmbedding（图节点特征向量）

/// 患者在 GNN 特征空间中的节点嵌入表示。
/// 真实系统中，这些向量由图卷积层聚合邻居信息后输出；
/// 此处使用原始临床特征向量代替，保留相同的距离度量逻辑。
struct PatientEmbedding {
    /// 症状特征向量（dim=4）：[震颤严重度, 肌肉僵直, 运动迟缓, 姿势不稳]  ∈ [0,1]
    let symptomVector: [Double]
    /// 治疗反应向量（dim=3）：[左旋多巴敏感性, 异动并发症风险, 剂末衰退频率]  ∈ [0,1]
    let treatmentVector: [Double]
    /// 病程向量（dim=2）：[发病年龄 ÷ 80 (归一化), 病程年数 ÷ 20 (归一化)]  ∈ [0,1]
    let progressionVector: [Double]
}

// MARK: - GNNMatchScores（节点距离计算输出）

struct GNNMatchScores {
    /// 维度1：症状空间余弦相似度 ∈ [0,1]
    let symptomSimilarity: Double
    /// 维度2：治疗反应空间高斯核相似度 ∈ [0,1]
    let treatmentResponseSimilarity: Double
    /// 维度3：病程轨迹加权欧氏相似度 ∈ [0,1]
    let progressionSimilarity: Double
    /// 治疗启发价值 TIV = 0.30·S + 0.45·T + 0.25·P  ∈ [0,1]
    let treatmentInspirationValue: Double
    /// 自然语言匹配原因（由各维度分数动态生成）
    let matchReason: String
}

// MARK: - 🕸️ GNNPatientMatcher

/// 模拟图神经网络中的节点嵌入距离计算引擎。
///
/// ## 图网络概念映射
/// - **图节点（Node）**：每位患者 = 特征向量空间中的一个节点
/// - **边权重（Edge Weight）**：节点间的 GNN 距离 = 治疗启发价值
/// - **社区（Community）**：高 TIV 聚类 = 具有相似治疗响应模式的患者群体
///
/// ## 三维度距离公式
/// ```
/// // 维度1：余弦相似度（症状空间，衡量症状模式方向一致性）
/// cos_sim(A,B) = (A·B) / (‖A‖ · ‖B‖)
///
/// // 维度2：高斯 RBF 核函数（治疗反应空间，σ=0.30）
/// k_rbf(A,B)   = exp(−‖A−B‖² / 2σ²)
///
/// // 维度3：加权欧氏距离相似度（病程轨迹空间）
/// d_w(A,B)     = √(Σ wᵢ·(aᵢ−bᵢ)²),   w=[1.5, 1.0]
/// eucl_sim     = exp(−d_w)
///
/// // 治疗启发价值（多空间加权融合）
/// TIV = 0.30·cos_sim + 0.45·k_rbf + 0.25·eucl_sim
/// ```
final class GNNPatientMatcher {

    static let shared = GNNPatientMatcher()

    // MARK: - 参考节点（当前用户的嵌入向量）

    /// 参考患者嵌入：代表典型的中期震颤主导型 PD 表现（约 58 岁发病，4.5 年病程）。
    /// 在真实系统中，此向量由 PDMonitoringAgent 从用户历史评估数据动态生成。
    let referenceEmbedding = PatientEmbedding(
        symptomVector:     [0.72, 0.48, 0.61, 0.33],   // 中度震颤+轻度僵直+中度迟缓
        treatmentVector:   [0.78, 0.28, 0.52],           // 较好左旋多巴响应+低异动风险
        progressionVector: [0.735, 0.225]                 // onset ~58.8y, 病程 4.5y
    )

    // MARK: - 🕸️ MOCKED GNN EMBEDDING DISTANCE CALCULATION
    // 该函数模拟图神经网络中两个患者节点在多维嵌入空间中的距离计算。
    // 真实 GNN 中，节点嵌入由多层图卷积（GraphConv）聚合邻居信息后输出；
    // 此处使用原始特征向量替代 GNN 输出嵌入，保留相同的距离度量数学逻辑。

    func calculateGraphNodeDistance(
        referenceNode patientA: PatientEmbedding,
        candidateNode patientB: PatientEmbedding
    ) -> GNNMatchScores {

        // ── 维度1：症状空间 — 余弦相似度 ─────────────────────────
        // cos_sim(A,B) = (A·B) / (‖A‖·‖B‖)
        // 余弦相似度度量向量方向的一致性，不受症状整体严重度影响。
        // 两位患者若有"相同症状模式"（如都是震颤主导），
        // 即使严重程度不同，余弦相似度也会较高。
        let symptomSim = cosineSimilarity(patientA.symptomVector,
                                          patientB.symptomVector)

        // ── 维度2：治疗反应空间 — 高斯 RBF 核函数 ────────────────
        // k_rbf(A,B) = exp(−‖A−B‖² / 2σ²),  σ = 0.30
        // RBF 核将欧氏距离映射到 (0,1]，对治疗反应向量的细微差异高度敏感。
        // σ=0.30 是经验调优值：使相似响应模式得分>0.85，不同模式<0.40。
        let treatmentSim = rbfKernel(patientA.treatmentVector,
                                     patientB.treatmentVector,
                                     sigma: 0.30)

        // ── 维度3：病程轨迹空间 — 加权欧氏距离相似度 ─────────────
        // 权重向量 w = [1.5, 1.0]：发病年龄对治疗选择影响更大(w=1.5)
        // d_w = √(1.5·(Δage)² + 1.0·(Δduration)²)
        // eucl_sim = exp(−d_w)
        let progressionSim = weightedEuclideanSim(
            patientA.progressionVector,
            patientB.progressionVector,
            weights: [1.5, 1.0]
        )

        // ── 治疗启发价值 TIV — 多空间加权融合 ────────────────────
        // TIV = 0.30·S_symptom + 0.45·S_treatment + 0.25·S_progression
        //
        // 权重设计依据：
        //   0.45 给治疗反应 → "该患者的用药方案对你的参考价值"最为关键
        //   0.30 给症状模式 → "你们有相似的疾病表现"是前提条件
        //   0.25 给病程轨迹 → "处于相近疾病阶段"增加可比性
        let tiv = 0.30 * symptomSim
                + 0.45 * treatmentSim
                + 0.25 * progressionSim

        let reason = generateMatchReason(
            symptomSim:    symptomSim,
            treatmentSim:  treatmentSim,
            progressionSim: progressionSim,
            tiv:           tiv
        )

        return GNNMatchScores(
            symptomSimilarity:           symptomSim,
            treatmentResponseSimilarity: treatmentSim,
            progressionSimilarity:       progressionSim,
            treatmentInspirationValue:   tiv,
            matchReason:                 reason
        )
    }

    // MARK: - Vector Math Primitives
    // 以下三个函数构成 GNN 距离计算的数学基础。

    /// 余弦相似度：cos_sim(A,B) = (A·B) / (‖A‖·‖B‖)
    func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        let dot   = zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
        let normA = sqrt(a.reduce(0.0) { $0 + $1 * $1 })
        let normB = sqrt(b.reduce(0.0) { $0 + $1 * $1 })
        guard normA > 1e-8, normB > 1e-8 else { return 0.0 }
        return max(0.0, min(1.0, dot / (normA * normB)))
    }

    /// 高斯 RBF 核：k_rbf(A,B) = exp(−‖A−B‖² / 2σ²)
    func rbfKernel(_ a: [Double], _ b: [Double], sigma: Double) -> Double {
        let sqDist = zip(a, b).reduce(0.0) { $0 + pow($1.0 - $1.1, 2) }
        return exp(-sqDist / (2.0 * sigma * sigma))
    }

    /// 加权欧氏距离相似度：sim = exp(−√(Σwᵢ·(aᵢ−bᵢ)²))
    func weightedEuclideanSim(_ a: [Double], _ b: [Double], weights: [Double]) -> Double {
        let wSqDist = zip(zip(a, b), weights)
            .reduce(0.0) { $0 + $1.1 * pow($1.0.0 - $1.0.1, 2) }
        return exp(-sqrt(wSqDist))
    }

    // MARK: - 匹配原因生成

    private func generateMatchReason(
        symptomSim: Double, treatmentSim: Double,
        progressionSim: Double, tiv: Double
    ) -> String {
        var clauses: [String] = []

        switch symptomSim {
        case 0.92...:
            clauses.append("症状谱余弦相似度达 \(pct(symptomSim))，与您几乎呈现相同的运动障碍模式")
        case 0.78...:
            clauses.append("症状模式相似（\(pct(symptomSim))），主要症状类型与您接近")
        default:
            clauses.append("症状模式存在差异（\(pct(symptomSim))），但病程阶段具参考性")
        }

        switch treatmentSim {
        case 0.80...:
            clauses.append("治疗反应向量高度吻合（RBF \(pct(treatmentSim))），其剂量方案具有直接参考价值")
        case 0.55...:
            clauses.append("治疗反应相近（\(pct(treatmentSim))），用药策略有借鉴空间")
        default:
            clauses.append("治疗路径差异明显（\(pct(treatmentSim))），可作为对比参照")
        }

        if progressionSim > 0.88 {
            clauses.append("发病年龄与病程阶段高度匹配（\(pct(progressionSim))）")
        }

        let conclusion: String
        switch tiv {
        case 0.80...: conclusion = "综合 TIV=\(pct(tiv))，属高价值参考案例 ★"
        case 0.60...: conclusion = "TIV=\(pct(tiv))，具备中等治疗启发价值"
        default:      conclusion = "TIV=\(pct(tiv))，可作辅助参考"
        }
        clauses.append(conclusion)

        return clauses.joined(separator: "；") + "。"
    }

    private func pct(_ v: Double) -> String { "\(Int(v * 100))%" }
}
