import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Talks to the JeevVPN backend for email-OTP sign in.
///
/// `sendCode` emails a 6-digit code and returns an opaque signed [token].
/// `verifyCode` checks the code against that token. The Gmail credentials that
/// send the mail live only on the server — never here.
class OtpService {
  static Future<String> sendCode(String email) async {
    final res = await http
        .post(
          Uri.parse('$kApiBase/api/otp/send'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 25));
    final data = _decode(res);
    if (res.statusCode != 200) {
      throw OtpException(_msg(data, 'Could not send the code. Try again.'));
    }
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw OtpException('The server did not return a valid token.');
    }
    return token;
  }

  static Future<void> verifyCode({
    required String email,
    required String code,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse('$kApiBase/api/otp/verify'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code, 'token': token}),
        )
        .timeout(const Duration(seconds: 25));
    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw OtpException(_msg(data, 'Incorrect or expired code.'));
    }
  }

  static Map<String, dynamic> _decode(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      return d is Map<String, dynamic> ? d : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _msg(Map<String, dynamic> d, String fallback) {
    final e = d['error']?.toString();
    return (e == null || e.isEmpty) ? fallback : e;
  }
}

class OtpException implements Exception {
  final String message;
  OtpException(this.message);
  @override
  String toString() => message;
}
