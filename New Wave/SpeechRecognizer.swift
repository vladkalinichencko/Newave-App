//
//  SpeechRecognizer.swift
//  New Wave
//

import AVFoundation
import AVFAudio
import Combine
import Speech

final class SpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var accumulatedTranscript: String = ""
    private var currentSessionTranscript: String = ""
    private var shouldContinueListening: Bool = false

    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.defaultTaskHint = .dictation
    }

    func requestPermissions() {
        // Request speech recognition permissions
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                    // Also request microphone permissions
                    self.requestMicrophonePermissions()
                case .denied:
                    print("Speech recognition denied")
                case .restricted:
                    print("Speech recognition restricted")
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    print("Speech recognition unknown status")
                }
            }
        }
    }

    private func requestMicrophonePermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                print(granted ? "Microphone permission granted" : "Microphone permission denied")
            }
        }
    }

    func startRecording() {
        Task(priority: .userInitiated) { @MainActor in
            guard !self.shouldContinueListening else {
                print("SpeechRecognizer already recording; ignoring start request.")
                return
            }

            self.shouldContinueListening = true
            self.accumulatedTranscript = ""
            self.currentSessionTranscript = ""
            self.transcript = ""
            self.isRecording = true

            let success = await self.performStartRecording()
            if success {
                return
            } else {
                self.shouldContinueListening = false
                self.isRecording = false
            }
        }
    }

    @MainActor
    private func performStartRecording() async -> Bool {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            shouldContinueListening = false
            return false
        }

        let speechAuthStatus = SFSpeechRecognizer.authorizationStatus()

        guard speechAuthStatus == .authorized else {
            print("Speech recognition not authorized, requesting permissions...")
            shouldContinueListening = false
            requestPermissions()
            return false
        }

        let micPermission = AVAudioApplication.shared.recordPermission

        guard micPermission == AVAudioApplication.recordPermission.granted else {
            print("Microphone permission not granted, requesting...")
            shouldContinueListening = false
            requestMicrophonePermissions()
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session: \(error)")
            shouldContinueListening = false
            return false
        }

        guard shouldContinueListening else {
            return false
        }

        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.setupAudioEngine { result in
                    continuation.resume(returning: result)
                }
            }
        }

        return success
    }

    private func setupAudioEngine(completion: @escaping (Bool) -> Void) {
        guard shouldContinueListening else {
            completion(false)
            return
        }

        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard configureRecognitionPipeline() else {
            DispatchQueue.main.async {
                print("Failed to configure speech recognition pipeline.")
                self.stopRecording()
            }
            completion(false)
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        engine.prepare()

        do {
            try engine.start()
            completion(true)
        } catch {
            DispatchQueue.main.async {
                print("Failed to start audio engine: \(error)")
                self.stopRecording()
            }
            completion(false)
        }
    }

    private func configureRecognitionPipeline() -> Bool {
        guard shouldContinueListening else { return false }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        recognitionRequest = request

        guard let speechRecognizer else {
            recognitionRequest = nil
            return false
        }

        let task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                self.handleRecognitionResult(result, error: error)
            }
        }

        recognitionTask = task
        return true
    }

    func stopRecording() {
        Task(priority: .userInitiated) { @MainActor in
            self.shouldContinueListening = false
            self.isRecording = false
            await self.performStopRecording()
        }
    }

    @MainActor
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            currentSessionTranscript = result.bestTranscription.formattedString

            let trimmedAccumulated = accumulatedTranscript.trimmingCharacters(in: .whitespaces)
            let trimmedCurrent = currentSessionTranscript.trimmingCharacters(in: .whitespaces)

            let pieces = [trimmedAccumulated, trimmedCurrent].filter { !$0.isEmpty }

            if pieces.isEmpty {
                transcript = ""
            } else if pieces.count == 1 {
                transcript = pieces[0]
            } else {
                transcript = pieces.joined(separator: " ")
            }

            if result.isFinal {
                commitCurrentSessionTranscript()
                restartRecognitionAfterSilence()
            }
        }

        if let error {
            handleRecognitionError(error)
        }
    }

    @MainActor
    private func commitCurrentSessionTranscript() {
        let trimmed = currentSessionTranscript.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if accumulatedTranscript.isEmpty {
            accumulatedTranscript = trimmed
        } else {
            accumulatedTranscript += " " + trimmed
        }

        currentSessionTranscript = ""
        transcript = accumulatedTranscript
    }

    @MainActor
    private func restartRecognitionAfterSilence() {
        guard shouldContinueListening else { return }
        guard audioEngine?.isRunning == true else { return }

        if !configureRecognitionPipeline() {
            print("Failed to restart speech recognition after silence.")
        }
    }

    @MainActor
    private func handleRecognitionError(_ error: Error) {
        guard shouldContinueListening else { return }

        let nsError = error as NSError

        if isCancellationError(nsError) {
            return
        }

        if isNoSpeechError(nsError) {
            print("No speech detected, continuing to listen...")
            commitCurrentSessionTranscript()
            restartRecognitionAfterSilence()
            return
        }

        print("Speech recognition error: \(error)")
        stopRecording()
    }

    private func isNoSpeechError(_ error: NSError) -> Bool {
        error.domain == "kAFAssistantErrorDomain" && error.code == 1110
    }

    private func isCancellationError(_ error: NSError) -> Bool {
        (error.domain == "kLSRErrorDomain" && error.code == 301)
    }

    private func performStopRecording() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.audioEngine?.stop()
                self.audioEngine?.inputNode.removeTap(onBus: 0)

                self.recognitionRequest?.endAudio()
                self.recognitionRequest = nil
                self.recognitionTask?.cancel()
                self.recognitionTask = nil

                continuation.resume()
            }
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playback, mode: .default)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }

        await MainActor.run {
            self.commitCurrentSessionTranscript()
            self.currentSessionTranscript = ""
        }
    }
}
