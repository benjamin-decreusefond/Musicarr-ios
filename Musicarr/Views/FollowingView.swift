import SwiftUI

/// Artists the user follows for auto-download of new releases.
/// Backed by GET /api/following with unfollow via DELETE /api/following/:id.
struct FollowingView: View {
    @EnvironmentObject private var app: AppState
    @State private var artists: [FollowedArtist] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let error { StateText(text: error, error: true) }
                else if !loaded {
                    ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 60)
                } else if artists.isEmpty {
                    StateText(text: "You're not following any artists yet. Follow an artist to auto-download their new releases.")
                } else {
                    ForEach(artists) { a in
                        HStack(spacing: 12) {
                            NavigationLink(value: Route.artist(a.id)) {
                                HStack(spacing: 12) {
                                    Cover(url: a.picture, size: 48, rounded: 24, circle: true)
                                    Text(a.name).font(Theme.body(15, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                                    Spacer()
                                }
                            }.buttonStyle(.plain)
                            Button("Unfollow") {
                                Task {
                                    try? await app.unfollow(artistId: a.id)
                                    artists.removeAll { $0.id == a.id }
                                }
                            }
                            .font(Theme.body(13, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
        }
        .navigationTitle("Following")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
    }

    private func load() async {
        do { artists = try await app.following(); error = nil }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        loaded = true
    }
}
