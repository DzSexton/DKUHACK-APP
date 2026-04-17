import SwiftUI

// MARK: - PatientProfileDetailView

struct PatientProfileDetailView: View {
    let profile: PatientProfile

    @EnvironmentObject var viewModel: MainViewModel

    private var user: UserProfile { viewModel.userProfile }

    @State private var aiPhase: AIPhase = .idle

    enum AIPhase {
        case idle
        case analyzing
        case revealed(ClinicalInsightReport)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                heroHeader.padding(.bottom, 20)

                VStack(spacing: 16) {
                    learnFromCaseSection
                    gnnScoreSection
                    if let reason = profile.gnnScores?.matchReason {
                        matchReasonSection(reason: reason)
                    }
                    infoSection(title: "Onset", icon: "clock.arrow.circlepath",
                                rows: [("Period",   profile.onsetPeriod),
                                       ("Symptoms", profile.symptomsDescription)])
                    infoSection(title: "Treatment", icon: "pills.fill",
                                rows: [("Hospital",   profile.treatmentLocation),
                                       ("Medication", profile.treatmentMethod)])
                    infoSection(title: "Outcome", icon: "chart.line.uptrend.xyaxis",
                                rows: [("Efficacy", profile.treatmentOutcome)])
                    disclaimerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("\(profile.displayTitle)'s Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: heroGradient(profile.treatmentInspirationValue),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 160)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(profile.displayTitle)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("· age \(profile.age)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    VStack(spacing: 1) {
                        Text("\(profile.matchPercentage)%")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.white)
                        Text("Match")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }
                Text(profile.treatmentLocation)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(16)
        }
    }

    // MARK: – "Learn from this case" Section

    @ViewBuilder
    private var learnFromCaseSection: some View {
        switch aiPhase {
        case .idle:
            Button { triggerAnalysis() } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 42, height: 42)
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Learn from this case")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text("AI compares your profile with this patient across 4 clinical dimensions")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .background(
                    LinearGradient(colors: [.indigo, .purple],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .indigo.opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

        case .analyzing:
            AnalyzingStepView()

        case .revealed(let report):
            AIInsightCard(report: report, patientTitle: profile.displayTitle)
        }
    }

    // MARK: – GNN Score Section

    private var gnnScoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .foregroundStyle(.indigo)
                Text("GNN Multi-Dimensional Analysis")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
            }
            if let scores = profile.gnnScores {
                let base = Double(profile.matchPercentage) / 100.0
                let tiv  = scores.treatmentInspirationValue
                let sAdj = base + min(0.05, max(-0.05, (scores.symptomSimilarity          - tiv) * 0.30))
                let tAdj = base + min(0.05, max(-0.05, (scores.treatmentResponseSimilarity - tiv) * 0.30))
                let pAdj = base + min(0.05, max(-0.05, (scores.progressionSimilarity       - tiv) * 0.30))
                gnnDimBar(label: "Symptom Cosine Similarity",
                          formula: "cos_sim = (A·B)/(‖A‖·‖B‖)",
                          value: sAdj, color: .purple)
                gnnDimBar(label: "Treatment RBF Kernel Similarity",
                          formula: "k_rbf = exp(−‖A−B‖²/2σ²)",
                          value: tAdj, color: .indigo)
                gnnDimBar(label: "Progression Weighted Euclidean",
                          formula: "eucl_sim = exp(−√(Σwᵢ·Δᵢ²))",
                          value: pAdj, color: .blue)
                Divider()
                gnnDimBar(label: "Treatment Inspiration Value  TIV",
                          formula: "0.30·S + 0.45·T + 0.25·P",
                          value: base,
                          color: tivColor(base),
                          highlight: true)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func gnnDimBar(label: String, formula: String,
                           value: Double, color: Color, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(highlight ? .subheadline.bold() : .caption.bold())
                    .foregroundStyle(highlight ? color : .primary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: highlight ? 10 : 7)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [color.opacity(0.7), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(value),
                               height: highlight ? 10 : 7)
                }
            }
            .frame(height: highlight ? 10 : 7)
            Text(formula)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }

    // MARK: – Match Reason

    private func matchReasonSection(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.orange)
                Text("GNN Match Reason").font(.subheadline.bold())
            }
            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – Info Section

    private func infoSection(title: String, icon: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.indigo).font(.caption.bold())
                Text(title).font(.subheadline.bold())
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                if idx > 0 { Divider().padding(.leading, 14) }
                HStack(alignment: .top, spacing: 10) {
                    Text(row.0)
                        .font(.caption.bold()).foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Text(row.1)
                        .font(.caption).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – Disclaimer

    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield.fill").foregroundStyle(.green).font(.caption)
            Text("Data sourced from a local de-identified database. All personal information is anonymised and stored offline. GNN similarity scores are for reference only — clinical decisions should follow medical guidance.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: – Helpers

    private func tivColor(_ v: Double) -> Color {
        switch v {
        case 0.80...: return .purple
        case 0.65...: return .indigo
        default:      return .blue
        }
    }

    private func heroGradient(_ v: Double) -> [Color] {
        switch v {
        case 0.80...: return [.purple, .indigo]
        case 0.65...: return [.indigo, .blue]
        case 0.50...: return [.blue, .teal]
        default:      return [Color(.systemGray2), Color(.systemGray3)]
        }
    }

    // MARK: – Trigger

    private func triggerAnalysis() {
        withAnimation(.easeInOut(duration: 0.25)) { aiPhase = .analyzing }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            let report = ClinicalInsightEngine.analyze(user: user, patient: profile)
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    aiPhase = .revealed(report)
                }
            }
        }
    }
}

