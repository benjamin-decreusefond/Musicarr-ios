import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var scrubbing = false
    @State private var scrubValue = 0.0
    @State private var showLyrics = false
    @State private var showQueue = false

    var body: some View {
        ZStack {
            PageBackground()
            if let t = player.current {
                VStack(spacing: 22) {
                    handle
                    Cover(url: t.cover, size: artSize, rounded: 14)
                        .shadow(color: .black.opacity(0.55), radius: 24, y: 12)
                        .padding(.top, 6)

                    VStack(spacing: 6) {
                        Text(t.title).font(Theme.display(24, weight: .bold))
                            .foregroundStyle(Theme.text).multilineTextAlignment(.center).lineLimit(2)
                        Text(t.artist ?? "").font(Theme.body(15)).foregroundStyle(Theme.textDim)
                    }

                    scrubber

                    controls

                    secondaryControls(t)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
            } else {
                StateText(text: "Nothing playing")
            }
        }
        .sheet(isPresented: $showLyrics) { LyricsView().musicarrScreen() }
        .sheet(isPresented: $showQueue) { QueueView().musicarrScreen() }
    }

    private var artSize: CGFloat {
        #if os(tvOS)
        return 420
        #else
        return 300
        #endif
    }

    private var handle: some View {
        Capsule().fill(Theme.line).frame(width: 40, height: 5).padding(.top, 8)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            #if os(tvOS)
            // tvOS has no Slider; show a progress bar (transport is driven from
            // the Siri Remote and the on-screen prev/next controls).
            ProgressView(value: min(player.time, max(player.duration, 0.0001)),
                         total: max(player.duration, 0.0001))
                .tint(Theme.accent)
            #else
            Slider(value: Binding(
                get: { scrubbing ? scrubValue : player.time },
                set: { scrubValue = $0 }
            ), in: 0...max(player.duration, 1), onEditingChanged: { editing in
                scrubbing = editing
                if !editing { player.seek(scrubValue) }
            })
            .tint(Theme.accent)
            #endif
            HStack {
                Text(formatTime(scrubbing ? scrubValue : player.time))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(Theme.body(11.5)).foregroundStyle(Theme.textFaint)
        }
    }

    private var controls: some View {
        HStack(spacing: 34) {
            Button { player.prev() } label: { Image(systemName: "backward.fill").font(.system(size: 26)) }
                .buttonStyle(.plain).foregroundStyle(Theme.text).disabled(!player.hasPrev)
            Button { player.toggle() } label: {
                ZStack {
                    Circle().fill(Theme.text).frame(width: 64, height: 64)
                    Image(systemName: player.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 26)).foregroundStyle(Theme.bg)
                }
            }.buttonStyle(.plain)
            Button { player.next() } label: { Image(systemName: "forward.fill").font(.system(size: 26)) }
                .buttonStyle(.plain).foregroundStyle(Theme.text).disabled(!player.hasNext)
        }
    }

    private func secondaryControls(_ t: Track) -> some View {
        HStack(spacing: 30) {
            Button { Task { await library.toggleFavorite(t) } } label: {
                Image(systemName: library.isFavorite(t.id) ? "heart.fill" : "heart")
                    .foregroundStyle(library.isFavorite(t.id) ? Theme.accent : Theme.textDim)
            }.buttonStyle(.plain)

            Button { downloads.isDownloaded(t.id) ? downloads.remove(t.id) : downloads.download(t) } label: {
                Image(systemName: downloads.isDownloaded(t.id) ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .foregroundStyle(downloads.isDownloaded(t.id) ? Theme.accent : Theme.textDim)
            }.buttonStyle(.plain)

            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(player.repeatMode == .off ? Theme.textDim : Theme.accent)
            }.buttonStyle(.plain)

            Button { showLyrics = true } label: {
                Image(systemName: "quote.bubble").foregroundStyle(Theme.textDim)
            }.buttonStyle(.plain)

            Button { showQueue = true } label: {
                Image(systemName: "list.bullet").foregroundStyle(Theme.textDim)
            }.buttonStyle(.plain)
        }
        .font(.system(size: 20))
    }
}
