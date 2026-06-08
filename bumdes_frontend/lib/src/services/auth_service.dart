import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<String?> readToken() async {
    return _storage.read(key: 'auth_token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
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
