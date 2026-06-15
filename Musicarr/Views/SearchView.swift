import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var app: AppState
    @State private var query = ""
    @State private var results = SearchResponse()
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchField
                if loading { ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 40) }
                else if let error { StateText(text: error, error: true) }
                else { resultsView }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
        }
        .navigationTitle("Search")
        // Debounced live search.
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { results = SearchResponse(); return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await runSearch(q)
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textDim)
            TextField("Artists, songs or albums", text: $query)
                .foregroundStyle(Theme.text)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .onSubmit { Task { await runSearch(query) } }
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textFaint) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 13).padding(.horizontal, 18)
        .background(Theme.bgElev2)
        .clipShape(Capsule())
    }

    @ViewBuilder private var resultsView: some View {
        if results.artists.isEmpty && results.albums.isEmpty && results.tracks.isEmpty {
            if query.count >= 2 { StateText(text: "No results.") }
            else { StateText(text: "Find anything in the Musicarr catalog.") }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                CardRow(title: "Artists", items: results.artists) { a in
                    NavigationLink(value: Route.artist(a.id)) {
                        ArtTile(cover: a.picture, title: a.name, circle: true, width: 130)
                    }.buttonStyle(.plain)
                }
                CardRow(title: "Albums", items: results.albums) { a in
                    NavigationLink(value: Route.album(a.id)) {
                        ArtTile(cover: a.cover, title: a.title, subtitle: a.artist, width: 130)
                    }.buttonStyle(.plain)
                }
                if !results.tracks.isEmpty {
                    RowTitle(text: "Songs")
                    VStack(spacing: 0) {
                        ForEach(results.tracks) { t in TrackRow(track: t, context: results.tracks) }
                    }
                }
            }
        }
    }

    private func runSearch(_ q: String) async {
        let q = q.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        loading = true; error = nil
        do { results = try await app.search(q) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        loading = false
    }
}
