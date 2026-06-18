import SwiftUI

/// One row in any track list. Tapping plays the list from this track; the
/// trailing menu offers like / add-to-playlist / download-for-later, and — when
/// the track isn't yet on the server — a "Download to server" action that queues
/// the Soulseek fetch (the server does the actual sourcing; the app never talks
/// to Deezer/Soulseek directly).
struct TrackRow: View {
    let track: Track
    /// The full list this row belongs to, so tapping can seed the play queue.
    var context: [Track] = []
    var showArtwork: Bool = true
    var index: Int? = nil

    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var library: LibraryStore

    private var isCurrent: Bool { player.current?.id == track.id }
    private var isFav: Bool { library.isFavorite(track.id) || track.favorite }
    private var offline: Bool { downloads.isDownloaded(track.id) }
    private var playable: Bool { track.available || offline }

    var body: some View {
        Button(action: playTapped) {
            HStack(spacing: 12) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(Theme.body(15, weight: .medium))
                        .foregroundStyle(isCurrent ? Theme.accent : Theme.text)
                        .lineLimit(1)
                    Text(track.artist ?? "")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .contentShape(Rectangle())
            .opacity(playable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .contextMenu { menu }
    }

    @ViewBuilder private var leading: some View {
        if showArtwork {
            Cover(url: track.cover, size: 44, rounded: 5)
        } else if let index {
            Text("\(index + 1)")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textDim)
                .frame(width: 22)
        }
    }

    @ViewBuilder private var trailing: some View {
        HStack(spacing: 10) {
            if offline {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Theme.accent).font(.system(size: 14))
            } else if downloads.isDownloading(track.id) {
                ProgressView().tint(Theme.accent).scaleEffect(0.7)
            } else if downloads.didFail(track.id) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.danger).font(.system(size: 13))
            }
            if isFav {
                Image(systemName: "heart.fill").foregroundStyle(Theme.accent).font(.system(size: 13))
            }
            if let s = track.download_status, !track.available, s != "done" {
                Text(s).font(Theme.body(11, weight: .semibold)).foregroundStyle(Theme.textFaint)
            } else if !track.available && !offline {
                Image(systemName: "icloud.and.arrow.down").foregroundStyle(Theme.textFaint).font(.system(size: 13))
            }
            Text(formatTime(track.duration))
                .font(Theme.body(13))
                .foregroundStyle(Theme.textDim)
                .frame(width: 42, alignment: .trailing)
        }
    }

    @ViewBuilder private var menu: some View {
        Button {
            Task { await library.toggleFavorite(track) }
        } label: {
            Label(isFav ? "Remove from Liked" : "Add to Liked",
                  systemImage: isFav ? "heart.slash" : "heart")
        }

        if playable {
            if offline {
                Button(role: .destructive) { downloads.remove(track.id) } label: {
                    Label("Remove download", systemImage: "trash")
                }
            } else {
                Button { downloads.download(track) } label: {
                    Label("Download for offline", systemImage: "arrow.down.circle")
                }
            }
        } else {
            Button {
                Task { try? await app.queueDownload(kind: "track", deezerId: track.id) }
            } label: {
                Label("Download to server", systemImage: "icloud.and.arrow.down")
            }
        }

        AddToPlaylistMenu(track: track)
    }

    private func playTapped() {
        guard playable else {
            // Not on the server yet — queue the fetch so it becomes playable.
            Task { try? await app.queueDownload(kind: "track", deezerId: track.id) }
            return
        }
        let list = context.isEmpty ? [track] : context
        let start = list.firstIndex(where: { $0.id == track.id }) ?? 0
        player.play(list, startAt: start)
    }
}

/// Submenu listing the user's playlists to add a track to.
struct AddToPlaylistMenu: View {
    let track: Track
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        Menu {
            ForEach(library.playlists) { pl in
                Button(pl.displayName) {
                    Task { try? await app.addToPlaylist(pl.id, track: track) }
                }
            }
            if library.playlists.isEmpty {
                Text("No playlists yet")
            }
        } label: {
            Label("Add to playlist", systemImage: "text.badge.plus")
        }
    }
}
