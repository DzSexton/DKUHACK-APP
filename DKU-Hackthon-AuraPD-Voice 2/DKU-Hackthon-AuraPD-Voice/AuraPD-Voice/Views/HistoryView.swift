import SwiftUI

/// Displays a chronological list of all past motor-state assessments stored on device.
struct HistoryView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.assessmentHistory.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Assessment History")
            .dynamicTypeSize(.large ... .accessibility5)
            .toolbar {
                if !viewModel.assessmentHistory.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear", role: .destructive) {
                            showClearConfirm = true
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear all history?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) { viewModel.clearHistory() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: – Sub-views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No assessments yet")
                .font(.headline)
            Text("Trigger an assessment from the Dashboard\nor say \"Check my condition\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var list: some View {
        List(viewModel.assessmentHistory) { result in
            HistoryRowView(result: result)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: – Row view

struct HistoryRowView: View {
    let result: AssessmentResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: result.state.symbolName)
                    .foregroundStyle(stateColor)
                Text(result.state.displayName)
                    .font(.headline)
                    .foregroundStyle(stateColor)
                Spacer()
                Text(result.formattedTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                label("σ", value: String(format: "%.3f", result.sigma))
                label("τ", value: String(format: "%.3f", result.threshold))
            }

            Text(result.voiceExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(result.state.displayName). " +
            "Sigma \(String(format: "%.3f", result.sigma)). " +
            "Threshold \(String(format: "%.3f", result.threshold)). " +
            "Recorded \(result.formattedTimestamp)."
        )
    }

    private func label(_ key: String, value: String) -> some View {
        Text("\(key): \(value)")
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
    }

    private var stateColor: Color {
        switch result.state {
        case .on:      return .green
        case .off:     return .orange
        case .tremor:  return .red
        case .unknown: return .gray
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(MainViewModel())
}
