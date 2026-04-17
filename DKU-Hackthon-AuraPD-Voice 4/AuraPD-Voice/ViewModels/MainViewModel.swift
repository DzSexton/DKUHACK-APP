import Foundation
import Combine
import AVFoundation

/// Central coordinator that drives all five system layers:
/// 1. **User Layer** – wake-word detection, fallback touch trigger
/// 2. **Sensing Layer** – CoreMotion data collection via `MotionService`
/// 3. **Intelligence Layer** – feature extraction + rule-based classification
/// 4. **Explainability Layer** – TTS rationale via `SpeechService`
/// 5. **Ethical AI Layer** – voiced consent gate via `ConsentService`
@MainActor
final class MainViewModel: ObservableObject {

    // MARK: – Published state (drives the UI)
    @Published var latestResult: AssessmentResult?
    @Published var assessmentHistory: [AssessmentResult] = []
    @Published var userProfile: UserProfile
    /// Whether the user has triggered the match-calculation step.
    /// Auto-restored to true on launch if the profile was already filled in a prior session.
    @Published var matchCalculated: Bool = false
    /// τ_adaptive = 0.65·τ_user + 0.35·τ_base — live-computed from both sources.
    /// Settings and Dashboard read this; it updates whenever the slider moves OR the Agent learns.
    @Published private(set) var currentAdaptiveThreshold: Double = 0.0
    @Published var appState: AppState = .idle
    @Published var statusMessage = "Say \"Check my condition\" to begin."
    @Published var isListeningForWakeWord = false
    @Published var isRecognizerAvailable = true
    /// Real-time tremor displacement (pixels) driven by accelerometer at 50 Hz.
    @Published var tremorOffset: CGSize = .zero

    // MARK: – Local tremor history + cohort matching

    /// Simulated 24-hour tremor history (used for timeline playback and cohort matching, fully mocked)
    @Published var tremorHistory: [TremorRecord] = []
    /// Cohort match result computed by the local rule engine (ProfileManager output)
    @Published var cohortMatchResult: CohortMatchResult?
    /// De-identified patient profile list (shown in InsightView grid, fully mocked)
    @Published var patientProfiles: [PatientProfile] = PatientProfileDatabase.mockProfiles

    // MARK: – Services (all private)
    let motionService      = MotionService()
    let speechService      = SpeechService()
    private let voiceCommandService = VoiceCommandService()
    private lazy var consentService = ConsentService(speechService: speechService)

    // MARK: – Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: – Intelligence
    private let featureExtractor = FeatureExtractor()
    private let classifier       = PDClassifier()
    let agent = PDMonitoringAgent()

    // MARK: – Timers / tokens
    private var capturingTimer: Timer?
    private var calibrationTimer: Timer?

    // MARK: – Initialisation

    init() {
        let saved = LocalStorageService.shared.loadUserProfile()
        userProfile      = saved
        matchCalculated  = saved.isReadyForMatching
        // Eager initial value — Combine subscription below will keep it live afterwards.
        currentAdaptiveThreshold = 0.65 * saved.varianceThreshold + 0.35 * 0.118
        assessmentHistory = LocalStorageService.shared.loadResults()
        setupWakeWord()
        setupConsentCallbacks()
        resumeWakeWordListening()
        observeRecognizerAvailability()
        observeAudioInterruptions()
        observeTremorOffset()
        bindAdaptiveThreshold()

        tremorHistory = TremorRecordGenerator.generateMockHistory()
        cohortMatchResult = ProfileManager.shared.match(against: tremorHistory)
    }

    // MARK: – Public API (also used by the fallback touch button)

    /// Triggers the full assessment pipeline.  Called by wake-word detection or
    /// by the manual "Check Now" button in the UI.
    func beginAssessmentFlow() {
        guard appState == .idle else { return }
        pauseWakeWordListening()
        // Ethical AI – Consent:
        // Every capture session must pass an explicit consent gate first.
        appState = .awaitingConsent
        statusMessage = "Awaiting your consent…"
        consentService.requestConsent()
    }

    /// Updates the personalised threshold based on a fresh calibration session.
    func recalibrate(with sigmaReadings: [Double]) {
        userProfile.recalibrate(using: sigmaReadings)
        LocalStorageService.shared.saveUserProfile(userProfile)
    }

