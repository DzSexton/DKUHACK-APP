import Foundation
import Combine

// MARK: - HypothesisOption

/// Agent 针对每次预测生成的可选反馈项。
/// 用户从中选择最符合自身情况的选项，Agent 据此执行参数更新。
struct HypothesisOption: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    /// true → 用户确认了 Agent 的推断 → 正强化信号 δ=+1
    /// false → 用户否定了 Agent 的推断 → 负强化信号 δ=−1
    let isConfirmation: Bool
}

// MARK: - AgentPrediction

/// Agent 输出的完整预测结构。
struct AgentPrediction {
    let state: MotorState
    /// 置信度 ∈ [0,1]，由 sigmoid(距决策边界距离) 计算
    let confidence: Double
    /// 技术解释（含公式数值，显示在 Agent 卡片内）
    let explanation: String
    /// 临床推断文本（基于时间 + 药效周期，显示在反馈卡片内）
    let hypothesis: String
    /// 用户可选的反馈选项（最多 4 项）
    let options: [HypothesisOption]
    let sigma: Double
    let adaptiveThreshold: Double
}

// MARK: - PDMonitoringAgent

/// 具备强化反馈机制的自适应 PD 运动状态监测 Agent。
///
/// ## 核心公式
/// ```
/// τ_adaptive = 0.65·τ_user + 0.35·τ_base
/// σ_w        = w₀·σ + w₁·(E/E_max)·σ·0.15 + w₂·|μ|·0.05
/// conf       = sigmoid(18 · min(|σ_w−τ|, |σ_w−2τ|))
/// τ_base    ← τ_base + α·δ·(σ_w − τ_base)          // 梯度下降
/// w         ← w + α·δ·φ/‖φ‖  → 归一化              // 感知机更新
/// acc       ← acc·(1−α·β) + y·(α·β)                 // EMA, β=0.6
/// ```
@MainActor
final class PDMonitoringAgent: ObservableObject {

    // MARK: - 🧠 AI ADAPTIVE LEARNING CORE (Mocked for Hackathon)

    /// τ_base：Agent 自学习的基础阈值，初始值来自 PD 文献静息态水平
    private(set) var baseThreshold: Double = 0.118

    /// α：学习率（参考 Adam 优化器典型取值 [0.001, 0.1]）
    let learningRate: Double = 0.05

    /// 特征权重向量 w = [w_σ, w_energy, w_mean]
    private(set) var featureWeights: [Double] = [0.62, 0.28, 0.10]

    @Published private(set) var currentAccuracy: Double = 0.718
    @Published private(set) var feedbackCount: Int = 0
    private(set) var confirmedCorrectCount: Int = 0
    @Published private(set) var accuracyHistory: [Double] = [0.718]

    /// 最近一次 EMA 更新的数值快照，供 UI 渲染公式字符串
    @Published private(set) var lastEmaSteps: EmaSteps? = nil

    struct EmaSteps {
        let accBefore: Double
        let decay:     Double   // 1 − α·β
        let y:         Double   // 0.0 or 1.0
        let emaRate:   Double   // α·β
        let accAfter:  Double
    }

    /// 最新预测缓存（供反馈关联 + View 访问选项列表）
    @Published private(set) var lastPrediction: AgentPrediction? = nil

    private var lastWeightedSigma:    Double = 0.0
    private var lastAdaptiveThreshold: Double = 0.118

    // MARK: - 🧠 Predict

    func predict(features: SensorFeatures, userThreshold: Double) -> AgentPrediction {

        // 自适应阈值融合
        let tau = 0.65 * userThreshold + 0.35 * baseThreshold

        // 加权 sigma
        let energyNorm = min(features.signalEnergy / 10.0, 1.0)
        let sigmaW = featureWeights[0] * features.sigma
                   + featureWeights[1] * energyNorm * features.sigma * 0.15
                   + featureWeights[2] * abs(features.mean) * 0.05

        // 分类
        let state: MotorState
        if sigmaW > tau * 2.0 { state = .tremor }
        else if sigmaW > tau  { state = .off    }
        else                  { state = .on     }

        // 置信度
        let d1 = abs(sigmaW - tau)
        let d2 = abs(sigmaW - tau * 2.0)
        let conf = sigmoid(min(d1, d2) * 18.0)

        lastWeightedSigma     = sigmaW
        lastAdaptiveThreshold = tau

        let explanation = buildExplanation(state: state, sigma: features.sigma,
                                           sigmaW: sigmaW, tau: tau, conf: conf)
        let (hypothesis, options) = buildHypothesis(state: state, sigma: features.sigma,
                                                    sigmaW: sigmaW, tau: tau)

        let prediction = AgentPrediction(
            state: state, confidence: conf,
            explanation: explanation, hypothesis: hypothesis, options: options,
            sigma: features.sigma, adaptiveThreshold: tau
        )
        lastPrediction = prediction
        return prediction
    }

