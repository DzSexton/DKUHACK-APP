import SwiftUI

/// 洞察视图 —— 本地脱敏患者数据库，小红书式 2 列瀑布流网格
///
/// 每张卡片展示匿名患者的摘要信息（姓名、性别、年龄、匹配度）。
/// 点击任意卡片跳转到 PatientProfileDetailView，查看完整的发病 / 治疗详情。
struct InsightView: View {
    @EnvironmentObject var viewModel: MainViewModel

    // 2 列弹性网格，间距 14pt
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 顶部说明卡
                    headerBanner

                    // 2 列瀑布流网格
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.patientProfiles) { profile in
                            NavigationLink(
                                destination: PatientProfileDetailView(profile: profile)
                            ) {
                                PatientProfileCard(profile: profile)
                            }
                            .buttonStyle(.plain)  // 去掉默认蓝色高亮
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("相似病例")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 顶部说明横幅

    private var headerBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("本地脱敏数据库")
                    .font(.subheadline.weight(.semibold))
                Text("以下档案均已匿名化处理，完全离线存储，数据从不上传")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - 患者档案卡片

/// 用于网格布局的摘要卡片：显示姓名、性别、年龄、匹配度
private struct PatientProfileCard: View {
    let profile: PatientProfile

    var body: some View {
        VStack(spacing: 0) {
            // ── 上半部：彩色渐变区 ──────────────────────────
            ZStack(alignment: .topTrailing) {
                // 渐变背景
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: accentGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 88)

                // 装饰圆（右上角）
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 70, height: 70)
                    .offset(x: 18, y: -18)

                // 匹配度徽章（左上角）
                matchBadge
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            // ── 下半部：文字区 ──────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                // 姓名
                Text(profile.anonymizedName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // 性别 + 年龄标签行
                HStack(spacing: 6) {
                    Label(profile.gender.rawValue, systemImage: "person")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(profile.age) 岁")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 匹配度进度条
                matchProgressBar
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: accentGradient[0].opacity(0.20), radius: 10, x: 0, y: 4)
    }

    // MARK: - 匹配度徽章（左上角）

    private var matchBadge: some View {
        VStack(spacing: 1) {
            Text("\(profile.matchPercentage)%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("匹配")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 匹配度进度条

    private var matchProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 底色轨道
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 5)
                // 填充段
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: accentGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geo.size.width * CGFloat(profile.matchPercentage) / 100.0,
                        height: 5
                    )
            }
        }
        .frame(height: 5)
    }

    // MARK: - 匹配度对应渐变色

    private var accentGradient: [Color] {
        switch profile.matchPercentage {
        case 90...100: return [Color(red: 0.35, green: 0.10, blue: 0.65), Color.indigo]
        case 80..<90:  return [Color.indigo, Color.blue]
        case 70..<80:  return [Color.teal, Color.cyan]
        default:       return [Color.orange, Color(red: 1.0, green: 0.65, blue: 0.1)]
        }
    }
}

// MARK: - Preview

#Preview {
    InsightView()
        .environmentObject(MainViewModel())
}
