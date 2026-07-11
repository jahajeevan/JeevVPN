import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'server_manager.dart';
import 'vpn_service.dart';
import 'update_service.dart';

/// Top-level app state. Composes the [ServerManager] and [VpnService] services
/// (so the rules live outside the UI) and adds theme, settings and auth.
/// Re-emits their notifications so a single [AppScope] drives every rebuild.
class AppState extends ChangeNotifier {
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  final ServerManager servers = ServerManager();
  final VpnService vpn = VpnService();

  // settings
  bool killSwitch = true;
  bool autoConnect = false;
  bool blockQuic = true; // reject UDP/QUIC — matches the real server config
  bool protectedNotif = true;
  bool haptics = true;

  // auth (set after sign in / sign up, persisted across launches)
  static const String _kEmailKey = 'jeev_signed_in_email';
  static const String _kNameKey = 'jeev_name';
  static const String _kAgeKey = 'jeev_age';
  static const String _kAvatarKey = 'jeev_avatar'; // base64 of a small JPEG
  String? signedInEmail;
  String? signedInName;
  int? signedInAge;
  Uint8List? avatarBytes; // profile photo, null = use the default avatar
  bool authReady = false; // true once the stored session has been loaded
  bool get isSignedIn => signedInEmail != null;
  bool get hasAvatar => avatarBytes != null;

  // in-app updates
  UpdateInfo? availableUpdate; // non-null when a newer APK is available
  bool updateDismissed = false;
  bool get showUpdateBanner => availableUpdate != null && !updateDismissed;

  AppState() {
    servers.addListener(notifyListeners);
    vpn.addListener(notifyListeners);
    _boot();
  }

  Future<void> _boot() async {
    await _loadSession();
    await servers.restore(); // last selected location
    vpn.activeServer = servers.current;
    // Attach the engine listener now, so if Android kept the tunnel alive
    // while the app was killed, reopening re-syncs the UI to "connected".
    await vpn.init();
    servers.measureAll(); // real latency to each node
    checkUpdate();
  }

  /// Checks the site for a newer version. Returns true if one was found.
  Future<bool> checkUpdate() async {
    final found = await UpdateService.check();
    if (found != null) {
      availableUpdate = found;
      updateDismissed = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  void dismissUpdate() {
    updateDismissed = true;
    notifyListeners();
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kEmailKey);
      if (saved != null && saved.isNotEmpty) {
        signedInEmail = saved;
        signedInName = prefs.getString(_kNameKey);
        signedInAge = prefs.getInt(_kAgeKey);
        final avatar = prefs.getString(_kAvatarKey);
        if (avatar != null && avatar.isNotEmpty) {
          try {
            avatarBytes = base64Decode(avatar);
          } catch (_) {}
        }
      }
    } catch (_) {
      // ignore — start signed out
    }
    authReady = true;
    notifyListeners();
  }

  /// Set (or replace) the profile photo. Pass null to keep the current one;
  /// use [clearAvatar] to remove it.
  Future<void> setAvatar(Uint8List bytes) async {
    avatarBytes = bytes;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAvatarKey, base64Encode(bytes));
    } catch (_) {}
  }

  Future<void> clearAvatar() async {
    avatarBytes = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAvatarKey);
    } catch (_) {}
  }

  /// Connect / disconnect using the currently selected location.
  Future<void> toggleConnection() =>
      vpn.toggle(servers.current, blockQuic: blockQuic);

  Future<void> signIn(String email, {String? name, int? age}) async {
    signedInEmail = email.trim();
    signedInName = (name != null && name.trim().isNotEmpty) ? name.trim() : null;
    signedInAge = age;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kEmailKey, signedInEmail!);
      if (signedInName != null) {
        await prefs.setString(_kNameKey, signedInName!);
      } else {
        await prefs.remove(_kNameKey);
      }
      if (signedInAge != null) {
        await prefs.setInt(_kAgeKey, signedInAge!);
      } else {
        await prefs.remove(_kAgeKey);
      }
    } catch (_) {}
  }

  Future<void> signOut() async {
    // Drop any live tunnel before returning to the gate.
    if (vpn.status != VpnStatus.disconnected) vpn.disconnect();
    signedInEmail = null;
    signedInName = null;
    signedInAge = null;
    avatarBytes = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kEmailKey);
      await prefs.remove(_kNameKey);
      await prefs.remove(_kAgeKey);
      await prefs.remove(_kAvatarKey);
    } catch (_) {}
  }

  void setTheme(ThemeMode m) => themeMode.value = m;

  void toggleThemeQuick(bool currentlyDark) {
    themeMode.value = currentlyDark ? ThemeMode.light : ThemeMode.dark;
  }

  void update(
      {bool? kill, bool? auto, bool? quic, bool? notif, bool? haptic}) {
    if (kill != null) killSwitch = kill;
    if (auto != null) autoConnect = auto;
    final quicChanged = quic != null && quic != blockQuic;
    if (quic != null) blockQuic = quic;
    if (notif != null) protectedNotif = notif;
    if (haptic != null) haptics = haptic;
    notifyListeners();
    // QUIC blocking is baked into the tunnel config, so re-apply it live.
    if (quicChanged && vpn.isConnected) {
      vpn.switchTo(servers.current, blockQuic: blockQuic);
    }
  }

  @override
  void dispose() {
    servers.removeListener(notifyListeners);
    vpn.removeListener(notifyListeners);
    servers.dispose();
    vpn.dispose();
    themeMode.dispose();
    super.dispose();
  }
}

/// Provides [AppState] to the tree and rebuilds dependents on notify.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState notifier, required Widget child})
      : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
