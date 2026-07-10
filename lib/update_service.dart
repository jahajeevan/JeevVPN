import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Details of a newer app version, from the website manifest.
class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String notes;
  final String apkUrl;
  final bool mandatory;
  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
    required this.mandatory,
  });
}

/// Checks the website manifest for a newer APK than this build.
///
/// Sideloaded apps don't auto-update, so the app polls a tiny JSON on the site
/// each launch. Returns null when up to date, unreachable, or malformed.
class UpdateService {
  static Future<UpdateInfo?> check() async {
    try {
      final res = await http
          .get(Uri.parse(kVersionManifestUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return null;
      final code = (data['versionCode'] as num?)?.toInt() ?? 0;
      if (code <= kVersionCode) return null; // already current
      final apkUrl = data['apkUrl']?.toString() ?? '';
      if (apkUrl.isEmpty) return null;
      return UpdateInfo(
        versionCode: code,
        versionName: data['versionName']?.toString() ?? '',
        notes: data['notes']?.toString() ?? '',
        apkUrl: apkUrl,
        mandatory: data['mandatory'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
