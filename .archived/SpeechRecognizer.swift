import Foundation
import Speech
import AVFoundation
import SwiftUI

@MainActor
final class SpeechRecognizer: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "de-DE"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var isListening: Bool = false

    func requestAuthorizationIfNeeded() async throws {
        if isAuthorized { return }
        try await withCheckedThrowingContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.isAuthorized = (status == .authorized)
                    if self.isAuthorized {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Spracherkennung nicht autorisiert"]))
                    }
                }
            }
        }
        // Mikrofonberechtigung
        let _ = try await requestMicrophonePermission()
    }

    func start(transcribe: @escaping (String) -> Void) throws {
        guard !isListening else { return }
        try configureSession()

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                transcribe(result.bestTranscription.formattedString)
            }
            if let error = error {
                // Stop on error
                print("[SpeechRecognizer] error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.stop()
                }
            }
        }

        isListening = true
    }

    func stop() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("[SpeechRecognizer] Failed to deactivate audio session: \(error.localizedDescription)")
            #endif
        }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    deinit {
        Task { @MainActor in
            self.stop()
        }
    }
}

private func requestMicrophonePermission() async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                continuation.resume(returning: true)
            } else {
                continuation.resume(throwing: NSError(domain: "SpeechRecognizer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mikrofon nicht autorisiert"]))
            }
        }
    }
}
