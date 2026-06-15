import SwiftUI

// Cross-platform shims so the same SwiftUI code builds for both iOS (iPhone) and
// tvOS (Apple TV), where a handful of modifiers differ or don't exist.

extension View {
    /// Segmented control on iOS; the default (menu/inline) style on tvOS, where
    /// `.segmented` isn't available.
    @ViewBuilder func musicarrSegmented() -> some View {
        #if os(tvOS)
        self.pickerStyle(.automatic)
        #else
        self.pickerStyle(.segmented)
        #endif
    }

    /// Hide the default list/scroll background on iOS (the modifier is
    /// unavailable on tvOS, where lists are already transparent over our bg).
    @ViewBuilder func hideScrollBackground() -> some View {
        #if os(iOS)
        self.scrollContentBackground(.hidden)
        #else
        self
        #endif
    }

    /// Pull-to-refresh on iOS only (unsupported on tvOS).
    @ViewBuilder func musicarrRefreshable(_ action: @escaping () async -> Void) -> some View {
        #if os(iOS)
        self.refreshable { await action() }
        #else
        self
        #endif
    }

    /// Consistent dark text-field chrome that works on both iOS and tvOS
    /// (the built-in `.plain` / `.roundedBorder` styles aren't available on tvOS).
    func musicarrField() -> some View {
        self
            .padding(13)
            .background(Theme.bgElev2)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .foregroundStyle(Theme.text)
            .autocorrectionDisabled()
    }

    /// A trailing destructive "Remove" swipe action on iOS; a no-op on tvOS,
    /// where the same action stays reachable from the context menu.
    @ViewBuilder func removeSwipe(_ action: @escaping () -> Void) -> some View {
        #if os(iOS)
        self.swipeActions(edge: .trailing) {
            Button(role: .destructive, action: action) { Label("Remove", systemImage: "trash") }
        }
        #else
        self
        #endif
    }
}
