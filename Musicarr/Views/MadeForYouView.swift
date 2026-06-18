import SwiftUI

/// "Made for you" — smart and daily mixes from GET /api/mixes, plus a link into
/// recommendations. Each mix opens a track list that can be played.
struct MadeForYouView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                AsyncContent(load: { try await app.mixes() }) { data in
                    VStack(alignment: .leading, spacing: 20) {
                        if data.smart.isEmpty && data.daily.isEmpty {
                            StateText(text: "No mixes yet. Listen to more music to unlock them.")
                        }
                        if !data.smart.isEmpty { mixSection("Smart mixes", data.smart) }
                        if !data.daily.isEmpty { mixSection("Daily mixes", data.daily) }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 60)
                    .musicarrDestinations()
                    .navigationDestination(for: Mix.self) { MixDetailView(mix: $0) }
                }
            }
            .background(PageBackground())
            .navigationTitle("Made for you")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .musicarrScreen()
    }

    private func mixSection(_ title: String, _ mixes: [Mix]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RowTitle(text: title)
            let cols = [GridItem(.adaptive(minimum: 150), spacing: 16)]
            LazyVGrid(columns: cols, alignment: .leading, spacing: 18) {
                ForEach(mixes) { mix in
                    NavigationLink(value: mix) {
                        ArtTile(cover: mix.cover ?? mix.tracks.first?.cover,
                                title: mix.displayName,
                                subtitle: mix.subtitle ?? "\(mix.tracks.count) tracks")
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

extension Mix: Hashable {
    static func == (lhs: Mix, rhs: Mix) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MixDetailView: View {
    let mix: Mix
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHero(cover: mix.cover ?? mix.tracks.first?.cover, kind: "Mix",
                           title: mix.displayName,
                           subtitle: mix.subtitle ?? "\(mix.tracks.count) tracks")
                if !mix.tracks.isEmpty {
                    PrimaryButton(title: "Play", systemImage: "play.fill") { player.play(mix.tracks) }
                }
                VStack(spacing: 0) {
                    ForEach(mix.tracks) { t in TrackRow(track: t, context: mix.tracks) }
                }
                if mix.tracks.isEmpty { StateText(text: "This mix is empty.") }
            }
            .padding(.horizontal, 16).padding(.bottom, 140)
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
