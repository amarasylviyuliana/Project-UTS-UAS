import 'api_service.dart';

class AdminService {
  // ── DASHBOARD STATS ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats(String token) async {
    final api = ApiService(token: token);
    try {
      final response = await api.getRaw('/admin/dashboard/stats');
      if (response is Map<String, dynamic>) {
        // Backend return {'status':'success','data':{...stats...}}
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        return response;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // ── ORDERS ──────────────────────────────────────────────────────────────────
  // ALUR BARU: Admin hanya MEMANTAU pesanan (read-only). Mengubah status
  // pesanan (konfirmasi/kirim/selesai/batal) sepenuhnya tanggung jawab
  // Penjual lewat aplikasinya sendiri, jadi method updateOrderStatus() yang
  // dulu ada di sini sudah DIHAPUS. Kalau backend endpoint
  // PUT /admin/orders/{id}/status masih aktif, pastikan endpoint itu juga
  // ditolak/dibatasi di sisi server untuk role Admin, supaya tidak bisa
  // dipanggil langsung lewat API di luar aplikasi ini.
  Future<List<Map<String, dynamic>>> getAdminOrders(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    for (final path in [
      '/admin/orders?per_page=$perPage',
      '/orders',
      '/seller/orders',
    ]) {
      try {
        final response = await api.getRaw(path);
        final list = _extractList(response);
        if (list.isNotEmpty) return list;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  // ── USERS (PENJUAL) ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdminUsers(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/users?per_page=$perPage', '/users']) {
      try {
        final response = await api.getRaw(path);
        final list = _extractList(response);
        return list;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  /// Buat pengguna baru (Admin/Penjual/Pembeli).
  ///
  /// ALUR BARU: kalau `data['role'] == 'Penjual'`, `data` HARUS sudah
  /// menyertakan field data toko/BUMDes sekaligus (store_name, village,
  /// district, regency, contact_phone, dst) — lihat
  /// AdminController@createUser di backend. Backend akan membuat User +
  /// Store dalam satu transaksi dan langsung aktif.
  ///
  /// FIX: dulu kalau path pertama (`/admin/users`) gagal karena error VALID
  /// dari server (mis. validasi 422, email sudah dipakai, dsb), kode ini
  /// tetap lanjut mencoba path kedua (`/users`) dan pesan error yang
  /// sebenarnya penting jadi ketimpa oleh error dari path kedua yang kurang
  /// relevan (atau malah membuat user dobel kalau path kedua ternyata juga
  /// valid). Sekarang hanya lanjut ke path berikutnya kalau errornya benar2
  /// karena endpoint tidak ditemukan (404) — bukan endpoint valid yang
  /// menolak request.
  Future<Map<String, dynamic>> createUser(
    String token,
    Map<String, dynamic> data,
  ) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in ['/admin/users', '/users']) {
      try {
        return await api.post(path, data);
      } catch (e) {
        lastError = e;
        if (!_isRouteNotFound(e)) rethrow;
        continue;
      }
    }
    throw lastError ??
        Exception('Gagal membuat pengguna: tidak ada endpoint yang merespons');
  }

  /// Update pengguna. Kalau user adalah Penjual dan `data` menyertakan field
  /// toko, data toko ikut diperbarui sekaligus (lihat AdminController@updateUser).
  ///
  /// FIX: sama seperti createUser — tidak lagi menimpa error asli dengan
  /// error dari path fallback kalau path pertama sudah merespons (walau
  /// responsnya berupa error yang valid).
  Future<Map<String, dynamic>> updateUser(
    String token,
    int userId,
    Map<String, dynamic> data,
  ) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in ['/admin/users/$userId', '/users/$userId']) {
      try {
        return await api.put(path, data);
      } catch (e) {
        lastError = e;
        if (!_isRouteNotFound(e)) rethrow;
        continue;
      }
    }
    throw lastError ??
        Exception(
          'Gagal memperbarui pengguna: tidak ada endpoint yang merespons',
        );
  }

  /// Hapus pengguna (Penjual/Pembeli/Admin).
  ///
  /// PENTING — INI PENYEBAB UTAMA "hapus pembeli tidak bisa tapi tidak ada
  /// keterangan":
  /// Backend sekarang akan menolak dengan pesan jelas (status 409) kalau
  /// pengguna itu masih punya data terkait lewat foreign key (mis. baris di
  /// tabel `orders`, apapun statusnya — Selesai maupun belum). Sebelumnya,
  /// begitu request ke `/admin/users/{id}` ditolak server, kode di sini
  /// tetap mencoba `/users/{id}` sebagai fallback, dan pesan error 409 yang
  /// jelas itu ketimpa oleh error generik dari path kedua (biasanya 404
  /// "not found" karena path itu memang tidak dimaksudkan untuk admin).
  /// Akibatnya UI di atas tidak pernah tahu alasan sebenarnya.
  /// Sekarang: begitu server merespons (apapun hasilnya) di path pertama,
  /// error itu langsung dilempar apa adanya ke pemanggil — fallback HANYA
  /// dicoba kalau errornya murni karena endpoint tidak ditemukan (404).
  Future<Map<String, dynamic>> deleteUser(String token, int userId) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in ['/admin/users/$userId', '/users/$userId']) {
      try {
        return await api.delete(path);
      } catch (e) {
        lastError = e;
        if (!_isRouteNotFound(e)) rethrow;
        continue;
      }
    }
    throw lastError ??
        Exception(
          'Gagal menghapus pengguna: tidak ada endpoint yang merespons',
        );
  }

