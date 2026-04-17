import SwiftUI

// MARK: - InsightView

struct InsightView: View {

    @EnvironmentObject var viewModel: MainViewModel
    @State private var showProfileSheet = false
    @State private var isCalculating    = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !viewModel.matchCalculated {
                        if viewModel.userProfile.isReadyForMatching {
                            MatchReadyBanner(isCalculating: $isCalculating) {
                                startCalculation()
                            }
                        } else {
                            MatchLockedBanner {
                                showProfileSheet = true
                            }
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.patientProfiles) { profile in
                            NavigationLink(
                                destination: PatientProfileDetailView(profile: profile)
                            ) {
                                ProfileCard(
                                    profile:   profile,
                                    showMatch: viewModel.matchCalculated
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.matchCalculated)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: viewModel.matchCalculated)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Patient Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !viewModel.matchCalculated {
                            Button {
                                fillDemoProfile()
                            } label: {
                                Label("Demo", systemImage: "wand.and.stars")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        Button { showProfileSheet = true } label: {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.indigo)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(viewModel.patientProfiles.count) patients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showProfileSheet) {
                UserProfileEditSheet(profile: $viewModel.userProfile) {
                    LocalStorageService.shared.saveUserProfile(viewModel.userProfile)
                }
            }
        }
    }

    private func fillDemoProfile() {
        let currentYear = Calendar.current.component(.year, from: Date())
        viewModel.userProfile.displayName      = "Demo User"
        viewModel.userProfile.biologicalSex    = "Male"
        viewModel.userProfile.birthYear        = currentYear - 66
        viewModel.userProfile.diagnosisYear    = currentYear - 4
        viewModel.userProfile.conditionSummary = "Stable — good motor control"
        LocalStorageService.shared.saveUserProfile(viewModel.userProfile)
        startCalculation()
    }

    private func startCalculation() {
        isCalculating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isCalculating = false
                viewModel.matchCalculated = true
            }
        }
    }
}

// MARK: - MatchLockedBanner

private struct MatchLockedBanner: View {
    let onTapFill: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(Color(.tertiaryLabel))

            VStack(alignment: .leading, spacing: 3) {
                Text("Fill in your profile to unlock match scores")
                    .font(.subheadline.bold())
                Text("Complete your profile so the system can calculate reference match scores for each patient.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button(action: onTapFill) {
                Text("Fill In")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.indigo.opacity(0.12))
                    .foregroundStyle(.indigo)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }
}

// MARK: - MatchReadyBanner

private struct MatchReadyBanner: View {
    @Binding var isCalculating: Bool
    let onCalculate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Profile Ready")
                        .font(.subheadline.bold())
                    Text("The system will calculate reference match scores for each patient based on your profile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button(action: onCalculate) {
                Group {
                    if isCalculating {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white).scaleEffect(0.85)
                            Text("Calculating...")
                        }
                    } else {
                        Label("Calculate Matches", systemImage: "waveform.badge.magnifyingglass")
                    }
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isCalculating ? Color.indigo.opacity(0.6) : Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .animation(.easeInOut(duration: 0.2), value: isCalculating)
            }
            .disabled(isCalculating)
        }
        .padding(14)
        .background(Color.indigo.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - ProfileCard

private struct ProfileCard: View {
    let profile:   PatientProfile
    let showMatch: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            LinearGradient(
                colors: showMatch
                    ? matchGradient(profile.matchPercentage)
                    : [Color(.systemGray4), Color(.systemGray3)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 4)

            VStack(alignment: .leading, spacing: 8) {

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(profile.displayTitle)
                        .font(.subheadline.bold())
                    Spacer()
                    Text("age \(profile.age)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .leading) {
                    if showMatch {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(profile.matchPercentage)")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(matchColor(profile.matchPercentage))
                            Text("%")
                                .font(.headline.bold())
                                .foregroundStyle(matchColor(profile.matchPercentage).opacity(0.7))
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7, anchor: .leading).combined(with: .opacity),
                            removal:   .opacity
                        ))
                    } else {
                        Text("?")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .transition(.opacity)
                    }
                }
                .frame(height: 40, alignment: .bottomLeading)

                Text("Reference Match")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider()

                // Symptom tags — short chips replacing the long description paragraph
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(profile.symptomTags.prefix(3), id: \.self) { tag in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(showMatch ? matchColor(profile.matchPercentage).opacity(0.55) : Color(.systemGray4))
                                .frame(width: 5, height: 5)
                            Text(tag)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .opacity(showMatch ? 1.0 : 0.72)
    }

    private func matchColor(_ pct: Int) -> Color {
        switch pct {
        case 85...: return .purple
        case 75...: return .indigo
        default:    return .blue
        }
    }

    private func matchGradient(_ pct: Int) -> [Color] {
        switch pct {
        case 85...: return [.purple, .indigo]
        case 75...: return [.indigo, .blue]
        default:    return [.blue, .teal]
        }
    }
}

// MARK: - UserProfileEditSheet

struct UserProfileEditSheet: View {

    @Binding var profile: UserProfile
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let genderOptions = ["Not set", "Male", "Female", "Other"]
    private let currentYear   = Calendar.current.component(.year, from: Date())

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    HStack {
                        Text("Name / Alias")
                        Spacer()
                        TextField("Anonymous", text: $profile.displayName)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Sex", selection: $profile.biologicalSex) {
                        ForEach(genderOptions, id: \.self) { Text($0) }
                    }

                    HStack {
                        Text("Birth Year")
                        Spacer()
                        Picker("Birth Year", selection: Binding(
                            get: { profile.birthYear ?? currentYear - 60 },
                            set: { profile.birthYear = $0 }
                        )) {
                            ForEach((1930...(currentYear - 10)).reversed(), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("Diagnosis Year")
                        Spacer()
                        Picker("Diagnosis Year", selection: Binding(
                            get: { profile.diagnosisYear ?? currentYear },
                            set: { profile.diagnosisYear = $0 }
                        )) {
                            ForEach((1980...currentYear).reversed(), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                Section("Calculated") {
                    HStack {
                        Text("Age")
                        Spacer()
                        Text(profile.ageDisplay)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(profile.diagnosisDurationDisplay)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Current Condition") {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(.indigo)
                            .padding(.top, 2)
                        Text(profile.conditionSummary)
                            .font(.subheadline)
                    }
                    Text("This field is updated automatically after each assessment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if profile.isCalibrated {
                    Section("Calibration Status") {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Personalised calibration complete")
                        }
                        if let date = profile.lastCalibrationDate {
                            HStack {
                                Text("Last Calibration")
                                Spacer()
                                Text(date, style: .date)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    InsightView()
        .environmentObject(MainViewModel())
}
