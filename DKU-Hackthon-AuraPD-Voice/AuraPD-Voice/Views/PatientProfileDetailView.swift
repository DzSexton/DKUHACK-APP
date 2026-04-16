import SwiftUI

/// GNN 患者档案详情页——多维度进度条 + 匹配原因 + 治疗方案。
struct PatientProfileDetailView: View {
    let profile: PatientProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Hero 头部 ────────────────────────────────────────
                heroHeader
                    .padding(.bottom, 20)

                VStack(spacing: 16) {

                    // ── GNN 多维度匹配分析 ────────────────────────────
                    gnnScoreSection

                    // ── 匹配原因 ──────────────────────────────────────
                    if let reason = profile.gnnScores?.matchReason {
                        matchReasonSection(reason: reason)
                    }

                    // ── 治疗方案详情 ──────────────────────────────────
                    infoSection(title: "发病情况", icon: "clock.arrow.circlepath",
                                rows: [
                                    ("发病时间", profile.onsetPeriod),
                                    ("症状描述", profile.symptomsDescription),
                                ])

                    infoSection(title: "治疗方案", icon: "pills.fill",
                                rows: [
                                    ("就诊医院", profile.treatmentLocation),
                                    ("用药方案", profile.treatmentMethod),
                                ])

                    infoSection(title: "治疗结果", icon: "chart.line.uptrend.xyaxis",
                                rows: [
                                    ("疗效评估", profile.treatmentOutcome),
                                ])

                    // ── 伦理免责声明 ──────────────────────────────────
                    disclaimerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("\(profile.anonymizedName)\(profile.gender.rawValue)的档案")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: heroGradient(profile.treatmentInspirationValue),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 160)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(profile.anonymizedName)\(profile.gender.rawValue)")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("· \(profile.age) 岁")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    // TIV 徽章
                    VStack(spacing: 1) {
                        Text("\(profile.matchPercentage)%")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.white)
                        Text("TIV")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }

                Text(profile.treatmentLocation)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(16)
        }
    }

    // MARK: – GNN 多维度评分

    private var gnnScoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .foregroundStyle(.indigo)
                Text("GNN 多维度匹配分析")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
            }

            if let scores = profile.gnnScores {
                // 维度1：症状余弦相似度
                gnnDimBar(
                    label: "症状空间余弦相似度",
                    formula: "cos_sim = (A·B)/(‖A‖·‖B‖)",
                    value: scores.symptomSimilarity,
                    color: .purple
                )

                // 维度2：治疗反应 RBF 核
                gnnDimBar(
                    label: "治疗反应 RBF 核相似度",
                    formula: "k_rbf = exp(−‖A−B‖²/2σ²)",
                    value: scores.treatmentResponseSimilarity,
                    color: .indigo
                )

                // 维度3：病程加权欧氏
                gnnDimBar(
                    label: "病程轨迹加权欧氏相似度",
                    formula: "eucl_sim = exp(−√(Σwᵢ·Δᵢ²))",
                    value: scores.progressionSimilarity,
                    color: .blue
                )

                Divider()

                // TIV 综合分
                gnnDimBar(
                    label: "治疗启发价值  TIV ⭐",
                    formula: "0.30·S + 0.45·T + 0.25·P",
                    value: scores.treatmentInspirationValue,
                    color: tivColor(scores.treatmentInspirationValue),
                    highlight: true
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func gnnDimBar(
        label: String, formula: String,
        value: Double, color: Color,
        highlight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(highlight ? .subheadline.bold() : .caption.bold())
                    .foregroundStyle(highlight ? color : .primary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(color)
            }
            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: highlight ? 10 : 7)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(value),
                               height: highlight ? 10 : 7)
                }
            }
            .frame(height: highlight ? 10 : 7)
            // 公式字符串（供评审识别算法）
            Text(formula)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }

    // MARK: – 匹配原因

    private func matchReasonSection(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                Text("GNN 匹配原因")
                    .font(.subheadline.bold())
            }
            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – 通用信息区

    private func infoSection(title: String, icon: String,
                             rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.indigo)
                    .font(.caption.bold())
                Text(title)
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                if idx > 0 { Divider().padding(.leading, 14) }
                HStack(alignment: .top, spacing: 10) {
                    Text(row.0)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Text(row.1)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – 免责声明

    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text("以上数据来自本地脱敏数据库，所有个人信息已匿名化处理，完全离线存储，不涉及任何网络传输。GNN 相似度仅供参考，临床决策请遵循医生指导。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: – 辅助

    private func tivColor(_ v: Double) -> Color {
        switch v {
        case 0.80...: return .purple
        case 0.65...: return .indigo
        default:      return .blue
        }
    }

    private func heroGradient(_ v: Double) -> [Color] {
        switch v {
        case 0.80...: return [.purple, .indigo]
        case 0.65...: return [.indigo, .blue]
        case 0.50...: return [.blue, .teal]
        default:      return [Color(.systemGray2), Color(.systemGray3)]
        }
    }
}

#Preview {
    NavigationStack {
        PatientProfileDetailView(profile: PatientProfileDatabase.mockProfiles.first!)
    }
}
