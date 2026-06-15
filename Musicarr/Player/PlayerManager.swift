import Foundation
import AVFoundation
import MediaPlayer
import SwiftUI

enum RepeatMode: String { case off, all, one }

/// AVPlayer-backed playback engine. Prefers an offline copy of a track when one
/// exists, otherwise streams from the server with the session cookie attached so
/// playback works exactly like the web player (HTTP range / seeking included).
@MainActor
final class PlayerManager: ObservableObject {
    @Published private(set) var queue: [Track] = []
    @Published private(set) var index: Int = -1
    @Published var playing = false
    @Published var time: Double = 0
    @Published var duration: Double = 0
    @Published var repeatMode: RepeatMode = {
        RepeatMode(rawValue: UserDefaults.standard.string(forKey: "musicarr.repeat") ?? "off") ?? .off
    }()
    @Published var volume: Float = {
        let v = UserDefaults.standard.object(forKey: "musicarr.volume") as? Float
        return v.map { min(1, max(0, $0)) } ?? 1
    }()

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private weak var app: AppState?
    private weak var downloads: DownloadManager?
    private var heartbeatTask: Task<Void, Never>?

    var current: Track? { (index >= 0 && index < queue.count) ? queue[index] : nil }
    var hasNext: Bool { repeatMode != .off || index < queue.count - 1 }
    var hasPrev: Bool { index > 0 }

    init() {
        configureAudioSession()
        player.volume = volume
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { t in
            Task { @MainActor [weak self] in self?.onTick(t) }
        }
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.trackEnded() }
        }
        setupRemoteCommands()
    }

    func attach(app: AppState, downloads: DownloadManager) {
        self.app = app
        self.downloads = downloads
    }

    // MARK: Public controls

    func play(_ tracks: [Track], startAt start: Int = 0) {
        guard !tracks.isEmpty else { return }
        queue = tracks
        playAt(max(0, min(start, tracks.count - 1)))
    }

    func playAt(_ i: Int) {
        guard i >= 0 && i < queue.count else { return }
        index = i
        loadCurrent()
    }

    func enqueue(_ tracks: [Track]) {
        let existing = Set(queue.map { $0.id })
        queue.append(contentsOf: tracks.filter { !existing.contains($0.id) })
    }

    func toggle() {
        guard current != nil else { return }
        if playing { player.pause(); playing = false }
        else { player.play(); playing = true }
        updateNowPlaying()
    }

    func next() {
        if repeatMode == .one { seek(0); player.play(); playing = true; return }
        if index < queue.count - 1 { playAt(index + 1) }
        else if repeatMode == .all && !queue.isEmpty { playAt(0) }
        else { playing = false; player.pause() }
        beat()
    }

    func prev() {
        if time > 3 { seek(0); return }
        if index > 0 { playAt(index - 1) }
        else { seek(0) }
    }

    func seek(_ seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        time = seconds
        updateNowPlaying()
    }

    func setVolume(_ v: Float) {
        volume = min(1, max(0, v))
        player.volume = volume
        UserDefaults.standard.set(volume, forKey: "musicarr.volume")
    }

    func cycleRepeat() {
        repeatMode = repeatMode == .off ? .all : (repeatMode == .all ? .one : .off)
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "musicarr.repeat")
    }

    func moveInQueue(_ from: Int, _ to: Int) {
        guard from != to, queue.indices.contains(from), to >= 0, to < queue.count else { return }
        let item = queue.remove(at: from)
        queue.insert(item, at: to)
        if index == from { index = to }
        else if from < index && to >= index { index -= 1 }
        else if from > index && to <= index { index += 1 }
    }

    func removeFromQueue(_ i: Int) {
        guard queue.indices.contains(i) else { return }
        queue.remove(at: i)
        if i < index { index -= 1 }
        else if i == index { if index >= queue.count { index = queue.count - 1 }; loadCurrent() }
    }

    // MARK: Source loading

    private func loadCurrent() {
        guard let track = current, let app else { return }
        let asset: AVURLAsset
        if let local = downloads?.localURL(track.id) {
            asset = AVURLAsset(url: local)
        } else {
            var options: [String: Any] = [:]
            let cookies = app.streamingCookies
            if !cookies.isEmpty {
                options[AVURLAssetHTTPCookiesKey] = cookies
            }
            asset = AVURLAsset(url: app.streamURL(track.id), options: options)
        }
        let item = AVPlayerItem(asset: asset)
        statusObservation = item.observe(\.status, options: [.new]) { it, _ in
            let ready = it.status == .readyToPlay
            let seconds = it.duration.seconds
            Task { @MainActor [weak self] in
                guard ready, let self else { return }
                self.duration = seconds.isFinite ? seconds : Double(track.duration ?? 0)
                self.updateNowPlaying()
            }
        }
        player.replaceCurrentItem(with: item)
        player.volume = volume
        player.play()
        playing = true
        time = 0
        duration = Double(track.duration ?? 0)
        updateNowPlaying()
        Task { await app.logPlay(track.id) }
        beat()
        startHeartbeat()
    }

    private func onTick(_ t: CMTime) {
        guard !t.seconds.isNaN else { return }
        time = t.seconds
        if let d = player.currentItem?.duration.seconds, d.isFinite, d > 0 { duration = d }
        updateNowPlaying(rateOnly: true)
    }

    private func trackEnded() {
        if repeatMode == .one { seek(0); player.play(); playing = true; return }
        next()
    }

    // MARK: Now-playing presence (heartbeat)

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.beat()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }
    private func beat() { Task { await app?.heartbeat(current?.id) } }

    // MARK: Audio session + remote command center

    private func configureAudioSession() {
        #if !os(macOS)
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default)
        try? s.setActive(true)
        #endif
    }

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { _ in Task { @MainActor [weak self] in self?.toggle() }; return .success }
        c.pauseCommand.addTarget { _ in Task { @MainActor [weak self] in self?.toggle() }; return .success }
        c.togglePlayPauseCommand.addTarget { _ in Task { @MainActor [weak self] in self?.toggle() }; return .success }
        c.nextTrackCommand.addTarget { _ in Task { @MainActor [weak self] in self?.next() }; return .success }
        c.previousTrackCommand.addTarget { _ in Task { @MainActor [weak self] in self?.prev() }; return .success }
        c.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = e.positionTime
            Task { @MainActor [weak self] in self?.seek(position) }
            return .success
        }
    }

    private func updateNowPlaying(rateOnly: Bool = false) {
        guard let track = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if !rateOnly {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist ?? ""
            info[MPMediaItemPropertyAlbumTitle] = track.album ?? ""
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
