import Foundation

// MARK: - PatientEmbedding

struct PatientEmbedding {
    /// Symptom feature vector (dim=4): [tremor severity, rigidity, bradykinesia, postural instability] in [0,1]
    let symptomVector: [Double]
    /// Treatment response vector (dim=3): [levodopa sensitivity, dyskinesia risk, end-of-dose frequency] in [0,1]
    let treatmentVector: [Double]
    /// Progression vector (dim=2): [onset age / 80 (normalised), disease duration / 20 (normalised)] in [0,1]
    let progressionVector: [Double]
}

// MARK: - GNNMatchScores

struct GNNMatchScores {
    /// Dimension 1: symptom-space cosine similarity in [0,1]
    let symptomSimilarity: Double
    /// Dimension 2: treatment-response Gaussian RBF kernel similarity in [0,1]
    let treatmentResponseSimilarity: Double
    /// Dimension 3: progression-trajectory weighted Euclidean similarity in [0,1]
    let progressionSimilarity: Double
    /// Treatment Inspiration Value: TIV = 0.30·S + 0.45·T + 0.25·P in [0,1]
    let treatmentInspirationValue: Double
    /// Natural-language match reason (generated dynamically from dimension scores)
    let matchReason: String
}

// MARK: - GNNPatientMatcher

/// Simulates node-embedding distance calculation in a graph neural network.
///
/// ## Graph concept mapping
/// - **Node**: each patient = one node in the feature-vector space
/// - **Edge weight**: GNN distance between nodes = Treatment Inspiration Value
/// - **Community**: high-TIV cluster = patients with similar treatment-response patterns
///
/// ## Three-dimensional distance formulas
/// ```
/// // Dimension 1: cosine similarity (symptom space)
/// cos_sim(A,B) = (A·B) / (‖A‖ · ‖B‖)
///
/// // Dimension 2: Gaussian RBF kernel (treatment-response space, σ=0.30)
/// k_rbf(A,B)   = exp(−‖A−B‖² / 2σ²)
///
/// // Dimension 3: weighted Euclidean similarity (progression space)
/// d_w(A,B)     = √(Σ wᵢ·(aᵢ−bᵢ)²),   w=[1.5, 1.0]
/// eucl_sim     = exp(−d_w)
///
/// // Treatment Inspiration Value (multi-space weighted fusion)
/// TIV = 0.30·cos_sim + 0.45·k_rbf + 0.25·eucl_sim
/// ```
final class GNNPatientMatcher {

    static let shared = GNNPatientMatcher()

    // MARK: - Reference node (current user's embedding)

    /// Reference patient embedding: represents a typical mid-stage tremor-dominant PD profile
    /// (~58 y onset, 4.5-year duration). In a real system this vector is generated dynamically
    /// from the user's assessment history by PDMonitoringAgent.
    let referenceEmbedding = PatientEmbedding(
        symptomVector:     [0.72, 0.48, 0.61, 0.33],   // moderate tremor + mild rigidity + moderate bradykinesia
        treatmentVector:   [0.78, 0.28, 0.52],           // good levodopa response + low dyskinesia risk
        progressionVector: [0.735, 0.225]                 // onset ~58.8y, duration 4.5y
    )

    // MARK: - MOCKED GNN EMBEDDING DISTANCE CALCULATION
    // Simulates two-patient node distance in a multi-dimensional embedding space.
    // In a real GNN, node embeddings are output by multi-layer GraphConv after neighbour aggregation;
    // raw feature vectors are used here in place of GNN output embeddings,
    // preserving the same distance-metric mathematics.

