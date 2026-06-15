import SwiftUI

/// Loads async data once (and on explicit refresh), rendering a spinner, an
/// error, or the content. Keeps the data screens free of repetitive state.
struct AsyncContent<T, Content: View>: View {
    let load: () async throws -> T
    @ViewBuilder let content: (T) -> Content

    @State private var value: T?
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        Group {
            if let value {
                content(value)
            } else if let error {
                StateText(text: error, error: true)
            } else {
                ProgressView().tint(Theme.accent)
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
            }
        }
        .task { if value == nil { await run() } }
        .musicarrRefreshable { await run() }
    }

    private func run() async {
        loading = true; defer { loading = false }
        do { value = try await load(); error = nil }
        catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
