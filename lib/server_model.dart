/// Formats a measured latency (ms) for display. null = still measuring,
/// negative = unreachable/timeout.
String pingText(int? ms) {
  if (ms == null) return '…';
  if (ms < 0) return 'timeout';
  return '$ms ms';
}

/// A JeevVPN location. Holds everything the UI needs plus the real tunnel
/// share-link the v3 engine (flutter_v2ray / Xray) connects with.
class ServerModel {
  final String id;
  final String name; // e.g. "India", "Korea Central"
  final String country;
  final String city;
  final String flag;

  final String host;
  final int port;
  final String protocol;

  /// The server's real public IP (what your traffic egresses as when connected).
  final String publicIp;

  /// v3 real-tunnel config as a share link (trojan://...). Empty until the
  /// node has a real endpoint provisioned — those stay a simulated preview.
  final String shareLink;

  final bool recommended;
  final bool online;
  final int ping; // ms (display)
  final double load; // 0..1 (display)

  const ServerModel({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.flag,
    required this.host,
    this.port = 443,
    this.protocol = 'Trojan · TLS 443',
    this.publicIp = '',
    this.shareLink = '',
    this.recommended = false,
    this.online = true,
    required this.ping,
    required this.load,
  });

  String get location => '$city · $country';

  /// True once this node can carry a real device-wide tunnel (v3).
  bool get canTunnel => shareLink.isNotEmpty;
}

/// The live JeevVPN fleet.
///
/// India (Pune) is fully real: sing-box Trojan-over-TLS on 443 (52.140.121.205),
/// connected via the share link below. Korea Central is provisioned on Azure but
/// has no tunnel endpoint yet, so it stays a simulated preview until set up.
const List<ServerModel> kServers = [
  ServerModel(
    id: 'in-pune',
    name: 'India',
    country: 'India',
    city: 'Pune',
    flag: '🇮🇳',
    host: '52-140-121-205.sslip.io',
    port: 443,
    publicIp: '52.140.121.205',
    shareLink:
        'trojan://2f787001ba855030db138fbaca39840c@52-140-121-205.sslip.io:443?security=tls&sni=52-140-121-205.sslip.io&type=tcp#JeevVPN-India',
    recommended: true,
    online: true,
    ping: 16,
    load: 0.24,
  ),
  ServerModel(
    id: 'kr-central',
    name: 'Korea Central',
    country: 'South Korea',
    city: 'Seoul',
    flag: '🇰🇷',
    host: '72-155-88-152.sslip.io',
    port: 443,
    publicIp: '72.155.88.152',
    shareLink:
        'trojan://cbe6d1f40a051a12726dddafb8e39c61@72-155-88-152.sslip.io:443?security=tls&sni=72-155-88-152.sslip.io&allowInsecure=1&type=tcp#JeevVPN-Korea',
    recommended: false,
    online: true,
    ping: 74,
    load: 0.31,
  ),
];
