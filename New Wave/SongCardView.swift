//
//  SongCardView.swift
//  New Wave
//

import SwiftUI

struct SongCardView: View {
    let song: Song
    let progress: Double
    let artwork: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            // Album cover
            coverImage
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Song info
            VStack(alignment: .leading, spacing: 8) {
                Text(song.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(song.artist)
                    .font(.title3)
                    .opacity(0.8)
            }
            .frame(maxWidth: 280, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let artwork {
            Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholderCover
        }
    }

    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [
                        song.accentColor.opacity(0.9),
                        song.accentColor.opacity(0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 40, weight: .medium))
            )
    }
}

struct EmptyStateView: View {
    enum Mode {
        case prompt
        case loading
        case noResults
    }

    let state: Mode

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 46, weight: .medium))

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .opacity(0.75)
            }

            if state == .loading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .foregroundStyle(.primary)
    }

    private var title: String {
        switch state {
        case .prompt:
            return "Tap the mic and describe what you want"
        case .loading:
            return "Loading your newest wave"
        case .noResults:
            return "No tracks yet"
        }
    }

    private var subtitle: String? {
        switch state {
        case .prompt:
            return "We will pull songs and artwork right after you speak."
        case .loading:
            return "Give us a second to match your vibe."
        case .noResults:
            return "Try again with a clearer description."
        }
    }

    private var iconName: String {
        switch state {
        case .prompt:
            return "mic"
        case .loading:
            return "wand.and.sparkles"
        case .noResults:
            return "music.quarternote.3"
        }
    }
}

#Preview("Empty State") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.purple.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
        EmptyStateView(state: .prompt)
    }
    .ignoresSafeArea()
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.purple, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        SongCardView(
            song: Song(
                name: "Sample Song",
                artist: "Sample Artist",
                albumCoverURL: "https://picsum.photos/400/400"
            ),
            progress: 0.3,
            artwork: UIImage(systemName: "music.note")
        )
    }
}
