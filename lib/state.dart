import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum VpnStatus { disconnected, connecting, connected }

class ServerNode {
  final String id;
  final String city;
  final String country;
  final String flag;
  final int ping; // ms
  final double load; // 0..1
  final bool available;
  const ServerNode({
    required this.id,
    required this.city,
    required this.country,
    required this.flag,
    required this.ping,
    required this.load,
    this.available = false,
  });
}

/// Only the India node is a real JeevVPN server (52.140.121.205). The others
/// are shown as upcoming locations and are not selectable yet.
const List<ServerNode> kServers = [
  ServerNode(
      id: 'in-mum',
      city: 'Mumbai',
      country: 'India',
      flag: '🇮🇳',
      ping: 16,
      load: 0.28,
      available: true),
  ServerNode(
      id: 'sg',
      city: 'Singapore',
      country: 'Singapore',
      flag: '🇸🇬',
      ping: 62,
      load: 0.41),
  ServerNode(
      id: 'de',
      city: 'Frankfurt',
      country: 'Germany',
      flag: '🇩🇪',
      ping: 138,
      load: 0.34),
  ServerNode(
      id: 'uk',
      city: 'London',
      country: 'United Kingdom',
      flag: '🇬🇧',
      ping: 142,
      load: 0.30),
  ServerNode(
      id: 'jp',
      city: 'Tokyo',
      country: 'Japan',
      flag: '🇯🇵',
      ping: 98,
      load: 0.38),
  ServerNode(
      id: 'us',
      city: 'New York',
      country: 'United States',
      flag: '🇺🇸',
      ping: 214,
      load: 0.22),
];

/// Central app state. Connect is still a **preview** (simulated) — real
/// tunnelling lands in v3. Everything else (settings, theme, selection,
/// live-metric animation) is real.
class AppState extends ChangeNotifier {
  final Random _rng = Random();
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  VpnStatus status = VpnStatus.disconnected;
  ServerNode server = kServers.first;

  // settings
  bool killSwitch = true;
  bool autoConnect = false;
  bool blockQuic = true; // reject UDP/QUIC — matches the real server config
  bool protectedNotif = true;
  bool haptics = true;

  // live session
  Duration elapsed = Duration.zero;
  double downMb = 0, upMb = 0; // cumulative this session
  double downRate = 0, upRate = 0; // Mbps
  int livePing = 16;
  final List<double> spark = List<double>.filled(52, 0.0);

  int _gen = 0;
  Timer? _tick;

  bool get isConnected => status == VpnStatus.connected;
  bool get isBusy => status == VpnStatus.connecting;

  Future<void> toggle() async {
    if (status == VpnStatus.disconnected) {
      await _connect();
    } else {
      _disconnect();
    }
  }

  Future<void> _connect() async {
    final g = ++_gen;
    status = VpnStatus.connecting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (g != _gen) return; // cancelled while connecting
    status = VpnStatus.connected;
    elapsed = Duration.zero;
    downMb = 0;
    upMb = 0;
    livePing = server.ping;
    for (int i = 0; i < spark.length; i++) {
      spark[i] = 0;
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    notifyListeners();
  }

  void _disconnect() {
    _gen++;
    _tick?.cancel();
    _tick = null;
    status = VpnStatus.disconnected;
    downRate = 0;
    upRate = 0;
    notifyListeners();
  }

  void _onTick() {
    elapsed += const Duration(seconds: 1);
    downRate = 6 + _rng.nextDouble() * 58;
    upRate = 1 + _rng.nextDouble() * 11;
    downMb += downRate / 8.0;
    upMb += upRate / 8.0;
    livePing = (server.ping + _rng.nextInt(7) - 3).clamp(4, 999);
    spark.removeAt(0);
    spark.add((downRate / 68.0).clamp(0.02, 1.0));
    notifyListeners();
  }

  void selectServer(ServerNode s) {
    if (!s.available) return;
    server = s;
    if (isConnected) livePing = s.ping;
    notifyListeners();
  }

  void setTheme(ThemeMode m) => themeMode.value = m;

  void toggleThemeQuick(bool currentlyDark) {
    themeMode.value = currentlyDark ? ThemeMode.light : ThemeMode.dark;
  }

  void update(
      {bool? kill, bool? auto, bool? quic, bool? notif, bool? haptic}) {
    if (kill != null) killSwitch = kill;
    if (auto != null) autoConnect = auto;
    if (quic != null) blockQuic = quic;
    if (notif != null) protectedNotif = notif;
    if (haptic != null) haptics = haptic;
    notifyListeners();
  }

  String get clock {
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _tick?.cancel();
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
