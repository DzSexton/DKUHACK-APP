import SwiftUI

/// Primary screen showing the current motor state, status messages,
/// and the voice / touch trigger to start an assessment.
/// Includes a 🧠 feedback loop for the adaptive PDMonitoringAgent.
struct DashboardView: View {
    @EnvironmentObject var viewModel:    MainViewModel
    @EnvironmentObject var appViewModel: AppViewModel

    @State private var feedbackSubmitted: Bool = false
    @State private var feedbackBounce: Bool = false
    /// Result sheet — shown whenever a new assessment result arrives
    @State private var showResultSheet: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color.purple.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: – Header
                        headerSection

                        // MARK: – State indicator + confidence
                        stateIndicatorSection

                        // MARK: – 🧠 ML Explanation card
                        if let result = viewModel.latestResult, !result.mlExplanation.isEmpty {
                            mlExplanationCard(result: result)
                        }

                        // MARK: – Status message
                        statusMessageSection

                        // MARK: – Consent / capturing progress
                        if viewModel.appState != .idle {
                            progressSection
                        }

                        if viewModel.latestResult != nil && viewModel.appState == .idle {
                            feedbackSection
                        }

                        // MARK: – Trigger button
                        triggerButton

                        demoButton

                        // MARK: – 🧠 Agent accuracy bar
                        agentAccuracyPanel

                        // MARK: – Recognizer unavailable banner
                        if !viewModel.isRecognizerAvailable {
                            recognizerUnavailableBanner
                        }

