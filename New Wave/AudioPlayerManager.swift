//
//  AudioPlayerManager.swift
//  New Wave
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var currentSong: Song?
    @Published var isBuffering: Bool = false

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var endObserver: Any?

    override init() {
        super.init()
        setupAudioSession()
    }

    deinit {
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        // Remove time observer safely
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        statusObserver?.invalidate()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func ensurePlaybackSessionActive() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("[AudioPlayer] Failed to activate playback session: \(error)")
        }
    }

    func playSong(_ song: Song, autoStart: Bool = true) {
        ensurePlaybackSessionActive()
        currentSong = song
        playbackProgress = 0
        currentTime = 0
        duration = song.duration
        removeTimeObserver()
        statusObserver?.invalidate()
        statusObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        guard let streamURL = resolveStreamURL(for: song) else {
            print("[AudioPlayer] Invalid audio URL for song \(song.name)")
            return
        }

        isBuffering = true
        print("[AudioPlayer] Loading song: \(song.name) -> \(streamURL)")

        // Create player item
        let item = AVPlayerItem(url: streamURL)
        playerItem = item
        // Load duration asynchronously (non-deprecated API)
        Task { @MainActor [weak self, weak item] in
            guard let self, let item else { return }
            do {
                let loadedDuration = try await item.asset.load(.duration)
                let seconds = loadedDuration.seconds
                if seconds.isFinite && seconds > 0 {
                    self.duration = seconds
                }
            } catch {
                // Keep duration at existing value if load fails
            }
        }

        // Observe player item status (KVO)
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard let self else { return }
            Task { @MainActor in
                switch observedItem.status {
                case .readyToPlay:
                    self.isBuffering = false
                    print("[AudioPlayer] Ready to play: \(song.name)")
                case .failed:
                    self.isBuffering = false
                    let errorDesc = observedItem.error?.localizedDescription ?? "unknown"
                    print("[AudioPlayer] Failed to load player item: \(errorDesc)")
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        // Observe end of playback
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSongEnded()
            }
        }

        // Create or replace player
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        // Add time observer
        addTimeObserver()

        // Start or stay paused based on caller intent
        if autoStart {
            player?.play()
            isPlaying = true
            print("[AudioPlayer] Playback started")
        } else {
            player?.pause()
            isPlaying = false
            print("[AudioPlayer] Prepared without autoplay")
        }
    }

    func play() {
        ensurePlaybackSessionActive()
        guard let player = player else { return }

        if player.currentItem?.status == .readyToPlay {
            player.play()
            isPlaying = true
        }
    }

    private func resolveStreamURL(for song: Song) -> URL? {
        guard let audioString = song.audioURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !audioString.isEmpty else {
            return nil
        }

        if let url = URL(string: audioString) {
            return url
        }

        // Handle raw file paths without scheme
        let fileURL = URL(fileURLWithPath: audioString)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        return nil
    }

    func pause() {
        player?.pause()
        isPlaying = false
        print("[AudioPlayer] Paused")
    }

    func stopPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        currentTime = 0
        duration = 0
        playbackProgress = 0
        removeTimeObserver()
    }

    func seekTo(_ time: TimeInterval) {
        guard let player = player else { return }

        let targetTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: targetTime) { [weak self] completed in
            guard completed, let self else { return }
            Task { @MainActor in
                self.updateProgress()
                print("[AudioPlayer] Seek complete to time: \(time)s")
            }
        }
    }

    func seekToProgress(_ progress: Double) {
        guard duration > 0 else { return }
        let time = duration * progress
        seekTo(time)
        print("[AudioPlayer] Seek to progress: \(progress) time: \(time)s")
    }

    private func addTimeObserver() {
        guard let player = player else { return }

        removeTimeObserver()

        let interval = CMTime(seconds: 0.1, preferredTimescale: 1000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateProgress()
            }
        }
    }

    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    @MainActor
    private func updateProgress() {
        guard let player = player,
              let currentItem = player.currentItem else { return }

        currentTime = player.currentTime().seconds

        if duration > 0 {
            playbackProgress = currentTime / duration
        } else {
            playbackProgress = 0
        }

        // Check if song has ended
        if currentTime >= duration - 0.1 && duration > 0 {
            handleSongEnded()
        }
    }

    private func handleSongEnded() {
        isPlaying = false
        print("[AudioPlayer] Song ended")
        // Notify that the song has ended - you could implement auto-play next song here
        NotificationCenter.default.post(name: .songDidEnd, object: currentSong)
    }
}

// Notification extension
extension Notification.Name {
    static let songDidEnd = Notification.Name("songDidEnd")
}

// MARK: - AVPlayerItem Duration Extension
extension CMTime {
    var seconds: TimeInterval {
        return CMTimeGetSeconds(self)
    }
}
