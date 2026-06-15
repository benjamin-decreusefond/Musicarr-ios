import Foundation

// MARK: - Flexible decoding helpers
//
// The Musicarr server returns two shapes for tracks:
//   * Deezer-proxied results use `id` for the track id, and booleans as JSON true/false.
//   * SQLite-backed rows (library, favorites, history, playlists) use `deezer_id`
//     and booleans as integers 0/1.
// These helpers let one model decode both.

/// Decodes a value that may arrive as Bool, Int (0/1) or numeric string.
struct FlexibleBool: Codable, Hashable {
    let value: Bool
    init(_ v: Bool) { value = v }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { value = b }
        else if let i = try? c.decode(Int.self) { value = i != 0 }
        else if let s = try? c.decode(String.self) { value = (s == "1" || s.lowercased() == "true") }
        else { value = false }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

// MARK: - User

struct Me: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    let is_admin: Bool
    let must_change_password: Bool?
}

// MARK: - Track

/// The unified track shape used everywhere in the UI. Decodes both the Deezer
/// (`id`) and DB (`deezer_id`) wire shapes.
struct Track: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var title: String
    var artist: String?
    var artist_id: Int?
    var album: String?
    var album_id: Int?
    var cover: String?
    var duration: Int?
    var track_position: Int?
    var available: Bool
    var favorite: Bool
    var download_status: String?

    enum CodingKeys: String, CodingKey {
        case id, deezer_id, title, artist, artist_id, album, album_id
        case cover, duration, track_position, available, favorite, download_status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let v = try? c.decode(Int.self, forKey: .id) { id = v }
        else { id = try c.decode(Int.self, forKey: .deezer_id) }
        title = (try? c.decode(String.self, forKey: .title)) ?? "Unknown"
        artist = try? c.decodeIfPresent(String.self, forKey: .artist)
        artist_id = try? c.decodeIfPresent(Int.self, forKey: .artist_id)
        album = try? c.decodeIfPresent(String.self, forKey: .album)
        album_id = try? c.decodeIfPresent(Int.self, forKey: .album_id)
        cover = try? c.decodeIfPresent(String.self, forKey: .cover)
        duration = try? c.decodeIfPresent(Int.self, forKey: .duration)
        track_position = try? c.decodeIfPresent(Int.self, forKey: .track_position)
        available = (try? c.decode(FlexibleBool.self, forKey: .available))?.value ?? false
        favorite = (try? c.decode(FlexibleBool.self, forKey: .favorite))?.value ?? false
        download_status = try? c.decodeIfPresent(String.self, forKey: .download_status)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(artist, forKey: .artist)
        try c.encodeIfPresent(artist_id, forKey: .artist_id)
        try c.encodeIfPresent(album, forKey: .album)
        try c.encodeIfPresent(album_id, forKey: .album_id)
        try c.encodeIfPresent(cover, forKey: .cover)
        try c.encodeIfPresent(duration, forKey: .duration)
        try c.encodeIfPresent(track_position, forKey: .track_position)
    }

    /// Memberwise initializer used when building tracks locally (offline cache).
    init(id: Int, title: String, artist: String?, artist_id: Int? = nil,
         album: String? = nil, album_id: Int? = nil, cover: String? = nil,
         duration: Int? = nil, track_position: Int? = nil,
         available: Bool = false, favorite: Bool = false) {
        self.id = id; self.title = title; self.artist = artist
        self.artist_id = artist_id; self.album = album; self.album_id = album_id
        self.cover = cover; self.duration = duration; self.track_position = track_position
        self.available = available; self.favorite = favorite
    }
}

// MARK: - Artist / Album / Playlist

struct ArtistLite: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    var picture: String?
    var nb_fan: Int?
    var count: Int?
}

