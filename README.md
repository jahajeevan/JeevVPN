# JeevVPN — Android app

A custom-built JeevVPN Android client (Flutter). Built in the cloud via GitHub Actions.

## Roadmap
- ✅ **v1 — custom UI shell**: JeevVPN home + connect orb, light/dark. *(connect was a UI preview)*
- ✅ **v1.1 — UI overhaul**: multi-screen app (Home · Servers · Profile · Settings), custom-painted connect orb, animated aurora background, glass bottom-nav, live throughput sparkline, animated switches/segments.
- ✅ **v2 — multi-server + real login**: two Azure locations (🇮🇳 India·Pune, 🇰🇷 Korea Central), anti-spam server switching (2 switches → 40s cooldown with live countdown), Recommended-Usage guidance, home "Current Server" card + duration + up/down indicators, and **real email-OTP sign in** (backend `/api/otp/*` on the Vercel app sends the code via Gmail SMTP — creds never ship in the APK). Service layer: `server_model.dart`, `server_manager.dart`, `vpn_service.dart`, `otp_service.dart`. *(connect is still simulated until v3)*
- ⏳ **v3 — real VPN engine**: tap connect → tunnels all traffic through your server (no config import).

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
Every push to `main` runs **Actions → Build JeevVPN APK**. Open the latest run → **Artifacts → JeevVPN-apk** → download → install on Android.
