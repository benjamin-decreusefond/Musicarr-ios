import SwiftUI

// MARK: - API access tokens (any signed-in user)

struct APITokensView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var tokens: [APIToken] = []
    @State private var loaded = false
    @State private var showCreate = false
    @State private var newName = ""
    @State private var createdToken: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                List {
                    Section {
                        if !loaded {
                            HStack { Spacer(); ProgressView().tint(Theme.accent); Spacer() }
                        } else if tokens.isEmpty {
                            Text("No tokens yet.").foregroundStyle(Theme.textFaint)
                        } else {
                            ForEach(tokens) { t in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.name).foregroundStyle(Theme.text).font(Theme.body(15, weight: .semibold))
                                    Text([t.token_prefix.map { "\($0)…" }, t.last_used_at.map { "Last used \($0)" } ?? "Never used"]
                                        .compactMap { $0 }.joined(separator: " · "))
                                        .font(Theme.body(12)).foregroundStyle(Theme.textDim)
                                }
                                .removeSwipe { revoke(t.id) }
                            }
                        }
                    } header: { Text("API access tokens") }
                    .listRowBackground(Theme.bgElev)

                    Section {
                        Button("Create token") { newName = ""; showCreate = true }
                    }.listRowBackground(Theme.bgElev)
                }
                .hideScrollBackground()
            }
            .navigationTitle("API tokens")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .alert("New token", isPresented: $showCreate) {
                TextField("Name", text: $newName)
                Button("Create") {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    Task {
                        if let t = try? await app.createApiToken(name: name) {
                            createdToken = t.token
                            await reload()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Token created", isPresented: Binding(
                get: { createdToken != nil }, set: { if !$0 { createdToken = nil } }
            )) {
                Button("Done") { createdToken = nil }
            } message: {
                Text("Copy this token now — it won't be shown again:\n\n\(createdToken ?? "")")
            }
        }
        .musicarrScreen()
        .task { await reload() }
    }

    private func reload() async {
        tokens = (try? await app.apiTokens()) ?? []
        loaded = true
    }
    private func revoke(_ id: Int) {
        Task { try? await app.revokeApiToken(id); await reload() }
    }
}

// MARK: - Admin: users

struct UsersAdminView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var users: [AdminUser] = []
    @State private var loaded = false
    @State private var showCreate = false
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var newAdmin = false

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                List {
                    Section {
                        if !loaded {
                            HStack { Spacer(); ProgressView().tint(Theme.accent); Spacer() }
                        } else {
                            ForEach(users) { u in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(u.username).foregroundStyle(Theme.text).font(Theme.body(15, weight: .semibold))
                                        if let c = u.created_at { Text(c).font(Theme.body(12)).foregroundStyle(Theme.textDim) }
                                    }
                                    Spacer()
                                    if u.is_admin {
                                        Text("Admin").font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.accentInk)
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(Theme.accent).clipShape(Capsule())
                                    }
                                }
                                .removeSwipe {
                                    Task { try? await app.deleteUser(u.id); await reload() }
                                }
                            }
                        }
                    } header: { Text("Users") }
                    .listRowBackground(Theme.bgElev)

                    Section {
                        Button("Add user") { newUsername = ""; newPassword = ""; newAdmin = false; showCreate = true }
                    }.listRowBackground(Theme.bgElev)
                }
                .hideScrollBackground()
            }
            .navigationTitle("Users")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showCreate) { createSheet }
        }
        .musicarrScreen()
        .task { await reload() }
    }

    private var createSheet: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                Form {
                    Section {
                        TextField("Username", text: $newUsername)
                            #if os(iOS)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            #endif
                        SecureField("Password", text: $newPassword)
                        Toggle("Administrator", isOn: $newAdmin)
                    }.listRowBackground(Theme.bgElev)
                }
                .hideScrollBackground()
            }
            .navigationTitle("New user")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showCreate = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let user = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !user.isEmpty, !newPassword.isEmpty else { return }
                        Task {
                            try? await app.createUser(username: user, password: newPassword, isAdmin: newAdmin)
                            showCreate = false
                            await reload()
                        }
                    }
                }
            }
        }
        .musicarrScreen()
    }

    private func reload() async {
        users = (try? await app.adminUsers()) ?? []
        loaded = true
    }
}

// MARK: - Admin: settings

struct SettingsAdminView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var settings: ServerSettings?
    @State private var loaded = false
    @State private var rootFolder = ""
    @State private var slskdURL = ""
    @State private var slskdKey = ""
    @State private var slskdDir = ""
    @State private var slskdEnabled = false
    @State private var testMessage: String?
    @State private var testing = false
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                Form {
                    if !loaded {
                        Section { HStack { Spacer(); ProgressView().tint(Theme.accent); Spacer() } }
                            .listRowBackground(Theme.bgElev)
                    } else {
                        Section("Library") {
                            TextField("Root folder", text: $rootFolder)
                                #if os(iOS)
                                .autocorrectionDisabled()
                                #endif
                        }.listRowBackground(Theme.bgElev)

                        Section("Soulseek (slskd)") {
                            Toggle("Enabled", isOn: $slskdEnabled)
                            TextField("slskd URL", text: $slskdURL)
                                #if os(iOS)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                #endif
                            SecureField(keyPlaceholder, text: $slskdKey)
                            TextField("Download directory", text: $slskdDir)
                                #if os(iOS)
                                .autocorrectionDisabled()
                                #endif
                            Button(testing ? "Testing…" : "Test connection") { test() }
                                .disabled(testing)
                            if let testMessage {
                                Text(testMessage).font(Theme.body(13)).foregroundStyle(Theme.textDim)
                            }
                        }.listRowBackground(Theme.bgElev)
                    }
                }
                .hideScrollBackground()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { save() }.disabled(saving || !loaded)
                }
            }
        }
        .musicarrScreen()
        .task { await reload() }
    }

    private var keyPlaceholder: String {
        if let s = settings, s.slskd_api_key_set { return s.slskd_api_key_hint.map { "API key (\($0))" } ?? "API key (set)" }
        return "API key"
    }

    private func reload() async {
        if let s = try? await app.settings() {
            settings = s
            rootFolder = s.root_folder ?? ""
            slskdURL = s.slskd_url ?? ""
            slskdDir = s.slskd_download_dir ?? ""
            slskdEnabled = s.slskd_enabled
        }
        loaded = true
    }

    private func save() {
        saving = true
        var d: [String: Encodable] = [
            "root_folder": rootFolder,
            "slskd_url": slskdURL,
            "slskd_download_dir": slskdDir,
            "slskd_enabled": slskdEnabled
        ]
        // Only send the key if the admin typed a new one.
        if !slskdKey.isEmpty { d["slskd_api_key"] = slskdKey }
        Task {
            try? await app.updateSettings(JSONBody(d))
            slskdKey = ""
            await reload()
            saving = false
        }
    }

    private func test() {
        testing = true; testMessage = nil
        Task {
            let result = try? await app.testSettings(
                section: "slskd",
                slskdURL: slskdURL.isEmpty ? nil : slskdURL,
                slskdKey: slskdKey.isEmpty ? nil : slskdKey)
            if let r = result {
                testMessage = r.ok ? (r.message ?? "Connection OK") : (r.error ?? r.message ?? "Connection failed")
            } else {
                testMessage = "Test failed"
            }
            testing = false
        }
    }
}
