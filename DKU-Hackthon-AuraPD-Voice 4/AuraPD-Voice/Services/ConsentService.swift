import Foundation
import Speech
import AVFoundation

/// Manages the voice-based informed-consent flow required before each motion capture.
///
/// Flow:
/// 1. Speak: "Do you allow motion tracking for the next 10 seconds?"
/// 2. Listen for a verbal "yes" (or "yeah", "sure", "ok") within a 7-second window.
/// 3. Call `onConsentGranted()` on approval, or `onConsentDenied()` on timeout / "no".
final class ConsentService: ObservableObject {

    // MARK: – Published state
    @Published private(set) var awaitingConsent = false

    // MARK: – Callbacks
    var onConsentGranted: (() -> Void)?
    var onConsentDenied: (() -> Void)?
    private var oneShotDecisionHandler: ((Bool) -> Void)?

    // MARK: – Dependencies (injected)
    private let speechService: SpeechService

    // MARK: – Private
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var timeoutTimer: Timer?
    private var didDecide = false

    private let consentQuestion =
        "Do you allow motion tracking for the next 10 seconds?"

    private let positiveResponses = ["yes", "yeah", "sure", "ok", "okay", "yep", "yup"]
    private let negativeResponses = ["no", "nope", "cancel", "stop"]

    // MARK: – Initialisation

    init(speechService: SpeechService) {
        self.speechService = speechService
    }

    // MARK: – Public API

    /// Asks the consent question and waits for a verbal answer.
    func requestConsent() {
        oneShotDecisionHandler = nil
        awaitingConsent = true
        // Ethical AI – Consent:
        // The app verbally asks permission before any new sensor capture.
        // Data collection begins only after an affirmative response.
        speechService.speak(consentQuestion) { [weak self] in
            self?.listenForAnswer()
        }
    }

    /// Asks for consent and returns the decision as a one-shot callback.
    func requestConsent(completion: @escaping (Bool) -> Void) {
        oneShotDecisionHandler = completion
        awaitingConsent = true
        // Ethical AI – Consent:
        // Reuses the same verbal informed-consent flow for all capture contexts.
        speechService.speak(consentQuestion) { [weak self] in
            self?.listenForAnswer()
        }
    }

    // MARK: – Private helpers

    private func listenForAnswer() {
        didDecide = false
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[ConsentService] Audio session setup failed: \(error)")
            handleConsentDecision(granted: false)
            return
        }

        // Reset the engine so the input node picks up the newly active session format.
        audioEngine.reset()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { buffer, _ in
            request.append(buffer)
        }

        guard let recognizerInstance = speechRecognizer, recognizerInstance.isAvailable else {
            // Ethical AI – Consent Safety:
            // If we cannot reliably hear a "yes", we fail closed (deny by default).
            handleConsentDecision(granted: false)
            return
        }

        recognitionTask = recognizerInstance.recognitionTask(with: request) { [weak self] result, _ in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString.lowercased()
                if self.positiveResponses.contains(where: { text.contains($0) }) {
                    self.handleConsentDecision(granted: true)
                } else if self.negativeResponses.contains(where: { text.contains($0) }) {
                    self.handleConsentDecision(granted: false)
                }
            }
        }

        do {
            try audioEngine.start()
        } catch {
            print("[ConsentService] Audio engine error: \(error)")
            // Ethical AI – Consent Safety:
            // If audio capture fails, do not infer consent.
            handleConsentDecision(granted: false)
            return
        }

        // Timeout after 7 seconds – deny consent if no answer is detected.
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { [weak self] _ in
            self?.handleConsentDecision(granted: false)
        }
    }

    private func handleConsentDecision(granted: Bool) {
        guard !didDecide else { return }
        didDecide = true
        timeoutTimer?.invalidate()
        timeoutTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        DispatchQueue.main.async {
            self.awaitingConsent = false
            let oneShot = self.oneShotDecisionHandler
            self.oneShotDecisionHandler = nil
            oneShot?(granted)
            guard oneShot == nil else { return }
            if granted {
                self.onConsentGranted?()
            } else {
                self.speechService.speak("Understood. Motion tracking has been cancelled.")
                self.onConsentDenied?()
            }
        }
    }
}