    // MARK: - 🧠 ADAPTIVE LEARNING CORE — 反馈驱动的在线参数更新

    /// 接收用户选择的反馈选项，执行一步在线梯度下降更新。
    ///
    /// **Step 1 — 阈值梯度更新：**
    /// ```
    /// δ = isConfirmation ? +1 : −1
    /// ∂L/∂τ ≈ −δ · (σ_w − τ_base)
    /// τ_base ← τ_base + α · δ · (σ_w − τ_base)
    /// ```
    /// **Step 2 — 特征权重更新（感知机规则）：**
    /// ```
    /// w ← w + α · δ · φ/‖φ‖  → 归一化
    /// ```
    /// **Step 3 — 精度 EMA：**
    /// ```
    /// acc ← acc · (1−α·β) + y · (α·β),  β=0.6
    /// ```
    func adaptModel(basedOn feedback: Bool) {
        feedbackCount += 1
        if feedback { confirmedCorrectCount += 1 }

        let delta: Double = feedback ? 1.0 : -1.0

        // Step 1: 阈值梯度更新
        let gradTau = -delta * (lastWeightedSigma - baseThreshold)
        baseThreshold -= learningRate * gradTau
        baseThreshold = max(0.02, min(0.45, baseThreshold))

        // Step 2: 特征权重更新
        let phi: [Double] = [lastWeightedSigma, 0.10, 0.05]
        let phiNorm = sqrt(phi.reduce(0.0) { $0 + $1 * $1 })
        for i in featureWeights.indices {
            featureWeights[i] += learningRate * delta * (phi[i] / max(phiNorm, 1e-8))
        }
        let wSum = featureWeights.reduce(0.0) { $0 + max(0.0, $1) }
        if wSum > 1e-8 { featureWeights = featureWeights.map { max(0.0, $0) / wSum } }

        // Step 3: 精度 EMA
        let y: Double  = feedback ? 1.0 : 0.0
        let emaRate    = learningRate * 0.6
        let accBefore  = currentAccuracy
        currentAccuracy = currentAccuracy * (1.0 - emaRate) + y * emaRate
        currentAccuracy = max(0.0, min(1.0, currentAccuracy))

        lastEmaSteps = EmaSteps(accBefore: accBefore, decay: 1.0 - emaRate,
                                y: y, emaRate: emaRate, accAfter: currentAccuracy)
        accuracyHistory.append(currentAccuracy)
        if accuracyHistory.count > 20 { accuracyHistory.removeFirst() }
    }

    // MARK: - 🧠 Hypothesis Generation — 基于时间与药效周期的临床推断

