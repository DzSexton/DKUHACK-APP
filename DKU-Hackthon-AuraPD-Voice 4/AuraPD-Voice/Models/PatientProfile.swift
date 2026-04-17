import Foundation

// MARK: - PatientGender

enum PatientGender: String, Codable {
    case male   = "Mr."
    case female = "Ms."
}

// MARK: - PatientProfile

struct PatientProfile: Identifiable, Hashable {
    let id: UUID
    let anonymizedName: String
    let gender: PatientGender
    let age: Int
    let onsetPeriod: String
    let symptomsDescription: String
    let treatmentLocation: String
    let treatmentMethod: String
    let treatmentOutcome: String
    /// Short English symptom chips displayed on the insight card (max 3).
    let symptomTags: [String]

    let embedding: PatientEmbedding

    var gnnScores: GNNMatchScores?

    var treatmentInspirationValue: Double { gnnScores?.treatmentInspirationValue ?? 0.5 }

    /// Match score scaled to medically realistic range [65%, 85%].
    /// Factor 0.20 prevents unrealistically high scores (raw TIV=1.0 → only 85%).
    var matchPercentage: Int {
        let scaled = 0.65 + max(0.0, min(1.0, treatmentInspirationValue)) * 0.20
        return Int(scaled * 100)
    }

    var displayTitle: String { "\(gender.rawValue) \(anonymizedName)" }

    static func == (lhs: PatientProfile, rhs: PatientProfile) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - PatientProfileDatabase

enum PatientProfileDatabase {

