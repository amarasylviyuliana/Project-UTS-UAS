import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'package:web/web.dart' as web;

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      web.window.localStorage.setItem(_tokenKey, token);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> readToken() async {
    if (kIsWeb) {
      final token = web.window.localStorage.getItem(_tokenKey);
      return (token == null || token.isEmpty) ? null : token;
    }
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    if (kIsWeb) {
      web.window.localStorage.removeItem(_tokenKey);
    } else {
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final api = ApiService();
    return api.post('/auth/login', {'email': email, 'password': password});
  }

  String _normalizeRoleForBackend(String role) {
    switch (role) {
      case 'buyer':
        return 'Pembeli';
      case 'seller':
        return 'Penjual';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    final api = ApiService();
    return api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'role': _normalizeRoleForBackend(role),
    });
  }

  Future<Map<String, dynamic>> resendVerification(String email) async {
    final api = ApiService();
    final endpoints = [
      '/auth/resend-verification',
      '/auth/email/verification-notification',
      '/email/verification-notification',
    ];
    late Exception lastException;
    for (final endpoint in endpoints) {
      try {
        return await api.post(endpoint, {'email': email});
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastException;
  }

  Future<Map<String, dynamic>> fetchProfile(String token) async {
    final api = ApiService(token: token);
    return api.get('/auth/me');
  }

  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> body,
  ) async {
    final api = ApiService(token: token);
    return api.put('/profile', body);
  }

  Future<Map<String, dynamic>> updatePassword(
    String token,
    String currentPassword,
    String password,
    String passwordConfirmation,
  ) async {
    final api = ApiService(token: token);
    return api.put('/profile/password', {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }
}