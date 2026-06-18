import Foundation
import SwiftUI

/// Central app session: holds the configured server, the signed-in user, and
/// typed wrappers over every endpoint the UI needs. Acts purely as a client of
/// the Musicarr server — no Deezer or Soulseek logic ever runs on-device.
@MainActor
final class AppState: ObservableObject {
    @Published var me: Me?
    @Published var serverURLString: String
    @Published var booting = true            // initial /me check in flight
    @Published var online = true             // last request reached the server

    private(set) var api: APIClient

    private let serverKey = "musicarr.serverURL"

    init() {
        let saved = UserDefaults.standard.string(forKey: serverKey) ?? ""
        serverURLString = saved
        let url = URL(string: saved.isEmpty ? "http://localhost:8686" : saved)!
        api = APIClient(baseURL: url)

        NotificationCenter.default.addObserver(
            forName: .musicarrUnauthorized, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.me = nil }
        }
    }

    var isConfigured: Bool { !serverURLString.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Normalize and persist the server URL the user typed on the login screen.
    func setServer(_ raw: String) -> Bool {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") { s = "https://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        guard let url = URL(string: s), url.host != nil else { return false }
        serverURLString = s
        UserDefaults.standard.set(s, forKey: serverKey)
        api.setBaseURL(url)
        return true
    }

    // MARK: Session

    func bootstrap() async {
        booting = true
        defer { booting = false }
        guard isConfigured else { me = nil; return }
        do {
            me = try await api.get("/api/auth/me", as: Me.self)
            online = true
        } catch APIError.unauthorized {
            me = nil
        } catch {
            // Server unreachable — stay signed-out but flag offline so the UI can
            // offer the offline library.
            online = false
            me = nil
        }
    }

    func login(username: String, password: String) async throws {
        let body = JSONBody(["username": username, "password": password])
        me = try await api.post("/api/auth/login", body: body, as: Me.self)
        online = true
    }

    func logout() async {
        _ = try? await api.post("/api/auth/logout")
        me = nil
    }

    func changePassword(current: String, next: String) async throws {
        try await api.post("/api/auth/password", body: JSONBody(["current": current, "next": next]))
        if let current = me {
            me = Me(id: current.id, username: current.username,
                    is_admin: current.is_admin, must_change_password: false)
        }
    }

    // MARK: Discovery / browse

    func home() async throws -> HomeResponse { try await api.get("/api/home", as: HomeResponse.self) }
    func explore() async throws -> ExploreResponse { try await api.get("/api/explore", as: ExploreResponse.self) }
    func genre(_ id: Int) async throws -> GenreResponse { try await api.get("/api/genre/\(id)", as: GenreResponse.self) }
    func mood(_ slug: String) async throws -> MoodResponse { try await api.get("/api/mood/\(slug)", as: MoodResponse.self) }
    func artist(_ id: Int) async throws -> ArtistResponse { try await api.get("/api/artist/\(id)", as: ArtistResponse.self) }
    func album(_ id: Int) async throws -> AlbumResponse { try await api.get("/api/album/\(id)", as: AlbumResponse.self) }
    func deezerPlaylist(_ id: Int) async throws -> DeezerPlaylistDetail {
        try await api.get("/api/deezer-playlist/\(id)", as: DeezerPlaylistDetail.self)
    }

    func search(_ q: String) async throws -> SearchResponse {
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await api.get("/api/search?q=\(enc)", as: SearchResponse.self)
    }

    func recommendations() async throws -> Recommendations {
        try await api.get("/api/recommendations", as: Recommendations.self)
    }
    func radio(seed: String) async throws -> RadioResponse {
        let enc = seed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? seed
        return try await api.get("/api/radio?seed=\(enc)", as: RadioResponse.self)
    }

    // MARK: Library / favorites / history

    func library() async throws -> [Track] { try await api.get("/api/library", as: [Track].self) }
    func libraryArtists() async throws -> [ArtistLite] { try await api.get("/api/library/artists", as: [ArtistLite].self) }
    func favorites() async throws -> [Track] { try await api.get("/api/favorites", as: [Track].self) }
    func history() async throws -> [Track] { try await api.get("/api/history", as: [Track].self) }

    func addFavorite(_ t: Track) async throws {
        try await api.put("/api/favorites/\(t.id)", body: trackBody(t))
    }
    func removeFavorite(_ id: Int) async throws {
        try await api.delete("/api/favorites/\(id)")
    }

    // MARK: Playlists

    func playlists() async throws -> [PlaylistLite] { try await api.get("/api/playlists", as: [PlaylistLite].self) }
    func playlist(_ id: Int) async throws -> PlaylistDetail { try await api.get("/api/playlists/\(id)", as: PlaylistDetail.self) }

    func createPlaylist(name: String) async throws -> PlaylistLite {
        try await api.post("/api/playlists", body: JSONBody(["name": name]), as: PlaylistLite.self)
    }
    func deletePlaylist(_ id: Int) async throws { try await api.delete("/api/playlists/\(id)") }

    func addToPlaylist(_ playlistId: Int, track: Track) async throws {
        try await api.post("/api/playlists/\(playlistId)/tracks",
                           body: JSONBody(["track_id": track.id, "track": trackBody(track)]))
    }
    func removeFromPlaylist(_ playlistId: Int, trackId: Int) async throws {
        try await api.delete("/api/playlists/\(playlistId)/tracks/\(trackId)")
    }
    func importDeezerPlaylist(_ deezerId: Int) async throws {
        try await api.post("/api/playlists/import-deezer", body: JSONBody(["deezer_playlist_id": deezerId]))
    }

    // MARK: Downloads (server fetch jobs)

    func downloads() async throws -> [DownloadJob] { try await api.get("/api/downloads", as: [DownloadJob].self) }
    func queueDownload(kind: String, deezerId: Int) async throws {
        try await api.post("/api/download", body: JSONBody(["kind": kind, "deezer_id": deezerId]))
    }
    func dismissDownload(_ id: Int) async throws { try await api.delete("/api/downloads/\(id)") }

    // MARK: Plays / lyrics / heartbeat

    func logPlay(_ id: Int) async { _ = try? await api.post("/api/plays", body: JSONBody(["track_id": id])) }
    func heartbeat(_ id: Int?) async {
        _ = try? await api.post("/api/social/heartbeat", body: JSONBody(["track_id": id ?? 0]))
    }
    func lyrics(_ id: Int) async throws -> LyricsResponse {
        try await api.get("/api/lyrics/\(id)", as: LyricsResponse.self)
    }

    // MARK: Helpers

    /// The flat track body the server's `ensureTrack` expects when favoriting /
    /// adding tracks it hasn't catalogued yet.
    private func trackBody(_ t: Track) -> JSONBody {
        var d: [String: Encodable] = ["title": t.title]
        if let v = t.artist { d["artist"] = v }
        if let v = t.artist_id { d["artist_id"] = v }
        if let v = t.album { d["album"] = v }
        if let v = t.album_id { d["album_id"] = v }
        if let v = t.duration { d["duration"] = v }
        if let v = t.cover { d["cover"] = v }
        if let v = t.track_position { d["track_position"] = v }
        return JSONBody(d)
    }

    /// Authenticated streaming URL for a track that exists on the server.
    func streamURL(_ id: Int) -> URL { api.url("/api/stream/\(id)") }
    var streamingCookies: [HTTPCookie] { api.cookies }
}

