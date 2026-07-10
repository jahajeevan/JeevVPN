/// Backend base URL — the JeevVPN web app on Vercel.
///
/// Email-OTP send/verify live here (server-side) so the Gmail credentials that
/// actually send the mail never ship inside the APK.
const String kApiBase = 'https://jeevvpn.vercel.app';

/// This build's version. [kVersionCode] MUST be bumped every release and match
/// the `+N` build number in pubspec.yaml — the in-app updater compares it
/// against the manifest at [kVersionManifestUrl] to decide if a newer APK
/// exists.
const int kVersionCode = 11;
const String kVersionName = '3.4.2';

/// Update manifest (JSON) hosted on the site. Shape:
/// { "versionCode": 9, "versionName": "3.4.0", "apkUrl": "...",
///   "notes": "…", "mandatory": false }
const String kVersionManifestUrl = '$kApiBase/app-version.json';