    /// Runs a consent-gated baseline calibration session and reports progress.
    func beginCalibrationFlow(
        duration: TimeInterval = 10.0,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping (Bool) -> Void
    ) {
        guard appState == .idle else {
            onCompletion(false)
            return
        }

        pauseWakeWordListening()
        appState = .awaitingConsent
        statusMessage = "Awaiting your consent for calibration…"

        // Ethical AI – Consent:
        // Calibration is also motion capture, so it must pass the same informed-consent gate.
        consentService.requestConsent { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard granted else {
                    self.appState = .idle
                    self.statusMessage = "Calibration cancelled: consent not granted."
                    self.resumeWakeWordListening()
                    onCompletion(false)
                    return
                }
                self.startCalibrationCapture(duration: duration, onProgress: onProgress, onCompletion: onCompletion)
            }
        }
    }

    /// Clears the assessment history from both memory and local storage.
    func clearHistory() {
        assessmentHistory = []
        LocalStorageService.shared.clearResults()
    }

    /// Re-runs local cohort matching and refreshes InsightView content.
    /// Called after each new assessment result or on manual refresh.
    func refreshCohortMatch() {
        let realRecords = assessmentHistory.prefix(12).map { result in
            TremorRecord(
                timestamp: result.timestamp,
                tremorIntensity: min(result.sigma / max(result.threshold * 2.0, 0.01), 1.0),
                state: result.state
            )
        }
        let combined = (tremorHistory + realRecords).sorted { $0.timestamp < $1.timestamp }
        cohortMatchResult = ProfileManager.shared.match(against: combined)
    }

    // MARK: – Private: pipeline wiring

    private func setupWakeWord() {
        voiceCommandService.onListeningStateChanged = { [weak self] listening in
            Task { @MainActor [weak self] in
                self?.isListeningForWakeWord = listening
            }
        }
        voiceCommandService.onWakeWordDetected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.beginAssessmentFlow()
            }
        }
    }

    private func setupConsentCallbacks() {
        consentService.onConsentGranted = { [weak self] in
            Task { @MainActor [weak self] in
                self?.startCapturing()
            }
        }
        consentService.onConsentDenied = { [weak self] in
            Task { @MainActor [weak self] in
                self?.appState = .idle
                self?.statusMessage = "Consent declined. Say \"Check my condition\" to try again."
                self?.resumeWakeWordListening()
            }
        }
    }

    private func startCapturing() {
        appState = .capturing
        statusMessage = "Analysing your motion… please hold the device normally."
        speechService.speak("Monitoring started.")

        // Capture for up to 10 seconds then auto-classify.
        motionService.startCapturing()
        capturingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finishCapturing()
            }
        }
    }

    private func finishCapturing() {
        capturingTimer?.invalidate()
        capturingTimer = nil
        motionService.stopCapturing()

        let window = motionService.currentWindow()
        guard let features = featureExtractor.extract(from: window) else {
            appState = .idle
            statusMessage = "Not enough data collected. Please try again."
            speechService.speak("Not enough motion data was collected. Please try again.")
            resumeWakeWordListening()
            return
        }

        let agentPrediction = agent.predict(features: features, userThreshold: userProfile.varianceThreshold)
        // Rule-based classifier runs in parallel to generate the voiceExplanation string
        let baseResult = classifier.classify(features: features, threshold: userProfile.varianceThreshold)
        let result = AssessmentResult(
            state:            agentPrediction.state,
            sigma:            agentPrediction.sigma,
            threshold:        agentPrediction.adaptiveThreshold,
            voiceExplanation: baseResult.voiceExplanation,
            confidence:       agentPrediction.confidence,
            mlExplanation:    agentPrediction.hypothesis
        )
        latestResult = result
        assessmentHistory.insert(result, at: 0)
        if assessmentHistory.count > 500 { assessmentHistory = Array(assessmentHistory.prefix(500)) }
        // Ethical AI – Privacy:
        // Persist only derived assessment metadata (state, σ, τ, explanation).
        // Raw time-series sensor samples are never saved or transmitted.
        LocalStorageService.shared.save(result: result)
        // MARK: - 🔄 DYNAMIC PROFILE UPDATE LOGIC
        syncConditionSummary(from: result)
        refreshCohortMatch()

        appState = .speaking
        statusMessage = "Assessment complete."

        speechService.speak(result.voiceExplanation) { [weak self] in
            Task { @MainActor [weak self] in
                self?.appState = .idle
                self?.statusMessage = "Say \"Check my condition\" to begin."
                self?.resumeWakeWordListening()
            }
        }
    }

    private func startCalibrationCapture(
        duration: TimeInterval,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping (Bool) -> Void
    ) {
        appState = .capturing
        statusMessage = "Calibrating baseline… please hold the device naturally."

        var collectedSigmas: [Double] = []
        let extractor = FeatureExtractor()
        let previousWindowUpdate = motionService.onWindowUpdate

        motionService.onWindowUpdate = { window in
            guard window.isReady, let features = extractor.extract(from: window) else { return }
            collectedSigmas.append(features.sigma)
        }

        motionService.startCapturing()
        calibrationTimer?.invalidate()
        onProgress(0.0)

        var elapsed: TimeInterval = 0.0
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else { return }
            elapsed += 0.1
            let progress = min(elapsed / max(duration, 0.1), 1.0)
            onProgress(progress)

            if elapsed >= duration {
                timer.invalidate()
                self.calibrationTimer = nil
                self.motionService.stopCapturing()
                self.motionService.onWindowUpdate = previousWindowUpdate

                guard !collectedSigmas.isEmpty else {
                    self.appState = .idle
                    self.statusMessage = "Calibration failed: not enough baseline data."
                    self.speechService.speak("Calibration failed because not enough motion data was collected.")
                    self.resumeWakeWordListening()
                    onCompletion(false)
                    return
                }

                self.recalibrate(with: collectedSigmas)
                self.appState = .idle
                self.statusMessage = "Calibration complete. Your personalised threshold has been updated."
                self.speechService.speak("Calibration complete. Your personal baseline has been updated.")
                self.resumeWakeWordListening()
                onCompletion(true)
            }
        }
    }

    /// Keeps `currentAdaptiveThreshold` live by merging two upstream publishers:
    ///   • `$userProfile.varianceThreshold`  — changes when user moves the Settings slider
    ///   • `agent.$baseThreshold`            — changes when the Agent learns from feedback
    /// Either source firing recomputes τ_adaptive = 0.65·τ_user + 0.35·τ_base.
    private func bindAdaptiveThreshold() {
        Publishers.CombineLatest(
            $userProfile.map(\.varianceThreshold),
            agent.$baseThreshold
        )
        .map { tau_u, tau_b in 0.65 * tau_u + 0.35 * tau_b }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] value in self?.currentAdaptiveThreshold = value }
        .store(in: &cancellables)
    }

    private func observeTremorOffset() {
        // Amplify raw accelerometer (g) → screen pixels for visual tremor.
        // Scale factor 28 px/g makes mild tremor (~0.1 g) clearly visible.
        motionService.$latestSample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                guard let self else { return }
                guard let sample else {
                    self.tremorOffset = .zero
                    return
                }
                self.tremorOffset = CGSize(
                    width:  CGFloat(sample.accelerometerX) * 28,
                    height: CGFloat(sample.accelerometerY) * 28
                )
            }
            .store(in: &cancellables)
    }

    private func observeRecognizerAvailability() {
        voiceCommandService.$isRecognizerAvailable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecognizerAvailable)
    }

    private func observeAudioInterruptions() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let info = notification.userInfo,
                      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                      type == .ended else { return }
                // Resume wake-word listening after a phone call, Siri, etc.
                if !self.isListeningForWakeWord && self.appState == .idle {
                    self.resumeWakeWordListening()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: – Agent feedback

    func submitFeedback(correct: Bool) {
        agent.adaptModel(basedOn: correct)
    }

    // MARK: – Demo: avatar hidden-tap pipeline

    /// Full voice-first demo pipeline without requiring a working microphone.
    ///
    /// Flow: voice feedback → 3-second simulated capture (avatar shakes live) →
    /// Agent prediction → result sheet pops up → TTS speaks result.
    ///
    /// Triggered by the hidden triple-tap on the avatar in DashboardView.
    func beginDemoAssessment() {
        guard appState == .idle else { return }
        pauseWakeWordListening()
        appState = .capturing
        statusMessage = "Analysing your motion… please hold the device normally."
        speechService.speak("Voice command received. Monitoring your condition.")

        // 3-second simulated capture — AppViewModel drives the live tremor animation
        // in DashboardView via the .onChange(appState) bridge wired there.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            Task { @MainActor [weak self] in self?.finishDemoAssessment() }
        }
    }

    private func finishDemoAssessment() {
        // Synthetic sensor features — three-band distribution matching real PD data:
        // ON 50 %, OFF 30 %, Tremor 20 %
        let roll = Double.random(in: 0..<1)
        let mockSigma: Double
        switch roll {
        case ..<0.50: mockSigma = Double.random(in: 0.02...0.10)   // ON
        case ..<0.80: mockSigma = Double.random(in: 0.11...0.22)   // OFF
        default:      mockSigma = Double.random(in: 0.24...0.40)   // Tremor
        }
        let mockFeatures = SensorFeatures(
            mean:         Double.random(in: -0.05...0.05),
            variance:     mockSigma * mockSigma,
            signalEnergy: mockSigma * 3.5
        )

        let prediction = agent.predict(features: mockFeatures,
                                       userThreshold: userProfile.varianceThreshold)
        let result = AssessmentResult(
            state:            prediction.state,
            sigma:            prediction.sigma,
            threshold:        prediction.adaptiveThreshold,
            voiceExplanation: prediction.state.voiceExplanation(
                                  sigma:     prediction.sigma,
                                  threshold: prediction.adaptiveThreshold),
            confidence:       prediction.confidence,
            mlExplanation:    prediction.explanation
        )

        latestResult = result
        assessmentHistory.insert(result, at: 0)
        if assessmentHistory.count > 500 { assessmentHistory = Array(assessmentHistory.prefix(500)) }
        LocalStorageService.shared.save(result: result)

        // MARK: - 🔄 DYNAMIC PROFILE UPDATE LOGIC
        syncConditionSummary(from: result)
        refreshCohortMatch()

        appState = .speaking
        statusMessage = "Assessment complete."

        speechService.speak(result.voiceExplanation) { [weak self] in
            Task { @MainActor [weak self] in
                self?.appState = .idle
                self?.statusMessage = "Say \"Check my condition\" to begin."
                self?.resumeWakeWordListening()
            }
        }
    }

    /// Bypasses CoreMotion + TTS and injects a synthetic prediction directly.
    /// For live demo use only — lets reviewers rapidly tap thumbs-up/down to see the learning curve.
    func injectMockResult() {
        guard appState == .idle else { return }

        let roll = Double.random(in: 0..<1)
        let mockSigma: Double
        if roll < 0.50 {
            mockSigma = Double.random(in: 0.02...0.10)   // ON range
        } else if roll < 0.80 {
            mockSigma = Double.random(in: 0.11...0.22)   // OFF range
        } else {
            mockSigma = Double.random(in: 0.24...0.40)   // Tremor range
        }

        let mockFeatures = SensorFeatures(
            mean: Double.random(in: -0.05...0.05),
            variance: mockSigma * mockSigma,
            signalEnergy: mockSigma * 3.5
        )
        let prediction = agent.predict(features: mockFeatures,
                                       userThreshold: userProfile.varianceThreshold)
        let result = AssessmentResult(
            state:            prediction.state,
            sigma:            prediction.sigma,
            threshold:        prediction.adaptiveThreshold,
            voiceExplanation: prediction.state.displayName,
            confidence:       prediction.confidence,
            mlExplanation:    prediction.hypothesis
        )
        latestResult = result
        assessmentHistory.insert(result, at: 0)
        syncConditionSummary(from: result)
        statusMessage  = "Demo injected — please give feedback below"
    }

    // MARK: - 🔄 DYNAMIC PROFILE UPDATE LOGIC

    /// Writes a human-readable condition summary into the user's personal profile
    /// based on the latest assessment outcome. Called automatically after every check.
    private func syncConditionSummary(from result: AssessmentResult) {
        switch result.state {
        case .tremor:
            userProfile.conditionSummary = "Tremor frequency increasing — monitor medication timing"
        case .off:
            userProfile.conditionSummary = "Currently in OFF period — mild motor limitation"
        case .on:
            userProfile.conditionSummary = "Stable — good motor control"
        case .unknown:
            break
        }
        LocalStorageService.shared.saveUserProfile(userProfile)
    }

    private func pauseWakeWordListening() {
        guard isListeningForWakeWord else { return }
        voiceCommandService.stopListening()
    }

    private func resumeWakeWordListening() {
        guard !isListeningForWakeWord else { return }
        voiceCommandService.startListening()
    }
}

// MARK: – AppState

enum AppState: String {
    case idle            = "Idle"
    case awaitingConsent = "Awaiting Consent"
    case capturing       = "Capturing"
    case speaking        = "Speaking"
}
