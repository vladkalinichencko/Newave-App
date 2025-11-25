//
//  Song.swift
//  New Wave
//

import Foundation
import SwiftData

@Model
final class Song {
    var id: UUID
    var name: String
    var artist: String
    var albumCoverURL: String?
    var audioURL: String?
    var duration: TimeInterval
    var isLoaded: Bool = false
    var timestamp: Date

    init(name: String, artist: String, albumCoverURL: String? = nil, audioURL: String? = nil, duration: TimeInterval = 0) {
        self.id = UUID()
        self.name = name
        self.artist = artist
        self.albumCoverURL = albumCoverURL
        self.audioURL = audioURL
        self.duration = duration
        self.timestamp = Date()
    }
}