struct AlbumLite: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let title: String
    var artist: String?
    var artist_id: Int?
    var cover: String?
    var nb_tracks: Int?
    var release_date: String?
    var record_type: String?
    private let availableRaw: FlexibleBool?
    var available: Bool { availableRaw?.value ?? false }

    enum CodingKeys: String, CodingKey {
        case id, title, artist, artist_id, cover, nb_tracks, release_date, record_type
        case availableRaw = "available"
    }
}

struct PlaylistLite: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var name: String?
    var title: String?       // Deezer playlists use `title`
    var cover: String?
    var count: Int?
    var nb_tracks: Int?
    var by: String?
    var displayName: String { name ?? title ?? "Playlist" }
    var trackCount: Int { count ?? nb_tracks ?? 0 }
}

// MARK: - Composite responses

struct SearchResponse: Codable {
    var artists: [ArtistLite] = []
    var albums: [AlbumLite] = []
    var tracks: [Track] = []
}

struct HomeResponse: Codable {
    var tracks: [Track] = []
    var albums: [AlbumLite] = []
    var artists: [ArtistLite] = []
    var playlists: [PlaylistLite] = []
}

struct ArtistResponse: Codable {
    let artist: ArtistLite
    var top: [Track] = []
    var albums: [AlbumLite] = []
    var related: [ArtistLite] = []
}

struct AlbumResponse: Codable {
    let id: Int
    let title: String
    var artist: String?
    var artist_id: Int?
    var cover: String?
    var release_date: String?
    var nb_tracks: Int?
    var tracks: [Track] = []
}

struct GenreCard: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    var picture: String?
}

struct MoodCard: Codable, Identifiable, Equatable, Hashable {
    var id: String { slug }
    let slug: String
    let name: String
    var image: String?
}

struct ExploreResponse: Codable {
    var releases: [AlbumLite] = []
    var topAlbums: [AlbumLite] = []
    var topPlaylists: [PlaylistLite] = []
    var topArtists: [ArtistLite] = []
    var moods: [MoodCard] = []
    var genres: [GenreCard] = []
}

struct GenreResponse: Codable {
    let id: Int
    let name: String
    var artists: [ArtistLite] = []
    var albums: [AlbumLite] = []
    var playlists: [PlaylistLite] = []
    var tracks: [Track] = []
}

struct MoodResponse: Codable {
    let slug: String
    let name: String
    var playlists: [PlaylistLite] = []
    var tracks: [Track] = []
}

struct DeezerPlaylistDetail: Codable {
    let id: Int
    let title: String
    var cover: String?
    var by: String?
    var nb_tracks: Int?
    var tracks: [Track] = []
}

struct PlaylistDetail: Codable {
    let id: Int
    var name: String?
    var title: String?
    let is_owner: Bool?
    var tracks: [Track] = []
    var displayName: String { name ?? title ?? "Playlist" }
}

struct Recommendations: Codable {
    let personalized: Bool
    var basedOn: [ArtistLite] = []
    var artists: [ArtistLite] = []
    var tracks: [Track] = []
}

struct RadioResponse: Codable {
    let seed: String
    var tracks: [Track] = []
}

// MARK: - Downloads (server-side fetch jobs)

struct DownloadJob: Codable, Identifiable, Equatable {
    let id: Int
    let kind: String
    let deezer_id: Int
    let label: String
    var cover: String?
    var status: String
    var detail: String?
    var progress: Double?
    var username: String?
    var created_at: String?
}

// MARK: - Lyrics

struct LyricLine: Codable, Identifiable, Equatable {
    var id: Double { time }
    let time: Double
    let text: String
}

struct LyricsResponse: Codable {
    var synced: [LyricLine] = []
    var plain: String = ""
}

// MARK: - Helpers

func formatTime(_ seconds: Int?) -> String {
    guard let s = seconds, s >= 0 else { return "--:--" }
    return String(format: "%d:%02d", s / 60, s % 60)
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "--:--" }
    let s = Int(seconds)
    return String(format: "%d:%02d", s / 60, s % 60)
}
