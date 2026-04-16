import SwiftUI

/// 患者档案详情页
///
/// 由瀑布流网格卡片点击跳转进入，完整展示 PatientProfile 的所有详情字段。
/// 使用 GroupBox 分区排版，清晰区隔基本信息、发病情况、治疗方案、治疗结果。
struct PatientProfileDetailView: View {
    let profile: PatientProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部英雄卡（匹配度 + 基本信息）
                heroCard

                // 发病情况区块
                infoSection(
                    title: "发病情况",
                    icon: "waveform.path.ecg",
                    iconColor: .red,
                    rows: [
                        ("发病时间段", profile.onsetPeriod),
                        ("症状描述",   profile.symptomsDescription)
                    ]
                )

                // 治疗方案区块
                infoSection(
                    title: "治疗方案",
                    icon: "cross.case.fill",
                    iconColor: .blue,
                    rows: [
                        ("就诊机构", profile.treatmentLocation),
                        ("治疗手段", profile.treatmentMethod)
                    ]
                )

                // 治疗结果区块
                infoSection(
                    title: "治疗结果",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    rows: [
                        ("改善情况", profile.treatmentOutcome)
                    ]
                )

                // 免责声明
                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle(profile.anonymizedName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - 顶部英雄卡

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            // 渐变背景
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: matchGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 160)

            // 装饰性大圆
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: 180, y: -40)

            VStack(alignment: .leading, spacing: 10) {
                // 姓名 + 匹配徽章
                HStack(alignment: .firstTextBaseline) {
                    Text(profile.anonymizedName)
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Spacer()

                    // 匹配度圆形徽章
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 64, height: 64)
                        VStack(spacing: 0) {
                            Text("\(profile.matchPercentage)%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("匹配")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }

                // 性别 · 年龄 标签组
                HStack(spacing: 10) {
                    tagBadge(text: profile.gender.rawValue, icon: "person.fill")
                    tagBadge(text: "\(profile.age) 岁", icon: "calendar")
                }
            }
            .padding(20)
        }
    }

    private func tagBadge(text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.18), in: Capsule())
    }

    // MARK: - 信息区块（通用）

    /// 带标题和行数据的 GroupBox 风格区块
    private func infoSection(
        title: String,
        icon: String,
        iconColor: Color,
        rows: [(label: String, value: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 区块标题行
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // 数据行
            ForEach(rows, id: \.label) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(row.value)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if row.label != rows.last?.label {
                    Divider().padding(.horizontal, 16)
                }
            }

            // 底部留白
            Spacer().frame(height: 4)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 免责声明

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
            Text("本档案来自本地脱敏数据库，仅供参考。所有治疗决策请遵循主治医生的专业建议。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 辅助：渐变配色

    private var matchGradient: [Color] {
        switch profile.matchPercentage {
        case 90...100: return [Color(red: 0.29, green: 0.00, blue: 0.51), Color.indigo]
        case 80..<90:  return [Color.indigo, Color.blue]
        case 70..<80:  return [Color.teal, Color(red: 0.0, green: 0.6, blue: 0.8)]
        default:       return [Color.orange, Color(red: 0.9, green: 0.5, blue: 0.1)]
        }
    }
}

#Preview {
    NavigationStack {
        PatientProfileDetailView(profile: PatientProfileDatabase.mockProfiles[0])
    }
}
