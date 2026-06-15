import SwiftUI

/// Compact always-on player above the tab bar, mirroring the web player bar.
struct MiniPlayerBar: View {
    @EnvironmentObject private var player: PlayerManager
    let onTap: () -> Void

    var body: some View {
        if let t = player.current {
            HStack(spacing: 12) {
                Cover(url: t.cover, size: 44, rounded: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(Theme.body(13.5, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(t.artist ?? "").font(Theme.body(12)).foregroundStyle(Theme.textDim).lineLimit(1)
                }
                Spacer()
                Button { player.toggle() } label: {
                    Image(systemName: player.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 18)).foregroundStyle(Theme.text)
                }.buttonStyle(.plain)
                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.system(size: 16)).foregroundStyle(Theme.text)
                }.buttonStyle(.plain).disabled(!player.hasNext)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    Rectangle().fill(Theme.accent)
                        .frame(width: geo.size.width * progress, height: 2)
                }.frame(height: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }

    private var progress: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(1, player.time / player.duration))
    }
}
