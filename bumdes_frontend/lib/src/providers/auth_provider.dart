import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? user;
  String? token;
  bool isLoading = false;
  String? errorMessage;
  String? infoMessage;

  bool get isAuthenticated => token != null && user != null;

  Future<void> loadToken() async {
    isLoading = true;
    notifyListeners();
    token = await _authService.readToken();
    if (token != null) {
      try {
        final response = await _authService.fetchProfile(token!);
        user = UserModel.fromJson(response['data'] ?? response);
      } catch (_) {
        token = null;
        await _authService.deleteToken();
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    errorMessage = null;
    infoMessage = null;
    isLoading = true;
    notifyListeners();
    try {
      final response = await _authService.login(email, password);
      token = response['token'] ?? response['access_token'];
      if (token == null) {
        errorMessage = 'Token tidak ditemukan dari server.';
        return false;
      }
      await _authService.saveToken(token!);
      user = UserModel.fromJson(response['user'] ?? response['data'] ?? {});
      return true;
    } catch (e) {
      infoMessage = null;
      if (e is ApiException) {
        if (e.errors != null && e.errors!.isNotEmpty) {
          final first = e.errors!.values.first;
          if (first is List && first.isNotEmpty) {
            errorMessage = first.first.toString();
          } else {
            errorMessage = e.message;
          }
        } else {
          errorMessage = e.message;
        }
      } else {
        errorMessage = e is Exception
            ? e.toString()
            : 'Terjadi kesalahan saat login.';
      }
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerification(String email) async {
    errorMessage = null;
    infoMessage = null;
    isLoading = true;
    notifyListeners();
    try {
      final response = await _authService.resendVerification(email);
      infoMessage =
          response['message'] ??
          'Permintaan verifikasi ulang berhasil dikirim.';
      return true;
    } catch (e) {
      if (e is ApiException) {
        if (e.errors != null && e.errors!.isNotEmpty) {
          final first = e.errors!.values.first;
          if (first is List && first.isNotEmpty) {
            errorMessage = first.first.toString();
          } else {
            errorMessage = e.message;
          }
        } else {
          errorMessage = e.message;
        }
      } else {
        errorMessage = e is Exception
            ? e.toString()
            : 'Terjadi kesalahan saat mengirim verifikasi ulang.';
      }
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    errorMessage = null;
    infoMessage = null;
    isLoading = true;
    notifyListeners();
    try {
      final response = await _authService.register(name, email, password, role);
      infoMessage =
          response['message'] ??
          'Registrasi berhasil. Silakan cek email untuk verifikasi akun.';
      return true;
    } catch (e) {
      if (e is ApiException) {
        if (e.errors != null && e.errors!.isNotEmpty) {
          final first = e.errors!.values.first;
          if (first is List && first.isNotEmpty) {
            errorMessage = first.first.toString();
          } else {
            errorMessage = e.message;
          }
        } else {
          errorMessage = e.message;
        }
      } else {
        errorMessage = e is Exception
            ? e.toString()
            : 'Terjadi kesalahan saat mendaftar.';
      }
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = null;
    user = null;
    await _authService.deleteToken();
    notifyListeners();
  }

  Future<bool> refreshProfile() async {
    if (token == null) return false;
    try {
      final response = await _authService.fetchProfile(token!);
      user = UserModel.fromJson(response['data'] ?? response);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
