import AVFoundation
import Speech

// AI-led voice teaching: speaks a question aloud (TTS) and listens for the
// user's spoken answer (STT), for the Study tab's voice quiz mode.
@MainActor
final class VoiceAnswerService: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published private(set) var isListening = false
    @Published private(set) var liveTranscript = ""

    private let synthesizer = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speakCompletion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, onDone: @escaping () -> Void) {
        guard !text.isEmpty else { onDone(); return }
        speakCompletion = onDone
        isSpeaking = true
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        synthesizer.speak(utterance)
    }

    // ponytail: fixed listen window instead of silence detection — the
    // simplest thing that reliably ends the turn on both iOS and macOS.
    // Tune duration (or add real endpointing) if answers get cut off.
    func listen(durationSeconds: Double = 6, onFinal: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard status == .authorized else { return }
                self?.startListening(durationSeconds: durationSeconds, onFinal: onFinal)
            }
        }
    }

    private func startListening(durationSeconds: Double, onFinal: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable, !isListening else { return }
        stopListening()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        guard (try? audioEngine.start()) != nil else { return }
        isListening = true
        liveTranscript = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            Task { @MainActor in self.liveTranscript = result.bestTranscription.formattedString }
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
            guard let self, self.isListening else { return }
            let transcript = self.liveTranscript
            self.stopListening()
            onFinal(transcript)
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension VoiceAnswerService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            let completion = self.speakCompletion
            self.speakCompletion = nil
            completion?()
        }
    }
}
