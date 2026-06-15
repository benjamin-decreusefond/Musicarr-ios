# Musicarr for iOS & Apple TV

A native **SwiftUI** client for a [Musicarr](https://github.com/benjamin-decreusefond/musicarr)
server, built to mirror the Musicarr web interface. It runs on **iPhone/iPad
(iOS 16+)** and **Apple TV (tvOS 16+)** from a single shared codebase.

The app is **purely a client** of your Musicarr server:

- It talks only to the Musicarr REST API — it never calls Deezer, Soulseek/slskd,
  or any other external service directly. All search, browse, artwork and
  download orchestration happens on the server, exactly like the web UI.
- Audio is streamed from the server's `/api/stream/:id` endpoint (HTTP range, so
  seeking works) using your authenticated session cookie.
- A **Download for later** feature saves tracks to the device so they play
  offline when the server is unreachable.

## Features

| Area | What's included |
|---|---|
| **Auth** | Server URL + username/password sign-in. Cookie session (same scheme as the web app). Forced password change on first admin login. |
| **Home** | Trending tracks, popular albums, artists and featured playlists. |
| **Search** | Live search across artists, albums and tracks. |
| **Explore** | Moods and genres (cover-art cards), new releases, top playlists/artists. |
| **Artist / Album** | Full detail pages with play, per-track actions, related artists. |
| **Library** | On-disk songs, artists, playlists, liked songs and history. |
| **Playlists** | Create, view, add/remove tracks, delete; import Deezer playlists (server-side). |
| **Downloads** | Two tabs — *On this device* (offline files) and *Server queue* (live Soulseek fetch progress). |
| **Player** | AVPlayer streaming, queue with reorder, repeat modes, lock-screen / Siri Remote controls (`MPNowPlayingInfoCenter`), time-synced **lyrics**. |
| **Offline** | "Download for offline" on any playable track; offline-only mode when the server can't be reached. |

## Project layout

```
Musicarr/
  App/            App entry, root routing, tab navigation
  Theme/          Colors/typography (ported from the web CSS vars) + platform shims
  Models/         Codable models matching the Musicarr API wire shapes
  Networking/     APIClient (cookie session), AppState (endpoints), LibraryStore
  Offline/        DownloadManager + URLSession download engine (offline audio)
  Player/         PlayerManager (AVPlayer, now-playing, queue, remote commands)
  Views/          SwiftUI screens + reusable components
  Resources/      Assets.xcassets, Info-iOS.plist, Info-tvOS.plist
```

## Building

Open **`Musicarr.xcodeproj`** in Xcode 15+ and pick a scheme:

- **Musicarr** → iPhone / iPad
- **Musicarr-tvOS** → Apple TV

Set your signing team on each target (Signing & Capabilities) and run.

> The two targets share every Swift source file; only the `Info.plist`, bundle id
> and device family differ.

### Regenerating the project

The Xcode project is committed so it opens without extra tooling. If you add or
remove source files, regenerate it with either:

```bash
python3 scripts/generate_xcodeproj.py     # no dependencies
# or
xcodegen generate                         # uses project.yml
```

## Configuration notes

- **Server URL** is entered on the sign-in screen and saved on device. Both
  `http://` and `https://` are supported (App Transport Security allows arbitrary
  loads so self-hosted HTTP servers on a LAN work; put the server behind HTTPS in
  production).
- **Background audio** is enabled (`UIBackgroundModes: audio`) so playback
  continues when the app is backgrounded.
- Offline downloads live in the app's Documents directory with a small JSON index
  (`Offline/index.json`); removing a download deletes its audio file.

## Requirements

- Xcode 15+
- iOS 16+ / tvOS 16+
- A reachable Musicarr server (e.g. `https://musicarr.example.com`)
