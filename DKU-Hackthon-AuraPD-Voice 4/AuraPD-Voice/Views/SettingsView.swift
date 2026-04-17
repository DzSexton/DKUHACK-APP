import SwiftUI

/// Allows users to adjust their personalised threshold (τ) and run a
/// calibration session.
struct SettingsView: View {
    @EnvironmentObject var viewModel: MainViewModel

    @State private var isCalibrating        = false
    @State private var calibrationProgress: Double = 0.0

    var body: some View {
        NavigationStack {
            Form {
                // MARK: – Profile section
                Section("User Profile") {
                    profileRow
                }

                // MARK: – Threshold section
                Section {
                    thresholdSliderRow
                    agentThresholdInfoRow
                    calibrationButton
                } header: {
                    Text("Personalised Threshold (τ)")
                } footer: {
                    Text("τ_user is your manually-set boundary. "
                       + "The Agent blends it with its learned τ_base "
                       + "(0.65 × τ_user + 0.35 × τ_base) before every assessment. "
                       + "Both values update live.")
                        .font(.caption)
                }

                // MARK: – Privacy section
                Section {
                    privacyInfo
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("All motion data is processed exclusively on this device. "
                       + "No raw sensor data is ever transmitted externally.")
                        .font(.caption)
                }

                // MARK: – About section
                Section("About") {
                    LabeledContent("App",        value: "AuraPD-Voice")
                    LabeledContent("Version",    value: "1.0.0")
                    LabeledContent("Framework",  value: "CoreMotion · Speech · AVFoundation")
                    LabeledContent("Processing", value: "100% On-Device")
                }
            }
            .navigationTitle("Settings")
            .dynamicTypeSize(.large ... .accessibility5)
            // Auto-persist whenever the slider is released / value committed
            .onChange(of: viewModel.userProfile.varianceThreshold) { _, _ in
                LocalStorageService.shared.saveUserProfile(viewModel.userProfile)
            }
        }
    }

    // MARK: – Sub-views

    private var profileRow: some View {
        LabeledContent("Calibration status") {
            Text(viewModel.userProfile.isCalibrated ? "Calibrated ✓" : "Default (uncalibrated)")
                .foregroundStyle(viewModel.userProfile.isCalibrated ? .green : .orange)
        }
    }

    /// Slider bound directly to `viewModel.userProfile.varianceThreshold`.
    /// Any change is immediately visible in Dashboard without tapping "Apply".
    private var thresholdSliderRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("τ_user")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", viewModel.userProfile.varianceThreshold))
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15),
                               value: viewModel.userProfile.varianceThreshold)
            }
            Slider(
                value: $viewModel.userProfile.varianceThreshold,
                in: 0.10...2.00,
                step: 0.01
            )
            .tint(.purple)
            .accessibilityLabel("Personalised threshold slider")
        }
    }

    /// Live read-only display of the Agent's adaptive threshold and its learned base.
    /// Reacts automatically to feedback from the Dashboard — no page reload needed.
    private var agentThresholdInfoRow: some View {
        VStack(spacing: 6) {
            HStack {
                Label("τ_adaptive (effective)", systemImage: "brain")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                Spacer()
                Text(String(format: "%.4f", viewModel.currentAdaptiveThreshold))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.indigo)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2),
                               value: viewModel.currentAdaptiveThreshold)
            }
            HStack {
                Text("τ_base (Agent self-learning)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.4f", viewModel.agent.baseThreshold))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2),
                               value: viewModel.agent.baseThreshold)
            }
            HStack {
                Text("0.65 × τ_user  +  0.35 × τ_base")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(.tertiaryLabel))
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    private var calibrationButton: some View {
        VStack(spacing: 8) {
            Button {
                startCalibration()
            } label: {
                HStack {
                    if isCalibrating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Calibrating… \(Int(calibrationProgress * 100))%")
                    } else {
                        Image(systemName: "wand.and.sparkles")
                        Text("Auto-Calibrate from Baseline")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(isCalibrating ? .gray : .indigo)
            .disabled(isCalibrating)
            .accessibilityLabel(isCalibrating ? "Calibration in progress" : "Auto calibrate from baseline")
            .accessibilityHint("Starts a consent-gated baseline capture to personalize your threshold.")

            if viewModel.userProfile.isCalibrated,
               let date = viewModel.userProfile.lastCalibrationDate {
                Text("Last calibrated: \(date, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacyInfo: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text("On-Device Only")
                    .font(.subheadline.bold())
                Text("Motion data never leaves your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: – Calibration logic

    private func startCalibration() {
        isCalibrating = true
        calibrationProgress = 0.0
        viewModel.beginCalibrationFlow(duration: 10.0) { progress in
            DispatchQueue.main.async { self.calibrationProgress = progress }
        } onCompletion: { success in
            DispatchQueue.main.async {
                // viewModel.userProfile.varianceThreshold was already updated inside
                // recalibrate(); the Slider binding picks it up automatically.
                self.isCalibrating = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MainViewModel())
}
