import SwiftUI

/// Start or join a shared listening session and watch members / current track.
struct ListenTogetherView: View {
    @EnvironmentObject private var listen: ListenTogetherManager
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var joinCode = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if listen.isActive {
                            activeSession
                        } else {
                            startOrJoin
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
                }
            }
            .navigationTitle("Listen Together")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .musicarrScreen()
        .task { await listen.loadActive() }
        .alert("Listen Together", isPresented: Binding(
            get: { listen.errorMessage != nil },
            set: { if !$0 { listen.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { listen.errorMessage = nil }
        } message: { Text(listen.errorMessage ?? "") }
    }

    // MARK: Not in a session

    private var startOrJoin: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Listen to the same music in sync with friends.")
                .font(Theme.body(14.5)).foregroundStyle(Theme.textDim)

            PrimaryButton(title: "Start a session", systemImage: "play.circle") {
                Task { await listen.start() }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Join with a code").font(Theme.body(13, weight: .semibold)).foregroundStyle(Theme.textDim)
                #if os(iOS)
                TextField("ABCD", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .musicarrField()
                #else
                TextField("ABCD", text: $joinCode).musicarrField()
                #endif
                GhostButton(title: "Join", systemImage: "person.2.fill") {
                    Task { await listen.join(code: joinCode); joinCode = "" }
                }
            }

            if listen.busy { ProgressView().tint(Theme.accent) }
        }
    }

    // MARK: In a session

    private var activeSession: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let code = listen.code {
                VStack(alignment: .leading, spacing: 6) {
                    Text(listen.isHost ? "You're hosting" : "Connected")
                        .font(Theme.body(13, weight: .semibold)).foregroundStyle(Theme.textDim)
                    Text(code)
                        .font(Theme.display(36, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .tracking(6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.bgElev)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }

            if let t = currentTrack {
                RowTitle(text: "Now playing")
                HStack(spacing: 12) {
                    Cover(url: t.cover, size: 56, rounded: 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.title).font(Theme.body(15, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                        Text(t.artist ?? "").font(Theme.body(13)).foregroundStyle(Theme.textDim).lineLimit(1)
                    }
                    Spacer()
                }
            } else {
                Text(listen.isHost ? "Start playing something to share it." : "Waiting for the host to play…")
                    .font(Theme.body(14)).foregroundStyle(Theme.textFaint)
            }

            RowTitle(text: "Members (\(listen.members.count))")
            VStack(spacing: 0) {
                ForEach(listen.members) { m in
                    HStack(spacing: 12) {
                        Image(systemName: m.is_host ? "crown.fill" : "person.fill")
                            .foregroundStyle(m.is_host ? Theme.accent : Theme.textDim)
                            .frame(width: 22)
                        Text(m.username).font(Theme.body(15)).foregroundStyle(Theme.text)
                        Spacer()
                        if m.is_host { Text("Host").font(Theme.body(12, weight: .semibold)).foregroundStyle(Theme.textFaint) }
                    }
                    .padding(.vertical, 10)
                }
            }

            Button(role: .destructive) {
                Task { await listen.leave() }
            } label: {
                Text(listen.isHost ? "End session" : "Leave session")
                    .font(Theme.body(14.5, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(Capsule().stroke(Theme.danger, lineWidth: 1))
                    .foregroundStyle(Theme.danger)
            }
            .buttonStyle(.plain)
        }
    }

    /// For the host show the local current track; for guests show the synced one.
    private var currentTrack: Track? {
        if listen.isHost { return player.current }
        return listen.session?.track ?? player.current
    }
}
