import SwiftUI

struct AlbumView: View {
    let id: Int
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        ScrollView {
            AsyncContent(load: { try await app.album(id) }) { data in
                VStack(alignment: .leading, spacing: 16) {
                    DetailHero(cover: data.cover, kind: "Album", title: data.title,
                               subtitle: subtitle(data))

                    HStack(spacing: 12) {
                        PrimaryButton(title: "Play", systemImage: "play.fill") {
                            player.play(data.tracks)
                        }
                        if data.tracks.contains(where: { !$0.available }) {
                            GhostButton(title: "Get album", systemImage: "icloud.and.arrow.down") {
                                Task { try? await app.queueDownload(kind: "album", deezerId: data.id) }
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(data.tracks.enumerated()), id: \.element.id) { i, t in
                            // Inherit the album cover for rows that ship without one.
                            TrackRow(track: withCover(t, data.cover), context: data.tracks.map { withCover($0, data.cover) },
                                     showArtwork: false, index: i)
                        }
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

    private func subtitle(_ d: AlbumResponse) -> String {
        var parts: [String] = []
        if let a = d.artist { parts.append(a) }
        if let y = d.release_date?.prefix(4) { parts.append(String(y)) }
        if let n = d.nb_tracks { parts.append("\(n) tracks") }
        return parts.joined(separator: " · ")
    }

    private func withCover(_ t: Track, _ cover: String?) -> Track {
        var c = t
        if c.cover == nil { c.cover = cover }
        if c.album == nil { c.album_id = id }
        return c
    }
}
