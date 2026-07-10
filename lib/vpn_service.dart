import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'server_model.dart';

enum VpnStatus { disconnected, connecting, connected }

/// The tunnel controller (flutter_v2ray / Xray → our sing-box Trojan servers).
///
/// The engine broadcasts its state + traffic every second. We attach that
/// listener at startup ([init]) so the UI always mirrors the real VpnService —
/// including after Android kills the app UI in the background but keeps the
/// tunnel alive: on reopen the engine re-broadcasts CONNECTED and we adopt it.
class VpnService extends ChangeNotifier {
  late final FlutterV2ray _v2ray =
      FlutterV2ray(onStatusChanged: _onEngineStatus);
  bool _engineInit = false;
  bool _stopping = false; // user asked to disconnect → ignore a trailing CONNECTED

  VpnStatus status = VpnStatus.disconnected;
  ServerModel? activeServer;
  String? errorText;

  Duration elapsed = Duration.zero;
  double downMb = 0, upMb = 0; // cumulative this session
  double downRate = 0, upRate = 0; // Mbps
  int livePing = 16;
  final List<double> spark = List<double>.filled(52, 0.0); // raw Mbps history

  int _gen = 0;

  bool get isConnected => status == VpnStatus.connected;
  bool get isBusy => status == VpnStatus.connecting;

  /// Attach the engine listener once, at startup. Safe to call repeatedly.
  Future<void> init() async {
    if (_engineInit) return;
    try {
      await _v2ray.initializeV2Ray();
      _engineInit = true;
    } catch (_) {}
  }

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
    _stopping = false;
    if (!server.canTunnel) {
      errorText = "This location isn't ready yet.";
      notifyListeners();
      return;
    }
    final g = ++_gen;
    status = VpnStatus.connecting;
    notifyListeners();
    try {
      await init();
      final granted = await _v2ray.requestPermission();
      if (!granted) {
        if (g == _gen) {
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
      // From here, real state/traffic arrive through _onEngineStatus.
    } catch (e) {
      if (g == _gen) {
        status = VpnStatus.disconnected;
        errorText = 'Could not start the tunnel. $e';
        notifyListeners();
      }
    }
  }

  Future<void> disconnect() async {
    _gen++;
    _stopping = true;
    status = VpnStatus.disconnected;
    downRate = 0;
    upRate = 0;
    notifyListeners();
    try {
      await _v2ray.stopV2Ray();
    } catch (_) {}
  }

  /// Change location: drop the current tunnel, then bring up the new one.
  Future<void> switchTo(ServerModel server) async {
    if (!isConnected && !isBusy) {
      activeServer = server;
      notifyListeners();
      return;
    }
    await disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await connect(server);
  }

  // ── the single source of truth for connection state ──────────────────────
  void _onEngineStatus(V2RayStatus s) {
    final st = s.state.toUpperCase();

    // Check DISCONNECT first — "DISCONNECTED" contains "CONNECTED" as a
    // substring, so order matters.
    if (st.contains('DISCONNECT')) {
      _stopping = false;
      if (status != VpnStatus.disconnected) {
        status = VpnStatus.disconnected;
        downRate = 0;
        upRate = 0;
        notifyListeners();
      }
      return;
    }

    // Ignore a stray CONNECTED that arrives right after the user tapped stop.
    if (_stopping) return;

    if (st.contains('CONNECTING')) {
      if (status != VpnStatus.connecting) {
        status = VpnStatus.connecting;
        notifyListeners();
      }
      return;
    }

    if (st.contains('CONNECTED')) {
      status = VpnStatus.connected;
      elapsed = _parseDuration(s.duration);
      downRate = s.downloadSpeed * 8 / 1000000.0; // bytes/s → Mbps
      upRate = s.uploadSpeed * 8 / 1000000.0;
      downMb = s.download / 1048576.0;
      upMb = s.upload / 1048576.0;
      livePing = activeServer?.ping ?? livePing;
      spark.removeAt(0);
      spark.add(downRate); // raw Mbps; the sparkline auto-scales
      notifyListeners();
    }
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

      return jsonEncode(cfg);
    } catch (_) {
      // If the template changes shape, fall back to the raw config.
      return parser.getFullConfiguration();
    }
  }

  String get clock {
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
