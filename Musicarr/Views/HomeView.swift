import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AsyncContent(load: { try await app.home() }) { data in
                    VStack(alignment: .leading, spacing: 14) {
                        if !data.tracks.isEmpty {
                            RowTitle(text: "Trending tracks")
                            VStack(spacing: 0) {
                                ForEach(data.tracks.prefix(8)) { t in
                                    TrackRow(track: t, context: data.tracks)
                                }
                            }
                        }
                        CardRow(title: "Popular albums", items: data.albums) { a in
                            NavigationLink(value: Route.album(a.id)) {
                                ArtTile(cover: a.cover, title: a.title, subtitle: a.artist)
                            }.buttonStyle(.plain)
                        }
                        CardRow(title: "Artists", items: data.artists) { a in
                            NavigationLink(value: Route.artist(a.id)) {
                                ArtTile(cover: a.picture, title: a.name, circle: true)
                            }.buttonStyle(.plain)
                        }
                        CardRow(title: "Featured playlists", items: data.playlists) { p in
                            NavigationLink(value: Route.deezerPlaylist(p.id)) {
                                ArtTile(cover: p.cover, title: p.displayName, subtitle: p.by)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
        }
        .navigationTitle("Home")
        .toolbar { ToolbarItem(placement: .primaryAction) { ProfileToolbarButton() } }
    }
}

/// Avatar button that opens the profile/settings sheet, shown in tab nav bars.
struct ProfileToolbarButton: View {
    @State private var show = false
    var body: some View {
        Button { show = true } label: {
            Image(systemName: "person.crop.circle").foregroundStyle(Theme.text)
        }
        .sheet(isPresented: $show) { ProfileView().musicarrScreen() }
    }
}
