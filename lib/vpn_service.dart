import 'dart:async';
import 'dart:convert';
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
      await _v2ray.startV2Ray(
        remark: 'JeevVPN · ${server.name}',
        config: _buildConfig(server),
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

  /// Builds a correct full-device Xray config from the server's share link.
  ///
  /// The TLS handshake was fine ("Protected") but no traffic flowed. Root
  /// causes fixed here:
  ///  - IPv6 black-hole: our servers are IPv4-only, but modern Android prefers
  ///    IPv6 (AAAA) → those connections die. Force IPv4-only DNS + direct.
  ///  - DNS: hijack the tunnel's DNS to Xray's resolver (over the proxy) so
  ///    names actually resolve inside the tunnel.
  ///  - Sniffing on: route by real domain (TLS SNI / HTTP host / QUIC).
  ///  - No UDP reject: Trojan carries UDP fine — send everything to the proxy,
  ///    keep LAN/private ranges direct.
  String _buildConfig(ServerModel server) {
    final parser = FlutterV2ray.parseFromURL(server.shareLink);
    try {
      final cfg =
          jsonDecode(parser.getFullConfiguration()) as Map<String, dynamic>;
      // Korea uses a link with allowInsecure=1; India has a valid cert.
      final insecure = server.shareLink.contains('allowInsecure=1');

      // ── inbound: keep the plugin's socks inbound (tun2socks feeds it); turn
      //    on sniffing and allow UDP. ──
      final inbounds = ((cfg['inbounds'] as List?) ?? <dynamic>[]).toList();
      String inboundTag = 'socks-in';
      if (inbounds.isNotEmpty && inbounds.first is Map) {
        final inb = inbounds.first as Map;
        inboundTag = (inb['tag'] as String?) ?? inboundTag;
        inb['sniffing'] = {
          'enabled': true,
          'destOverride': ['http', 'tls', 'quic'],
          'routeOnly': false,
        };
        final s = (inb['settings'] as Map?) ?? <String, dynamic>{};
        s['udp'] = true;
        inb['settings'] = s;
      }
      cfg['inbounds'] = inbounds;

      // ── outbounds: proxy(trojan) first — fix its TLS; ensure direct/block/dns. ──
      final outbounds =
          ((cfg['outbounds'] as List?) ?? <dynamic>[]).toList();
      String proxyTag = 'proxy';
      if (outbounds.isNotEmpty && outbounds.first is Map) {
        final proxy = outbounds.first as Map;
        proxyTag = (proxy['tag'] as String?) ?? 'proxy';
        final ss = (proxy['streamSettings'] as Map?) ?? <String, dynamic>{};
        final tls = (ss['tlsSettings'] as Map?) ?? <String, dynamic>{};
        tls['allowInsecure'] = insecure;
        ss['tlsSettings'] = tls;
        proxy['streamSettings'] = ss;
      }
      for (final o in outbounds) {
        if (o is Map && (o['protocol'] == 'freedom' || o['tag'] == 'direct')) {
          final s = (o['settings'] as Map?) ?? <String, dynamic>{};
          s['domainStrategy'] = 'UseIPv4';
          o['settings'] = s;
        }
      }
      if (!outbounds.any((o) => o is Map && o['protocol'] == 'blackhole')) {
        outbounds.add({'tag': 'block', 'protocol': 'blackhole'});
      }
      if (!outbounds.any((o) => o is Map && o['protocol'] == 'dns')) {
        outbounds.add({'tag': 'dns-out', 'protocol': 'dns'});
      }
      cfg['outbounds'] = outbounds;

      // ── DNS: IPv4-only over the proxy (kills the IPv6 black-hole). ──
      cfg['dns'] = {
        'servers': ['https://1.1.1.1/dns-query', 'https://8.8.8.8/dns-query'],
        'queryStrategy': 'UseIPv4',
      };

      // ── routing: hijack DNS, keep LAN direct, send everything else to the
      //    proxy. No UDP reject. ──
      cfg['routing'] = {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          {
            'type': 'field',
            'inboundTag': [inboundTag],
            'port': 53,
            'outboundTag': 'dns-out',
          },
          {
            'type': 'field',
            'ip': [
              '10.0.0.0/8',
              '172.16.0.0/12',
              '192.168.0.0/16',
              '127.0.0.0/8',
              '::1/128',
              'fc00::/7',
              'fe80::/10',
            ],
            'outboundTag': 'direct',
          },
          {
            'type': 'field',
            'network': 'tcp,udp',
            'outboundTag': proxyTag,
          },
        ],
      };

      // Resolve names through a clean resolver inside the tunnel. The engine
      // defaults to 8.8.8.8, which some ISPs hijack/poison — that alone can make
      // pages fail to load even when the tunnel itself is up. Force Cloudflare
      // first (queries ride the tunnel, so they don't leak or get tampered).
      cfg['dns'] = {
        'servers': ['1.1.1.1', '1.0.0.1', '8.8.8.8'],
        'queryStrategy': 'UseIP',
      };

      return jsonEncode(cfg);
    } catch (_) {
      // If the template changes shape, fall back to the raw config.
      return parser.getFullConfiguration();
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
