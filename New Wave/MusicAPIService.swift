//
//  MusicAPIService.swift
//  New Wave
//
//  Created by Владислав Калиниченко on 02.11.2025.
//

import Foundation
import SwiftData
import Combine
import AVFoundation

class MusicAPIService: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let soundCloudBaseURL = "https://api.soundcloud.com"
    // Base URL of the LyricCovers Vector API (FastAPI service)
    // Defaults to localhost but can be overridden via `VectorAPIBaseURL` in Info.plist.
    private let vectorAPIBaseURL: String

    init() {
        vectorAPIBaseURL = MusicAPIService.resolveBaseURL()
    }

    private static func resolveBaseURL() -> String {
        let fallback = "http://127.0.0.1:8888"

        guard let override = Bundle.main.object(
            forInfoDictionaryKey: "VectorAPIBaseURL"
        ) as? String else {
            return fallback
        }

        let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
        let containsPlaceholder = trimmed.contains("<mac-ip>") || trimmed.contains("<mac_ip>")

        // If the plist still has the placeholder or the URL is malformed, use the safe fallback.
        guard !trimmed.isEmpty, !containsPlaceholder, URL(string: trimmed) != nil else {
            print("[VectorAPI] VectorAPIBaseURL is missing/placeholder; update Info.plist to your Mac IP. Falling back to \(fallback)")
            return fallback
        }

        return trimmed
    }

    // SoundCloud API integration
    func searchTracks(query: String, limit: Int = 20) async throws -> [Song] {
        isLoading = true
        defer { isLoading = false }

        // This is a mock implementation - replace with actual SoundCloud API calls
        // You'll need to add SoundCloud API authentication

        let mockSongs = generateMockSongs(for: query, count: limit)
        return mockSongs
    }

    /// Stream songs directly from the LyricCovers `/search/combined` endpoint.
    /// For each fully received song, `onSong` is called on the main actor so the UI
    /// can append it to the swipe queue.
    func streamSongsFromDescription(_ description: String, topK: Int = 20, onSong: @escaping (Song) -> Void) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        guard let url = URL(string: "\(vectorAPIBaseURL)/search/combined") else {
            errorMessage = APIError.invalidURL.localizedDescription
            return
        }

        print("[VectorAPI] >>> start stream, query='\(description)', topK=\(topK), url=\(url)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = SearchRequestDTO(query: description, top_k: topK)

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            errorMessage = APIError.encodingError.localizedDescription
            return
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[VectorAPI] <<< server error, status=\(code)")
                await MainActor.run {
                    errorMessage = APIError.serverError.localizedDescription
                }
                return
            }

            print("[VectorAPI] <<< connected, streaming NDJSON...")
            var streamed = 0
            let decoder = JSONDecoder()

            // The server streams NDJSON (one JSON object per line)
            for try await line in bytes.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                do {
                let data = Data(trimmed.utf8)
                let payload = try decoder.decode(CombinedSongPayload.self, from: data)
                let song = try createSong(from: payload)
                streamed += 1
                print("[VectorAPI] <<< song #\(streamed): \(song.artist) — \(song.name)")
                await MainActor.run {
                    onSong(song)
                }
            } catch {
                // Skip malformed lines but keep the stream alive
                print("Failed to decode streamed song: \(error)")
            }
        }
        print("[VectorAPI] <<< stream finished, total songs=\(streamed)")
    } catch {
        print("[VectorAPI] <<< network error: \(error)")
        await MainActor.run {
            errorMessage = APIError.networkError.localizedDescription
        }
    }
}

    private func createSong(from payload: CombinedSongPayload) throws -> Song {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory

        let songID = UUID().uuidString

        // Decode and write audio
        guard let audioData = Data(base64Encoded: payload.audio) else {
            throw APIError.decodingError
        }
        let audioURL = cachesDirectory.appendingPathComponent("song-\(songID).mp3")
        try audioData.write(to: audioURL, options: .atomic)

        // Measure duration so the scrubber works (no deprecated AVAsset.duration)
        let durationSeconds: TimeInterval
        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            durationSeconds = player.duration
        } catch {
            durationSeconds = 0
        }
        let safeDuration = durationSeconds.isFinite && durationSeconds > 0 ? durationSeconds : 0

        // Decode and write cover image
        var coverURLString: String? = nil
        if let coverData = Data(base64Encoded: payload.cover) {
            let coverURL = cachesDirectory.appendingPathComponent("cover-\(songID).jpg")
            try? coverData.write(to: coverURL, options: .atomic)
            coverURLString = coverURL.absoluteString
        }

        let song = Song(
            name: payload.title,
            artist: payload.artist,
            albumCoverURL: coverURLString,
            audioURL: audioURL.absoluteString,
            duration: safeDuration
        )
        song.isLoaded = true
        return song
    }

    private func generateMockSongs(for query: String, count: Int) -> [Song] {
        let adjectives = ["Happy", "Sad", "Energetic", "Calm", "Upbeat", "Relaxing", "Exciting", "Peaceful"]
        let genres = ["Pop", "Rock", "Jazz", "Electronic", "Classical", "Hip-Hop", "R&B", "Country"]
        let artists = ["Artist Alpha", "The Beta Band", "Gamma Waves", "Delta Force", "Echo Valley", "Foxtrot", "Nova Lights", "Quantum Sound"]

        var songs: [Song] = []

        for i in 0..<count {
            let adjective = adjectives.randomElement() ?? "Amazing"
            let genre = genres.randomElement() ?? "Pop"
            let artist = artists.randomElement() ?? "Unknown Artist"

            let songName = "\(adjective) \(genre) Song \(i + 1)"
            let albumCoverURL = "https://picsum.photos/400/400?random=\(i)"
            let audioURL = "\(Song.sampleAudioURL)?v=\(i)" // Mock URL

            let song = Song(
                name: songName,
                artist: artist,
                albumCoverURL: albumCoverURL,
                audioURL: audioURL,
                duration: Double.random(in: 120...240) // 2-4 minutes
            )

            songs.append(song)
        }

        return songs
    }
}

