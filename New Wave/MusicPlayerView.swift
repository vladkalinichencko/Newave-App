//
//  MusicPlayerView.swift
//  New Wave
//
//  Created by Владислав Калиниченко on 02.11.2025.
//

import SwiftUI
import SwiftData
import AVFoundation

struct SongState: Identifiable {
    let id = UUID()
    let song: Song
    var backgroundImage: UIImage?
    var isImageLoading: Bool = false

    init(song: Song) {
        self.song = song
    }
}

struct MusicPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayerManager
    @EnvironmentObject private var apiService: MusicAPIService
    @Query private var songs: [Song]
    @State private var currentIndex: Int = 0
    @State private var songQueue: [Song] = []
    @State private var cardOffset: CGFloat = 0
    @State private var cardRotation: Double = 0
    @State private var cardOpacity: Double = 1.0
    @State private var isTransitioning: Bool = false
    @State private var songStates: [SongState] = []
    @State private var backgroundIndex: Int = 0
    @State private var isRecording: Bool = false
    @State private var hasRequestedQuery: Bool = false
    @State private var isLoadingSongs: Bool = false
    @State private var transcript: String = ""
    @State private var transcriptDebounceTask: Task<Void, Never>? = nil
    @State private var lastSubmittedQuery: String = ""

    var currentSong: Song? {
        guard currentIndex < songQueue.count else { return nil }
        return songQueue[currentIndex]
    }

    
    var body: some View {
        GeometryReader { geometry in
            let overlayVisible = isRecording && !transcript.isEmpty
            ZStack {
                BackgroundViewManager(
                    songStates: songStates,
                    backgroundIndex: backgroundIndex
                )

                mainContentView(geometry: geometry)
                    .zIndex(0)

                if overlayVisible {
                    StreamingTextOverlay(
                        transcript: transcript,
                        isRecording: isRecording
                    )
                    .transition(
                        .move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .scale)
                    )
                    .zIndex(2)
                }

                BottomControlsView(
                    currentSong: currentSong,
                    onPlayPause: handlePlayPause,
                    isRecording: $isRecording,
                    transcript: $transcript,
                    safeAreaBottom: geometry.safeAreaInsets.bottom
                )
                .zIndex(3)
            }
            .ignoresSafeArea(edges: .all)
            .animation(
                .easeOut(duration: 1.0),
                value: overlayVisible
            )
        }
        .onAppear {
            setupAudioSession()
        }
        .onChange(of: transcript) { _, newValue in
            print("MusicPlayerView transcript changed to: '\(newValue)'")
            handleTranscriptChange(newValue)
        }
        .onChange(of: isRecording) { _, newValue in
            handleRecordingStateChange(isRecording: newValue)
        }
    }

    
    private func mainContentView(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            VStack {
                if songQueue.isEmpty {
                    Spacer()
                    EmptyStateView(state: emptyStateMode)
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    currentSongCard()
                }
            }
            Spacer()
        }
    }

    private var emptyStateMode: EmptyStateView.Mode {
        if isLoadingSongs {
            return .loading
        }
        if hasRequestedQuery {
            return .noResults
        }
        return .prompt
    }

    private func currentSongCard() -> some View {
        Group {
            if let song = currentSong {
                let currentState = songStates[safe: currentIndex]
                AnimatedSongCard(
                    song: song,
                    artwork: currentState?.backgroundImage,
                    cardOffset: cardOffset,
                    cardRotation: cardRotation,
                    cardOpacity: cardOpacity,
                    isTransitioning: isTransitioning,
                    onSwipeUp: transitionToNextSong,
                    onSwipeDown: transitionToPreviousSong,
                    onAnimationComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            cardOffset = 0
                            cardRotation = 0
                            cardOpacity = 1.0
                        }
                    }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if !isTransitioning {
                                let progress = min(abs(value.translation.height) / 200, 1.0)
                                cardOffset = value.translation.height

                                if value.translation.height < 0 {
                                    cardRotation = -Double(progress * 45)
                                } else {
                                    cardRotation = Double(progress * 45)
                                }

                                cardOpacity = 1.0 - progress * 0.8
                            }
                        }
                )
            } else {
                EmptyView()
            }
        }
    }

    private func transitionToNextSong() {
        guard !isTransitioning else { return }

        // Check if we can go to next song
        if currentIndex < songQueue.count - 1 {
            isTransitioning = true

            // CHANGE BACKGROUND IMMEDIATELY - before any animation
            backgroundIndex = currentIndex + 1
            currentIndex += 1
            audioPlayer.pause()

            // Animate current song out upward
            withAnimation(.easeInOut(duration: 0.3)) {
                cardOffset = -300
                cardRotation = -45
                cardOpacity = 0
            }

            // Start new song from BOTTOM and animate UPWARD to center
            cardOffset = 300
            cardRotation = 45
            cardOpacity = 0

            withAnimation(.easeInOut(duration: 0.3)) {
                cardOffset = 0
                cardRotation = 0
                cardOpacity = 1.0
                isTransitioning = false
            }
        } else {
            // At last song - snap back to center
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                cardOffset = 0
                cardRotation = 0
                cardOpacity = 1.0
            }
        }
    }

    private func transitionToPreviousSong() {
        guard !isTransitioning else { return }

        // Check if we can go to previous song
        if currentIndex > 0 {
            isTransitioning = true

            // CHANGE BACKGROUND IMMEDIATELY - before any animation
            backgroundIndex = currentIndex - 1
            currentIndex -= 1
            audioPlayer.pause()

            // Animate current song out downward
            withAnimation(.easeInOut(duration: 0.3)) {
                cardOffset = 300
                cardRotation = 45
                cardOpacity = 0
            }

            // Start new song from TOP and animate DOWNWARD to center
            cardOffset = -300
            cardRotation = -45
            cardOpacity = 0

            withAnimation(.easeInOut(duration: 0.3)) {
                cardOffset = 0
                cardRotation = 0
                cardOpacity = 1.0
                isTransitioning = false
            }
        } else {
            // At first song - snap back to center
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                cardOffset = 0
                cardRotation = 0
                cardOpacity = 1.0
            }
        }
    }

  
    private func handleTranscriptChange(_ newValue: String) {
        transcriptDebounceTask?.cancel()
        guard !newValue.isEmpty else { return }

        if !isRecording {
            processVoiceRequest(using: newValue)
            return
        }

        transcriptDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            if !isRecording && transcript == newValue {
                processVoiceRequest(using: newValue)
            }
        }
    }

    private func handleRecordingStateChange(isRecording: Bool) {
        if isRecording {
            // Cancel pending request trigger while user is still speaking
            transcriptDebounceTask?.cancel()
            lastSubmittedQuery = ""
        } else {
            transcriptDebounceTask?.cancel()
            processVoiceRequest(using: transcript)
        }
    }

    private func processVoiceRequest(using text: String? = nil) {
        let base = text ?? transcript
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isLoadingSongs else { return }
        guard trimmed != lastSubmittedQuery else { return }

        lastSubmittedQuery = trimmed

        Task {
            await loadSongsFromDescription(trimmed)
        }
    }

    private func handlePlayPause() {
        HapticFeedback.light()
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            if audioPlayer.currentSong?.id != currentSong?.id {
                playCurrentSong()
            } else if audioPlayer.currentSong == nil {
                playCurrentSong()
            } else {
                audioPlayer.play()
            }
        }
    }

    private func playCurrentSong() {
        if let song = currentSong {
            audioPlayer.playSong(song)
            if songStates.isEmpty {
                initializeSongStates()
            }
        }
    }

    private func initializeSongStates() {
        // Create song states for all songs in queue
        songStates = songQueue.map { SongState(song: $0) }

        // Initialize background index to match current index
        backgroundIndex = currentIndex

        // Preload images for all song states
        preloadAllImages()
    }

    private func preloadAllImages() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for index in songStates.indices {
                    let songState = songStates[index]
                    if let albumCoverURL = songState.song.albumCoverURL,
                       songState.backgroundImage == nil,
                       !songState.isImageLoading {
                        group.addTask {
                            await downloadImageForSongState(at: index, url: albumCoverURL)
                        }
                    }
                }
            }
        }
    }

    private func downloadImageForSongState(at index: Int, url: String) async {
        guard let imageURL = URL(string: url) else { return }

        // Mark as loading
        _ = await MainActor.run {
            if index < songStates.count {
                songStates[index].isImageLoading = true
            }
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            if let image = UIImage(data: data) {
                let square = image.croppedToSquare()
                _ = await MainActor.run {
                    if index < songStates.count {
                        songStates[index].backgroundImage = square
                        songStates[index].isImageLoading = false
                    }
                }
            }
        } catch {
            _ = await MainActor.run {
                if index < songStates.count {
                    songStates[index].isImageLoading = false
                }
            }
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    @MainActor
    private func loadSongsFromDescription(_ description: String) async {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        hasRequestedQuery = true
        isLoadingSongs = true
        defer { isLoadingSongs = false }

        audioPlayer.stopPlayback()
        songQueue.removeAll()
        songStates.removeAll()
        currentIndex = 0

        await apiService.streamSongsFromDescription(trimmed) { loadedSong in
            songQueue.append(loadedSong)
            songStates.append(SongState(song: loadedSong))

            if let albumCoverURL = loadedSong.albumCoverURL {
                let newIndex = songStates.count - 1
                Task {
                    await downloadImageForSongState(at: newIndex, url: albumCoverURL)
                }
            }

            if songQueue.count == 1 {
                audioPlayer.playSong(loadedSong, autoStart: false)
            }

            modelContext.insert(loadedSong)
        }
    }
}

#Preview {
    MusicPlayerView()
        .modelContainer(for: Song.self, inMemory: true)
}
