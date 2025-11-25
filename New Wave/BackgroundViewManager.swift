//
//  BackgroundViewManager.swift
//  New Wave
//
//  Created by Владислав Калиниченко on 02.11.2025.
//

import SwiftUI

struct BackgroundViewManager: View {
    let songStates: [SongState]
    let backgroundIndex: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layers for all song states
                ForEach(Array(songStates.enumerated()), id: \.element.id) { index, songState in
                    if let backgroundImage = songState.backgroundImage {
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 80)
                            .opacity(0.7)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .opacity(index == backgroundIndex ? 1.0 : 0.0)
                            .scaleEffect(index == backgroundIndex ? 1.0 : 1.1)
                            .animation(.easeInOut(duration: 0.6), value: backgroundIndex)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(edges: .all)
            .clipped()
        }
        .ignoresSafeArea(edges: .all)
        .clipped()
    }
}

#Preview {
    BackgroundViewManager(
        songStates: [],
        backgroundIndex: 0
    )
}