// MARK: - Newer features (stats, mixes, listen-together, social, sharing, admin)

extension AppState {
    // MARK: Stats
    func stats(range: String) async throws -> StatsResponse {
        try await api.get("/api/stats?range=\(range)", as: StatsResponse.self)
    }

    // MARK: Mixes / Made For You
    func mixes() async throws -> MixesResponse {
        try await api.get("/api/mixes", as: MixesResponse.self)
    }

    // MARK: Listen Together
    func listenActive() async throws -> ListenActiveResponse {
        try await api.get("/api/listen/active", as: ListenActiveResponse.self)
    }
    func listenStart() async throws -> ListenSession {
        try await api.post("/api/listen/start", as: ListenSession.self)
    }
    func listenJoin(code: String) async throws -> ListenSession {
        try await api.post("/api/listen/join", body: JSONBody(["code": code]), as: ListenSession.self)
    }
    func listenSession(_ id: Int) async throws -> ListenSession {
        try await api.get("/api/listen/\(id)", as: ListenSession.self)
    }
    func listenPostState(_ id: Int, trackId: Int?, position: Double, isPlaying: Bool) async throws {
        try await api.post("/api/listen/\(id)/state",
                           body: JSONBody(["track_id": trackId ?? 0,
                                           "position": position,
                                           "is_playing": isPlaying]))
    }
    func listenLeave(_ id: Int) async throws {
        try await api.post("/api/listen/\(id)/leave")
    }

