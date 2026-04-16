import SwiftUI

/// GNN 社区匹配主页——瀑布流卡片，突出显示治疗启发价值 (TIV)。
struct InsightView: View {

    @EnvironmentObject var viewModel: MainViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    gnnHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.patientProfiles) { profile in
                            NavigationLink(destination: PatientProfileDetailView(profile: profile)) {
                                ProfileCard(profile: profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("GNN 社区匹配")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: – GNN 说明头部

    private var gnnHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .foregroundStyle(.indigo)
                    .font(.subheadline.bold())
                Text("图神经网络患者社区")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
                Spacer()
                Text("节点数: \(viewModel.patientProfiles.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("以多维嵌入向量距离衡量治疗启发价值（TIV）。按 TIV 降序排列，高亮案例对您的用药方案最具参考意义。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 公式字符串（让评审一眼看到算法）
            Text("TIV = 0.30·cos_sim(症状) + 0.45·k_rbf(治疗) + 0.25·eucl_sim(病程)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.indigo.opacity(0.7))
        }
        .padding(12)
        .background(Color.indigo.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: – ProfileCard（单个瀑布流卡片）

private struct ProfileCard: View {
    let profile: PatientProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 顶部渐变色条（颜色随 TIV 变化）
            LinearGradient(
                colors: tivGradient(profile.treatmentInspirationValue),
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 5)

            VStack(alignment: .leading, spacing: 8) {

                // 姓名 + 年龄
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(profile.anonymizedName)\(profile.gender.rawValue)")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(profile.age)岁")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // ⭐ 治疗启发价值大数字
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(profile.matchPercentage)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(tivColor(profile.treatmentInspirationValue))
                    Text("%")
                        .font(.headline.bold())
                        .foregroundStyle(tivColor(profile.treatmentInspirationValue).opacity(0.7))
                    Spacer()
                    if profile.treatmentInspirationValue >= 0.80 {
                        Text("⭐")
                            .font(.caption)
                    }
                }

                Text("治疗启发价值")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider()

                // GNN 两维度迷你进度条
                if let scores = profile.gnnScores {
                    miniBar(label: "症状", value: scores.symptomSimilarity, color: .purple)
                    miniBar(label: "治疗", value: scores.treatmentResponseSimilarity, color: .indigo)
                }

                // 医院标签
                Text(profile.treatmentLocation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func miniBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.tertiarySystemFill))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.75))
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(height: 5)
            Text("\(Int(value * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
        }
    }

    private func tivColor(_ v: Double) -> Color {
        switch v {
        case 0.80...: return .purple
        case 0.65...: return .indigo
        case 0.50...: return .blue
        default:      return .gray
        }
    }

    private func tivGradient(_ v: Double) -> [Color] {
        switch v {
        case 0.80...: return [.purple, .indigo]
        case 0.65...: return [.indigo, .blue]
        case 0.50...: return [.blue, .teal]
        default:      return [.gray, Color(.systemGray3)]
        }
    }
}

#Preview {
    InsightView()
        .environmentObject(MainViewModel())
}
