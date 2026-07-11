/// Backend base URL — the JeevVPN web app on Vercel.
///
/// Email-OTP send/verify live here (server-side) so the Gmail credentials that
/// actually send the mail never ship inside the APK.
const String kApiBase = 'https://jeevvpn.vercel.app';

/// This build's version. [kVersionCode] MUST be bumped every release and match
/// the `+N` build number in pubspec.yaml — the in-app updater compares it
/// against the manifest at [kVersionManifestUrl] to decide if a newer APK
/// exists.
const int kVersionCode = 12;
const String kVersionName = '3.5.0';

/// Update manifest (JSON). Shape:
/// { "versionCode": 12, "versionName": "3.5.0", "apkUrl": "...",
///   "notes": "…", "mandatory": false }
///
/// Served from the latest GitHub Release so the whole update flow is
/// self-contained (CI attaches both the APK and this manifest to each release —
/// no separate site deploy needed). `releases/latest/download/<asset>` always
/// resolves to the newest published release.
const String kGithubRepo = 'jahajeevan/JeevVPN';
const String kVersionManifestUrl =
    'https://github.com/$kGithubRepo/releases/latest/download/app-version.json';
