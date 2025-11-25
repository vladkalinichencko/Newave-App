//
//  AnimatedSongCard.swift
//  New Wave
//
//  Created by Владислав Калиниченко on 02.11.2025.
//

import SwiftUI

struct AnimatedSongCard: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerManager
    let song: Song
    let artwork: UIImage?
    let cardOffset: CGFloat
    let cardRotation: Double
    let cardOpacity: Double
    let isTransitioning: Bool
    let onSwipeUp: () -> Void
    let onSwipeDown: () -> Void
    let onAnimationComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let cardHeight: CGFloat = min(max(geometry.size.height * 0.72, 420), 620)

            SongCardView(
                song: song,
                progress: audioPlayer.playbackProgress,
                artwork: artwork
            )
            .frame(height: cardHeight)
            .scaleEffect(1.0)
            .opacity(cardOpacity)
            .offset(y: cardOffset - 50)
            .rotation3DEffect(
                .degrees(cardRotation),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                anchor: .center,
                perspective: 0.8
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isTransitioning {
                            // Respond to both upward and downward swipes
                            _ = min(abs(value.translation.height) / 200, 1.0)

                            withAnimation(.easeInOut(duration: 0.1)) {
                                // This will be handled by parent state
                            }
                        }
                    }
                    .onEnded { value in
                        if !isTransitioning {
                            if value.translation.height < -100 {
                                // Swipe up completed - transition to next song
                                onSwipeUp()
                            } else if value.translation.height > 100 {
                                // Swipe down completed - transition to previous song
                                onSwipeDown()
                            } else {
                                // Swipe cancelled - reset to center
                                onAnimationComplete()
                            }
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.purple, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        AnimatedSongCard(
            song: Song(
                name: "Sample Song",
                artist: "Sample Artist",
                albumCoverURL: "https://picsum.photos/400/400"
            ),
            artwork: UIImage(systemName: "music.note"),
            cardOffset: 0,
            cardRotation: 0,
            cardOpacity: 1.0,
            isTransitioning: false,
            onSwipeUp: {},
            onSwipeDown: {},
            onAnimationComplete: {}
        )
        .environmentObject(AudioPlayerManager())
    }
}