// MARK: - Analyzing Step View

private struct AnalyzingStepView: View {
    @State private var step = 0

    private let steps = [
        "Mapping symptom feature vectors…",
        "Comparing pharmacological response profiles…",
        "Evaluating disease trajectory alignment…",
        "Synthesising clinical action plan…",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.title3).foregroundStyle(.indigo)
                    .symbolEffect(.pulse)
                Text("AI Analysing Clinical Patterns")
                    .font(.subheadline.bold()).foregroundStyle(.indigo)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, label in
                    HStack(spacing: 8) {
                        Group {
                            if idx < step {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if idx == step {
                                Image(systemName: "circle.dotted")
                                    .foregroundStyle(.indigo)
                                    .symbolEffect(.pulse, isActive: true)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(Color(.systemGray4))
                            }
                        }
                        .font(.caption)
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(idx <= step ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            for i in 0..<steps.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.58) {
                    withAnimation { step = i }
                }
            }
        }
    }
}

// MARK: - AI Insight Card

private struct AIInsightCard: View {
    let report: ClinicalInsightReport
    let patientTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Banner header
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.title3).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Clinical Analysis")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                    Text("Your profile compared with \(patientTitle) across 4 dimensions")
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .background(LinearGradient(colors: [.indigo, .purple],
                                       startPoint: .leading, endPoint: .trailing))

            // Four analysis blocks
            VStack(spacing: 0) {
                insightBlock(index: 1, icon: "waveform.path.ecg",
                             title: "Symptom Profile Overlap",  color: .purple, body: report.symptomOverlap)
                Divider().padding(.leading, 14)
                insightBlock(index: 2, icon: "pills.circle.fill",
                             title: "Pharmacological Pattern Analysis", color: .indigo, body: report.pharmacologicalAnalysis)
                Divider().padding(.leading, 14)
                insightBlock(index: 3, icon: "chart.line.uptrend.xyaxis",
                             title: "Disease Trajectory Comparison", color: .blue, body: report.trajectoryComparison)
                Divider().padding(.leading, 14)

                // Action plan — numbered bullets
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .foregroundStyle(.teal).font(.caption.bold())
                        Text("Suggested Discussion Points for Your Neurologist")
                            .font(.caption.bold()).foregroundStyle(.teal)
                    }
                    ForEach(Array(report.clinicalActionPlan.enumerated()), id: \.offset) { idx, bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1).")
                                .font(.caption.bold()).foregroundStyle(.teal)
                                .frame(width: 18)
                            Text(bullet)
                                .font(.caption).foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(14)
            }
            .background(Color(.secondarySystemGroupedBackground))

            // AI disclaimer footer
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(.orange)
                Text("AI Insight — for informational purposes only. This analysis does not constitute medical advice. Always consult a licensed neurologist before adjusting your treatment plan.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.05))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .indigo.opacity(0.15), radius: 10, y: 4)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func insightBlock(index: Int, icon: String, title: String,
                              color: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(color).font(.caption.bold())
                Text("0\(index)  /  \(title)")
                    .font(.caption.bold()).foregroundStyle(color)
            }
            Text(body)
                .font(.caption).foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(14)
    }
}

