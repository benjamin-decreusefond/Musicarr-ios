import Foundation
import SwiftUI

/// Lightweight cache of the user's favorites and playlists so any track row can
/// reflect/like state and offer "add to playlist" without re-fetching. Backed by
/// the server; refreshed on sign-in and after mutations.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favoriteIds: Set<Int> = []
    @Published private(set) var playlists: [PlaylistLite] = []

    private let app: AppState
    init(app: AppState) { self.app = app }

    func refresh() async {
        async let favs = try? app.favorites()
        async let pls = try? app.playlists()
        if let favs = await favs { favoriteIds = Set(favs.map { $0.id }) }
        if let pls = await pls { playlists = pls }
    }

    func refreshPlaylists() async {
        if let pls = try? await app.playlists() { playlists = pls }
    }

    func isFavorite(_ id: Int) -> Bool { favoriteIds.contains(id) }

    func toggleFavorite(_ track: Track) async {
        if favoriteIds.contains(track.id) {
            favoriteIds.remove(track.id)
            try? await app.removeFavorite(track.id)
        } else {
            favoriteIds.insert(track.id)
            try? await app.addFavorite(track)
        }
    }

    func createPlaylist(_ name: String) async -> PlaylistLite? {
        guard let pl = try? await app.createPlaylist(name: name) else { return nil }
        await refreshPlaylists()
        return pl
    }

    func clear() { favoriteIds = []; playlists = [] }
}