    /// 根据当前时间、运动状态、σ 值生成有临床意义的假设文本与反馈选项。
    ///
    /// 药效周期模型（典型三次服药方案）：
    /// - 晨间剂：~07:30，药效持续 4-5h
    /// - 午间剂：~13:30，药效持续 4-5h
    /// - 晚间剂：~19:00，药效持续 4-5h
    ///
    /// 每个时间窗对应不同的推断逻辑与选项。
    private func buildHypothesis(
        state: MotorState, sigma: Double, sigmaW: Double, tau: Double
    ) -> (String, [HypothesisOption]) {

        let now    = Date()
        let cal    = Calendar.current
        let hour   = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let h      = Double(hour) + Double(minute) / 60.0
        let tStr   = String(format: "%02d:%02d", hour, minute)
        let sStr   = String(format: "%.3f", sigma)
        let tauStr = String(format: "%.3f", tau)

        // ── 时间窗定义（基于典型左旋多巴三次给药方案）─────────────
        let preMorning  = h >= 6.0  && h < 8.0    // 06:00–08:00 晨间服药前
        let postMorning = h >= 8.0  && h < 12.0   // 08:00–12:00 晨间药效期
        let preNoon     = h >= 12.0 && h < 14.5   // 12:00–14:30 午间服药前
        let postNoon    = h >= 14.5 && h < 18.0   // 14:30–18:00 午间药效期
        let preEvening  = h >= 18.0 && h < 20.5   // 18:00–20:30 晚间服药前
        let postEvening = h >= 20.5 && h < 24.0   // 20:30–24:00 晚间药效期
        let isNight     = h < 6.0                  // 00:00–06:00 夜间

        switch state {

        // ── TREMOR ──────────────────────────────────────────────────
        case .tremor:
            if preMorning {
                return (
                    "🔍 我观察到您当前的震颤幅度（σ=\(sStr)）**显著高于**您的个人阈值（τ=\(tauStr)），比值达 \(String(format:"%.1f",sigmaW/tau))×。\n\n现在是 \(tStr)，正处于早晨服药时间（通常 07:30）之前。这与帕金森的**晨间剂末效应（Morning Wearing-off）**高度吻合——夜间停药后，上一剂左旋多巴的血药浓度已降至谷值，导致清晨震颤加剧。\n\n💡 Agent 推断：您可能还未服今天的早晨剂量，或昨晚最后一剂服药时间偏早。",
                    [
                        HypothesisOption(emoji: "💊", label: "还没服晨间药", isConfirmation: true),
                        HypothesisOption(emoji: "⏰", label: "昨晚睡前药比平时早", isConfirmation: true),
                        HypothesisOption(emoji: "✅", label: "已经服药了", isConfirmation: false),
                        HypothesisOption(emoji: "🏃", label: "刚做过运动", isConfirmation: false),
                    ]
                )
            } else if preNoon {
                let hoursAgo = String(format: "%.1f", h - 7.5)
                return (
                    "🔍 当前 σ=\(sStr)，超过 2τ，检测到明显震颤。\n\n现在是 \(tStr)，距您上次服药（约 07:30）已过去约 **\(hoursAgo) 小时**。左旋多巴的半衰期约 1.5 小时，典型药效持续 4–5 小时，您目前可能已进入**剂末效应（End-of-dose Wearing-off）**窗口。\n\n💡 Agent 推断：上午剂量的药效正在衰退，午间剂量尚未服用。",
                    [
                        HypothesisOption(emoji: "⏳", label: "感觉药效在减弱", isConfirmation: true),
                        HypothesisOption(emoji: "💊", label: "还没吃午间药", isConfirmation: true),
                        HypothesisOption(emoji: "😰", label: "情绪紧张/压力大", isConfirmation: false),
                        HypothesisOption(emoji: "✅", label: "状态和描述不符", isConfirmation: false),
                    ]
                )
            } else if preEvening {
                let hoursAgo = String(format: "%.1f", h - 13.5)
                return (
                    "🔍 当前 σ=\(sStr)，检测到震颤加剧。\n\n现在是 \(tStr)，距午间服药约 **\(hoursAgo) 小时**，药效曲线正接近谷值区间。这是帕金森患者下午常见的**剂末波动（Motor Fluctuation）**现象。\n\n💡 Agent 推断：您处于晚间剂量服用前的症状低谷期。",
                    [
                        HypothesisOption(emoji: "⏳", label: "下午一直感觉状态差", isConfirmation: true),
                        HypothesisOption(emoji: "💊", label: "还没服晚间药", isConfirmation: true),
                        HypothesisOption(emoji: "😴", label: "今天睡眠不佳", isConfirmation: false),
                        HypothesisOption(emoji: "✅", label: "状态比描述要好", isConfirmation: false),
                    ]
                )
            } else {
                return (
                    "🔍 检测到非典型震颤模式（σ=\(sStr)，当前 \(tStr)），不在常规的剂末时间窗内。\n\n可能的触发因素：(1) 近期剧烈运动导致肌肉疲劳 (2) 精神压力/情绪波动 (3) 昨晚睡眠质量差 (4) 咖啡因摄入过多。\n\n💡 Agent 推断：外部环境因素可能正在放大震颤信号。",
                    [
                        HypothesisOption(emoji: "🏋️", label: "刚做了剧烈运动", isConfirmation: true),
                        HypothesisOption(emoji: "😰", label: "心情紧张或压力大", isConfirmation: true),
                        HypothesisOption(emoji: "😴", label: "昨晚睡眠不好", isConfirmation: true),
                        HypothesisOption(emoji: "❓", label: "原因不明", isConfirmation: false),
                    ]
                )
            }

        // ── OFF ─────────────────────────────────────────────────────
        case .off:
            if postMorning || postNoon || postEvening {
                let medTime = postMorning ? "07:30" : (postNoon ? "13:30" : "19:00")
                return (
                    "🔍 当前 σ=\(sStr)，处于 τ 到 2τ 之间（中间状态），运动功能轻度受限。\n\n现在是 \(tStr)，处于 \(medTime) 服药后的过渡期。左旋多巴通常在服药后 30–60 分钟开始起效，药效尚未完全建立。\n\n💡 Agent 推断：您可能刚服药不久，正处于 ON 状态建立期。",
                    [
                        HypothesisOption(emoji: "💊", label: "刚服药，等待起效", isConfirmation: true),
                        HypothesisOption(emoji: "🍽️", label: "随餐服药，起效偏慢", isConfirmation: true),
                        HypothesisOption(emoji: "😐", label: "感觉状态没那么差", isConfirmation: false),
                        HypothesisOption(emoji: "✅", label: "和描述不符", isConfirmation: false),
                    ]
                )
            } else {
                return (
                    "🔍 σ=\(sStr) 处于轻度波动范围，运动功能轻度受限。\n\n💡 Agent 推断：当前处于 OFF/ON 过渡状态，建议记录此时服药情况以帮助医生调整用药时间。",
                    [
                        HypothesisOption(emoji: "😪", label: "感到轻微乏力", isConfirmation: true),
                        HypothesisOption(emoji: "💊", label: "刚服过药", isConfirmation: false),
                        HypothesisOption(emoji: "✅", label: "感觉还不错", isConfirmation: false),
                    ]
                )
            }

        // ── ON ──────────────────────────────────────────────────────
        case .on:
            if postMorning || postNoon || postEvening {
                let medTime = postMorning ? "07:30" : (postNoon ? "13:30" : "19:00")
                return (
                    "🔍 当前 σ=\(sStr) 低于阈值（τ=\(tauStr)），运动功能状态良好。\n\n现在是 \(tStr)，处于 **\(medTime) 服药后约 \(String(format:"%.0f",abs(h-(postMorning ? 7.5:postNoon ? 13.5:19.0))*60)) 分钟**。这符合左旋多巴**药效高峰（ON 期）**的典型特征——血药浓度达峰，震颤得到有效控制。\n\n💡 Agent 推断：您目前正处于最佳的药效窗口期。",
                    [
                        HypothesisOption(emoji: "✅", label: "是的，感觉状态不错", isConfirmation: true),
                        HypothesisOption(emoji: "💊", label: "刚服过药", isConfirmation: true),
                        HypothesisOption(emoji: "😐", label: "感觉没描述的那么好", isConfirmation: false),
                    ]
                )
            } else if isNight {
                return (
                    "🔍 σ=\(sStr) 显示运动状态平稳，夜间数据正常。\n\n现在是深夜 \(tStr)，较低的震颤幅度通常与睡眠状态或身体静息有关。\n\n💡 建议：如您此时刚醒来，这是记录夜间症状的好时机。",
                    [
                        HypothesisOption(emoji: "😴", label: "刚睡醒", isConfirmation: true),
                        HypothesisOption(emoji: "🌙", label: "夜间症状本来就少", isConfirmation: true),
                        HypothesisOption(emoji: "❓", label: "其他情况", isConfirmation: false),
                    ]
                )
            } else {
                return (
                    "🔍 σ=\(sStr) 低于阈值（τ=\(tauStr)），未检测到显著震颤或运动受限特征。\n\n💡 Agent 推断：当前运动状态良好，请继续保持日常活动，并在状态变化时随时触发新一轮检测。",
                    [
                        HypothesisOption(emoji: "✅", label: "状态确实不错", isConfirmation: true),
                        HypothesisOption(emoji: "💊", label: "药效很好", isConfirmation: true),
                        HypothesisOption(emoji: "😐", label: "感觉没描述的那么好", isConfirmation: false),
                    ]
                )
            }

        case .unknown:
            return (
                "数据不足，Agent 无法生成可靠推断。请重新检测。",
                [HypothesisOption(emoji: "🔄", label: "重新检测", isConfirmation: false)]
            )
        }
    }

    // MARK: - 辅助

    private func sigmoid(_ x: Double) -> Double { 1.0 / (1.0 + exp(-x)) }

    private func buildExplanation(
        state: MotorState, sigma: Double, sigmaW: Double, tau: Double, conf: Double
    ) -> String {
        let confPct  = Int(conf * 100)
        let ratio    = String(format: "%.2f", sigmaW / max(tau, 1e-6))
        let sigmaStr = String(format: "%.4f", sigma)
        let tauStr   = String(format: "%.4f", tau)
        switch state {
        case .on:
            return "σ=\(sigmaStr)，τ_a=\(tauStr)，比值 \(ratio) < 1.0 → ON。置信度 \(confPct)%。"
        case .off:
            return "σ=\(sigmaStr)，τ_a=\(tauStr)，比值 \(ratio) ∈ [1,2) → OFF。置信度 \(confPct)%。"
        case .tremor:
            return "σ=\(sigmaStr)，τ_a=\(tauStr)，比值 \(ratio) ≥ 2.0 → Tremor。置信度 \(confPct)%。"
        case .unknown:
            return "特征向量不足（σ=\(sigmaStr)），置信度 \(confPct)%。"
        }
    }
}
