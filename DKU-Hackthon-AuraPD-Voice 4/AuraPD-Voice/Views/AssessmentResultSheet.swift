import SwiftUI

// MARK: - AssessmentResultSheet

/// Beautiful result sheet that pops up after every assessment (real or demo).
/// Presented by DashboardView via .onChange(of: viewModel.latestResult?.id).
struct AssessmentResultSheet: View {

    let result: AssessmentResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            heroBanner
            ScrollView {
                VStack(spacing: 16) {
                    metricsRow
                    confidenceSection
                    sigmaBar
                    if !result.mlExplanation.isEmpty {
                        explanationCard
                    }
                    voiceCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
    }

    // MARK: – Hero banner

    private var heroBanner: some View {
        ZStack {
            LinearGradient(
                colors: heroColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: result.state.symbolName)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)

                Text(result.state.displayName)
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text(result.formattedTimestamp)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.vertical, 36)
        }
    }

    // MARK: – σ / τ metric badges

    private var metricsRow: some View {
        HStack(spacing: 12) {
            metricBadge(
                symbol: "σ",
                label:  "Measured SD",
                value:  String(format: "%.4f", result.sigma),
                color:  sigmaColor
            )
            metricBadge(
                symbol: "τ",
                label:  "Adaptive Threshold",
                value:  String(format: "%.4f", result.threshold),
                color:  .indigo
            )
        }
    }

    private func metricBadge(symbol: String, label: String,
                              value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(symbol)
                .font(.caption2.bold())
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: – Confidence arc meter

    private var confidenceSection: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Agent Confidence", systemImage: "brain.head.profile")
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
                Spacer()
                Text("\(Int(result.confidence * 100))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(confidenceColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.purple, confidenceColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * result.confidence, height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: – σ relative to τ bar

    private var sigmaBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("σ relative to threshold τ")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let w = geo.size.width
                // τ at 1/3 of bar; 2τ at 2/3; display σ clamped to bar width
                let tauX  = w / 3
                let tau2X = w * 2 / 3
                let sigX  = min(w, w * CGFloat(result.sigma / (result.threshold * 3.0)))

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 12)

                    // Colored zones: ON | OFF | Tremor
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.green.opacity(0.25))
                            .frame(width: tauX, height: 12)
                        Rectangle().fill(Color.orange.opacity(0.25))
                            .frame(width: tauX, height: 12)
                        Rectangle().fill(Color.red.opacity(0.25))
                            .frame(maxWidth: .infinity, maxHeight: 12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                    // τ marker
                    Rectangle()
                        .fill(Color.indigo.opacity(0.6))
                        .frame(width: 2, height: 18)
                        .offset(x: tauX - 1)

                    // 2τ marker
                    Rectangle()
                        .fill(Color.indigo.opacity(0.4))
                        .frame(width: 2, height: 14)
                        .offset(x: tau2X - 1)

                    // σ dot
                    Circle()
                        .fill(sigmaColor)
                        .frame(width: 16, height: 16)
                        .shadow(color: sigmaColor.opacity(0.4), radius: 4)
                        .offset(x: sigX - 8)
                }
            }
            .frame(height: 18)

            HStack {
                Label("ON", systemImage: "")
                    .font(.system(size: 9)).foregroundStyle(.green)
                Spacer()
                Text("τ").font(.system(size: 9, design: .monospaced)).foregroundStyle(.indigo)
                Spacer()
                Text("2τ").font(.system(size: 9, design: .monospaced)).foregroundStyle(.indigo)
                Spacer()
                Label("Tremor", systemImage: "")
                    .font(.system(size: 9)).foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: – ML explanation

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Agent Explanation", systemImage: "text.bubble.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.purple)
            Text(result.mlExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: – Voice explanation

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Voice Report", systemImage: "speaker.wave.2.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.teal)
            Text(result.voiceExplanation)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.teal.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: – Helpers

    private var heroColors: [Color] {
        switch result.state {
        case .on:      return [.green,  .teal]
        case .off:     return [.orange, .yellow]
        case .tremor:  return [.red,    .pink]
        case .unknown: return [.gray,   Color(.systemGray3)]
        }
    }

    private var sigmaColor: Color {
        switch result.state {
        case .on:      return .green
        case .off:     return .orange
        case .tremor:  return .red
        case .unknown: return .gray
        }
    }

    private var confidenceColor: Color {
        switch result.confidence {
        case 0.80...: return .green
        case 0.60...: return .orange
        default:      return .red
        }
    }
}

#Preview {
    AssessmentResultSheet(result: AssessmentResult(
        state: .tremor,
        sigma: 0.312,
        threshold: 0.185,
        voiceExplanation: "Tremor activity has been detected. Your motion variability is 0.31, above your baseline of 0.19. Please rest if possible.",
        confidence: 0.87,
        mlExplanation: "σ_w=0.297 > 2τ=0.370 → Tremor. Confidence: sigmoid(18 × min(0.065, 0.073))=0.87."
    ))
}
