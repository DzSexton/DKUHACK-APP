import SwiftUI

/// Allows users to adjust their personalised threshold (τ) and run a
/// calibration session.
struct SettingsView: View {
    @EnvironmentObject var viewModel: MainViewModel

    @State private var thresholdSlider: Double = 0.60
    @State private var isCalibrating = false
    @State private var calibrationProgress: Double = 0.0

    var body: some View {
        NavigationStack {
            Form {
                // MARK: – Profile section
                Section {
                    profileRow
                } header: {
                    Text("User Profile")
                }

                // MARK: – Threshold section
                Section {
                    thresholdRow
                    calibrationButton
                } header: {
                    Text("Personalised Threshold (τ)")
                } footer: {
                    Text("τ is the variability boundary used to classify your motor state. "
                       + "Use the calibration button to derive it automatically from your "
                       + "current baseline, or adjust it manually.")
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
                    LabeledContent("App", value: "AuraPD-Voice")
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Framework", value: "CoreMotion · Speech · AVFoundation")
                    LabeledContent("Processing", value: "100% On-Device")
                }
            }
            .navigationTitle("Settings")
            .dynamicTypeSize(.large ... .accessibility5)
            .onAppear { thresholdSlider = viewModel.userProfile.varianceThreshold }
        }
    }

    // MARK: – Sub-views

    private var profileRow: some View {
        LabeledContent("Calibration status") {
            Text(viewModel.userProfile.isCalibrated ? "Calibrated ✓" : "Default (uncalibrated)")
                .foregroundStyle(viewModel.userProfile.isCalibrated ? .green : .orange)
        }
    }

    private var thresholdRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("τ = \(String(format: "%.2f", thresholdSlider))")
                    .font(.headline.monospacedDigit())
                Spacer()
                Button("Apply") {
                    viewModel.userProfile.varianceThreshold = thresholdSlider
                    LocalStorageService.shared.saveUserProfile(viewModel.userProfile)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)
                .accessibilityLabel("Apply threshold")
                .accessibilityHint("Saves the displayed personalised threshold value.")
            }
            Slider(value: $thresholdSlider, in: 0.10...2.00, step: 0.01)
                .tint(.purple)
                .accessibilityLabel("Personalised threshold slider")
        }
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

    /// Starts a 10-second baseline capture to derive τ automatically.
    private func startCalibration() {
        isCalibrating = true
        calibrationProgress = 0.0
        viewModel.beginCalibrationFlow(duration: 10.0) { progress in
            DispatchQueue.main.async { self.calibrationProgress = progress }
        } onCompletion: { success in
            DispatchQueue.main.async {
                if success {
                    self.thresholdSlider = self.viewModel.userProfile.varianceThreshold
                }
                self.isCalibrating = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MainViewModel())
}
