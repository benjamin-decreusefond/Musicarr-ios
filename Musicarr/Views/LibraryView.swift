import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: DownloadManager

    enum Tab: String, CaseIterable { case songs = "Songs", artists = "Artists", playlists = "Playlists", liked = "Liked", history = "History" }
    @State private var tab: Tab = .songs
    @State private var newPlaylistName = ""
    @State private var showNewPlaylist = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .musicarrSegmented()

                switch tab {
                case .songs: songs
                case .artists: artists
                case .playlists: playlists
                case .liked: liked
                case .history: history
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewPlaylist = true } label: { Image(systemName: "plus") }
            }
        }
        .alert("New playlist", isPresented: $showNewPlaylist) {
            TextField("Name", text: $newPlaylistName)
            Button("Create") {
                let name = newPlaylistName; newPlaylistName = ""
                Task { _ = await library.createPlaylist(name) }
            }
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
        }
        .task { await library.refresh() }
    }

    private var songs: some View {
        AsyncContent(load: { try await app.library() }) { tracks in
            if tracks.isEmpty { StateText(text: "Your library is empty. Download songs to fill it.") }
            else {
                VStack(spacing: 0) { ForEach(tracks) { TrackRow(track: $0, context: tracks) } }
            }
        }
    }

    private var artists: some View {
        AsyncContent(load: { try await app.libraryArtists() }) { list in
            let cols = [GridItem(.adaptive(minimum: 110), spacing: 16)]
            LazyVGrid(columns: cols, spacing: 18) {
                ForEach(list) { a in
                    NavigationLink(value: Route.artist(a.id)) {
                        ArtTile(cover: a.picture, title: a.name,
                                subtitle: a.count.map { "\($0) songs" }, circle: true, width: 110)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var playlists: some View {
        VStack(spacing: 8) {
            ForEach(library.playlists) { pl in
                NavigationLink(value: Route.playlist(pl.id)) {
                    HStack(spacing: 12) {
                        Cover(url: pl.cover, size: 52, rounded: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pl.displayName).font(Theme.body(15, weight: .semibold)).foregroundStyle(Theme.text)
                            Text("\(pl.trackCount) tracks").font(Theme.body(13)).foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.textFaint).font(.system(size: 13))
                    }
                    .padding(.vertical, 6)
                }.buttonStyle(.plain)
            }
            if library.playlists.isEmpty { StateText(text: "No playlists yet. Tap + to create one.") }
        }
        .task { await library.refreshPlaylists() }
    }

    private var liked: some View {
        AsyncContent(load: { try await app.favorites() }) { tracks in
            if tracks.isEmpty { StateText(text: "No liked songs yet.") }
            else { VStack(spacing: 0) { ForEach(tracks) { TrackRow(track: $0, context: tracks) } } }
        }
    }

    private var history: some View {
        AsyncContent(load: { try await app.history() }) { tracks in
            if tracks.isEmpty { StateText(text: "Nothing played yet.") }
            else { VStack(spacing: 0) { ForEach(tracks) { TrackRow(track: $0, context: tracks) } } }
        }
    }
}

struct PlaylistView: View {
    let id: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var reloadToken = 0

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.playlist(id) }) { data in
                playlistBody(data)
            }
            .id(reloadToken)
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        Task { try? await app.deletePlaylist(id); await library.refreshPlaylists(); dismiss() }
                    } label: { Label("Delete playlist", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis") }
            }
        }
    }

    @ViewBuilder private func playlistBody(_ data: PlaylistDetail) -> some View {
                VStack(alignment: .leading, spacing: 16) {
                    DetailHero(cover: data.tracks.first?.cover, kind: "Playlist", title: data.displayName,
                               subtitle: "\(data.tracks.count) tracks")
                    if !data.tracks.isEmpty {
                        PrimaryButton(title: "Play", systemImage: "play.fill") { player.play(data.tracks) }
                    }
                    VStack(spacing: 0) {
                        ForEach(data.tracks) { t in
                            Group {
                                if data.is_owner == true {
                                    TrackRow(track: t, context: data.tracks)
                                        .removeSwipe {
                                            Task {
                                                try? await app.removeFromPlaylist(id, trackId: t.id)
                                                reloadToken += 1
                                            }
                                        }
                                } else {
                                    TrackRow(track: t, context: data.tracks)
                                }
                            }
                        }
                    }
                    if data.tracks.isEmpty { StateText(text: "This playlist is empty.") }
                }
                .padding(.horizontal, 16).padding(.bottom, 140)
    }
}