  // ── BUYERS (PEMBELI) ────────────────────────────────────────────────────────
  // Read-only + hapus saja. Tidak ada createBuyer/updateBuyer karena Pembeli
  // daftar sendiri lewat app, bukan dibuatkan Admin. Hapus pembeli memakai
  // deleteUser() di atas (endpoint generic DELETE /admin/users/{id}).
  Future<List<Map<String, dynamic>>> getAdminBuyers(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    try {
      final response = await api.getRaw('/admin/buyers?per_page=$perPage');
      return _extractList(response);
    } catch (_) {
      return [];
    }
  }

  // CATATAN PERUBAHAN ALUR BISNIS:
  // Fitur "Persetujuan Toko" (getStoreApprovals/approveStore) dan "Verifikasi
  // Penjual" (getPendingVerifications/verifySeller) sudah DIHAPUS total dari
  // sini karena endpoint backend-nya (/admin/store-approvals,
  // /admin/verifications) sudah tidak ada. Toko sekarang dibuat langsung oleh
  // Admin lewat createUser() di atas dan otomatis aktif — tidak ada lagi
  // proses menunggu/menyetujui/menolak toko atau verifikasi identitas penjual.
  // Kalau Admin ingin mengaktifkan/menonaktifkan toko yang sudah ada,
  // pakai updateStore() di bawah dengan {'is_active': true/false}.

