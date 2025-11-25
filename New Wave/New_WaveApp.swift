//
//  New_WaveApp.swift
//  New Wave
//

import SwiftUI
import SwiftData

@main
struct New_WaveApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Song.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = scene.windows.first?.rootViewController {
                        LocalNetworkAuthorizer.shared.requestAuthorizationIfNeeded(from: rootVC)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
