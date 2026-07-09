# JeevVPN — Android app

A custom-built JeevVPN Android client (Flutter). Built in the cloud via GitHub Actions.

## Roadmap
- ✅ **v1 — custom UI shell**: JeevVPN home + connect orb, light/dark. *(connect is a UI preview for now)*
- ⏳ **v2 — login**: sign in with your JeevVPN (Supabase) account; admins + members, no in-app signup.
- ⏳ **v3 — real VPN engine**: tap connect → tunnels all traffic through your server (no config import).

## Getting the APK
Every push to `main` runs **Actions → Build JeevVPN APK**. Open the latest run → **Artifacts → JeevVPN-apk** → download → install on Android.

The `android/` scaffold is generated during the build, so the repo stays tiny — the app lives in `lib/`.
