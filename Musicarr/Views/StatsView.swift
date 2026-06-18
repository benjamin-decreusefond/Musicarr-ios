import SwiftUI

/// "Your stats" — listening totals, top artists/tracks/albums and a simple
/// 14-day bar chart, all driven by GET /api/stats?range=…
struct StatsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    enum Range: String, CaseIterable, Identifiable {
        case week, month, year, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .week: return "Week"
            case .month: return "Month"
            case .year: return "Year"
            case .all: return "All time"
            }
        }
    }
    @State private var range: Range = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Range", selection: $range) {
                        ForEach(Range.allCases) { Text($0.label).tag($0) }
                    }
                    .musicarrSegmented()

                    AsyncContent(load: { try await app.stats(range: range.rawValue) }) { data in
                        content(data)
                    }
                    .id(range)   // reload when the range changes
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 60)
            }
            .background(PageBackground())
            .navigationTitle("Your stats")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .musicarrScreen()
    }

    @ViewBuilder private func content(_ data: StatsResponse) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            totals(data.totals)

            if !data.daily.isEmpty {
                RowTitle(text: "Last 14 days")
                BarChart(days: Array(data.daily.suffix(14)))
            }

            if !data.topArtists.isEmpty {
                RowTitle(text: "Top artists")
                VStack(spacing: 0) {
                    ForEach(data.topArtists) { a in
                        NavigationLink(value: Route.artist(a.artist_id)) {
                            statRow(cover: a.cover, circle: true, title: a.artist,
                                    subtitle: "\(a.plays) plays")
                        }.buttonStyle(.plain)
                    }
                }
            }

            if !data.topTracks.isEmpty {
                RowTitle(text: "Top tracks")
                VStack(spacing: 0) {
                    ForEach(Array(data.topTracks.enumerated()), id: \.element.id) { i, t in
                        TrackRow(track: t, context: data.topTracks, index: i)
                    }
                }
            }

            if !data.topAlbums.isEmpty {
                RowTitle(text: "Top albums")
                VStack(spacing: 0) {
                    ForEach(data.topAlbums) { al in
                        NavigationLink(value: Route.album(al.album_id)) {
                            statRow(cover: al.cover, circle: false, title: al.title,
                                    subtitle: "\(al.artist ?? "") · \(al.plays) plays")
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .musicarrDestinations()
    }

    private func totals(_ t: StatsTotals) -> some View {
        let cards: [(String, String)] = [
            ("Plays", "\(t.plays)"),
            ("Tracks", "\(t.tracks)"),
            ("Artists", "\(t.artists)"),
            ("Listening", hours(t.seconds))
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(cards, id: \.0) { c in
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.1).font(Theme.display(24, weight: .bold)).foregroundStyle(Theme.accent)
                    Text(c.0).font(Theme.body(12, weight: .semibold)).foregroundStyle(Theme.textDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.bgElev)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
        }
    }

    private func statRow(cover: String?, circle: Bool, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Cover(url: cover, size: 44, rounded: circle ? 22 : 5, circle: circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.body(15, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                Text(subtitle).font(Theme.body(13)).foregroundStyle(Theme.textDim).lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .contentShape(Rectangle())
    }

    private func hours(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

/// Plain-SwiftUI bar chart (no external dependencies).
struct BarChart: View {
    let days: [StatDay]

    private var maxPlays: Int { max(days.map { $0.plays }.max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let count = max(days.count, 1)
                let spacing: CGFloat = 4
                let barWidth = max((geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count), 2)
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(days) { d in
                        let frac = CGFloat(d.plays) / CGFloat(maxPlays)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: barWidth, height: max(geo.size.height * frac, 2))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 120)
        }
        .padding(14)
        .background(Theme.bgElev)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}
