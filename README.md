# JeevVPN — Android app

A custom-built JeevVPN Android client (Flutter). Built in the cloud via GitHub Actions.

## Roadmap
- ✅ **v1 — custom UI shell**: JeevVPN home + connect orb, light/dark. *(connect was a UI preview)*
- ✅ **v1.1 — UI overhaul**: multi-screen app (Home · Servers · Profile · Settings), custom-painted connect orb, animated aurora background, glass bottom-nav, live throughput sparkline, animated switches/segments.
- ✅ **v2 — multi-server + real login**: two Azure locations (🇮🇳 India·Pune, 🇰🇷 Korea Central), anti-spam server switching (2 switches → 40s cooldown with live countdown), Recommended-Usage guidance, home "Current Server" card + duration + up/down indicators, and **real email-OTP sign in** (backend `/api/otp/*` on the Vercel app sends the code via Gmail SMTP — creds never ship in the APK). Service layer: `server_model.dart`, `server_manager.dart`, `vpn_service.dart`, `otp_service.dart`. *(connect is still simulated until v3)*
- ✅ **v3 — real VPN engine**: tap connect → tunnels all traffic through your server (no config import).
- ✅ **v3.5 — strong connections + profile photo + self-updating**:
  - **Reliable tunnel**: fixed "connected but nothing loads". The exit server now resolves DNS (`routing.domainStrategy: AsIs`), the proxy outbound is detected by protocol (no more traffic sent into a black hole), and **QUIC (UDP/443) is blocked** so Chrome/YouTube fall back to dependable TCP. IPv4-only + LAN-direct kill the IPv6 black-hole. See `vpn_service.dart` → `_buildConfig`.
  - **Profile photo**: pick from gallery or camera (`image_picker`), stored on-device and shown on Profile + Home.
  - **In-app updates, self-contained**: each CI build publishes a **GitHub Release** with `JeevVPN.apk` + `app-version.json`. The app polls the latest release's manifest and shows a "What's new" sheet with the feature list, then downloads the new build — no separate installer to hand around.

## Structure
The app lives in `lib/` (the `android/` scaffold is generated during the build, so the repo stays tiny):

| file | purpose |
|------|---------|
| `main.dart` | app entry, theme wiring, root shell + glass bottom-nav |
| `theme.dart` | brand palette, theme builder, font helpers |
| `state.dart` | `AppState` (connection/session/settings) + `AppScope` provider |
| `orb.dart` | the animated connect orb (CustomPainter) |
| `background.dart` | drifting aurora background (CustomPainter) |
| `widgets.dart` | glass card, switches, segmented control, sparkline, OTP boxes |
| `home.dart` / `servers.dart` / `profile.dart` / `settings.dart` | the four screens |

## Getting the APK
Every push to `main` runs **Actions → Build JeevVPN APK**, which:
1. builds the signed arm64 release APK, and
2. publishes it as a **GitHub Release** together with `app-version.json` (the update manifest).

Install options:
- **First install / share**: grab `JeevVPN.apk` from the newest [Release](https://github.com/jahajeevan/JeevVPN/releases/latest) (public link: `releases/latest/download/JeevVPN.apk`). The CI run also keeps it under **Artifacts → JeevVPN-apk**.
- **Already have the app**: it checks the latest release on launch and shows an **Update available** banner with the changelog — download from there.

## Cutting a release
1. Bump `version:` in `pubspec.yaml` **and** `kVersionCode` / `kVersionName` in `lib/config.dart` (keep them in sync).
2. Edit `app-version.json` — set `versionCode`, `versionName`, and the `notes` (one feature per line; each line becomes a bullet in the in-app "What's new" sheet). Set `"mandatory": true` for a forced update.
3. Push to `main`. CI builds the APK and publishes the release with both files attached.

> **Migrating existing v3.4.2 installs (one-time):** builds up to v3.4.2 poll `jeevvpn.vercel.app/app-version.json`. To push those users to v3.5.0, update that file on the Vercel project once with the same contents as this repo's `app-version.json`. From v3.5.0 onward the app reads the GitHub release manifest, so no site deploy is ever needed again.
