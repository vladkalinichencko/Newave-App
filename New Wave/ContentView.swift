//
//  ContentView.swift
//  New Wave
//
//  Created by Владислав Калиниченко on 02.11.2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var apiService = MusicAPIService()
    @StateObject private var audioPlayer = AudioPlayerManager()

    var body: some View {
        MusicPlayerView()
            .environmentObject(apiService)
            .environmentObject(audioPlayer)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Song.self, inMemory: true)
}
