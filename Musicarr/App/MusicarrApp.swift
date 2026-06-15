import SwiftUI

@main
struct MusicarrApp: App {
    @StateObject private var app: AppState
    @StateObject private var player = PlayerManager()
    @StateObject private var downloads: DownloadManager
    @StateObject private var library: LibraryStore

    init() {
        let appState = AppState()
        _app = StateObject(wrappedValue: appState)
        _downloads = StateObject(wrappedValue: DownloadManager(app: appState))
        _library = StateObject(wrappedValue: LibraryStore(app: appState))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(player)
                .environmentObject(downloads)
                .environmentObject(library)
                .task {
                    player.attach(app: app, downloads: downloads)
                    await app.bootstrap()
                    if app.me != nil { await library.refresh() }
                }
                .musicarrScreen()
        }
    }
}
