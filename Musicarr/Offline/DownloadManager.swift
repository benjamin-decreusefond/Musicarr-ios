import Foundation
import SwiftUI

/// "Download for later": pulls a track's audio from the server's `/api/stream`
/// endpoint to the device's Documents directory and records its metadata so it
/// can be browsed and played with no network. Each download is keyed by the
/// Deezer track id, so it lines up with everything else in the app.
@MainActor
final class DownloadManager: ObservableObject {
    /// Tracks that are fully downloaded and playable offline.
    @Published private(set) var items: [OfflineItem] = []
    /// Track id -> 0...1 progress while a download is in flight.
    @Published private(set) var inFlight: [Int: Double] = [:]
    /// Track ids whose most recent offline download attempt failed, so the UI can
    /// surface the failure instead of silently swallowing it.
    @Published private(set) var failed: Set<Int> = []

    private let app: AppState
    private let fm = FileManager.default
    private let engine = FileDownloadEngine()
    private var tasks: [Int: Task<Void, Never>] = [:]

    init(app: AppState) {
        self.app = app
        load()
    }

    // MARK: Locations

    private var dir: URL {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Offline", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    private var indexURL: URL { dir.appendingPathComponent("index.json") }
    private func audioURL(_ id: Int) -> URL { dir.appendingPathComponent("\(id).audio") }

    // MARK: Queries

    func isDownloaded(_ id: Int) -> Bool { items.contains { $0.track.id == id } }
    func isDownloading(_ id: Int) -> Bool { inFlight[id] != nil }
    func localURL(_ id: Int) -> URL? {
        guard isDownloaded(id) else { return nil }
        let u = audioURL(id)
        return fm.fileExists(atPath: u.path) ? u : nil
    }
    var offlineTracks: [Track] { items.map { $0.track } }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }

    // MARK: Mutations

    /// Start (or no-op) an offline download for a track. The track must already
    /// be available on the server (streamable); otherwise nothing is saved.
    func download(_ track: Track) {
        guard !isDownloaded(track.id), tasks[track.id] == nil else { return }
        inFlight[track.id] = 0
        failed.remove(track.id)
        let id = track.id
        let url = app.streamURL(id)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let (tempURL, bytes) = try await self.engine.download(url: url) { progress in
                    Task { @MainActor [weak self] in self?.inFlight[id] = progress }
                }
                if Task.isCancelled { try? self.fm.removeItem(at: tempURL); self.inFlight[id] = nil; self.tasks[id] = nil; return }
                let dest = self.audioURL(id)
                try? self.fm.removeItem(at: dest)
                try self.fm.moveItem(at: tempURL, to: dest)
                var saved = track
                saved.available = true
                self.items.append(OfflineItem(track: saved, bytes: bytes, savedAt: Date()))
                self.failed.remove(id)
                self.persist()
            } catch {
                try? self.fm.removeItem(at: self.audioURL(id))   // no partial file
                if !Task.isCancelled { self.failed.insert(id) }  // surface the failure
            }
            self.inFlight[id] = nil
            self.tasks[id] = nil
        }
        tasks[id] = task
    }

    /// Whether the last offline-download attempt for this track failed.
    func didFail(_ id: Int) -> Bool { failed.contains(id) }
    /// Clear a recorded failure (e.g. before a retry or when dismissed).
    func clearFailure(_ id: Int) { failed.remove(id) }

    func cancel(_ id: Int) {
        tasks[id]?.cancel()
        tasks[id] = nil
        inFlight[id] = nil
        failed.remove(id)
        try? fm.removeItem(at: audioURL(id))
    }

    func remove(_ id: Int) {
        cancel(id)
        items.removeAll { $0.track.id == id }
        try? fm.removeItem(at: audioURL(id))
        persist()
    }

    func removeAll() {
        for t in tasks.values { t.cancel() }
        tasks.removeAll(); inFlight.removeAll()
        for item in items { try? fm.removeItem(at: audioURL(item.track.id)) }
        items.removeAll()
        persist()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([OfflineItem].self, from: data) else { return }
        // Drop entries whose audio file went missing.
        items = decoded.filter { fm.fileExists(atPath: audioURL($0.track.id).path) }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }
}

struct OfflineItem: Codable, Identifiable, Equatable {
    var id: Int { track.id }
    let track: Track
    let bytes: Int64
    let savedAt: Date
}

/// A small `URLSessionDownloadTask` wrapper that streams a URL straight to a
/// temp file (efficient for large audio) while reporting fractional progress.
/// Uses the shared cookie storage so the authenticated stream endpoint works.
final class FileDownloadEngine: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    private struct Pending {
        let progress: (Double) -> Void
        let continuation: CheckedContinuation<(URL, Int64), Error>
    }
    private let lock = NSLock()
    private var pending: [Int: Pending] = [:]

    func download(url: URL, progress: @escaping (Double) -> Void) async throws -> (URL, Int64) {
        try await withCheckedThrowingContinuation { cont in
            var req = URLRequest(url: url)
            req.setValue("audio/*", forHTTPHeaderField: "Accept")
            let task = session.downloadTask(with: req)
            lock.lock()
            pending[task.taskIdentifier] = Pending(progress: progress, continuation: cont)
            lock.unlock()
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let p = min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        lock.lock(); let cb = pending[downloadTask.taskIdentifier]?.progress; lock.unlock()
        cb?(p)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // The system deletes `location` when this delegate returns, so move it now.
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let attrs = try? FileManager.default.attributesOfItem(atPath: location.path)
        let bytes = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            lock.lock(); let p = pending.removeValue(forKey: downloadTask.taskIdentifier); lock.unlock()
            // Validate HTTP status — a 404/401 body would otherwise be saved as "audio".
            if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: dest)
                p?.continuation.resume(throwing: APIError.http(http.statusCode, ""))
            } else {
                p?.continuation.resume(returning: (dest, bytes))
            }
        } catch {
            lock.lock(); let p = pending.removeValue(forKey: downloadTask.taskIdentifier); lock.unlock()
            p?.continuation.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }   // success is handled in didFinishDownloadingTo
        lock.lock(); let p = pending.removeValue(forKey: task.taskIdentifier); lock.unlock()
        p?.continuation.resume(throwing: error)
    }
}
