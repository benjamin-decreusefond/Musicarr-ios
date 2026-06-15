# Deploying Musicarr (iOS & tvOS)

Everything here needs a **Mac with Xcode 15+**. Beyond running on your own
device you also need an **Apple ID**; for over‑the‑air installs (TestFlight) or
the App Store you need the paid **Apple Developer Program** ($99/yr).

---

## 1. One‑time project setup

1. Clone and open the project:
   ```bash
   git clone https://github.com/benjamin-decreusefond/Musicarr-ios.git
   cd Musicarr-ios
   open Musicarr.xcodeproj
   ```
2. For **each** target (`Musicarr` and `Musicarr-tvOS`) → **Signing & Capabilities**:
   - Tick **Automatically manage signing**.
   - Pick your **Team** (your Apple ID or org).
   - If Xcode reports the bundle id is taken, change **Bundle Identifier** to
     something unique to you, e.g. `com.yourname.musicarr` (and `.tv` for tvOS).
     The two targets must have **different** ids.
3. Build settings already configured in the repo:
   - iOS deployment target **16.0**, tvOS **17.0**.
   - Background audio (`UIBackgroundModes: audio`).
   - App Transport Security allows arbitrary loads (so a self‑hosted HTTP server
     on your LAN works — use HTTPS in production).

---

## 2. Run on your own device (free, fastest)

Good for personal use and quick testing.

1. Plug in your iPhone (or pair an Apple TV via **Xcode → Window → Devices and
   Simulators**).
2. Select the **Musicarr** scheme and your device, press **▶**.
3. On the device: **Settings → General → VPN & Device Management** → trust your
   developer certificate.
4. Launch the app, enter your server URL (e.g. `https://musicarr.bigbossben.ovh`)
   and sign in.

> ⚠️ With a **free** Apple ID the app signature **expires after 7 days** and you
> must re‑deploy from Xcode. A paid account raises this to a year.

---

## 3. TestFlight (recommended for ongoing use + Apple TV)

Over‑the‑air installs for you and anyone you invite — no cable, and it covers
Apple TV cleanly.

1. In **App Store Connect** (appstoreconnect.apple.com) create a new app record;
   reuse the bundle id from step 1. The iOS and tvOS builds live under the same
   app record.
2. In Xcode: select **Any iOS Device (arm64)** (and later **Any tvOS Device**),
   then **Product → Archive**.
3. In the Organizer that opens: **Distribute App → TestFlight (App Store Connect)**
   and upload.
4. Back in App Store Connect → **TestFlight**: add yourself/others as testers.
   Internal testers get builds with no review; builds are valid for 90 days.

---

## 4. App Store (public)

Same **Archive → Distribute** flow, choosing **App Store Connect → Upload**, then
submit for review.

> ⚠️ Because Musicarr's server sources audio from the Soulseek network, App
> Review may raise copyright questions even though this app is only a *client* of
> your own server. TestFlight (section 3) sidesteps that and is the practical
> route for a personal/self‑hosted client.

---

## App icons

- **iOS:** a 1024×1024 icon is included (`Assets.xcassets/AppIcon`). Regenerate or
  tweak it with:
  ```bash
  python3 scripts/generate_appicon.py
  ```
- **tvOS:** the App Store / TestFlight requires a **layered Brand Assets** icon
  (App Icon + Top Shelf image) that can't be a single flat PNG. To add it in
  Xcode: select the asset catalog → **+ → tvOS → New tvOS Brand Assets**, drop in
  layered artwork (front/back layers at 400×240 and 1280×768), then set the
  tvOS target's **Asset Catalog App Icon Set Name** to it. tvOS dev builds run
  without this; it's only needed for distribution.

---

## Updating the server URL

The server URL is entered on the sign‑in screen and stored on device — no rebuild
needed to point the app at a different Musicarr server.
