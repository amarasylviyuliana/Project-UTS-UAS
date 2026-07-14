import 'package:flutter/material.dart';
import '../models/store_model.dart';
import '../services/store_service.dart';

// TAMBAHAN: provider untuk halaman daftar BUMDes. Polanya sengaja dibuat
// mirip ProductProvider (isLoading, search, filter) supaya konsisten.
class StoreProvider extends ChangeNotifier {
  final StoreService _storeService = StoreService();

  List<StoreModel> _stores = [];
  bool isLoading = false;
  String? error;
  String lastQuery = '';
  String selectedRegion = 'Semua Wilayah';

  // FIX: endpoint /stores butuh token (di-protect di backend). Token
  // di-set dari luar (biasanya dari AuthProvider) sebelum loadStores()
  // dipanggil — lihat BumdesListScreen.
  String? _token;
  void setToken(String? token) {
    _token = token;
  }

  List<StoreModel> get stores => _stores;

  // Catatan: daftar wilayah untuk dropdown filter diambil dari hasil
  // yang SEDANG tampil (bukan dari seluruh database), jadi bisa berubah
  // sesuai hasil pencarian/filter aktif. Ini pendekatan sederhana untuk
  // versi awal — kalau nanti mau daftar wilayah yang tetap lengkap,
  // sebaiknya backend menyediakan endpoint /stores/regions terpisah.
  List<String> get regionOptions {
    final regions = <String>{};
    for (final store in _stores) {
      if (store.regency != null && store.regency!.isNotEmpty) {
        regions.add(store.regency!);
      }
    }
    final sorted = regions.toList()..sort();
    return ['Semua Wilayah', ...sorted];
  }

  Future<void> loadStores({String? query, String? region}) async {
    isLoading = true;
    error = null;
    if (query != null) lastQuery = query;
    if (region != null) selectedRegion = region;
    notifyListeners();

    try {
      _stores = await _storeService.fetchStores(
        token: _token,
        query: lastQuery,
        region: selectedRegion,
      );
    } catch (_) {
      error = 'Gagal memuat daftar BUMDes. Coba lagi.';
      _stores = [];
    }

    isLoading = false;
    notifyListeners();
  }

  void search(String query) => loadStores(query: query);

  void filterByRegion(String region) => loadStores(region: region);
}