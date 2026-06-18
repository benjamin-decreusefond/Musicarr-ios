import Foundation
import SwiftUI

/// Polling-based "Listen Together". The host broadcasts its playback state; guests
/// poll every ~2.5s and keep the local PlayerManager in sync (seek on drift,
/// follow play/pause). Kept deliberately simple and nil-safe.
@MainActor
final class ListenTogetherManager: ObservableObject {
    @Published private(set) var session: ListenSession?
    @Published private(set) var busy = false
    @Published var errorMessage: String?

    private weak var app: AppState?
    private weak var player: PlayerManager?
    private var pollTask: Task<Void, Never>?
    private var hostObserver: Task<Void, Never>?

    /// Drift threshold (seconds) before a guest re-seeks to match the host.
    private let driftThreshold: Double = 2.0
    private let pollInterval: UInt64 = 2_500_000_000

    var isActive: Bool { session != nil }
    var isHost: Bool { session?.is_host ?? false }
    var code: String? { session?.code }
    var members: [ListenMember] { session?.members ?? [] }

    func attach(app: AppState, player: PlayerManager) {
        self.app = app
        self.player = player
    }

    // MARK: Lifecycle

    func loadActive() async {
        guard let app else { return }
        if let res = try? await app.listenActive(), res.active, let s = res.session {
            session = s
            startLoops()
        }
    }

    func start() async {
        guard let app else { return }
        busy = true; defer { busy = false }
        do {
            session = try await app.listenStart()
            startLoops()
        } catch { errorMessage = describe(error) }
    }

    func join(code: String) async {
        guard let app else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        busy = true; defer { busy = false }
        do {
            session = try await app.listenJoin(code: trimmed)
            startLoops()
        } catch { errorMessage = describe(error) }
    }

    func leave() async {
        let id = session?.id
        stopLoops()
        session = nil
        if let id, let app { _ = try? await app.listenLeave(id) }
    }

    // MARK: Loops

    private func startLoops() {
        stopLoops()
        guard let s = session else { return }
        if s.is_host { startHostObserver() } else { startGuestPolling() }
    }

    private func stopLoops() {
        pollTask?.cancel(); pollTask = nil
        hostObserver?.cancel(); hostObserver = nil
    }

    /// Guests poll the session and sync the local player to the host.
    private func startGuestPolling() {
        guard let id = session?.id else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce(id)
                try? await Task.sleep(nanoseconds: self?.pollInterval ?? 2_500_000_000)
            }
        }
    }

    private func pollOnce(_ id: Int) async {
        guard let app, let player else { return }
        guard let fresh = try? await app.listenSession(id) else { return }
        session = fresh
        guard !fresh.is_host else { return }   // we became host somehow; stop following

        // Match the host's current track.
        if let hostTrack = fresh.track {
            if player.current?.id != hostTrack.id {
                player.play([hostTrack])
            }
            // Sync position if drift is large.
            let target = fresh.position ?? 0
            if abs(player.time - target) > driftThreshold {
                player.seek(target)
            }
            // Follow play/pause.
            if fresh.is_playing && !player.playing { player.toggle() }
            else if !fresh.is_playing && player.playing { player.toggle() }
        }
    }

    /// The host pushes its playback state whenever it changes.
    private func startHostObserver() {
        guard let id = session?.id else { return }
        hostObserver = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let player = self.player else { return }
                let cur = player.current?.id
                let playing = player.playing
                let pos = player.time
                // Always post the latest state on a fixed cadence so members stay
                // in sync (transport changes are reflected on the next tick).
                await self.pushHostState(id, trackId: cur, position: pos, playing: playing)
                // refresh member list periodically
                if let app = self.app, let fresh = try? await app.listenSession(id) {
                    self.session = fresh
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    private func pushHostState(_ id: Int, trackId: Int?, position: Double, playing: Bool) async {
        guard let app else { return }
        _ = try? await app.listenPostState(id, trackId: trackId, position: position, isPlaying: playing)
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
