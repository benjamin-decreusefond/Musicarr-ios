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
                let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                newPlaylistName = ""
                guard !name.isEmpty else { return }
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
                            HStack(spacing: 6) {
                                Text("\(pl.trackCount) tracks").font(Theme.body(13)).foregroundStyle(Theme.textDim)
                                if pl.is_owner == false {
                                    Label(pl.owner_name ?? "Shared", systemImage: "person.2.fill")
                                        .font(Theme.body(11, weight: .semibold)).foregroundStyle(Theme.accent)
                                }
                            }
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
    @State private var isOwner = false
    @State private var showShare = false

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
                    if isOwner {
                        Button { showShare = true } label: { Label("Share", systemImage: "person.crop.circle.badge.plus") }
                        Button(role: .destructive) {
                            Task { try? await app.deletePlaylist(id); await library.refreshPlaylists(); dismiss() }
                        } label: { Label("Delete playlist", systemImage: "trash") }
                    } else {
                        Text("Shared with you")
                    }
                } label: { Image(systemName: "ellipsis") }
            }
        }
        .sheet(isPresented: $showShare) { PlaylistShareView(playlistId: id).musicarrScreen() }
    }

    @ViewBuilder private func playlistBody(_ data: PlaylistDetail) -> some View {
                let owner = data.is_owner ?? false
                let canEdit = owner || (data.can_edit ?? false)
                VStack(alignment: .leading, spacing: 16) {
                    DetailHero(cover: data.tracks.first?.cover, kind: "Playlist", title: data.displayName,
                               subtitle: subtitle(data))
                    if !data.tracks.isEmpty {
                        PrimaryButton(title: "Play", systemImage: "play.fill") { player.play(data.tracks) }
                    }
                    VStack(spacing: 0) {
                        ForEach(data.tracks) { t in
                            Group {
                                if canEdit {
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
                .onAppear { isOwner = owner }
    }

    private func subtitle(_ data: PlaylistDetail) -> String {
        var s = "\(data.tracks.count) tracks"
        if data.is_owner == false, let owner = data.owner_name { s += " · shared by \(owner)" }
        return s
    }
}

/// Owner-only sharing controls: pick users to share with (read-only or editable)
/// and manage existing shares.
struct PlaylistShareView: View {
    let playlistId: Int
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var shares: [PlaylistShare] = []
    @State private var users: [SocialUser] = []
    @State private var query = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        RowTitle(text: "Shared with")
                        if shares.isEmpty {
                            StateText(text: "Not shared with anyone yet.")
                        } else {
                            ForEach(shares) { s in
                                HStack(spacing: 12) {
                                    Image(systemName: "person.fill").foregroundStyle(Theme.textDim).frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.username).font(Theme.body(15, weight: .semibold)).foregroundStyle(Theme.text)
                                        Text(s.can_edit ? "Can edit" : "Read-only").font(Theme.body(12)).foregroundStyle(Theme.textDim)
                                    }
                                    Spacer()
                                    Button("Remove") {
                                        Task { try? await app.removePlaylistShare(playlistId, userId: s.user_id); await reload() }
                                    }
                                    .font(Theme.body(13, weight: .semibold)).foregroundStyle(Theme.danger).buttonStyle(.plain)
                                }
                                .padding(.vertical, 6)
                            }
                        }

                        RowTitle(text: "Add people")
                        #if os(iOS)
                        TextField("Search users", text: $query)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .musicarrField().onSubmit { Task { await searchUsers() } }
                        #else
                        TextField("Search users", text: $query).musicarrField().onSubmit { Task { await searchUsers() } }
                        #endif

                        ForEach(candidates) { u in
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill").foregroundStyle(Theme.textDim).frame(width: 22)
                                Text(u.username).font(Theme.body(15)).foregroundStyle(Theme.text)
                                Spacer()
                                Button("View") { Task { try? await app.addPlaylistShare(playlistId, userId: u.id, canEdit: false); await reload() } }
                                    .font(Theme.body(12, weight: .semibold)).foregroundStyle(Theme.textDim).buttonStyle(.plain)
                                Button("Edit") { Task { try? await app.addPlaylistShare(playlistId, userId: u.id, canEdit: true); await reload() } }
                                    .font(Theme.body(12, weight: .semibold)).foregroundStyle(Theme.accent).buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
                }
            }
            .navigationTitle("Share playlist")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .task { await reload(); await searchUsers() }
    }

    /// Users not already shared with.
    private var candidates: [SocialUser] {
        let shared = Set(shares.map { $0.user_id })
        return users.filter { !shared.contains($0.id) }
    }

    private func reload() async {
        shares = (try? await app.playlistShares(playlistId)) ?? []
        loaded = true
    }
    private func searchUsers() async {
        users = (try? await app.socialUsers(q: query)) ?? []
    }
}