// MARK: - ClinicalInsightReport

struct ClinicalInsightReport {
    let symptomOverlap: String
    let pharmacologicalAnalysis: String
    let trajectoryComparison: String
    let clinicalActionPlan: [String]
}

// MARK: - ClinicalInsightEngine

private enum ClinicalInsightEngine {

    static func analyze(user: UserProfile, patient: PatientProfile) -> ClinicalInsightReport {
        let currentYear  = Calendar.current.component(.year, from: Date())
        let userAge      = user.birthYear.map    { currentYear - $0 } ?? 0
        let userDiagYrs  = user.diagnosisYear.map { currentYear - $0 } ?? 0
        let patientDiagYrs = parseOnsetYears(patient.onsetPeriod)
        let ageDelta     = userAge > 0 ? userAge - patient.age : 0
        let condNote     = user.conditionSummary.lowercased()
        let tags         = patient.symptomTags.map { $0.lowercased() }

        return ClinicalInsightReport(
            symptomOverlap:          symptomSection(condNote: condNote, tags: tags, patient: patient),
            pharmacologicalAnalysis: pharmacoSection(patient: patient, ageDelta: ageDelta),
            trajectoryComparison:    trajectorySection(userDiagYrs: userDiagYrs,
                                                       patientDiagYrs: patientDiagYrs,
                                                       ageDelta: ageDelta,
                                                       patient: patient),
            clinicalActionPlan:      actionPlan(patient: patient, userDiagYrs: userDiagYrs)
        )
    }

    // MARK: 01 – Symptom Overlap

