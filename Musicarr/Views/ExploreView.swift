import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var app: AppState
    private let cols = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.explore() }) { data in
                VStack(alignment: .leading, spacing: 26) {
                    if !data.moods.isEmpty {
                        RowTitle(text: "Moods")
                        LazyVGrid(columns: cols, spacing: 12) {
                            ForEach(data.moods) { m in
                                NavigationLink(value: Route.mood(m.slug)) {
                                    GradientCard(image: m.image, label: m.name)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !data.genres.isEmpty {
                        RowTitle(text: "Genres")
                        LazyVGrid(columns: cols, spacing: 12) {
                            ForEach(data.genres) { g in
                                NavigationLink(value: Route.genre(g.id)) {
                                    GradientCard(image: g.picture, label: g.name)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    CardRow(title: "New releases", items: data.releases) { a in
                        NavigationLink(value: Route.album(a.id)) {
                            ArtTile(cover: a.cover, title: a.title, subtitle: a.artist)
                        }.buttonStyle(.plain)
                    }
                    CardRow(title: "Top playlists", items: data.topPlaylists) { p in
                        NavigationLink(value: Route.deezerPlaylist(p.id)) {
                            ArtTile(cover: p.cover, title: p.displayName, subtitle: p.by)
                        }.buttonStyle(.plain)
                    }
                    CardRow(title: "Top artists", items: data.topArtists) { a in
                        NavigationLink(value: Route.artist(a.id)) {
                            ArtTile(cover: a.picture, title: a.name, circle: true)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
            }
        }
        .navigationTitle("Explore")
    }
}

/// A cover-image card with a dark gradient and a bold label (moods + genres).
struct GradientCard: View {
    let image: String?
    let label: String
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image, let u = URL(string: image) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else { Theme.bgElev2 }
                }
            } else {
                LinearGradient(colors: [Theme.accent.opacity(0.6), Theme.bgElev2],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            Text(label)
                .font(Theme.display(18, weight: .bold))
                .foregroundStyle(.white)
                .padding(14)
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
