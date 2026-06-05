import 'api_service.dart';

class ProfileService {
  Future<Map<String, dynamic>> getStore(String token) async {
    final api = ApiService(token: token);
    return api.get('/store');
  }

  Future<Map<String, dynamic>> saveStore(String token, Map<String, dynamic> body) async {
    final api = ApiService(token: token);
    return api.post('/store', body);
  }
}
