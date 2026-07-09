import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'server_model.dart';

enum VpnStatus { disconnected, connecting, connected }

/// The tunnel controller. Today the tunnel is **simulated** (a preview) — the
/// timers, throughput and counters are real animations driven off a ticker.
///
/// v3 replaces [_openTunnel]/[_closeTunnel] with a real Android VpnService that
/// routes traffic to [ServerModel.host]:[ServerModel.port] over TLS. The rest
/// of the surface (status, session timer, up/down indicators) stays the same,
/// which is why the UI already binds to it.
class VpnService extends ChangeNotifier {
  final Random _rng = Random();

  VpnStatus status = VpnStatus.disconnected;
  ServerModel? activeServer;

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
      disconnect();
    }
  }

  Future<void> connect(ServerModel server) async {
    final g = ++_gen;
    activeServer = server;
    status = VpnStatus.connecting;
    notifyListeners();

    await _openTunnel(server);
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

  void disconnect() {
    _gen++;
    _tick?.cancel();
    _tick = null;
    _closeTunnel();
    status = VpnStatus.disconnected;
    downRate = 0;
    upRate = 0;
    notifyListeners();
  }

  /// If we're connected and the location changes, hop to it seamlessly.
  Future<void> switchTo(ServerModel server) async {
    if (!isConnected) {
      activeServer = server;
      return;
    }
    disconnect();
    await connect(server);
  }

  // ── the parts v3 will make real ──────────────────────────────────────────
  Future<void> _openTunnel(ServerModel server) async {
    // TODO(v3): start Android VpnService + engine → tls://${server.host}:${server.port}
    await Future<void>.delayed(const Duration(milliseconds: 1600));
  }

  void _closeTunnel() {
    // TODO(v3): stop the VpnService / tear down the tunnel.
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
