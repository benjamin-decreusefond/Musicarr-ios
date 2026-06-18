import Foundation

enum APIError: LocalizedError {
    case notConfigured
    case unauthorized
    case http(Int, String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "No server configured"
        case .unauthorized: return "Not signed in"
        case .http(let code, let msg): return msg.isEmpty ? "HTTP \(code)" : msg
        case .decoding(let m): return "Bad response: \(m)"
        case .transport(let m): return m
        }
    }
}

/// Thin async wrapper around the Musicarr REST API. Authentication is the same
/// cookie-session scheme the web app uses: the server sets a `musicarr_session`
/// HttpOnly cookie on login, which URLSession persists in the shared cookie
/// storage and replays on every request.
final class APIClient {
    private(set) var baseURL: URL
    let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpShouldSetCookies = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
    }

    func setBaseURL(_ url: URL) { baseURL = url }

    func url(_ path: String) -> URL {
        if path.hasPrefix("http") {
            // Fall back to the base URL if the absolute path is somehow malformed,
            // rather than crashing on a force-unwrap.
            return URL(string: path) ?? baseURL
        }
        return baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
    }

    /// Build a request URL, throwing a clear error for a malformed absolute path
    /// instead of trapping. Used by the request path so callers get APIError.
    private func requestURL(_ path: String) throws -> URL {
        if path.hasPrefix("http") {
            guard let u = URL(string: path) else { throw APIError.transport("Bad URL: \(path)") }
            return u
        }
        return baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
    }

    /// Cookies currently held for the configured server (passed to AVPlayer for
    /// authenticated streaming).
    var cookies: [HTTPCookie] {
        HTTPCookieStorage.shared.cookies(for: baseURL) ?? []
    }

    // MARK: Core request

    @discardableResult
    private func request<T: Decodable>(_ method: String, _ path: String,
                                       body: Encodable? = nil,
                                       decode: T.Type) async throws -> T {
        let data = try await raw(method, path, body: body)
        // Only force the cast when T really is EmptyResponse; otherwise decode
        // normally so a mismatch surfaces as a decoding error, not a crash.
        if T.self == EmptyResponse.self {
            if let empty = EmptyResponse() as? T { return empty }
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func raw(_ method: String, _ path: String, body: Encodable?) async throws -> Data {
        var req = URLRequest(url: try requestURL(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.transport("No HTTP response")
        }
        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .musicarrUnauthorized, object: nil)
            throw APIError.unauthorized
        }
        if !(200...299).contains(http.statusCode) {
            let msg = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? ""
            throw APIError.http(http.statusCode, msg)
        }
        return data
    }

    // MARK: Convenience verbs

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await request("GET", path, decode: type)
    }
    func post<T: Decodable>(_ path: String, body: Encodable? = nil, as type: T.Type) async throws -> T {
        try await request("POST", path, body: body, decode: type)
    }
    func put<T: Decodable>(_ path: String, body: Encodable? = nil, as type: T.Type) async throws -> T {
        try await request("PUT", path, body: body, decode: type)
    }
    @discardableResult func delete(_ path: String) async throws -> EmptyResponse {
        try await request("DELETE", path, decode: EmptyResponse.self)
    }
    @discardableResult func post(_ path: String, body: Encodable? = nil) async throws -> EmptyResponse {
        try await request("POST", path, body: body, decode: EmptyResponse.self)
    }
    @discardableResult func put(_ path: String, body: Encodable? = nil) async throws -> EmptyResponse {
        try await request("PUT", path, body: body, decode: EmptyResponse.self)
    }

    /// Download raw bytes (used by the offline-download manager for audio files).
    func download(_ path: String) async throws -> Data {
        try await raw("GET", path, body: nil)
    }
}

struct EmptyResponse: Decodable {}
private struct ErrorBody: Decodable { let error: String? }

extension Notification.Name {
    static let musicarrUnauthorized = Notification.Name("musicarr.unauthorized")
}

// MARK: - Type-erased Encodable

struct AnyEncodable: Encodable {
    private let encodeFn: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFn = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFn(encoder) }
}

/// Convenience for sending ad-hoc JSON bodies.
struct JSONBody: Encodable {
    private var storage: [String: AnyEncodable] = [:]
    init(_ dict: [String: Encodable]) {
        for (k, v) in dict { storage[k] = AnyEncodable(v) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: StringKey.self)
        for (k, v) in storage { try c.encode(v, forKey: StringKey(k)) }
    }
    private struct StringKey: CodingKey {
        var stringValue: String; var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}
