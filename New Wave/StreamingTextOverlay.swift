//
//  StreamingTextOverlay.swift
//  New Wave
//

import SwiftUI

struct StreamingTextOverlay: View {
    let transcript: String
    let isRecording: Bool

    var body: some View {
        VStack {
            Spacer()

            if !transcript.isEmpty {
                Text(transcript)
                    .font(.title)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .background {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .frame(maxWidth: 320, alignment: .center)
            }
            Spacer()
        }
    }
}

#Preview("Tap to toggle") {
    PreviewHarness()
}

private struct PreviewHarness: View {
    @State private var transcript: String = ""
    @State private var isRecording: Bool = true

    var body: some View {
        ZStack {
            // A full-screen tappable background to toggle the transcript
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                        if transcript.isEmpty {
                            withAnimation {
                                transcript = "I want to hear some relaxing jazz music"
                            }
                        } else {
                            withAnimation {
                                transcript = ""
                            }
                        }
                    }
            StreamingTextOverlay(
                transcript: transcript,
                isRecording: isRecording
            )
        }
    }
}