    func calculateGraphNodeDistance(
        referenceNode patientA: PatientEmbedding,
        candidateNode patientB: PatientEmbedding
    ) -> GNNMatchScores {

        // Dimension 1: symptom space — cosine similarity
        // cos_sim(A,B) = (A·B) / (‖A‖·‖B‖)
        // Cosine similarity measures directional alignment; not affected by overall severity.
        let symptomSim = cosineSimilarity(patientA.symptomVector,
                                          patientB.symptomVector)

        // Dimension 2: treatment-response space — Gaussian RBF kernel
        // k_rbf(A,B) = exp(−‖A−B‖² / 2σ²),  σ = 0.30
        // RBF maps Euclidean distance to (0,1], highly sensitive to subtle differences.
        // σ=0.30 is empirically tuned: similar response patterns score >0.85, dissimilar <0.40.
        let treatmentSim = rbfKernel(patientA.treatmentVector,
                                     patientB.treatmentVector,
                                     sigma: 0.30)

        // Dimension 3: progression space — weighted Euclidean similarity
        // Weight vector w = [1.5, 1.0]: onset age has greater influence on treatment choice (w=1.5)
        // d_w = √(1.5·(Δage)² + 1.0·(Δduration)²)
        // eucl_sim = exp(−d_w)
        let progressionSim = weightedEuclideanSim(
            patientA.progressionVector,
            patientB.progressionVector,
            weights: [1.5, 1.0]
        )

        // Treatment Inspiration Value — multi-space weighted fusion
        // TIV = 0.30·S_symptom + 0.45·S_treatment + 0.25·S_progression
        //
        // Weight rationale:
        //   0.45 for treatment response — "how relevant is their medication plan to yours" is most critical
        //   0.30 for symptom pattern  — "similar disease presentation" is a prerequisite
        //   0.25 for progression      — "similar disease stage" adds comparability
        let tiv = 0.30 * symptomSim
                + 0.45 * treatmentSim
                + 0.25 * progressionSim

        let reason = generateMatchReason(
            symptomSim:    symptomSim,
            treatmentSim:  treatmentSim,
            progressionSim: progressionSim,
            tiv:           tiv
        )

        return GNNMatchScores(
            symptomSimilarity:           symptomSim,
            treatmentResponseSimilarity: treatmentSim,
            progressionSimilarity:       progressionSim,
            treatmentInspirationValue:   tiv,
            matchReason:                 reason
        )
    }

    // MARK: - Vector Math Primitives

    /// Cosine similarity: cos_sim(A,B) = (A·B) / (‖A‖·‖B‖)
    func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        let dot   = zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
        let normA = sqrt(a.reduce(0.0) { $0 + $1 * $1 })
        let normB = sqrt(b.reduce(0.0) { $0 + $1 * $1 })
        guard normA > 1e-8, normB > 1e-8 else { return 0.0 }
        return max(0.0, min(1.0, dot / (normA * normB)))
    }

    /// Gaussian RBF kernel: k_rbf(A,B) = exp(−‖A−B‖² / 2σ²)
    func rbfKernel(_ a: [Double], _ b: [Double], sigma: Double) -> Double {
        let sqDist = zip(a, b).reduce(0.0) { $0 + pow($1.0 - $1.1, 2) }
        return exp(-sqDist / (2.0 * sigma * sigma))
    }

    /// Weighted Euclidean similarity: sim = exp(−√(Σwᵢ·(aᵢ−bᵢ)²))
    func weightedEuclideanSim(_ a: [Double], _ b: [Double], weights: [Double]) -> Double {
        let wSqDist = zip(zip(a, b), weights)
            .reduce(0.0) { $0 + $1.1 * pow($1.0.0 - $1.0.1, 2) }
        return exp(-sqrt(wSqDist))
    }

    // MARK: - Match Reason Generation

    private func generateMatchReason(
        symptomSim: Double, treatmentSim: Double,
        progressionSim: Double, tiv: Double
    ) -> String {
        var clauses: [String] = []

        switch symptomSim {
        case 0.92...:
            clauses.append("Symptom cosine similarity \(pct(symptomSim)) — nearly identical motor disorder pattern")
        case 0.78...:
            clauses.append("Similar symptom profile (\(pct(symptomSim))) — primary symptom types closely aligned")
        default:
            clauses.append("Symptom patterns differ (\(pct(symptomSim))), but disease stage is comparable")
        }

        switch treatmentSim {
        case 0.80...:
            clauses.append("Treatment response vectors closely matched (RBF \(pct(treatmentSim))) — dosing regimen directly applicable")
        case 0.55...:
            clauses.append("Similar treatment response (\(pct(treatmentSim))) — medication strategy worth considering")
        default:
            clauses.append("Treatment paths differ (\(pct(treatmentSim))) — useful as a contrast reference")
        }

        if progressionSim > 0.88 {
            clauses.append("Onset age and disease stage closely matched (\(pct(progressionSim)))")
        }

        let conclusion: String
        switch tiv {
        case 0.80...: conclusion = "Overall TIV=\(pct(tiv)) — high-value reference case"
        case 0.60...: conclusion = "TIV=\(pct(tiv)) — moderate treatment inspiration value"
        default:      conclusion = "TIV=\(pct(tiv)) — supplementary reference"
        }
        clauses.append(conclusion)

        return clauses.joined(separator: "; ") + "."
    }

    private func pct(_ v: Double) -> String { "\(Int(v * 100))%" }
}
