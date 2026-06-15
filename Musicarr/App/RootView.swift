import SwiftUI

/// Navigation targets that push detail screens onto any tab's stack.
enum Route: Hashable {
    case artist(Int)
    case album(Int)
    case genre(Int)
    case mood(String)
    case deezerPlaylist(Int)
    case playlist(Int)
}

extension View {
    /// Common destination map so every tab can navigate to the same detail pages.
    func musicarrDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .artist(let id): ArtistView(id: id)
            case .album(let id): AlbumView(id: id)
            case .genre(let id): GenreView(id: id)
            case .mood(let slug): MoodView(slug: slug)
            case .deezerPlaylist(let id): DeezerPlaylistView(id: id)
            case .playlist(let id): PlaylistView(id: id)
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var downloads: DownloadManager

    var body: some View {
        Group {
            if app.booting {
                ZStack {
                    PageBackground()
                    ProgressView().tint(Theme.accent)
                }
            } else if app.me == nil {
                // Signed out. Offer the offline library if downloads exist and the
                // server can't be reached.
                LoginView(showOfflineOption: !downloads.offlineTracks.isEmpty)
            } else if app.me?.must_change_password == true {
                ChangePasswordView(forced: true)
            } else {
                MainTabView()
            }
        }
        .musicarrScreen()
    }
}
