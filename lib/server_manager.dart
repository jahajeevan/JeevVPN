import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'server_model.dart';

/// Owns the server list, the current selection, and the anti-spam switching
/// cooldown. Kept out of the UI so the rules live in one place.
///
/// Rule: a user may switch locations, but after [switchLimit] consecutive
/// switches the selector locks for [cooldownSeconds] with a live countdown.
class ServerManager extends ChangeNotifier {
  ServerManager();

  static const int switchLimit = 2; // switches allowed before a lock
  static const int cooldownSeconds = 40;

  final List<ServerModel> servers = kServers;
  ServerModel current = kServers.first;

  int _switchCount = 0;
  bool locked = false;
  int cooldownRemaining = 0;
  Timer? _cooldown;

  /// Real measured latency per server id (ms). -1 = unreachable, absent = not
  /// measured yet. Measured with a real TCP handshake to host:port.
  final Map<String, int> pings = {};
  final Set<String> _measuring = {};

  int? pingFor(String id) => pings[id];

  Future<void> measureAll() async {
    await Future.wait(servers.map(measurePing));
  }

  Future<void> measurePing(ServerModel s) async {
    if (_measuring.contains(s.id)) return;
    _measuring.add(s.id);
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(s.host, s.port,
          timeout: const Duration(seconds: 4));
      sw.stop();
      socket.destroy();
      pings[s.id] = sw.elapsedMilliseconds;
    } catch (_) {
      pings[s.id] = -1;
    } finally {
      _measuring.remove(s.id);
      notifyListeners();
    }
  }

  /// Attempt to switch to [s].
  /// Returns a result the UI can react to (lock message vs. success).
  SwitchResult selectServer(ServerModel s) {
    if (locked) {
      return SwitchResult.locked;
    }
    if (s.id == current.id) {
      return SwitchResult.unchanged;
    }
    current = s;
    _switchCount++;
    if (_switchCount >= switchLimit) {
      _startCooldown();
    }
    notifyListeners();
    return SwitchResult.switched;
  }

  void _startCooldown() {
    locked = true;
    cooldownRemaining = cooldownSeconds;
    _cooldown?.cancel();
    _cooldown = Timer.periodic(const Duration(seconds: 1), (_) {
      cooldownRemaining--;
      if (cooldownRemaining <= 0) {
        _unlock();
      }
      notifyListeners();
    });
  }

  void _unlock() {
    _cooldown?.cancel();
    _cooldown = null;
    locked = false;
    cooldownRemaining = 0;
    _switchCount = 0;
  }

  String get cooldownLabel {
    final s = cooldownRemaining.clamp(0, cooldownSeconds);
    return '${s}s';
  }

  /// Progress 0..1 through the current cooldown (for a ring/bar).
  double get cooldownProgress =>
      locked ? (cooldownRemaining / cooldownSeconds).clamp(0.0, 1.0) : 0.0;

  @override
  void dispose() {
    _cooldown?.cancel();
    super.dispose();
  }
}

enum SwitchResult { switched, unchanged, locked }
