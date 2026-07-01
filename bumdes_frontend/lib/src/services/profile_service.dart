import 'api_service.dart';

class ProfileService {
  // FIX: Handle 404 dengan aman — kalau toko belum ada, return map kosong
  // bukan throw exception yang crash di seluruh app
  Future<Map<String, dynamic>> getStore(String token) async {
    final api = ApiService(token: token);
    try {
      return await api.get('/store');
    } on ApiException catch (e) {
      // 404 = toko belum ada, bukan error sebenarnya
      if (e.statusCode == 404) return {};
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  // FIX: Pisahkan create (POST) dan update (PUT) sesuai routes Laravel
  Future<Map<String, dynamic>> saveStore(
    String token,
    Map<String, dynamic> body, {
    bool isUpdate = false,
  }) async {
    final api = ApiService(token: token);
    if (isUpdate) {
      return api.put('/store', body);
    }
    return api.post('/store', body);
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final api = ApiService(token: token);
    return api.get('/profile');
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
    Map<String, dynamic> body,
  ) async {
    final api = ApiService(token: token);
    return api.put('/profile/password', body);
  }
}