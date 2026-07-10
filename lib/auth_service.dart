import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// A signed-in JeevVPN account.
class Account {
  final String email;
  final String? name;
  final int? age;
  const Account({required this.email, this.name, this.age});
}

/// Email+password accounts backed by the JeevVPN backend (Supabase, bcrypt).
/// Sign-up verifies the email with a one-time code first; returning users just
/// use email + password.
class AuthService {
  static Future<Account> register({
    required String email,
    required String code,
    required String token,
    required String password,
    required String name,
    int? age,
  }) async {
    final res = await http
        .post(
          Uri.parse('$kApiBase/api/auth/register'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'code': code,
            'token': token,
            'password': password,
            'name': name,
            'age': age,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw AuthException(_msg(data, 'Could not create your account.'));
    }
    return Account(
      email: data['email']?.toString() ?? email,
      name: data['name']?.toString(),
      age: (data['age'] as num?)?.toInt(),
    );
  }

  static Future<Account> login({
    required String email,
    required String password,
  }) async {
    final res = await http
        .post(
          Uri.parse('$kApiBase/api/auth/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 25));
    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw AuthException(_msg(data, 'Could not sign in.'));
    }
    return Account(
      email: data['email']?.toString() ?? email,
      name: data['name']?.toString(),
      age: (data['age'] as num?)?.toInt(),
    );
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

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
