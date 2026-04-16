import SwiftUI

/// Primary screen showing the current motor state, status messages,
/// and the voice / touch trigger to start an assessment.
struct DashboardView: View {
    @EnvironmentObject var viewModel:    MainViewModel
    @EnvironmentObject var appViewModel: AppViewModel   // 全局状态联动

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

                VStack(spacing: 32) {
                    // MARK: – Header
                    headerSection

                    // MARK: – State indicator
                    stateIndicatorSection

                    // MARK: – Status message
                    statusMessageSection

                    Spacer()

                    // MARK: – Consent / capturing progress
                    if viewModel.appState != .idle {
                        progressSection
                    }

                    // MARK: – Trigger button (fallback touch input)
                    triggerButton

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
            .navigationBarHidden(true)
        }
        // 当 MainViewModel 完成评估回到 idle 时，同步停止全局监测
        .onChange(of: viewModel.appState) { _, newState in
            if newState == .idle { appViewModel.stopChecking() }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Virtual avatar showing current motor state: \(state.displayName)")

            Text(state.displayName)
                .font(.title2.bold())
                .foregroundStyle(stateColor(state))

            if let result = viewModel.latestResult {
                HStack(spacing: 16) {
                    metricBadge(label: "σ", value: String(format: "%.3f", result.sigma))
                    metricBadge(label: "τ", value: String(format: "%.3f", result.threshold))
                }
            }
        }
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

    private var triggerButton: some View {
        Button {
            viewModel.beginAssessmentFlow()
            appViewModel.startChecking()   // 同步触发全局状态 → Timeline 联动
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
        .accessibilityHint("Large single-tap fallback for users who prefer not to use voice.")
    }

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Voice recognition unavailable. Download the English offline speech model in Settings.")
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
}

#Preview {
    DashboardView()
        .environmentObject(MainViewModel())
}