  // ── PRODUCTS ─────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdminProducts(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    for (final path in [
      '/admin/products?per_page=$perPage',
      '/admin/product-approvals',
      '/products',
    ]) {
      try {
        final response = await api.getRaw(path);
        return _extractList(response);
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> deleteProduct(
    String token,
    int productId,
  ) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in ['/admin/products/$productId', '/products/$productId']) {
      try {
        return await api.delete(path);
      } catch (e) {
        lastError = e;
        if (!_isRouteNotFound(e)) rethrow;
        continue;
      }
    }
    throw lastError ??
        Exception('Gagal menghapus produk: tidak ada endpoint yang merespons');
  }

  // ── STORES ───────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdminStores(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/stores?per_page=$perPage', '/stores']) {
      try {
        final response = await api.getRaw(path);
        return _extractList(response);
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getStoreApprovals(String token) async {
    try {
      final response = await ApiService(
        token: token,
      ).getRaw('/admin/store-approvals');
      return _extractList(response);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> approveStore(
    String token,
    int approvalId,
    String status, {
    String? reason,
  }) async {
    final api = ApiService(token: token);
    final payload = <String, dynamic>{'status': status};
    if (reason != null && reason.isNotEmpty) {
      payload['rejected_reason'] = reason;
    }
    try {
      return await api.put('/admin/store-approvals/$approvalId', payload);
    } catch (_) {
      return {'success': false};
    }
  }

  /// Aktifkan/nonaktifkan toko, atau ubah data toko lain. Contoh:
  /// `updateStore(token, storeId, {'is_active': false})`
  Future<Map<String, dynamic>> updateStore(
    String token,
    int storeId,
    Map<String, dynamic> data,
  ) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in ['/admin/stores/$storeId', '/stores/$storeId']) {
      try {
        return await api.put(path, data);
      } catch (e) {
        lastError = e;
        if (!_isRouteNotFound(e)) rethrow;
        continue;
      }
    }
    throw lastError ??
        Exception('Gagal memperbarui toko: tidak ada endpoint yang merespons');
  }

  Future<Map<String, dynamic>> deleteStore(String token, int storeId) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in ['/admin/stores/$storeId', '/stores/$storeId']) {
      try {
        return await api.delete(path);
      } catch (e) {
        lastError = e;
        if (!_isRouteNotFound(e)) rethrow;
        continue;
      }
    }
    throw lastError ??
        Exception('Gagal menghapus toko: tidak ada endpoint yang merespons');
  }

  // ── HELPER ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _extractList(dynamic response) {
    List<dynamic> raw = [];

    if (response is List) {
      raw = response;
    } else if (response is Map<String, dynamic>) {
      final dataField =
          response['data'] ??
          response['items'] ??
          response['stores'] ??
          response['users'] ??
          response['products'] ??
          response['orders'];

      if (dataField is List) {
        raw = dataField;
      } else if (dataField is Map<String, dynamic>) {
        final nested = dataField['data'];
        if (nested is List) {
          raw = nested;
        }
      }
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Cek apakah sebuah error itu murni karena endpoint tidak ditemukan
  /// (404 / route not found). Dipakai supaya loop fallback path HANYA
  /// lanjut mencoba path lain kalau memang path pertama tidak ada,
  /// bukan setiap kali server menolak request dengan alasan bisnis
  /// (409 konflik, 422 validasi, dll) — karena kalau tetap lanjut,
  /// pesan error yang penting dari path pertama akan hilang/ketimpa.
  bool _isRouteNotFound(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('404') ||
        msg.contains('not found') ||
        msg.contains('route not found') ||
        msg.contains('no route');
  }

  // ── WALLET / SALDO & PAJAK (Admin) ────────────────────────────────────────────
  Future<Map<String, dynamic>> getWalletSummary(String token) async {
    final api = ApiService(token: token);
    // FIX: sebelumnya tidak ada try/catch — kalau endpoint gagal, exception
    // menyebar tanpa ditangkap dan bisa bikin layar wallet crash.
    try {
      final response = await api.get('/admin/wallet/summary');
      return Map<String, dynamic>.from(response['data'] ?? {});
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getPlatformTaxTransactions(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    try {
      final response = await api.getRaw(
        '/admin/wallet/transactions?scope=platform&per_page=$perPage',
      );
      return _extractList(response);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStoreWallets(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    try {
      final response = await api.getRaw(
        '/admin/wallet/store-wallets?per_page=$perPage',
      );
      return _extractList(response);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllWithdrawals(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    try {
      final response = await api.getRaw('/admin/withdrawals?per_page=$perPage');
      return _extractList(response);
    } catch (_) {
      return [];
    }
  }

  /// Ajukan penarikan saldo Admin/platform (dari kumpulan biaya admin/pajak).
  Future<Map<String, dynamic>> requestPlatformWithdrawal(
    String token, {
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final api = ApiService(token: token);
    // Ini operasi mutating (POST) — biarkan exception menyebar kalau gagal,
    // supaya UI tahu penarikan tidak benar-benar berhasil.
    final response = await api.post('/admin/wallet/withdrawals', {
      'amount': amount,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
    });
    return response['data'] ?? {};
  }
}