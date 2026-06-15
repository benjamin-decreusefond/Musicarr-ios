import SwiftUI

struct LoginView: View {
    var showOfflineOption: Bool = false

    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var library: LibraryStore
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var enterOffline = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x1A1D2B), Theme.bg],
                           center: .top, startRadius: 0, endRadius: 700)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                BrandMark(size: 30)
                Text("Your music, your server.")
                    .font(Theme.body(14)).foregroundStyle(Theme.textDim)

                VStack(spacing: 12) {
                    field("Server URL", text: $server, placeholder: "https://musicarr.example.com")
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    field("Username", text: $username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    secureField("Password", text: $password)
                }

                if let error {
                    Text(error).font(Theme.body(13)).foregroundStyle(Theme.danger)
                }

                Button(action: submit) {
                    Text(busy ? "Signing in…" : "Sign in")
                        .font(Theme.body(15, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.accent).foregroundStyle(Theme.accentInk)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(busy)

                if showOfflineOption {
                    Button("Continue offline") { enterOffline = true }
                        .font(Theme.body(13, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                }
            }
            .padding(34)
            .frame(maxWidth: 420)
            .background(Theme.bgElev)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding()
        }
        .onAppear { if server.isEmpty { server = app.serverURLString } }
        .fullScreenCover(isPresented: $enterOffline) {
            OfflineOnlyView().musicarrScreen()
        }
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String = "") -> some View {
        TextField(placeholder.isEmpty ? title : placeholder, text: text)
            .musicarrField()
    }

    private func secureField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .musicarrField()
    }

    private func submit() {
        error = nil
        guard app.setServer(server) else { error = "Enter a valid server URL"; return }
        guard !username.isEmpty, !password.isEmpty else { error = "Enter your username and password"; return }
        busy = true
        Task {
            do {
                try await app.login(username: username, password: password)
                await library.refresh()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            busy = false
        }
    }
}

/// The acid-lime square logo used across the app.
struct BrandMark: View {
    var size: CGFloat = 22
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Theme.accent)
                    .frame(width: size * 0.9, height: size * 0.9)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 8)
                RoundedRectangle(cornerRadius: 1).fill(Theme.accentInk)
                    .frame(width: size * 0.28, height: size * 0.42)
            }
            Text("Musicarr").font(Theme.display(size, weight: .bold)).foregroundStyle(Theme.text)
        }
    }
}

struct ChangePasswordView: View {
    var forced = false
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var next = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 14) {
                BrandMark(size: 26)
                Text(forced ? "Choose a new password to continue" : "Change password")
                    .font(Theme.body(14)).foregroundStyle(Theme.textDim)
                SecureField("Current password", text: $current).musicarrField()
                SecureField("New password", text: $next).musicarrField()
                SecureField("Confirm new password", text: $confirm).musicarrField()
                if let error { Text(error).foregroundStyle(Theme.danger).font(Theme.body(13)) }
                PrimaryButton(title: busy ? "Saving…" : "Set password", action: submit)
            }
            .frame(maxWidth: 380)
            .padding(30)
        }
    }

    private func submit() {
        error = nil
        guard next.count >= 8 else { error = "New password must be at least 8 characters"; return }
        guard next == confirm else { error = "Passwords do not match"; return }
        busy = true
        Task {
            do { try await app.changePassword(current: current, next: next); if !forced { dismiss() } }
            catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
            busy = false
        }
    }
}
