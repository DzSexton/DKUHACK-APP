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
    @Published var appState: AppState = .idle
    @Published var statusMessage = "Say \"Check my condition\" to begin."
    @Published var isListeningForWakeWord = false
    @Published var isRecognizerAvailable = true
    /// Real-time tremor displacement (pixels) driven by accelerometer at 50 Hz.
    @Published var tremorOffset: CGSize = .zero

    // MARK: – 功能一：本地震颤历史 + 队列匹配

    /// 模拟的 24 小时震颤历史记录（用于时间轴回放与队列匹配，完全 Mock）
    @Published var tremorHistory: [TremorRecord] = []
    /// 本地规则引擎计算的相似病例匹配结果（ProfileManager 输出）
    @Published var cohortMatchResult: CohortMatchResult?
    /// 本地脱敏患者档案列表（供 InsightView 瀑布流网格展示，完全 Mock）
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

    // MARK: – Timers / tokens
    private var capturingTimer: Timer?
    private var calibrationTimer: Timer?

    // MARK: – Initialisation

    init() {
        userProfile = LocalStorageService.shared.loadUserProfile()
        assessmentHistory = LocalStorageService.shared.loadResults()
        setupWakeWord()
        setupConsentCallbacks()
        resumeWakeWordListening()
        observeRecognizerAvailability()
        observeAudioInterruptions()
        observeTremorOffset()

        // 初始化模拟的 24h 震颤历史（完全本地 Mock，供时间轴回放和队列匹配使用）
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

    /// 重新执行本地队列匹配，刷新 InsightView 的显示内容
    ///
    /// 当新的评估结果加入、或用户手动点击刷新时调用。
    func refreshCohortMatch() {
        // 将最新的真实评估记录转换为 TremorRecord，合并到历史数据中
        let realRecords = assessmentHistory.prefix(12).map { result in
            TremorRecord(
                timestamp: result.timestamp,
                // 将 sigma 归一化为 0~1（以 2×threshold 为上限）
                tremorIntensity: min(result.sigma / max(result.threshold * 2.0, 0.01), 1.0),
                state: result.state
            )
        }
        // 合并真实记录与 Mock 历史，按时间排序后重新匹配
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

        let result = classifier.classify(features: features, threshold: userProfile.varianceThreshold)
        latestResult = result
        assessmentHistory.insert(result, at: 0)
        if assessmentHistory.count > 500 { assessmentHistory = Array(assessmentHistory.prefix(500)) }
        // Ethical AI – Privacy:
        // Persist only derived assessment metadata (state, σ, τ, explanation).
        // Raw time-series sensor samples are never saved or transmitted.
        LocalStorageService.shared.save(result: result)
        // 每次新评估完成后自动刷新队列匹配洞察
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
