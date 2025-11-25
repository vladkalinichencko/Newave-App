//
//  BottomControlsView.swift
//  New Wave
//

import SwiftUI

struct BottomControlsView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerManager
    let currentSong: Song?
    let onPlayPause: () -> Void
    let isRecording: Binding<Bool>
    let transcript: Binding<String>
    let safeAreaBottom: CGFloat
    @State private var sliderProgress: Double = 0
    @State private var isScrubbing: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                playPauseButton
                progressBar
            }

            VoiceInputButton(
                isRecording: isRecording,
                transcript: transcript
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 12)
        .padding(.bottom, safeAreaBottom + 12)
        .onReceive(audioPlayer.$playbackProgress) { value in
            if !isScrubbing {
                sliderProgress = value
            }
        }
    }

    private var playPauseButton: some View {
        Button(action: {
            HapticFeedback.medium()
            print("[UI] Play/Pause tapped (isPlaying=\(audioPlayer.isPlaying))")
            onPlayPause()
        }) {
            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 24, weight: .medium))
                .frame(width: 50, height: 60)
                .contentShape(Circle())
        }
        .buttonStyle(.glass)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let containerWidth: CGFloat = geometry.size.width
            let trackWidth = max(0, containerWidth - 60)
            let horizontalInset: CGFloat = (60 / 2 - 10)
            let displayProgress = isScrubbing ? sliderProgress : audioPlayer.playbackProgress
            let progressWidth = max(0, trackWidth * displayProgress)

            VStack {
                Spacer()
                Button(action: {
                    HapticFeedback.selectionChanged()
                }) {
                    Capsule()
                        .fill(Color.clear)
                        .frame(height: 60)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .opacity(0.3)
                                .frame(width: trackWidth, height: 10)
                                .padding(.horizontal, horizontalInset)
                        }
                        .overlay(alignment: .leading) {
                            Capsule()
                                .frame(width: progressWidth, height: 10)
                                .padding(.horizontal, horizontalInset)
                                .animation(.easeInOut(duration: 0.2), value: displayProgress)
                        }
                }
                .buttonStyle(.glass)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            let newProgress = normalizedProgress(for: value.location.x, trackWidth: trackWidth, inset: horizontalInset)
                            sliderProgress = newProgress
                            audioPlayer.seekToProgress(newProgress)
                            print("[UI] Scrubbing progress: \(newProgress)")
                        }
                        .onEnded { value in
                            let newProgress = normalizedProgress(for: value.location.x, trackWidth: trackWidth, inset: horizontalInset)
                            sliderProgress = newProgress
                            audioPlayer.seekToProgress(newProgress)
                            DispatchQueue.main.async {
                                isScrubbing = false
                            }
                            print("[UI] Scrub ended at progress: \(newProgress)")
                        }
                )
            }
        }
    }

    private func normalizedProgress(for xPosition: CGFloat, trackWidth: CGFloat, inset: CGFloat) -> Double {
        let localX = xPosition - inset
        let ratio = localX / max(trackWidth, 1)
        return Double(max(0, min(1, ratio)))
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.purple, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        BottomControlsView(
            currentSong: nil,
            onPlayPause: {},
            isRecording: .constant(false),
            transcript: .constant(""),
            safeAreaBottom: 0
        )
        .environmentObject(AudioPlayerManager())
    }
}
