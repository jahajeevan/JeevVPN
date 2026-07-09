/// A JeevVPN location. Holds everything the UI needs today plus the
/// connection coordinates the real tunnel engine will use in v3.
class ServerModel {
  final String id;
  final String name; // e.g. "India", "Korea Central"
  final String country; // e.g. "India"
  final String city; // e.g. "Pune"
  final String flag;

  // Tunnel coordinates (used by the real engine in v3; connect is simulated now).
  final String host;
  final int port;
  final String protocol;

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
    this.protocol = 'HTTPS · TLS 443',
    this.recommended = false,
    this.online = true,
    required this.ping,
    required this.load,
  });

  String get location => '$city · $country';

  /// True once we have real tunnel coordinates for this node (v3).
  bool get hasEndpoint => host.isNotEmpty;
}

/// The live JeevVPN fleet.
///
/// India (Pune) is the real, working node (52.140.121.205 → the sslip.io TLS
/// front). Korea Central is provisioned on Azure; its tunnel host is filled in
/// once we have the endpoint — connect is simulated until v3 either way.
const List<ServerModel> kServers = [
  ServerModel(
    id: 'in-pune',
    name: 'India',
    country: 'India',
    city: 'Pune',
    flag: '🇮🇳',
    host: '52-140-121-205.sslip.io',
    port: 443,
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
    host: '', // TODO(v3): Azure Korea Central tunnel endpoint
    port: 443,
    recommended: false,
    online: true,
    ping: 74,
    load: 0.31,
  ),
];
