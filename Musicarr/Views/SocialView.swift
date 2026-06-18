import SwiftUI

/// Social: search users, follow/unfollow, and see who you follow + their
/// now-playing. Tapping a user opens a profile detail (recent, favorites,
/// playlists).
struct SocialView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var searchResults: [SocialUser] = []
    @State private var followingUsers: [SocialUser] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    #if os(iOS)
                    TextField("Search users", text: $query)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .musicarrField()
                        .onSubmit { Task { await runSearch() } }
                    #else
                    TextField("Search users", text: $query).musicarrField()
                        .onSubmit { Task { await runSearch() } }
                    #endif

                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        RowTitle(text: "Results")
                        if searching { ProgressView().tint(Theme.accent) }
                        else if searchResults.isEmpty { StateText(text: "No users found.") }
                        else {
                            ForEach(searchResults) { u in userRow(u) }
                        }
                    }

                    RowTitle(text: "Following")
                    if followingUsers.isEmpty {
                        StateText(text: "You're not following anyone yet.")
                    } else {
                        ForEach(followingUsers) { u in userRow(u) }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
                .navigationDestination(for: SocialUserRoute.self) { SocialProfileView(userId: $0.id) }
                .musicarrDestinations()
            }
            .background(PageBackground())
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .musicarrScreen()
        .task { await loadFollowing() }
    }

    private func userRow(_ u: SocialUser) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: SocialUserRoute(id: u.id)) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.bgElev2).frame(width: 44, height: 44)
                        Image(systemName: "person.fill").foregroundStyle(Theme.textDim)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(u.username).font(Theme.body(15, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                            if u.is_admin {
                                Text("Admin").font(Theme.body(10, weight: .bold)).foregroundStyle(Theme.accentInk)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Theme.accent).clipShape(Capsule())
                            }
                        }
                        if let np = u.nowPlaying {
                            Label("\(np.title) — \(np.artist ?? "")", systemImage: "music.note")
                                .font(Theme.body(12)).foregroundStyle(Theme.accent).lineLimit(1)
                        } else if let lp = u.lastPlayed {
                            Text("Last: \(lp.title)").font(Theme.body(12)).foregroundStyle(Theme.textDim).lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }.buttonStyle(.plain)

            followToggle(u)
        }
        .padding(.vertical, 6)
    }

    private func followToggle(_ u: SocialUser) -> some View {
        Button(u.following ? "Unfollow" : "Follow") {
            Task {
                if u.following { try? await app.socialUnfollow(u.id) }
                else { try? await app.socialFollow(u.id) }
                await loadFollowing()
                if !query.trimmingCharacters(in: .whitespaces).isEmpty { await runSearch() }
            }
        }
        .font(Theme.body(13, weight: .semibold))
        .foregroundStyle(u.following ? Theme.danger : Theme.accent)
        .buttonStyle(.plain)
    }

    private func runSearch() async {
        searching = true; defer { searching = false }
        searchResults = (try? await app.socialUsers(q: query)) ?? []
    }
    private func loadFollowing() async {
        followingUsers = (try? await app.socialFollowing()) ?? []
    }
}

/// Navigation value for opening a social user's profile.
struct SocialUserRoute: Hashable { let id: Int }

struct SocialProfileView: View {
    let userId: Int
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.socialProfile(userId) }) { p in
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack {
                            Circle().fill(Theme.bgElev2).frame(width: 72, height: 72)
                            Image(systemName: "person.fill").foregroundStyle(Theme.textDim).font(.system(size: 30))
                        }
                        Text(p.username).font(Theme.display(26, weight: .bold)).foregroundStyle(Theme.text)
                        HStack(spacing: 16) {
                            if let f = p.followers { Text("\(f) followers").font(Theme.body(13)).foregroundStyle(Theme.textDim) }
                            if let f = p.following_count { Text("\(f) following").font(Theme.body(13)).foregroundStyle(Theme.textDim) }
                        }
                    }

                    Button(p.following ? "Unfollow" : "Follow") {
                        Task {
                            if p.following { try? await app.socialUnfollow(userId) }
                            else { try? await app.socialFollow(userId) }
                        }
                    }
                    .font(Theme.body(14, weight: .bold))
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(p.following ? Theme.bgElev2 : Theme.accent)
                    .foregroundStyle(p.following ? Theme.text : Theme.accentInk)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)

                    if let np = p.nowPlaying {
                        RowTitle(text: "Now playing")
                        TrackRow(track: np, context: [np])
                    }
                    if !p.recent.isEmpty {
                        RowTitle(text: "Recently played")
                        VStack(spacing: 0) { ForEach(p.recent) { TrackRow(track: $0, context: p.recent) } }
                    }
                    if !p.favorites.isEmpty {
                        RowTitle(text: "Favorites")
                        VStack(spacing: 0) { ForEach(p.favorites) { TrackRow(track: $0, context: p.favorites) } }
                    }
                    CardRow(title: "Playlists", items: p.playlists) { pl in
                        NavigationLink(value: Route.playlist(pl.id)) {
                            ArtTile(cover: pl.cover, title: pl.displayName, subtitle: "\(pl.trackCount) tracks")
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 140)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