// API Request/Response Models for LyricCovers Vector API

/// Matches the FastAPI `SearchRequest` model.
struct SearchRequestDTO: Codable {
    let query: String
    let top_k: Int
}

/// Matches one line of the `/search/combined` NDJSON stream:
/// {
///   "title": "...",
///   "artist": "...",
///   "audio": "<base64 audio bytes>",
///   "cover": "<base64 image bytes>"
/// }
struct CombinedSongPayload: Codable {
    let title: String
    let artist: String
    let audio: String
    let cover: String
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError
    case decodingError
    case noData
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .serverError:
            return "Server error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .noData:
            return "No data received"
        case .encodingError:
            return "Failed to encode request body"
        }
    }
}

// Lightweight DTO for external APIs (e.g., SoundCloud) to keep app models decoupled.
struct APISong: Identifiable {
    let id: String
    let name: String
    let artist: String
    let albumCoverURL: String?
    let audioURL: String?
    let duration: TimeInterval
}

// SoundCloud API Service (more detailed implementation)
class SoundCloudAPIService {
    private let clientID: String // You'll need to get this from SoundCloud developer portal
    private let baseURL = "https://api.soundcloud.com"

    init(clientID: String) {
        self.clientID = clientID
    }

    func searchTracks(query: String, limit: Int = 20) async throws -> [APISong] {
        guard var components = URLComponents(string: "\(baseURL)/tracks") else {
            throw APIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "client_id", value: clientID)
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        let tracks = try JSONDecoder().decode([SoundCloudTrack].self, from: data)
        return tracks.map { track in
            APISong(
                id: String(track.id),
                name: track.title,
                artist: track.username,
                albumCoverURL: track.artworkURL?.replacingOccurrences(of: "-large", with: "-t500x500"),
                audioURL: track.streamURL,
                duration: TimeInterval(track.duration) / 1000.0
            )
        }
    }
}

struct SoundCloudTrack: Codable {
    let id: Int
    let title: String
    let username: String
    let artworkURL: String?
    let streamURL: String?
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case id, title, username, duration
        case artworkURL = "artwork_url"
        case streamURL = "stream_url"
    }

    func toAPISong() -> APISong {
        return APISong(
            id: String(id),
            name: title,
            artist: username,
            albumCoverURL: artworkURL?.replacingOccurrences(of: "-large", with: "-t500x500"),
            audioURL: streamURL,
            duration: TimeInterval(duration) / 1000.0 // Convert from milliseconds
        )
    }
}