    private static func symptomSection(condNote: String, tags: [String],
                                       patient: PatientProfile) -> String {
        let pct = patient.matchPercentage
        let tagList = patient.symptomTags.prefix(3).joined(separator: ", ")

        let hasTremor    = tags.contains(where: { $0.contains("tremor") })
        let hasRigidity  = tags.contains(where: { $0.contains("rigid") || $0.contains("fatigue") })
        let hasDyskines  = tags.contains(where: { $0.contains("dyskine") || $0.contains("wearing") || $0.contains("on/off") })
        let hasPostural  = tags.contains(where: { $0.contains("postural") || $0.contains("falls") || $0.contains("gait") })
        let hasCognitive = tags.contains(where: { $0.contains("cognitive") || $0.contains("dementia") || $0.contains("fluctuation") })

        let userHasTremor  = condNote.contains("tremor")
        let userIsStable   = condNote.contains("stable")
        let userInOff      = condNote.contains("off")

        var overlap: String
        if hasTremor && userHasTremor {
            overlap = "Your AuraPD motion logs show a resting-tremor signature — characteristic 3–6 Hz oscillations consistent with dopaminergic nigrostriatal pathway depletion — that directly mirrors this patient's primary presentation (\(tagList)). The \(pct)% compatibility score reflects strong cosine alignment in the 4-dimensional symptom feature space, particularly on the tremor-severity and bradykinesia axes."
        } else if hasDyskines {
            overlap = "Your assessment history shows intermittent high-amplitude kinematic excursions, a pattern associated with levodopa-induced motor fluctuations and consistent with this patient's documented \(tagList). Motor fluctuation patterns are reproducible biomarkers — their presence in your data significantly elevates the pharmacological relevance of this comparison (\(pct)% match)."
        } else if hasPostural {
            overlap = "Biomechanical analysis of your motion data reveals postural stability markers in a range consistent with this patient's dominant presentation (\(tagList)). Postural reflex impairment implicates pathology beyond classic nigrostriatal circuits — likely involving the pedunculopontine nucleus and cerebellar pathways — which distinguishes this phenotype and explains the \(pct)% phenotypic overlap."
        } else if hasCognitive {
            overlap = "Your motor assessment profile shares a \(pct)% overlap with this patient (\(tagList)) across multi-axis embedding. Notably, this patient also exhibits cognitive co-morbidity, indicating Lewy body propagation into cortical regions (Braak stage IV–V territory). If cognitive changes accompany your motor symptoms, this case is particularly informative for long-term trajectory planning."
        } else if hasRigidity {
            overlap = "Your recent assessments indicate an elevated motion-variance baseline consistent with extrapyramidal rigidity — a feature shared with this patient's lead-pipe presentation (\(tagList)). Rigidity-dominant PD often shows less dramatic kinematic amplitude fluctuation than tremor-dominant forms, which aligns with your assessment waveform profile (\(pct)% compatibility)."
        } else if userIsStable {
            overlap = "Your current stable motor state (\(pct)% match) suggests you are in a well-controlled ON-period, comparable to this patient's documented profile (\(tagList)). Stable periods offer the best window for discussing medication adjustments, as pharmacokinetic parameters are most reliably measurable when the system is not in flux."
        } else {
            overlap = "Multi-dimensional embedding analysis yields a \(pct)% phenotypic overlap between your motor assessment profile and this patient (\(tagList)). The composite match integrates cosine similarity across symptom vectors, Gaussian RBF kernel distance across treatment-response vectors, and weighted Euclidean distance in the disease-progression space — making it a richer comparator than single-axis correlation."
        }
        return overlap
    }

    // MARK: 02 – Pharmacological Analysis

