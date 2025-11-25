//
//  Song+Preview.swift
//  New Wave
//

import SwiftUI

extension Song {
    static let sampleAudioURL = "https://samplelib.com/lib/preview/mp3/sample-3s.mp3"

    var accentColor: Color {
        let hash = abs(name.hashValue &+ artist.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.85)
    }
}

#if DEBUG
extension Song {
    static var previewSongs: [Song] {
        [
            Song(name: "Neon Drift", artist: "Aurora Pulse", albumCoverURL: "https://picsum.photos/seed/neon/600/600", audioURL: sampleAudioURL, duration: 210),
            Song(name: "Skyline Echoes", artist: "Citywave", albumCoverURL: "https://picsum.photos/seed/skyline/600/600", audioURL: sampleAudioURL, duration: 185),
            Song(name: "Velvet Midnight", artist: "Lunar Grove", albumCoverURL: "https://picsum.photos/seed/velvet/600/600", audioURL: sampleAudioURL, duration: 240),
            Song(name: "Sunrise Bloom", artist: "Golden Hour", albumCoverURL: "https://picsum.photos/seed/sunrise/600/600", audioURL: sampleAudioURL, duration: 198),
            Song(name: "Crystal Tides", artist: "Seabreeze", albumCoverURL: "https://picsum.photos/seed/crystal/600/600", audioURL: sampleAudioURL, duration: 205)
        ]
    }
}
#endif
