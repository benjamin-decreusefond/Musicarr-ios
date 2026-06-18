import SwiftUI

struct ArtistView: View {
    let id: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var player: PlayerManager

    @State private var following: Bool? = nil   // nil until resolved
    @State private var followBusy = false

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.artist(id) }) { data in
                VStack(alignment: .leading, spacing: 18) {
                    DetailHero(cover: data.artist.picture, kind: "Artist",
                               title: data.artist.name,
                               subtitle: fanCount(data.artist.nb_fan), circle: true)

                    followButton(data)

                    if !data.top.isEmpty {
                        PrimaryButton(title: "Play", systemImage: "play.fill") {
                            player.play(data.top)
                        }
                        RowTitle(text: "Popular")
                        VStack(spacing: 0) {
                            ForEach(Array(data.top.enumerated()), id: \.element.id) { i, t in
                                TrackRow(track: t, context: data.top, showArtwork: false, index: i)
                            }
                        }
                    }
                    CardRow(title: "Albums", items: data.albums) { a in
                        NavigationLink(value: Route.album(a.id)) {
                            ArtTile(cover: a.cover, title: a.title, subtitle: a.release_date?.prefix(4).description)
                        }.buttonStyle(.plain)
                    }
                    CardRow(title: "Related artists", items: data.related) { a in
                        NavigationLink(value: Route.artist(a.id)) {
                            ArtTile(cover: a.picture, title: a.name, circle: true)
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

    @ViewBuilder private func followButton(_ data: ArtistResponse) -> some View {
        let isFollowing = following ?? data.following ?? false
        Button {
            guard !followBusy else { return }
            followBusy = true
            let next = !isFollowing
            following = next
            Task {
                do {
                    if next { try await app.follow(artistId: id) }
                    else { try await app.unfollow(artistId: id) }
                } catch { following = isFollowing }   // revert on failure
                followBusy = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isFollowing ? "checkmark" : "plus")
                Text(isFollowing ? "Following" : "Follow").font(Theme.body(14, weight: .semibold))
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .overlay(Capsule().stroke(isFollowing ? Theme.accent : Theme.line, lineWidth: 1))
            .foregroundStyle(isFollowing ? Theme.accent : Theme.text)
        }
        .buttonStyle(.plain)
        .task {
            // Resolve follow state from /api/following when the response omitted it.
            if following == nil && data.following == nil {
                if let list = try? await app.following() {
                    following = list.contains { $0.id == id }
                }
            }
        }
    }

    private func fanCount(_ n: Int?) -> String? {
        guard let n else { return nil }
        return "\(n.formatted()) fans"
    }
}

/// Big header used on artist / album / playlist pages.
struct DetailHero: View {
    let cover: String?
    let kind: String
    let title: String
    var subtitle: String?
    var circle: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Cover(url: cover, size: 180, rounded: 10, circle: circle)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
            VStack(alignment: .leading, spacing: 6) {
                Text(kind.uppercased())
                    .font(Theme.body(12, weight: .bold))
                    .foregroundStyle(Theme.textDim)
                Text(title)
                    .font(Theme.display(32, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(3)
                if let subtitle {
                    Text(subtitle).font(Theme.body(14.5)).foregroundStyle(Theme.textDim)
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
