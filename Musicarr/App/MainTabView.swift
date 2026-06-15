import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var player: PlayerManager
    @State private var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                stack { HomeView() }
                    .tabItem { Label("Home", systemImage: "house.fill") }

                stack { SearchView() }
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                stack { ExploreView() }
                    .tabItem { Label("Explore", systemImage: "safari") }

                stack { LibraryView() }
                    .tabItem { Label("Library", systemImage: "square.stack.fill") }

                stack { DownloadsView() }
                    .tabItem { Label("Downloads", systemImage: "arrow.down.circle.fill") }
            }
            .tint(Theme.accent)

            if player.current != nil {
                MiniPlayerBar { showNowPlaying = true }
                    #if os(iOS)
                    .padding(.bottom, 49) // sit above the tab bar
                    #endif
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
                .musicarrScreen()
        }
    }

    @ViewBuilder private func stack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .musicarrDestinations()
                .background(PageBackground())
        }
    }
}
