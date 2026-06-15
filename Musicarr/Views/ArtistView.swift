import SwiftUI

struct ArtistView: View {
    let id: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.artist(id) }) { data in
                VStack(alignment: .leading, spacing: 18) {
                    DetailHero(cover: data.artist.picture, kind: "Artist",
                               title: data.artist.name,
                               subtitle: fanCount(data.artist.nb_fan), circle: true)

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
