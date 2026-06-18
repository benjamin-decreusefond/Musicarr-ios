import Foundation

// Models for the newer server features: stats, mixes, listen-together,
// following, social, playlist sharing, API tokens, and admin users/settings.
// Booleans that may arrive as int/bool use FlexibleBool (see Models.swift).

// MARK: - Stats (GET /api/stats?range=week|month|year|all)

struct StatsTotals: Codable, Equatable {
    var plays: Int = 0
    var tracks: Int = 0
    var artists: Int = 0
    var seconds: Int = 0
}

struct StatArtist: Codable, Identifiable, Equatable {
    var id: Int { artist_id }
    let artist_id: Int
    let artist: String
    var plays: Int = 0
    var cover: String?
}

struct StatAlbum: Codable, Identifiable, Equatable {
    var id: Int { album_id }
    let album_id: Int
    let title: String
    var artist: String?
    var cover: String?
    var plays: Int = 0
}

struct StatDay: Codable, Identifiable, Equatable {
    var id: String { day }
    let day: String
    var plays: Int = 0
}

struct StatsResponse: Codable, Equatable {
    let range: String
    var totals: StatsTotals = StatsTotals()
    var topArtists: [StatArtist] = []
    var topTracks: [Track] = []
    var topAlbums: [StatAlbum] = []
    var daily: [StatDay] = []
}

// MARK: - Mixes / Made For You (GET /api/mixes)

/// A playlist-like mix that already carries its tracks.
/// (Hashable / Equatable are provided in MadeForYouView so it can be a nav value.)
struct Mix: Codable, Identifiable {
    let id: Int
    var name: String?
    var title: String?
    var subtitle: String?
    var cover: String?
    var tracks: [Track] = []

    var displayName: String { name ?? title ?? "Mix" }

    enum CodingKeys: String, CodingKey {
        case id, name, title, subtitle, cover, tracks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Some mixes are server-generated and may not have a stable numeric id.
        id = (try? c.decode(Int.self, forKey: .id)) ?? Int.random(in: 1_000_000...9_999_999)
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        subtitle = try? c.decodeIfPresent(String.self, forKey: .subtitle)
        cover = try? c.decodeIfPresent(String.self, forKey: .cover)
        tracks = (try? c.decodeIfPresent([Track].self, forKey: .tracks)) ?? []
    }
}

struct MixesResponse: Codable {
    var smart: [Mix] = []
    var daily: [Mix] = []
}

// MARK: - Listen Together

struct ListenMember: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    private let isHostRaw: FlexibleBool?
    var is_host: Bool { isHostRaw?.value ?? false }

    enum CodingKeys: String, CodingKey {
        case id, username
        case isHostRaw = "is_host"
    }
}

struct ListenSession: Codable, Equatable {
    let id: Int
    let code: String
    var host_id: Int?
    var host_name: String?
    private let isHostRaw: FlexibleBool?
    var is_host: Bool { isHostRaw?.value ?? false }
    var track_id: Int?
    var position: Double?
    private let isPlayingRaw: FlexibleBool?
    var is_playing: Bool { isPlayingRaw?.value ?? false }
    var updated_at: String?
    var server_time: Double?
    var track: Track?
    var members: [ListenMember] = []

    enum CodingKeys: String, CodingKey {
        case id, code, host_id, host_name
        case isHostRaw = "is_host"
        case track_id, position
        case isPlayingRaw = "is_playing"
        case updated_at, server_time, track, members
    }
}

struct ListenActiveResponse: Codable {
    private let activeRaw: FlexibleBool?
    var active: Bool { activeRaw?.value ?? false }
    var session: ListenSession?

    enum CodingKeys: String, CodingKey {
        case activeRaw = "active"
        case session
    }
}

// MARK: - Following artists (auto-download)

struct FollowedArtist: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    var picture: String?
    var created_at: String?
}

struct FollowingState: Codable {
    private let followingRaw: FlexibleBool?
    var following: Bool { followingRaw?.value ?? false }
    enum CodingKeys: String, CodingKey { case followingRaw = "following" }
}

// MARK: - Social

struct SocialUser: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    private let isAdminRaw: FlexibleBool?
    var is_admin: Bool { isAdminRaw?.value ?? false }
    private let followingRaw: FlexibleBool?
    var following: Bool { followingRaw?.value ?? false }
    var followers: Int?
    var nowPlaying: Track?
    var lastPlayed: Track?

    enum CodingKeys: String, CodingKey {
        case id, username
        case isAdminRaw = "is_admin"
        case followingRaw = "following"
        case followers, nowPlaying, lastPlayed
    }
}

struct SocialProfile: Codable, Equatable {
    let id: Int
    let username: String
    private let isAdminRaw: FlexibleBool?
    var is_admin: Bool { isAdminRaw?.value ?? false }
    private let followingRaw: FlexibleBool?
    var following: Bool { followingRaw?.value ?? false }
    var followers: Int?
    var following_count: Int?
    var nowPlaying: Track?
    var recent: [Track] = []
    var favorites: [Track] = []
    var playlists: [PlaylistLite] = []

    enum CodingKeys: String, CodingKey {
        case id, username
        case isAdminRaw = "is_admin"
        case followingRaw = "following"
        case followers, following_count, nowPlaying, recent, favorites, playlists
    }
}

// MARK: - Shared playlists

struct PlaylistShare: Codable, Identifiable, Equatable {
    var id: Int { user_id }
    let user_id: Int
    let username: String
    private let canEditRaw: FlexibleBool?
    var can_edit: Bool { canEditRaw?.value ?? false }
    var created_at: String?

    enum CodingKeys: String, CodingKey {
        case user_id, username
        case canEditRaw = "can_edit"
        case created_at
    }
}

// MARK: - API tokens

struct APIToken: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    var token_prefix: String?
    var created_at: String?
    var last_used_at: String?
    /// Only present in the response that creates the token (shown once).
    var token: String?
}

// MARK: - Admin users

struct AdminUser: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    private let isAdminRaw: FlexibleBool?
    var is_admin: Bool { isAdminRaw?.value ?? false }
    var created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case isAdminRaw = "is_admin"
        case created_at
    }
}

// MARK: - Admin settings

struct ServerSettings: Codable, Equatable {
    var root_folder: String?
    var slskd_url: String?
    private let slskdKeySetRaw: FlexibleBool?
    var slskd_api_key_set: Bool { slskdKeySetRaw?.value ?? false }
    var slskd_api_key_hint: String?
    var slskd_download_dir: String?
    private let slskdEnabledRaw: FlexibleBool?
    var slskd_enabled: Bool { slskdEnabledRaw?.value ?? false }

    enum CodingKeys: String, CodingKey {
        case root_folder, slskd_url
        case slskdKeySetRaw = "slskd_api_key_set"
        case slskd_api_key_hint, slskd_download_dir
        case slskdEnabledRaw = "slskd_enabled"
    }
}

struct SettingsTestResult: Codable {
    private let okRaw: FlexibleBool?
    var ok: Bool { okRaw?.value ?? false }
    var message: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case okRaw = "ok"
        case message, error
    }
}
