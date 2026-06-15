import SwiftUI

struct GenreView: View {
    let id: Int
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.genre(id) }) { data in
                VStack(alignment: .leading, spacing: 18) {
                    PageTitle(text: data.name)
                    if !data.tracks.isEmpty {
                        RowTitle(text: "Songs")
                        VStack(spacing: 0) {
                            ForEach(data.tracks) { TrackRow(track: $0, context: data.tracks) }
                        }
                    }
                    CardRow(title: "Albums", items: data.albums) { a in
                        NavigationLink(value: Route.album(a.id)) {
                            ArtTile(cover: a.cover, title: a.title, subtitle: a.artist)
                        }.buttonStyle(.plain)
                    }
                    CardRow(title: "Artists", items: data.artists) { a in
                        NavigationLink(value: Route.artist(a.id)) {
                            ArtTile(cover: a.picture, title: a.name, circle: true)
                        }.buttonStyle(.plain)
                    }
                    CardRow(title: "Playlists", items: data.playlists) { p in
                        NavigationLink(value: Route.deezerPlaylist(p.id)) {
                            ArtTile(cover: p.cover, title: p.displayName, subtitle: p.by)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct MoodView: View {
    let slug: String
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.mood(slug) }) { data in
                VStack(alignment: .leading, spacing: 18) {
                    PageTitle(text: data.name)
                    if !data.tracks.isEmpty {
                        PrimaryButton(title: "Play", systemImage: "play.fill") { player.play(data.tracks) }
                        VStack(spacing: 0) {
                            ForEach(data.tracks) { TrackRow(track: $0, context: data.tracks) }
                        }
                    }
                    CardRow(title: "Playlists", items: data.playlists) { p in
                        NavigationLink(value: Route.deezerPlaylist(p.id)) {
                            ArtTile(cover: p.cover, title: p.displayName, subtitle: p.by)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct DeezerPlaylistView: View {
    let id: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var player: PlayerManager
    @State private var importing = false
    @State private var imported = false

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.deezerPlaylist(id) }) { data in
                VStack(alignment: .leading, spacing: 16) {
                    PageTitle(text: data.title)
                    HStack(spacing: 12) {
                        PrimaryButton(title: "Play", systemImage: "play.fill") { player.play(data.tracks) }
                        GhostButton(title: imported ? "Imported" : (importing ? "Importing…" : "Import"),
                                    systemImage: "square.and.arrow.down") {
                            guard !importing && !imported else { return }
                            importing = true
                            Task {
                                try? await app.importDeezerPlaylist(id)
                                importing = false; imported = true
                            }
                        }
                    }
                    Text("Importing creates a playlist on your server and fetches any missing tracks.")
                        .font(Theme.body(12.5)).foregroundStyle(Theme.textFaint)
                    VStack(spacing: 0) {
                        ForEach(data.tracks) { TrackRow(track: $0, context: data.tracks) }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
