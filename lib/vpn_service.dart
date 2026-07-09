import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'server_model.dart';

enum VpnStatus { disconnected, connecting, connected }

/// The tunnel controller.
///
/// Nodes with a real endpoint ([ServerModel.canTunnel]) route ALL device
/// traffic through a real VPN via flutter_v2ray (Xray) → our sing-box Trojan
/// server. Nodes without one (not yet provisioned) fall back to a simulated
/// preview so the UI stays alive.
class VpnService extends ChangeNotifier {
  final Random _rng = Random();
  late final FlutterV2ray _v2ray =
      FlutterV2ray(onStatusChanged: _onEngineStatus);
  bool _engineInit = false;
  bool _real = false; // is the current session a real tunnel?

  VpnStatus status = VpnStatus.disconnected;
  ServerModel? activeServer;
  String? errorText;

  Duration elapsed = Duration.zero;
  double downMb = 0, upMb = 0; // cumulative this session
  double downRate = 0, upRate = 0; // Mbps
  int livePing = 16;
  final List<double> spark = List<double>.filled(52, 0.0);

  int _gen = 0;
  Timer? _tick;

  bool get isConnected => status == VpnStatus.connected;
  bool get isBusy => status == VpnStatus.connecting;

  Future<void> toggle(ServerModel server) async {
    if (status == VpnStatus.disconnected) {
      await connect(server);
    } else {
      await disconnect();
    }
  }

  Future<void> connect(ServerModel server) async {
    activeServer = server;
    errorText = null;
    if (server.canTunnel) {
      await _connectReal(server);
    } else {
      await _connectSimulated(server);
    }
  }

  // ── real tunnel (flutter_v2ray / Xray → sing-box Trojan) ──────────────────
  Future<void> _connectReal(ServerModel server) async {
    final g = ++_gen;
    _real = true;
    status = VpnStatus.connecting;
    notifyListeners();
    try {
      if (!_engineInit) {
        await _v2ray.initializeV2Ray();
        _engineInit = true;
      }
      final granted = await _v2ray.requestPermission();
      if (!granted) {
        if (g == _gen) {
          _real = false;
          status = VpnStatus.disconnected;
          errorText = 'VPN permission denied.';
          notifyListeners();
        }
        return;
      }
      if (g != _gen) return;
      final parser = FlutterV2ray.parseFromURL(server.shareLink);
      await _v2ray.startV2Ray(
        remark: 'JeevVPN · ${server.name}',
        config: parser.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );
      // Connection state now arrives through _onEngineStatus.
    } catch (e) {
      if (g == _gen) {
        _real = false;
        status = VpnStatus.disconnected;
        errorText = 'Could not start the tunnel. $e';
        notifyListeners();
      }
    }
  }

  void _onEngineStatus(V2RayStatus s) {
    if (!_real) return; // ignore stray callbacks during simulated sessions
    final st = s.state.toUpperCase();
    if (st.contains('CONNECTED')) {
      status = VpnStatus.connected;
    } else if (st.contains('CONNECTING')) {
      status = VpnStatus.connecting;
    } else {
      status = VpnStatus.disconnected;
    }
    elapsed = _parseDuration(s.duration);
    downRate = s.downloadSpeed * 8 / 1000000.0; // bytes/s → Mbps
    upRate = s.uploadSpeed * 8 / 1000000.0;
    downMb = s.download / 1048576.0;
    upMb = s.upload / 1048576.0;
    livePing = activeServer?.ping ?? livePing;
    spark.removeAt(0);
    spark.add((downRate / 68.0).clamp(0.0, 1.0));
    notifyListeners();
  }

  Duration _parseDuration(String d) {
    final p = d.split(':');
    if (p.length != 3) return Duration.zero;
    return Duration(
      hours: int.tryParse(p[0]) ?? 0,
      minutes: int.tryParse(p[1]) ?? 0,
      seconds: int.tryParse(p[2]) ?? 0,
    );
  }

  // ── simulated preview (nodes without a real endpoint) ─────────────────────
  Future<void> _connectSimulated(ServerModel server) async {
    final g = ++_gen;
    _real = false;
    status = VpnStatus.connecting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (g != _gen) return;
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

  void _onTick() {
    elapsed += const Duration(seconds: 1);
    final base = activeServer?.ping ?? 16;
    downRate = 6 + _rng.nextDouble() * 58;
    upRate = 1 + _rng.nextDouble() * 11;
    downMb += downRate / 8.0;
    upMb += upRate / 8.0;
    livePing = (base + _rng.nextInt(7) - 3).clamp(4, 999);
    spark.removeAt(0);
    spark.add((downRate / 68.0).clamp(0.02, 1.0));
    notifyListeners();
  }

  Future<void> disconnect() async {
    _gen++;
    _tick?.cancel();
    _tick = null;
    if (_real) {
      try {
        await _v2ray.stopV2Ray();
      } catch (_) {}
      _real = false;
    }
    status = VpnStatus.disconnected;
    downRate = 0;
    upRate = 0;
    notifyListeners();
  }

  /// If connected and the location changes, hop to it.
  Future<void> switchTo(ServerModel server) async {
    if (!isConnected) {
      activeServer = server;
      return;
    }
    await disconnect();
    await connect(server);
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
    super.dispose();
  }
}
