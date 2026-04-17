import SwiftUI

/// Root navigation view.  Presents the Dashboard as the primary screen and
/// provides tab navigation to Settings and History.
struct ContentView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var selectedTab = 0
    @State private var showCalibrationPrompt = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "waveform.path.ecg.rectangle")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet.clipboard")
                }
                .tag(1)

            InsightView()
                .tabItem {
                    Label("Insight", systemImage: "brain.head.profile")
                }
                .tag(2)

            TimelinePlaybackView()
                .tabItem {
                    Label("Timeline", systemImage: "timeline.selection")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(.purple)
        .sheet(isPresented: $showCalibrationPrompt) {
            CalibrationPromptSheet {
                showCalibrationPrompt = false
                selectedTab = 4   // navigate to Settings (now tab 4)
            }
        }
        .onAppear {
            if !viewModel.userProfile.isCalibrated {
                showCalibrationPrompt = true
            }
        }
    }
}

/// One-time sheet shown on first launch to prompt the user to calibrate.
private struct CalibrationPromptSheet: View {
    let onGoToSettings: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.indigo)

            VStack(spacing: 10) {
                Text("Calibration Recommended")
                    .font(.title2.bold())

                Text(
                    "AuraPD Voice uses a personalised threshold to classify your motor state. "
                  + "Default value of τ = 0.60 is used, which may not reflect "
                  + "your individual baseline."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button("Go to Settings") {
                    onGoToSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.large)

                Button("Use Default") {
                    onGoToSettings()   // dismisses the sheet without switching tab
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}

#Preview {
    ContentView()
        .environmentObject(MainViewModel())
}
