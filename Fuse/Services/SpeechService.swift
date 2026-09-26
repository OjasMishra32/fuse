import Foundation
import Observation
import Speech
import AVFoundation

// MARK: - Speech: "say what to fuse" while holding the seam
//
// SFSpeechRecognizer (en-US, on-device when the assets are present) fed by an AVAudioEngine
// tap. Partial results stream into `transcript`. Built to survive the Simulator: a missing
// microphone or missing on-device model sets `errorText` instead of crashing, and an
// on-device failure falls back to the server recognizer once.

@MainActor
@Observable
final class SpeechService {
    static let shared = SpeechService()

    var transcript: String = ""
    private(set) var isListening = false
    private(set) var authorized = false
    var errorText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var usingOnDevice = false
    @ObservationIgnored private var receivedAnyResult = false
    /// Bumped on every (re)start and on teardown so callbacks from a stale task are ignored.
    @ObservationIgnored private var generation = 0

    private init() {
        authorized = SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        authorized = speechStatus == .authorized && micGranted
        if !authorized {
            errorText = speechStatus == .authorized
                ? "Microphone access is off. Allow it in Settings › Privacy › Microphone."
                : "Speech recognition is off. Allow it in Settings › Privacy › Speech Recognition."
        }
        return authorized
    }

    // MARK: - Start / stop

    /// Clears the transcript and starts streaming partial results into it.
    func start() async {
        guard !isListening else { return }
        errorText = nil
        if !authorized {
            guard await requestAuthorization() else { return }
        }
        guard let recognizer, recognizer.isAvailable else {
            errorText = "Speech recognition isn't available right now."
            return
        }
        tearDown()
        transcript = ""
        receivedAnyResult = false
        usingOnDevice = recognizer.supportsOnDeviceRecognition
        beginRecognition(with: recognizer)
    }

    /// Ends audio capture and lets the recognizer deliver its final transcript.
    func stop() {
        guard isListening else { return }
        isListening = false
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        deactivateSession()
        // `task`/`request` stay alive until the final callback lands in handle(...).
    }

    // MARK: - Recognition pipeline

    private func beginRecognition(with recognizer: SFSpeechRecognizer) {
        generation += 1
        let thisGeneration = generation
        isListening = false   // flipped back on only once audio is flowing

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorText = "Couldn't open the microphone. \(error.localizedDescription)"
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorText = "No microphone input is available on this device."
            deactivateSession()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = usingOnDevice
        self.request = request

        inputNode.removeTap(onBus: 0)
        // iOS 27 deprecates this in favour of a throwing variant, but the 27.1 SDK exposes the
        // replacement only as `__installTap(onBus:bufferSize:format:error:block:)` (no Swift
        // refinement yet). The deprecated call still works; revisit when the overlay lands.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.request = nil
            errorText = "Couldn't start audio capture. \(error.localizedDescription)"
            deactivateSession()
            return
        }

        isListening = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Extract value types here; the handler runs on the recognizer's queue.
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failure = error
            Task { @MainActor in
                self?.handle(generation: thisGeneration, text: text, isFinal: isFinal, error: failure)
            }
        }
    }

    private func handle(generation callbackGeneration: Int, text: String?, isFinal: Bool, error: Error?) {
        guard callbackGeneration == generation else { return }

        if let text {
            transcript = text
            if !text.isEmpty { receivedAnyResult = true }
        }

        if let error {
            // On-device assets can be missing (notably in Simulator). Retry once via the server.
            if isListening, usingOnDevice, !receivedAnyResult, let recognizer {
                usingOnDevice = false
                tearDown()
                beginRecognition(with: recognizer)
                return
            }
            if isListening {
                errorText = Self.friendly(error)
            }
            finish()
            return
        }

        if isFinal { finish() }
    }

    private func finish() {
        tearDown()
        isListening = false
    }

    /// Stops everything without touching `transcript`.
    private func tearDown() {
        generation += 1
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        deactivateSession()
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func friendly(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain" || nsError.domain == "kLSRErrorDomain" {
            return "Didn't catch that — hold the seam and try again."
        }
        return nsError.localizedDescription
    }
}