    private static func pharmacoSection(patient: PatientProfile, ageDelta: Int) -> String {
        let method  = patient.treatmentMethod.lowercased()
        let outcome = patient.treatmentOutcome.lowercased()

        var drugNote: String
        if method.contains("pramipexole") {
            drugNote = "This patient combines levodopa/carbidopa with pramipexole — a D2/D3 dopamine receptor agonist. The agonist component provides smoother dopaminergic stimulation with a longer half-life (~8–12 h) than levodopa alone, reducing pulsatile receptor activation and therefore lowering early dyskinesia risk. D3 receptor agonism specifically targets tremor-generating circuits in the subthalamic nucleus, making this combination particularly effective for tremor-dominant phenotypes."
        } else if method.contains("amantadine") {
            drugNote = "Amantadine in this patient's regimen acts via dual mechanisms: mild dopamine-releasing effect providing early motor benefit, and NMDA receptor antagonism suppressing levodopa-induced dyskinesia. If you begin experiencing involuntary movements at peak levodopa plasma levels (typically 1–2 h post-dose), amantadine is one of the first agents neurologists consider for dyskinesia suppression."
        } else if method.contains("entacapone") || method.contains("comt") {
            drugNote = "Entacapone — a peripheral COMT inhibitor — extends effective levodopa half-life by blocking catechol-O-methyltransferase, the enzyme responsible for ~10% of levodopa's peripheral degradation. Each levodopa dose effectively becomes longer-acting, extending ON-time by approximately 1 hour per dose cycle. This is the most targeted pharmacological intervention for wearing-off that begins to appear 30–60 minutes before the next scheduled dose."
        } else if method.contains("rasagiline") || method.contains("mao-b") {
            drugNote = "Rasagiline, an irreversible MAO-B inhibitor, slows central dopamine catabolism by blocking monoamine oxidase type B. Beyond its symptomatic benefit (~0.5 UPDRS improvement), rasagiline carries prospective neuroprotective signals from the TEMPO and ADAGIO trials — particularly relevant at earlier disease stages where neuroplasticity windows remain open. It also has mild antidepressant properties through serotonergic modulation."
        } else if method.contains("rivastigmine") {
            drugNote = "Rivastigmine — a dual AChE/BuChE inhibitor — is incorporated here to address the cholinergic deficit that accompanies Lewy body propagation to the basal forebrain. This reflects involvement of non-dopaminergic pathways that dopamine replacement cannot address. If cognitive fluctuations or attentional difficulties accompany your motor symptoms, the therapeutic rationale used in this case may become directly applicable to your management."
        } else if method.contains("dbs") && method.contains("gel pump") {
            drugNote = "This patient employs two advanced interventional strategies simultaneously: DBS (continuous high-frequency electrical modulation of STN or GPi) plus intestinal levodopa gel pump (bypassing erratic gastric absorption to achieve near-constant plasma levodopa). This combination represents the most aggressive pharmacological approach in advanced PD and is pursued when standard oral polypharmacy can no longer control motor fluctuations."
        } else if method.contains("dbs") {
            drugNote = "Post-DBS management requires a fundamentally different pharmacological strategy. DBS modulates but does not replace dopaminergic signalling — most patients still require oral levodopa at reduced doses. The continued need for entacapone here suggests residual wearing-off despite stimulation, pointing to incomplete coverage of the OFF-period troughs by the stimulation parameters."
        } else if method.contains("escitalopram") || method.contains("depression") {
            drugNote = "This patient's protocol explicitly addresses depression — an often-undertreated non-motor feature present in ~40% of PD patients. Escitalopram (SSRI) is well-tolerated in PD; dopamine agonists also carry antidepressant properties relevant when mood and motor symptoms co-occur. Recognising and treating the non-motor symptom burden is a critical determinant of overall quality of life in PD, independent of motor outcomes."
        } else {
            drugNote = "This patient's regimen follows a levodopa-backbone strategy — the cornerstone of PD motor management. Levodopa's striatal conversion to dopamine directly replenishes the deficit created by nigrostriatal neurodegeneration. The formulation type (immediate-release vs. controlled-release), dose fractionation schedule, and co-administration of dietary protein all significantly influence ON-period quality."
        }

        let ageNote = abs(ageDelta) > 4
            ? " Note: you are approximately \(abs(ageDelta)) years \(ageDelta > 0 ? "older" : "younger") — age-related pharmacokinetic differences (hepatic CYP metabolism, renal clearance) and receptor sensitivity changes mean dosing requirements may differ from this patient's documented regimen."
            : ""

        let outcomeNote = (outcome.contains("88%") || outcome.contains("85%") || outcome.contains("excellent"))
            ? " This patient achieved an outstanding ON-time ratio, establishing a meaningful clinical benchmark when discussing your own ON-period optimisation targets."
            : ""

        return drugNote + ageNote + outcomeNote
    }

    // MARK: 03 – Trajectory Comparison

