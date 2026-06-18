import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: DownloadManager
    @Environment(\.dismiss) private var dismiss
    @State private var showChangePassword = false
    @State private var sheet: ProfileSheet?

    private enum ProfileSheet: Identifiable {
        case stats, madeForYou, listen, social, following, equalizer, tokens, users, settings
        var id: Int { hashValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                List {
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Theme.bgElev2).frame(width: 56, height: 56)
                                Image(systemName: "person.fill").foregroundStyle(Theme.textDim).font(.system(size: 22))
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.me?.username ?? "—").font(Theme.body(18, weight: .semibold)).foregroundStyle(Theme.text)
                                if app.me?.is_admin == true {
                                    Text("Admin").font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.accentInk)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Theme.accent).clipShape(Capsule())
                                }
                            }
                        }
                    }.listRowBackground(Theme.bgElev)

                    Section("For you") {
                        navButton("Your stats", "chart.bar.fill") { sheet = .stats }
                        navButton("Made for you", "sparkles") { sheet = .madeForYou }
                        navButton("Listen Together", "person.2.wave.2.fill") { sheet = .listen }
                        navButton("Friends", "person.2.fill") { sheet = .social }
                        NavigationLink { FollowingView() } label: {
                            Label("Following artists", systemImage: "bell.fill")
                        }
                        navButton("Equalizer", "slider.horizontal.3") { sheet = .equalizer }
                    }.listRowBackground(Theme.bgElev)

                    Section("Server") {
                        labeled("Connected to", app.serverURLString)
                        labeled("Offline songs", "\(downloads.offlineTracks.count)")
                        labeled("Offline size", ByteCountFormatter.string(fromByteCount: downloads.totalBytes, countStyle: .file))
                    }.listRowBackground(Theme.bgElev)

                    Section("Account") {
                        Button("Change password") { showChangePassword = true }
                        navButton("API access tokens", "key.fill") { sheet = .tokens }
                        Button("Sign out", role: .destructive) {
                            Task { await app.logout(); library.clear(); dismiss() }
                        }
                    }.listRowBackground(Theme.bgElev)

                    if app.me?.is_admin == true {
                        Section("Admin") {
                            navButton("Users", "person.3.fill") { sheet = .users }
                            navButton("Settings", "gearshape.fill") { sheet = .settings }
                        }.listRowBackground(Theme.bgElev)
                    }

                    Section {
                        Button("Remove all offline downloads", role: .destructive) { downloads.removeAll() }
                    }.listRowBackground(Theme.bgElev)
                }
                .hideScrollBackground()
            }
            .musicarrDestinations()
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView().musicarrScreen()
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .stats: StatsView()
                case .madeForYou: MadeForYouView()
                case .listen: ListenTogetherView()
                case .social: SocialView()
                case .following: NavigationStack { FollowingView().musicarrDestinations() }.musicarrScreen()
                case .equalizer: EqualizerView()
                case .tokens: APITokensView()
                case .users: UsersAdminView()
                case .settings: SettingsAdminView()
                }
            }
        }
    }

    private func navButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .foregroundStyle(Theme.text)
        }
    }

    private func labeled(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(Theme.textDim)
            Spacer()
            Text(v).foregroundStyle(Theme.text).font(Theme.body(13)).lineLimit(1).truncationMode(.middle)
        }
    }
}

/// Minimal browse-and-play UI when the user opted to continue offline (no server
/// reachable). Only downloaded tracks are available.
struct OfflineOnlyView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        let tracks = downloads.offlineTracks
                        if tracks.isEmpty {
                            StateText(text: "No offline songs available.")
                        } else {
                            PrimaryButton(title: "Play all", systemImage: "play.fill") { player.play(tracks) }
                                .padding(.horizontal, 12)
                            VStack(spacing: 0) { ForEach(tracks) { TrackRow(track: $0, context: tracks) } }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8).padding(.bottom, 140)
                }
            }
            .navigationTitle("Offline")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sign in") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if player.current != nil { MiniPlayerBar { }.padding(.bottom, 8) }
            }
        }
    }
}