                        // MARK: – Wake-word indicator
                        wakeWordIndicator

                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 24)
                    .dynamicTypeSize(.large ... .accessibility5)
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: viewModel.appState) { _, newState in
            switch newState {
            case .capturing: appViewModel.startChecking()
            case .idle:      appViewModel.stopChecking()
            default:         break
            }
        }
        .onChange(of: viewModel.tremorOffset) { _, offset in
            guard viewModel.appState == .capturing else { return }
            let magnitude = hypot(offset.width, offset.height) / 28.0  // undo 28 px/g scale → g
            appViewModel.liveTremorIntensity = max(0.0, min(1.0, magnitude * 2.5))
        }
        // New result → reset feedback flag + show result sheet
        .onChange(of: viewModel.latestResult?.id) { _, _ in
            feedbackSubmitted = false
            if viewModel.latestResult != nil {
                showResultSheet = true
            }
        }
        .sheet(isPresented: $showResultSheet) {
            if let result = viewModel.latestResult {
                AssessmentResultSheet(result: result)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: – Sub-views

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("AuraPD Voice")
                .font(.largeTitle.bold())
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                )
            Text("On-Device PD Motor State Monitor")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AuraPD Voice. On-device Parkinson's motor state monitor.")
    }

    private var stateIndicatorSection: some View {
        VStack(spacing: 8) {
            let state = viewModel.latestResult?.state ?? .unknown

            HumanAvatarView(
                tremorOffset: viewModel.tremorOffset,
                state: state,
                isCapturing: viewModel.appState == .capturing
            )
            // Hidden demo trigger: triple-tap the avatar to run a full voice-first
            // assessment without needing the microphone (demo-night safety net).
            .onTapGesture(count: 3) {
                viewModel.beginDemoAssessment()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Virtual avatar showing current motor state: \(state.displayName)")

            Text(state.displayName)
                .font(.title2.bold())
                .foregroundStyle(stateColor(state))

            if let result = viewModel.latestResult {
                HStack(spacing: 12) {
                    metricBadge(label: "σ", value: String(format: "%.3f", result.sigma))
                    metricBadge(label: "τ", value: String(format: "%.3f", result.threshold))
                    confidenceBadge(value: result.confidence)
                }
            }
        }
    }

    private func confidenceBadge(value: Double) -> some View {
        VStack(spacing: 2) {
            Text("Confidence")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(value * 100))%")
                .font(.headline.monospacedDigit())
                .foregroundStyle(confidenceColor(value))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(confidenceColor(value).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func mlExplanationCard(result: AssessmentResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("Agent Explanation")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
                Spacer()
                Text("τ_adaptive = 0.65·τ_u + 0.35·τ_base")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(result.mlExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: result.id)
    }

    private var statusMessageSection: some View {
        Text(viewModel.statusMessage)
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .animation(.easeInOut, value: viewModel.statusMessage)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.purple)
            Text(viewModel.appState.rawValue)
                .font(.caption)
                .foregroundStyle(.purple)
        }
    }

    // MARK: – Feedback Section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("Agent Analysis — please confirm")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.purple)
            }

            if let prediction = viewModel.agent.lastPrediction {
                Text(prediction.hypothesis)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)

                VStack(spacing: 8) {
                    ForEach(prediction.options) { option in
                        optionButton(option: option)
                    }
                }
            }

            if feedbackSubmitted {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Model updated", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(String(format: "τ_base=%.4f  w=[%.2f, %.2f, %.2f]",
                                viewModel.agent.baseThreshold,
                                viewModel.agent.featureWeights[0],
                                viewModel.agent.featureWeights[1],
                                viewModel.agent.featureWeights[2]))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(14)
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: feedbackSubmitted)
    }

    private func optionButton(option: HypothesisOption) -> some View {
        Button {
            guard !feedbackSubmitted else { return }
            feedbackSubmitted = true
            viewModel.submitFeedback(correct: option.isConfirmation)
        } label: {
            HStack(spacing: 10) {
                Text(option.emoji)
                    .font(.body)
                Text(option.label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if !feedbackSubmitted {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                option.isConfirmation
                    ? Color.purple.opacity(feedbackSubmitted ? 0.04 : 0.08)
                    : Color(.tertiarySystemFill)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(feedbackSubmitted)
    }

    // MARK: – Trigger button

    private var triggerButton: some View {
        Button {
            viewModel.beginAssessmentFlow()
            appViewModel.startChecking()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.appState == .idle ? "mic.circle.fill" : "hourglass")
                    .font(.title2)
                Text(viewModel.appState == .idle ? "Check Now" : "In Progress…")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .padding(.vertical, 8)
            .background(
                viewModel.appState == .idle ? Color.purple : Color.gray.opacity(0.4)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
        }
        .disabled(viewModel.appState != .idle)
        .accessibilityLabel(viewModel.appState == .idle ? "Check my condition now" : "Assessment in progress")
    }

    // MARK: – Agent Accuracy Panel

    private var agentAccuracyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(.indigo)
                    .font(.subheadline)
                Text("PDMonitoringAgent Accuracy")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
                Spacer()
                Text(String(format: "%.1f%%", viewModel.agent.currentAccuracy * 100))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(accuracyColor(viewModel.agent.currentAccuracy))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.indigo, accuracyColor(viewModel.agent.currentAccuracy)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * viewModel.agent.currentAccuracy, height: 10)
                        .animation(.spring(response: 0.5), value: viewModel.agent.currentAccuracy)
                }
            }
            .frame(height: 10)

            HStack {
                Text("Feedback: \(viewModel.agent.feedbackCount) · Confirmed: \(viewModel.agent.confirmedCorrectCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("EMA: acc ← acc·(1−α·β) + y·(α·β)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if viewModel.agent.accuracyHistory.count > 1 {
                SparklineView(values: viewModel.agent.accuracyHistory)
                    .frame(height: 28)
                    .padding(.top, 2)
            }

            if let s = viewModel.agent.lastEmaSteps {
                Text(emaFormulaString(s))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.indigo.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                    .animation(.easeIn(duration: 0.2), value: viewModel.agent.feedbackCount)
            }
        }
        .padding(14)
        .background(Color.indigo.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – Demo button

    private var demoButton: some View {
        Button {
            viewModel.injectMockResult()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.caption.bold())
                Text("Demo: Inject Mock Prediction")
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.indigo.opacity(0.10))
            .foregroundStyle(.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.indigo.opacity(0.25), lineWidth: 1)
            )
        }
        .disabled(viewModel.appState != .idle)
        .accessibilityLabel("Demo mode: inject mock prediction result")
    }

    // MARK: – Recognizer unavailable banner

    private var recognizerUnavailableBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice recognition unavailable")
                    .font(.caption.bold())
                Text("Download the English offline speech model in\nSettings → Accessibility → Spoken Content → Voices.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var wakeWordIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isListeningForWakeWord ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.4), lineWidth: viewModel.isListeningForWakeWord ? 4 : 0)
                )
            Text(viewModel.isListeningForWakeWord
                 ? "Listening for \"Check my condition\""
                 : viewModel.isRecognizerAvailable
                     ? "Wake-word detection paused"
                     : "Wake-word unavailable")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: – Helpers

    private func metricBadge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stateColor(_ state: MotorState) -> Color {
        switch state {
        case .on:      return .green
        case .off:     return .orange
        case .tremor:  return .red
        case .unknown: return .gray
        }
    }

    private func confidenceColor(_ v: Double) -> Color {
        switch v {
        case 0.80...: return .green
        case 0.60...: return .orange
        default:      return .red
        }
    }

    private func emaFormulaString(_ s: PDMonitoringAgent.EmaSteps) -> String {
        String(format: "acc: %.3f × %.3f + %.1f × %.3f = %.3f",
               s.accBefore, s.decay, s.y, s.emaRate, s.accAfter)
    }

    private func accuracyColor(_ v: Double) -> Color {
        switch v {
        case 0.80...: return .green
        case 0.60...: return .orange
        default:      return .red
        }
    }
}

// MARK: – SparklineView

private struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minV = values.min() ?? 0
            let maxV = max((values.max() ?? 1), minV + 0.001)

            ZStack {
                Path { p in
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                        let y = h * (1 - CGFloat((v - minV) / (maxV - minV)))
                        if i == 0 { p.move(to: .init(x: x, y: y)) }
                        else       { p.addLine(to: .init(x: x, y: y)) }
                    }
                    if let last = values.last {
                        let lx = w
                        let ly = h * (1 - CGFloat((last - minV) / (maxV - minV)))
                        p.addLine(to: .init(x: lx, y: ly))
                    }
                    p.addLine(to: .init(x: w, y: h))
                    p.addLine(to: .init(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [Color.indigo.opacity(0.18), .clear],
                    startPoint: .top, endPoint: .bottom
                ))

                Path { p in
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                        let y = h * (1 - CGFloat((v - minV) / (maxV - minV)))
                        if i == 0 { p.move(to: .init(x: x, y: y)) }
                        else       { p.addLine(to: .init(x: x, y: y)) }
                    }
                }
                .stroke(Color.indigo.opacity(0.8),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(MainViewModel())
        .environmentObject(AppViewModel())
}