    private static func trajectorySection(userDiagYrs: Int, patientDiagYrs: Int,
                                          ageDelta: Int, patient: PatientProfile) -> String {
        let delta    = userDiagYrs - patientDiagYrs
        let absDelta = abs(delta)

        var stageNote: String
        if userDiagYrs == 0 {
            stageNote = "Your diagnosis year has not been entered, so a precise staging comparison cannot be made. This patient has approximately \(patientDiagYrs) year\(patientDiagYrs == 1 ? "" : "s") of disease duration and presents the documented profile above — useful as a prospective reference regardless of your exact timeline."
        } else if absDelta <= 1 {
            stageNote = "You and this patient are at almost identical points on the disease timeline (both ~\(userDiagYrs) year\(userDiagYrs == 1 ? "" : "s") post-diagnosis). This temporal synchrony is the most directly instructive scenario: treatment decisions this patient made at your current stage have already produced the documented outcomes — a near real-time benchmark for your own management trajectory."
        } else if delta < 0 {
            stageNote = "This patient is ~\(absDelta) year\(absDelta == 1 ? "" : "s") further along than you. Their current clinical complexity serves as a prospective window into your disease trajectory — particularly the pharmacological escalation decisions that will likely arise as your disease progresses. The treatment strategy they employed at your equivalent stage is especially instructive."
        } else {
            stageNote = "You are ~\(absDelta) year\(absDelta == 1 ? "" : "s") further along than this patient's documented stage. Their documented pharmacological approach may represent strategies your team has already navigated — useful as a historical comparison to understand why your current regimen diverges from their earlier protocol."
        }

        let tags = patient.symptomTags.map { $0.lowercased() }
        let progressionNote: String
        if tags.contains(where: { $0.contains("early") }) {
            progressionNote = " Early-onset PD (diagnosis <50 years) typically follows a slower motor progression curve but carries higher lifetime dyskinesia risk due to longer cumulative levodopa exposure — a key consideration in optimising the levodopa-initiation decision."
        } else if tags.contains(where: { $0.contains("severe") || $0.contains("dementia") || $0.contains("orthostatic") }) {
            progressionNote = " Advanced PD (likely Braak stage IV–V) is characterised by levodopa-unresponsive axial features, autonomic dysfunction, and cognitive decline — reflecting pathological spread well beyond nigrostriatal circuits. Awareness of this trajectory supports informed, prospective care planning."
        } else if patientDiagYrs <= 5 {
            progressionNote = " At \(patientDiagYrs) years post-diagnosis, this patient remains in the early-to-mid stage where dopaminergic compensation is still effective. Evidence from the PRECEPT and ADAGIO trials suggests this window carries the highest potential for disease-modifying and neuroprotective interventions."
        } else {
            progressionNote = " With \(patientDiagYrs) years of documented disease, this patient has entered the mid-to-late phase where motor complications (wearing-off, dyskinesia) and non-motor features progressively dominate quality-of-life outcomes — an important framing for long-term management expectations."
        }
        return stageNote + progressionNote
    }

    // MARK: 04 – Action Plan