    private static let rawProfiles: [PatientProfile] = [

        PatientProfile(
            id: UUID(),
            anonymizedName: "A",
            gender: .male,
            age: 62,
            onsetPeriod: "~4 years ago (onset at age 57)",
            symptomsDescription: "Predominant resting tremor in both hands, mild rigidity and bradykinesia, posture stable.",
            treatmentLocation: "Peking Union Medical College Hospital",
            treatmentMethod: "Madopar 250mg three times daily + Pramipexole 0.5mg adjunct",
            treatmentOutcome: "Tremor well controlled, ON-state ~70% of day, occasional mild wearing-off.",
            symptomTags: ["Resting Tremor", "Mild Rigidity", "Bradykinesia"],
            embedding: PatientEmbedding(
                symptomVector:     [0.78, 0.44, 0.62, 0.28],
                treatmentVector:   [0.82, 0.26, 0.50],
                progressionVector: [0.713, 0.200]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "B",
            gender: .female,
            age: 58,
            onsetPeriod: "~3 years ago (onset at age 55)",
            symptomsDescription: "Predominantly rigid, lead-pipe stiffness in upper limbs, minimal resting tremor, slight shuffling gait.",
            treatmentLocation: "Ruijin Hospital, Shanghai Jiao Tong University",
            treatmentMethod: "Sinemet 100/25mg twice daily + Amantadine 100mg",
            treatmentOutcome: "Rigidity improved ~50%, daily function maintained, no significant dyskinesia.",
            symptomTags: ["Lead-pipe Rigidity", "Bradykinesia", "Shuffling Gait"],
            embedding: PatientEmbedding(
                symptomVector:     [0.22, 0.86, 0.55, 0.42],
                treatmentVector:   [0.60, 0.18, 0.45],
                progressionVector: [0.688, 0.150]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "C",
            gender: .male,
            age: 71,
            onsetPeriod: "~11 years ago (onset at age 60)",
            symptomsDescription: "Tremor in all limbs, marked rigidity, freezing of gait, impaired postural reflexes, mild cognitive fluctuation.",
            treatmentLocation: "West China Hospital, Sichuan University",
            treatmentMethod: "Post-DBS + Madopar maintenance + Entacapone 200mg",
            treatmentOutcome: "Motor function improved ~40% post-DBS, but gait freezing persists; requires walking aid.",
            symptomTags: ["Freezing of Gait", "Severe Rigidity", "Cognitive Fluctuation"],
            embedding: PatientEmbedding(
                symptomVector:     [0.90, 0.86, 0.88, 0.78],
                treatmentVector:   [0.28, 0.84, 0.90],
                progressionVector: [0.750, 0.550]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "D",
            gender: .female,
            age: 55,
            onsetPeriod: "~4 years ago (onset at age 51)",
            symptomsDescription: "Onset with right-hand resting tremor, gradually bilateral, mild rigidity, ADL largely independent.",
            treatmentLocation: "Huashan Hospital, Fudan University",
            treatmentMethod: "Madopar 125mg + Pramipexole 0.75mg, optimised three-dose timing",
            treatmentOutcome: "Excellent levodopa response, ON-state 85%, tremor nearly resolved, no dyskinesia.",
            symptomTags: ["Resting Tremor", "Mild Rigidity", "Excellent L-DOPA Response"],
            embedding: PatientEmbedding(
                symptomVector:     [0.84, 0.32, 0.46, 0.20],
                treatmentVector:   [0.94, 0.14, 0.30],
                progressionVector: [0.638, 0.200]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "E",
            gender: .male,
            age: 67,
            onsetPeriod: "~8 years ago (onset at age 59)",
            symptomsDescription: "Core symptoms: postural instability and gait disturbance with repeated falls, mild tremor, dysphagia.",
            treatmentLocation: "Tongji Hospital, Huazhong University of Science and Technology",
            treatmentMethod: "Madopar + Rasagiline 1mg + physiotherapy",
            treatmentOutcome: "Limited gait improvement, fall frequency reduced ~30%, requires walking aid.",
            symptomTags: ["Postural Instability", "Recurrent Falls", "Dysphagia"],
            embedding: PatientEmbedding(
                symptomVector:     [0.30, 0.65, 0.74, 0.94],
                treatmentVector:   [0.35, 0.55, 0.80],
                progressionVector: [0.738, 0.400]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "F",
            gender: .female,
            age: 63,
            onsetPeriod: "~6 years ago (onset at age 57)",
            symptomsDescription: "Mixed tremor and rigidity, mild executive cognitive decline, prominent mood fluctuation and sleep disturbance.",
            treatmentLocation: "First Affiliated Hospital, Sun Yat-sen University",
            treatmentMethod: "Madopar + Rivastigmine (cognition) + Melatonin (sleep)",
            treatmentOutcome: "Motor symptoms moderately controlled, cognitive symptoms stable, sleep quality significantly improved.",
            symptomTags: ["Tremor & Rigidity", "Sleep Disturbance", "Executive Decline"],
            embedding: PatientEmbedding(
                symptomVector:     [0.65, 0.55, 0.72, 0.48],
                treatmentVector:   [0.72, 0.40, 0.56],
                progressionVector: [0.713, 0.300]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "G",
            gender: .male,
            age: 69,
            onsetPeriod: "~9 years ago (onset at age 60)",
            symptomsDescription: "Comprehensive symptoms, predominantly tremor and bradykinesia; long-term medication has produced prominent dyskinesia and wearing-off.",
            treatmentLocation: "Second Affiliated Hospital, Zhejiang University School of Medicine",
            treatmentMethod: "Madopar + Entacapone + Amantadine (anti-dyskinesia); DBS evaluation in progress",
            treatmentOutcome: "Dyskinesia partially controlled with polypharmacy; ON/OFF fluctuation frequent. DBS evaluation approved.",
            symptomTags: ["Dyskinesia", "Wearing-Off", "ON/OFF Fluctuation"],
            embedding: PatientEmbedding(
                symptomVector:     [0.76, 0.60, 0.70, 0.52],
                treatmentVector:   [0.68, 0.74, 0.80],
                progressionVector: [0.750, 0.450]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "H",
            gender: .female,
            age: 61,
            onsetPeriod: "~6 years ago (onset at age 55)",
            symptomsDescription: "Early-onset PD, tremor as initial symptom, gradually bilateral, daily function well maintained, positive mood.",
            treatmentLocation: "Xiangya Hospital, Central South University",
            treatmentMethod: "Low-dose Madopar 125mg three times daily (precision timing), regular aerobic exercise",
            treatmentOutcome: "Excellent ON-peak control (ON-state 88% of day), no dyskinesia, maintains occupational activity.",
            symptomTags: ["Early-Onset PD", "Resting Tremor", "Excellent ON-time"],
            embedding: PatientEmbedding(
                symptomVector:     [0.68, 0.38, 0.55, 0.24],
                treatmentVector:   [0.95, 0.16, 0.28],
                progressionVector: [0.688, 0.300]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "I",
            gender: .male,
            age: 73,
            onsetPeriod: "~14 years ago (onset at age 59)",
            symptomsDescription: "Advanced PD: severe generalised rigidity and tremor, orthostatic hypotension, urinary frequency, mild dementia.",
            treatmentLocation: "Beijing Tiantan Hospital, Capital Medical University",
            treatmentMethod: "Post-DBS + intestinal levodopa gel pump + multi-system symptomatic treatment",
            treatmentOutcome: "DBS still effective but diminishing over years; high care dependency, low quality-of-life score.",
            symptomTags: ["Severe Tremor", "Orthostatic Hypotension", "Mild Dementia"],
            embedding: PatientEmbedding(
                symptomVector:     [0.94, 0.90, 0.92, 0.86],
                treatmentVector:   [0.22, 0.90, 0.95],
                progressionVector: [0.738, 0.700]
            )
        ),

        PatientProfile(
            id: UUID(),
            anonymizedName: "J",
            gender: .female,
            age: 60,
            onsetPeriod: "~5 years ago (onset at age 55)",
            symptomsDescription: "Predominant rigidity and fatigue, minimal tremor, noticeably slowed daily movements, prominent depressed mood.",
            treatmentLocation: "Peking University Third Hospital",
            treatmentMethod: "Carbidopa-levodopa CR + Escitalopram (depression) + psychological rehabilitation",
            treatmentOutcome: "Motor function moderately improved, depression significantly reduced, overall quality-of-life score improved.",
            symptomTags: ["Rigidity & Fatigue", "Prominent Depression", "Bradykinesia"],
            embedding: PatientEmbedding(
                symptomVector:     [0.35, 0.88, 0.70, 0.60],
                treatmentVector:   [0.62, 0.32, 0.62],
                progressionVector: [0.688, 0.250]
            )
        ),
    ]

    static let mockProfiles: [PatientProfile] = {
        let matcher = GNNPatientMatcher.shared
        var result = rawProfiles
        for i in result.indices {
            result[i].gnnScores = matcher.calculateGraphNodeDistance(
                referenceNode: matcher.referenceEmbedding,
                candidateNode: result[i].embedding
            )
        }
        return result.sorted { $0.treatmentInspirationValue > $1.treatmentInspirationValue }
    }()
}
