//
//  VoiceInputButton.swift
//  New Wave
//
//  Created by Владислав Калиниченко on 02.11.2025.
//

import SwiftUI

struct VoiceInputButton: View {
    @Binding var isRecording: Bool
    @Binding var transcript: String
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var transcriptUpdateTask: Task<Void, Never>?
    @State private var isAwaitingToggle: Bool = false
    @State private var toggleResetTask: Task<Void, Never>?

    init(isRecording: Binding<Bool>, transcript: Binding<String>) {
        self._isRecording = isRecording
        self._transcript = transcript
    }

    var body: some View {
        Button(action: toggleRecording) {
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 28, weight: .medium))
                .frame(width: 50, height: 60)
                .contentShape(Circle())
        }

        .buttonStyle(.glass)
        .disabled(isAwaitingToggle)
        .onAppear {
            speechRecognizer.requestPermissions()
            triggerLocalNetworkPrompt()
        }
        .onReceive(speechRecognizer.$transcript) { newTranscript in
            transcriptUpdateTask?.cancel()

            transcriptUpdateTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                if !Task.isCancelled {
                    withAnimation {
                        transcript = newTranscript
                    }
                }
            }
        }
        .onReceive(speechRecognizer.$isRecording) { active in
            withAnimation(.easeOut(duration: 0.15)) {
                isRecording = active
            }
            isAwaitingToggle = false
            toggleResetTask?.cancel()
        }
        .onDisappear {
            transcriptUpdateTask?.cancel()
            toggleResetTask?.cancel()
        }
    }

    private func toggleRecording() {
        guard !isAwaitingToggle else {
            print("Ignoring tap while awaiting recorder transition")
            return
        }
        isAwaitingToggle = true

        HapticFeedback.medium()
        print("Button tapped, recognizer state: \(speechRecognizer.isRecording)")

        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        } else {
            speechRecognizer.startRecording()
        }

        toggleResetTask?.cancel()
        toggleResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            isAwaitingToggle = false
        }
    }

    private func triggerLocalNetworkPrompt() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            LocalNetworkAuthorizer.shared.requestAuthorizationIfNeeded(from: rootVC)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        VoiceInputButton(
            isRecording: .constant(false),
            transcript: .constant("")
        )
    }
}
