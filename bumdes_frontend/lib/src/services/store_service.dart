import 'api_service.dart';
import '../models/store_model.dart';

// FIX: endpoint /stores ternyata BUTUH token (di-protect middleware auth
// di backend), meski sebelumnya diasumsikan publik. StoreService sekarang
// menerima token opsional dan meneruskannya ke ApiService supaya header
// Authorization terpasang, sama seperti pola fetchProductsByStore() di
// ProductService.
class StoreService {
  Future<List<StoreModel>> fetchStores({
    String? token,
    String? query,
    String? region,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (region != null && region.isNotEmpty && region != 'Semua Wilayah') {
      params['region'] = region;
    }

    final queryString = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

    final api = ApiService(token: token);
    final response = await api.getRaw('/stores$queryString');
    final rawList = _extractStoreList(response);
    return rawList
        .map((item) => StoreModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<dynamic> _extractStoreList(dynamic response) {
    if (response is List) return response;
    if (response is Map<String, dynamic>) {
      if (response['data'] is List) return response['data'] as List<dynamic>;
      if (response['data'] is Map<String, dynamic> &&
          response['data']['data'] is List) {
        return response['data']['data'] as List<dynamic>;
      }
    }
    return [];
  }
}