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
  Future<List<Map<String, dynamic>>> getAdminOrders(String token, {int perPage = 200}) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/orders?per_page=$perPage', '/orders', '/seller/orders']) {
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

  Future<Map<String, dynamic>> updateOrderStatus(
    String token,
    int orderId,
    String status,
  ) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in [
      '/admin/orders/$orderId/status',
      '/orders/$orderId/status',
    ]) {
      try {
        return await api.put(path, {'status': status});
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw lastError ?? Exception('Gagal memperbarui status pesanan: tidak ada endpoint yang merespons');
  }

  // ── USERS ───────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdminUsers(String token, {int perPage = 200}) async {
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
        continue;
      }
    }
    throw lastError ?? Exception('Gagal membuat pengguna: tidak ada endpoint yang merespons');
  }

  /// Update pengguna. Kalau user adalah Penjual dan `data` menyertakan field
  /// toko, data toko ikut diperbarui sekaligus (lihat AdminController@updateUser).
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
        continue;
      }
    }
    throw lastError ?? Exception('Gagal memperbarui pengguna: tidak ada endpoint yang merespons');
  }

  Future<Map<String, dynamic>> deleteUser(String token, int userId) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in ['/admin/users/$userId', '/users/$userId']) {
      try {
        return await api.delete(path);
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw lastError ?? Exception('Gagal menghapus pengguna: tidak ada endpoint yang merespons');
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
  Future<List<Map<String, dynamic>>> getAdminProducts(String token, {int perPage = 200}) async {
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
    for (final path in [
      '/admin/products/$productId',
      '/products/$productId'
    ]) {
      try {
        return await api.delete(path);
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw lastError ?? Exception('Gagal menghapus produk: tidak ada endpoint yang merespons');
  }

  // ── STORES ───────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdminStores(String token, {int perPage = 200}) async {
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
        continue;
      }
    }
    throw lastError ?? Exception('Gagal memperbarui toko: tidak ada endpoint yang merespons');
  }

  Future<Map<String, dynamic>> deleteStore(String token, int storeId) async {
    final api = ApiService(token: token);
    Object? lastError;
    for (final path in ['/admin/stores/$storeId', '/stores/$storeId']) {
      try {
        return await api.delete(path);
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw lastError ?? Exception('Gagal menghapus toko: tidak ada endpoint yang merespons');
  }

  // ── HELPER ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _extractList(dynamic response) {
    List<dynamic> raw = [];

    if (response is List) {
      raw = response;
    } else if (response is Map<String, dynamic>) {
      final dataField = response['data'] ??
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
      final response =
          await api.getRaw('/admin/wallet/store-wallets?per_page=$perPage');
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
      final response =
          await api.getRaw('/admin/withdrawals?per_page=$perPage');
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
