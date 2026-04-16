import Foundation
import AVFoundation

/// Wraps `AVSpeechSynthesizer` to provide text-to-speech output for the app.
///
/// Uses a slower, more accessible speech rate suitable for patients with PD.
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    // MARK: – Published state
    @Published private(set) var isSpeaking = false

    // MARK: – Private
    private let synthesizer = AVSpeechSynthesizer()

    /// Completion called when the utterance finishes.
    private var completionHandler: (() -> Void)?
    /// Tracks which utterance instance the current completion belongs to.
    private var pendingUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: – Public API

    /// Speaks the given text.
    /// - Parameters:
    ///   - text: The string to synthesise.
    ///   - completion: Optional closure executed after speech completes.
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        // If already speaking, stop without triggering the previous completion.
        if synthesizer.isSpeaking {
            completionHandler = nil
            pendingUtterance = nil
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45          // Slightly slower than default (0.5) for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        completionHandler = completion
        pendingUtterance = utterance

        configureAudioSession()
        synthesizer.speak(utterance)

        DispatchQueue.main.async { self.isSpeaking = true }
    }

    /// Immediately stops any ongoing speech.
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: – AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard utterance === self.pendingUtterance else { return }
            self.isSpeaking = false
            self.pendingUtterance = nil
            self.completionHandler?()
            self.completionHandler = nil
        }
    }

    // MARK: – Private helpers

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
