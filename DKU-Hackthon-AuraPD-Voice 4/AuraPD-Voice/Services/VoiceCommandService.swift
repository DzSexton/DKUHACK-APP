import Foundation
import Speech
import AVFoundation

/// Listens continuously for the wake phrase "check my condition" using the on-device
/// `SFSpeechRecognizer` API.
///
/// When the phrase is detected the `onWakeWordDetected` closure is invoked on the
/// main thread.  All recognition runs on-device (`requiresOnDeviceRecognition = true`)
/// so no audio data leaves the device.
final class VoiceCommandService: NSObject, ObservableObject, SFSpeechRecognizerDelegate {

    // MARK: – Published state
    @Published private(set) var isListening = false
    @Published private(set) var recognisedText = ""
    /// False when the on-device speech model is unavailable (not yet downloaded, etc.).
    @Published private(set) var isRecognizerAvailable = false

    // MARK: – Callbacks
    var onWakeWordDetected: (() -> Void)?
    var onListeningStateChanged: ((Bool) -> Void)?

    // MARK: – Private
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    /// Whether the caller wants the service to be listening. Used to decide
    /// whether to restart after errors or audio-route changes.
    private var shouldBeListening = false
    private var hasTap = false

    private let wakePhrase = "check my condition"

    override init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        speechRecognizer?.delegate = self
        speechRecognizer?.defaultTaskHint = .search
        isRecognizerAvailable = speechRecognizer?.isAvailable ?? false

        // Restart when audio hardware changes (e.g. route change, interruption end).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineConfigChange),
            name: .AVAudioEngineConfigurationChange,
            object: audioEngine
        )
    }

    // MARK: – Public API

    /// Requests authorisation and starts continuous background listening.
    func startListening() {
        shouldBeListening = true
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            guard status == .authorized else {
                print("[VoiceCommandService] Speech recognition not authorised.")
                self.publishListeningState(false)
                return
            }
            DispatchQueue.main.async { self.beginRecognition() }
        }
    }

    /// Stops listening and tears down the audio engine.
    func stopListening() {
        shouldBeListening = false
        tearDown()
        publishListeningState(false)
    }

    // MARK: – SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            self.isRecognizerAvailable = available
            if !available {
                self.tearDown()
                self.publishListeningState(false)
            } else if self.shouldBeListening {
                self.beginRecognition()
            }
        }
    }

    // MARK: – Private helpers

    @objc private func handleEngineConfigChange() {
        guard shouldBeListening else { return }
        // Brief delay lets the system settle the new audio route.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.beginRecognition()
        }
    }

    private func beginRecognition() {
        tearDown()

        let session = AVAudioSession.sharedInstance()
        do {
            // .mixWithOthers lets the engine keep running when the app is backgrounded
            // alongside other audio (required for background audio mode).
            try session.setCategory(.record, mode: .measurement,
                                    options: [.duckOthers, .allowBluetooth, .mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VoiceCommandService] Audio session setup failed: \(error)")
            publishListeningState(false)
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            DispatchQueue.main.async { self.isRecognizerAvailable = false }
            publishListeningState(false)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        hasTap = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString.lowercased()
                DispatchQueue.main.async { self.recognisedText = text }

                if text.contains(self.wakePhrase) {
                    DispatchQueue.main.async {
                        self.tearDown()
                        self.publishListeningState(false)
                        self.onWakeWordDetected?()
                    }
                    return
                }
            }

            if let error, self.shouldBeListening {
                // 1110 = silence timeout (normal); all other errors also restart,
                // but with a small delay to avoid tight loops on persistent failures.
                let delay: TimeInterval = (error as NSError).code == 1110 ? 0 : 0.5
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard self.shouldBeListening else { return }
                    self.beginRecognition()
                }
            }
        }

        do {
            try audioEngine.start()
            DispatchQueue.main.async { self.isRecognizerAvailable = true }
            publishListeningState(true)
        } catch {
            print("[VoiceCommandService] Audio engine start failed: \(error)")
            publishListeningState(false)
        }
    }

    private func tearDown() {
        audioEngine.stop()
        if hasTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func publishListeningState(_ listening: Bool) {
        DispatchQueue.main.async {
            self.isListening = listening
            self.onListeningStateChanged?(listening)
        }
    }
}
