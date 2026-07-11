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

  Future<void> toggle(ServerModel server, {bool blockQuic = true}) async {
    if (status == VpnStatus.disconnected) {
      await connect(server, blockQuic: blockQuic);
    } else {
      await disconnect();
    }
  }

  Future<void> connect(ServerModel server, {bool blockQuic = true}) async {
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
        config: _buildConfig(server, blockQuic: blockQuic),
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
  Future<void> switchTo(ServerModel server, {bool blockQuic = true}) async {
    if (!isConnected && !isBusy) {
      activeServer = server;
      notifyListeners();
      return;
    }
    await disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await connect(server, blockQuic: blockQuic);
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
  /// The tunnel used to report "Protected" while no page, YouTube or Chrome
  /// would load. The fixes that make the connection actually carry traffic:
  ///  - Server-side DNS ([routing.domainStrategy] = AsIs): we do NOT resolve
  ///    names on-device. Sniffing lifts the real domain out of the TLS/HTTP
  ///    handshake and the exit server resolves it. Local resolution stalling
  ///    was the #1 cause of "connected but nothing loads".
  ///  - Robust proxy detection: find the real proxy outbound by protocol
  ///    (trojan/vless/vmess/…) instead of assuming it's first — a wrong tag
  ///    sent every packet into a black hole.
  ///  - Block QUIC (UDP/443) when [blockQuic]: Chrome & YouTube try QUIC first
  ///    and hang when it half-works through a tunnel. Blocking it forces an
  ///    instant fallback to TCP/TLS, which Trojan carries reliably.
  ///  - IPv4-only + LAN-direct: our nodes are IPv4-only, so kill the IPv6
  ///    (AAAA) black-hole; private ranges stay off the tunnel.
  ///  - DNS hijack: every port-53 query is answered inside the tunnel (no DNS
  ///    leak, no reliance on the phone's resolver).
  String _buildConfig(ServerModel server, {bool blockQuic = true}) {
    final parser = FlutterV2ray.parseFromURL(server.shareLink);
    try {
      final cfg =
          jsonDecode(parser.getFullConfiguration()) as Map<String, dynamic>;
      // Korea uses a link with allowInsecure=1; India has a valid cert.
      final insecure = server.shareLink.contains('allowInsecure=1');

      // ── inbound: keep the plugin's socks inbound (tun2socks feeds it); turn
      //    on sniffing so we route by the real domain, and allow UDP. ──
      final inbounds = ((cfg['inbounds'] as List?) ?? <dynamic>[]).toList();
      for (final inb in inbounds) {
        if (inb is! Map) continue;
        inb['sniffing'] = {
          'enabled': true,
          // Recover the domain from TLS SNI / HTTP host so the exit server can
          // resolve it. QUIC is dropped (see routing) so no need to sniff it.
          'destOverride': ['http', 'tls'],
          'routeOnly': false,
        };
        final s = (inb['settings'] as Map?) ?? <String, dynamic>{};
        s['udp'] = true;
        inb['settings'] = s;
      }
      cfg['inbounds'] = inbounds;

      // ── outbounds: find the real proxy by protocol; fix its TLS; make sure
      //    direct/block/dns outbounds exist. ──
      final outbounds =
          ((cfg['outbounds'] as List?) ?? <dynamic>[]).toList();
      const proxyProtocols = {'trojan', 'vless', 'vmess', 'shadowsocks'};
      Map? proxy;
      for (final o in outbounds) {
        if (o is Map && proxyProtocols.contains(o['protocol'])) {
          proxy = o;
          break;
        }
      }
      proxy ??= (outbounds.isNotEmpty && outbounds.first is Map)
          ? outbounds.first as Map
          : null;
      String proxyTag = 'proxy';
      if (proxy != null) {
        proxyTag = (proxy['tag'] as String?) ?? 'proxy';
        proxy['tag'] = proxyTag;
        final ss = (proxy['streamSettings'] as Map?) ?? <String, dynamic>{};
        final tls = (ss['tlsSettings'] as Map?) ?? <String, dynamic>{};
        tls['allowInsecure'] = insecure;
        ss['tlsSettings'] = tls;
        proxy['streamSettings'] = ss;
      }
      // Freedom/direct outbound → IPv4 only (our nodes have no IPv6). Normalise
      // its tag to 'direct'; track whether we found one so we don't add a
      // duplicate (two outbounds sharing a tag can break routing).
      var hasDirect = false;
      for (final o in outbounds) {
        if (o is Map && (o['protocol'] == 'freedom' || o['tag'] == 'direct')) {
          o['tag'] = 'direct';
          final s = (o['settings'] as Map?) ?? <String, dynamic>{};
          s['domainStrategy'] = 'UseIPv4';
          o['settings'] = s;
          hasDirect = true;
        }
      }
      if (!hasDirect) {
        outbounds.add({
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': {'domainStrategy': 'UseIPv4'},
        });
      }
      if (!outbounds.any((o) => o is Map && o['protocol'] == 'blackhole')) {
        outbounds.add({'tag': 'block', 'protocol': 'blackhole'});
      }
      if (!outbounds.any((o) => o is Map && o['protocol'] == 'dns')) {
        outbounds.add({'tag': 'dns-out', 'protocol': 'dns'});
      }
      cfg['outbounds'] = outbounds;

      // ── DNS: answer the app's hijacked port-53 queries with DoH. DoH egresses
      //    on :443 (carried through the proxy), so the resolver's own lookups
      //    never re-match the port-53 rule below — no DNS loop. IPv4 answers
      //    only (our nodes are v4-only). With routing = AsIs this resolver is
      //    used only to answer apps, not for every routing decision. ──
      cfg['dns'] = {
        'servers': ['https://1.1.1.1/dns-query', 'https://8.8.8.8/dns-query'],
        'queryStrategy': 'UseIPv4',
      };

      // ── routing: AsIs = don't resolve on-device (server resolves). Hijack
      //    DNS, drop QUIC (forces TCP), keep LAN direct, everything else to the
      //    proxy. Order matters: DNS and QUIC rules must come before catch-all. ──
      final rules = <Map<String, dynamic>>[
        {
          'type': 'field',
          'port': 53,
          'outboundTag': 'dns-out',
        },
      ];
      if (blockQuic) {
        rules.add({
          'type': 'field',
          'network': 'udp',
          'port': 443,
          'outboundTag': 'block',
        });
      }
      rules.add({
        'type': 'field',
        'ip': [
          '10.0.0.0/8',
          '172.16.0.0/12',
          '192.168.0.0/16',
          '127.0.0.0/8',
          '169.254.0.0/16',
          '::1/128',
          'fc00::/7',
          'fe80::/10',
        ],
        'outboundTag': 'direct',
      });
      rules.add({
        'type': 'field',
        'network': 'tcp,udp',
        'outboundTag': proxyTag,
      });
      cfg['routing'] = {
        'domainStrategy': 'AsIs',
        'rules': rules,
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