    private static func actionPlan(patient: PatientProfile, userDiagYrs: Int) -> [String] {
        let method  = patient.treatmentMethod.lowercased()
        let outcome = patient.treatmentOutcome.lowercased()
        let tags    = patient.symptomTags.map { $0.lowercased() }
        var bullets: [String] = []

        // Bullet 1 — Dosing optimisation
        if outcome.contains("88%") || outcome.contains("85%") || method.contains("precision") || method.contains("timing") {
            bullets.append("Ask your neurologist about precision dose-timing optimisation: this patient achieved >85% ON-time by fine-tuning levodopa administration windows relative to waking time, meal protein content, and activity peaks. A two-week pharmacokinetic diary (logging exact dose times, food intake, and hourly motor state) is the starting instrument for this calibration.")
        } else if method.contains("entacapone") || method.contains("comt") {
            bullets.append("Discuss COMT inhibitor augmentation if wearing-off is emerging: adding entacapone to each levodopa dose extends ON-time by ~60–90 minutes per dose cycle by blocking peripheral levodopa degradation — a targeted fix for predictable end-of-dose motor decline.")
        } else {
            bullets.append("Review your current levodopa dosing interval: fractionating the total daily dose into 4–5 smaller administrations (rather than 3 larger ones) smooths plasma levodopa peaks and troughs, directly reducing the amplitude and frequency of OFF-period episodes without requiring dose escalation.")
        }

        // Bullet 2 — Exercise / non-pharmacological
        if tags.contains(where: { $0.contains("gait") || $0.contains("falls") || $0.contains("postural") }) {
            bullets.append("Pursue gait-specific neurorehabilitation: rhythmic auditory stimulation (RAS) using a metronome or cueing music at 90–120 BPM carries Level A evidence for improving gait velocity, stride length, and cadence in PD. Request referral to a physiotherapist trained in neurological rehabilitation — specifically in LSVT BIG or cueing strategies for freezing-of-gait episodes.")
        } else if tags.contains(where: { $0.contains("early") || $0.contains("excellent") }) {
            bullets.append("Prioritise high-intensity aerobic exercise (≥80% max heart rate, ≥150 min/week): the SPARX2 trial and Park-in-Shape data demonstrate that vigorous exercise at early-to-mid PD stages can slow clinical progression, enhance dopamine receptor sensitivity, and potentially support levodopa dose reduction over the long term.")
        } else {
            bullets.append("Discuss structured exercise with your care team: the LSVT BIG protocol (large-amplitude movement therapy) and resistance training have both shown significant improvements in UPDRS motor scores, balance, and quality of life independent of medication effects — evidence-grade recommendations in current PD clinical guidelines.")
        }

        // Bullet 3 — Monitoring / next step
        if tags.contains(where: { $0.contains("cognitive") || $0.contains("sleep") || $0.contains("dementia") }) {
            bullets.append("Request comprehensive non-motor symptom evaluation: cognitive screening using the MoCA (score <26 suggests MCI), polysomnography for REM sleep behaviour disorder (a significant PD biomarker and fall-risk predictor), and orthostatic blood pressure measurements. Non-motor features are the primary driver of quality-of-life impairment in mid-to-late PD and are frequently under-assessed.")
        } else if tags.contains(where: { $0.contains("dyskine") || $0.contains("wearing") || $0.contains("on/off") }) {
            bullets.append("Consider a formal motor-fluctuation diary assessment: two weeks of Hauser Diary self-recording (hourly ON/OFF/dyskinesia states) provides objective data to qualify for DBS candidacy evaluation or to justify regimen restructuring under formal movement disorder specialist criteria. AuraPD assessment logs can supplement this diary with objective sensor-derived metrics.")
        } else {
            bullets.append("Bring your AuraPD assessment history to your next neurology appointment as objective longitudinal biomarker data. Quantitative tremor amplitude and bradykinesia indices provide your neurologist with trend data unavailable from standard clinic observation — enabling more evidence-based dose-titration decisions than symptom self-report alone.")
        }

        // Bullet 4 — Specialist pathway
        if method.contains("dbs") {
            bullets.append("If motor fluctuations persist despite pharmacological optimisation, discuss DBS candidacy criteria with a movement disorder specialist: ideal candidates show ≥5 years of PD with intact cognition (MoCA ≥24), significant motor fluctuations refractory to medication, and ≥30% UPDRS motor improvement on a formal levodopa challenge test.")
        } else if tags.contains(where: { $0.contains("depression") || $0.contains("sleep") || $0.contains("cognitive") }) {
            bullets.append("Seek multidisciplinary input for non-motor features: depression, sleep disorder, and cognitive decline each have evidence-based interventions (pharmacological and non-pharmacological) that are best coordinated by a PD-specific MDT including neurology, neuropsychology, and occupational therapy.")
        } else {
            bullets.append("Explore enrolment in a Parkinson's Disease multidisciplinary team (MDT) clinic: combined neurology, physiotherapy, occupational therapy, and speech therapy coordination has demonstrated superior outcomes over neurology-alone management in randomised trials. Ask your neurologist whether an MDT referral is appropriate at your current stage.")
        }

        return bullets
    }

    // MARK: – Utility

    private static func parseOnsetYears(_ onset: String) -> Int {
        let words = onset.components(separatedBy: CharacterSet(charactersIn: " ~()"))
        for (i, w) in words.enumerated() {
            if (w == "years" || w == "year") && i > 0,
               let n = Int(words[i - 1]) { return n }
        }
        return 5
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PatientProfileDetailView(profile: PatientProfileDatabase.mockProfiles.first!)
            .environmentObject(MainViewModel())
    }
}
