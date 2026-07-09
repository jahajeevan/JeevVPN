import 'dart:async';
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
