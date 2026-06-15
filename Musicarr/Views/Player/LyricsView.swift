import SwiftUI

/// Time-synced (or plain) lyrics for the current track, fetched from the server's
/// LRCLIB-backed `/api/lyrics` endpoint.
struct LyricsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var player: PlayerManager
    @State private var lyrics: LyricsResponse?
    @State private var error: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let lyrics {
                        if !lyrics.synced.isEmpty {
                            ForEach(Array(lyrics.synced.enumerated()), id: \.offset) { i, line in
                                Text(line.text.isEmpty ? "♪" : line.text)
                                    .font(Theme.body(17, weight: i == activeLine ? .bold : .regular))
                                    .foregroundStyle(i == activeLine ? Theme.text : (i < activeLine ? Theme.textFaint : Theme.textDim))
                                    .id(i)
                                    .onTapGesture { player.seek(line.time) }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else if !lyrics.plain.isEmpty {
                            Text(lyrics.plain).font(Theme.body(15)).foregroundStyle(Theme.textDim)
                        } else {
                            StateText(text: "No lyrics for this track.")
                        }
                    } else if let error {
                        StateText(text: error)
                    } else {
                        ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 60)
                    }
                }
                .padding(20).padding(.bottom, 60)
            }
            .onChange(of: activeLine) { line in
                withAnimation { proxy.scrollTo(line, anchor: .center) }
            }
        }
        .navigationTitle("Lyrics")
        .task(id: player.current?.id) { await load() }
    }

    private var activeLine: Int {
        guard let synced = lyrics?.synced else { return -1 }
        var active = -1
        for (i, l) in synced.enumerated() {
            if l.time <= player.time + 0.25 { active = i } else { break }
        }
        return active
    }

    private func load() async {
        guard let id = player.current?.id else { return }
        lyrics = nil; error = nil
        do { lyrics = try await app.lyrics(id) }
        catch { self.error = "No lyrics found." }
    }
}

/// The current play queue with reordering and jump-to-track.
struct QueueView: View {
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(player.queue.enumerated()), id: \.element.id) { i, t in
                    Button { player.playAt(i) } label: {
                        HStack(spacing: 12) {
                            if i == player.index {
                                Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.accent).font(.system(size: 13))
                            } else {
                                Text("\(i + 1)").foregroundStyle(Theme.textDim).font(Theme.body(13)).frame(width: 20)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.title).foregroundStyle(i == player.index ? Theme.accent : Theme.text)
                                    .font(Theme.body(14.5)).lineLimit(1)
                                Text(t.artist ?? "").foregroundStyle(Theme.textDim).font(Theme.body(12)).lineLimit(1)
                            }
                        }
                    }
                    .listRowBackground(Theme.bgElev)
                }
                .onMove { from, to in
                    if let f = from.first { player.moveInQueue(f, to > f ? to - 1 : to) }
                }
                .onDelete { idx in idx.forEach { player.removeFromQueue($0) } }
            }
            .hideScrollBackground()
            .background(PageBackground())
            .navigationTitle("Queue")
            #if os(iOS)
            .toolbar { EditButton() }
            #endif
        }
    }
}