    // MARK: Following artists (auto-download)
    func following() async throws -> [FollowedArtist] {
        try await api.get("/api/following", as: [FollowedArtist].self)
    }
    func follow(artistId: Int) async throws {
        try await api.put("/api/following/\(artistId)")
    }
    func unfollow(artistId: Int) async throws {
        try await api.delete("/api/following/\(artistId)")
    }

    // MARK: Social
    func socialUsers(q: String = "") async throws -> [SocialUser] {
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await api.get("/api/social/users?q=\(enc)", as: [SocialUser].self)
    }
    func socialFollowing() async throws -> [SocialUser] {
        try await api.get("/api/social/following", as: [SocialUser].self)
    }
    func socialFollow(_ id: Int) async throws {
        try await api.post("/api/social/follow/\(id)")
    }
    func socialUnfollow(_ id: Int) async throws {
        try await api.delete("/api/social/follow/\(id)")
    }
    func socialProfile(_ id: Int) async throws -> SocialProfile {
        try await api.get("/api/social/users/\(id)", as: SocialProfile.self)
    }

    // MARK: Shared playlists
    func playlistShares(_ id: Int) async throws -> [PlaylistShare] {
        try await api.get("/api/playlists/\(id)/shares", as: [PlaylistShare].self)
    }
    func addPlaylistShare(_ id: Int, userId: Int, canEdit: Bool) async throws {
        try await api.post("/api/playlists/\(id)/shares",
                           body: JSONBody(["user_id": userId, "can_edit": canEdit]))
    }
    func removePlaylistShare(_ id: Int, userId: Int) async throws {
        try await api.delete("/api/playlists/\(id)/shares/\(userId)")
    }

    // MARK: API tokens (any signed-in user)
    func apiTokens() async throws -> [APIToken] {
        try await api.get("/api/auth/tokens", as: [APIToken].self)
    }
    func createApiToken(name: String) async throws -> APIToken {
        try await api.post("/api/auth/tokens", body: JSONBody(["name": name]), as: APIToken.self)
    }
    func revokeApiToken(_ id: Int) async throws {
        try await api.delete("/api/auth/tokens/\(id)")
    }

    // MARK: Admin — users
    func adminUsers() async throws -> [AdminUser] {
        try await api.get("/api/users", as: [AdminUser].self)
    }
    func createUser(username: String, password: String, isAdmin: Bool) async throws {
        try await api.post("/api/users",
                           body: JSONBody(["username": username, "password": password, "is_admin": isAdmin]))
    }
    func deleteUser(_ id: Int) async throws {
        try await api.delete("/api/users/\(id)")
    }

    // MARK: Admin — settings
    func settings() async throws -> ServerSettings {
        try await api.get("/api/settings", as: ServerSettings.self)
    }
    func updateSettings(_ body: JSONBody) async throws {
        try await api.put("/api/settings", body: body)
    }
    func testSettings(section: String, slskdURL: String?, slskdKey: String?) async throws -> SettingsTestResult {
        var d: [String: Encodable] = ["section": section]
        if let slskdURL { d["slskd_url"] = slskdURL }
        if let slskdKey { d["slskd_api_key"] = slskdKey }
        return try await api.post("/api/settings/test", body: JSONBody(d), as: SettingsTestResult.self)
    }
}
