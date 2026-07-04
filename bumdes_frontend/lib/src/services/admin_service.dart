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
    for (final path in [
      '/admin/orders/$orderId/status',
      '/orders/$orderId/status',
    ]) {
      try {
        return await api.put(path, {'status': status});
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  // ── USERS ───────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdminUsers(String token, {int perPage = 200}) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/users?per_page=$perPage', '/users']) {
      try {
        final response = await api.getRaw(path);
        final list = _extractList(response);
        // FIX: jangan skip kalau list kosong — mungkin memang belum ada user
        // hanya skip kalau throw exception
        return list;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> createUser(
    String token,
    Map<String, dynamic> data,
  ) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/users', '/users']) {
      try {
        return await api.post(path, data);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>> updateUser(
    String token,
    int userId,
    Map<String, dynamic> data,
  ) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/users/$userId', '/users/$userId']) {
      try {
        return await api.put(path, data);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>> deleteUser(String token, int userId) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/users/$userId', '/users/$userId']) {
      try {
        return await api.delete(path);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  // ── STORE APPROVALS ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStoreApprovals(String token) async {
    final api = ApiService(token: token);

    // Coba endpoint khusus store-approvals dulu
    for (final path in [
      '/admin/store-approvals',
      '/admin/stores/pending',
    ]) {
      try {
        final response = await api.getRaw(path);
        final list = _extractList(response);
        // FIX: kalau dapat data (berapapun), langsung return
        // Jangan return kalau kosong — coba endpoint berikutnya dulu
        if (list.isNotEmpty) return list;
      } catch (_) {
        continue;
      }
    }

    // FIX FALLBACK: Kalau endpoint khusus tidak ada / kosong,
    // ambil dari /admin/stores lalu filter yang statusnya pending/menunggu
    // Ini mengatasi backend yang tidak punya endpoint store-approvals terpisah
    try {
      final response = await api.getRaw('/admin/stores');
      final allStores = _extractList(response);
      final pendingStores = allStores.where((store) {
        // Cek approval_status di store
        final approvalStatus =
            (store['approval_status'] ?? '').toString().toLowerCase();
        // Cek di dalam object store_approval jika ada
        final storeApproval = store['store_approval'] as Map<String, dynamic>?;
        final approvalStatusNested =
            (storeApproval?['status'] ?? '').toString().toLowerCase();

        final isPending = approvalStatus.contains('menunggu') ||
            approvalStatus.contains('pending') ||
            approvalStatus.isEmpty ||
            approvalStatusNested.contains('menunggu') ||
            approvalStatusNested.contains('pending') ||
            approvalStatusNested.isEmpty;

        // Jangan masukkan yang is_active=true dan sudah disetujui
        final isActive = store['is_active'] == true;
        final isApproved = approvalStatus == 'disetujui' ||
            approvalStatusNested == 'disetujui';

        return isPending && !(isActive && isApproved);
      }).toList();

      // Bungkus dalam format yang sama dengan store-approvals
      // agar _buildStoreApprovalCard bisa baca dengan benar
      return pendingStores.map((store) {
        return <String, dynamic>{
          'id': store['id'],
          'status': store['approval_status'] ??
              store['store_approval']?['status'] ??
              'Menunggu Persetujuan',
          'created_at': store['created_at'],
          'store': store,
        };
      }).toList();
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
    final body = <String, dynamic>{'status': status};
    if (reason != null && reason.isNotEmpty) {
      body['rejected_reason'] = reason;
    }
    for (final path in [
      '/admin/store-approvals/$approvalId',
      '/admin/stores/$approvalId/approve',
    ]) {
      try {
        return await api.put(path, body);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

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
        return _extractList(response); // FIX: return langsung
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
    for (final path in [
      '/admin/products/$productId',
      '/products/$productId'
    ]) {
      try {
        return await api.delete(path);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  // ── STORES ───────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdminStores(String token, {int perPage = 200}) async {
    final api = ApiService(token: token);
    // FIX: hanya coba /admin/stores — endpoint yang benar
    // Jangan fallback ke /admin/store-approvals karena itu data berbeda
    for (final path in ['/admin/stores?per_page=$perPage', '/stores']) {
      try {
        final response = await api.getRaw(path);
        return _extractList(response); // FIX: return langsung, jangan skip kalau kosong
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> updateStore(
    String token,
    int storeId,
    Map<String, dynamic> data,
  ) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/stores/$storeId', '/stores/$storeId']) {
      try {
        return await api.put(path, data);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>> deleteStore(String token, int storeId) async {
    final api = ApiService(token: token);
    for (final path in ['/admin/stores/$storeId', '/stores/$storeId']) {
      try {
        return await api.delete(path);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  // ── SELLER VERIFICATIONS ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingVerifications(
      String token) async {
    final api = ApiService(token: token);
    for (final path in [
      '/admin/verifications',
      '/admin/seller-verifications',
    ]) {
      try {
        final response = await api.getRaw(path);
        return _extractList(response); // FIX: return langsung
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> verifySeller(
    String token,
    int verificationId,
    String status, {
    String? rejectionReason,
  }) async {
    final api = ApiService(token: token);
    final body = <String, dynamic>{'status': status};
    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      body['rejection_reason'] = rejectionReason;
    }
    for (final path in [
      '/admin/verifications/$verificationId',
      '/admin/seller-verifications/$verificationId',
      '/admin/store-approvals/$verificationId',
    ]) {
      try {
        return await api.put(path, body);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  // ── HELPER ───────────────────────────────────────────────────────────────────
  // FIX: Handle semua format response Laravel:
  // 1. List langsung: [...]
  // 2. {status, data: [...]}
  // 3. {status, data: {current_page, data: [...]}} ← Laravel paginate
  // 4. {status, data: {data: [...]}} ← nested
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
          response['orders'] ??
          response['approvals'] ??
          response['verifications'];

      if (dataField is List) {
        // Format: {data: [...]}
        raw = dataField;
      } else if (dataField is Map<String, dynamic>) {
        // Format: {data: {current_page:1, data: [...]}} ← Laravel paginate
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
    final response = await api.get('/admin/wallet/summary');
    return Map<String, dynamic>.from(response['data'] ?? {});
  }

  Future<List<Map<String, dynamic>>> getPlatformTaxTransactions(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    final response = await api.getRaw(
      '/admin/wallet/transactions?scope=platform&per_page=$perPage',
    );
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getStoreWallets(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    final response =
        await api.getRaw('/admin/wallet/store-wallets?per_page=$perPage');
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getAllWithdrawals(
    String token, {
    int perPage = 200,
  }) async {
    final api = ApiService(token: token);
    final response =
        await api.getRaw('/admin/withdrawals?per_page=$perPage');
    return _extractList(response);
  }
}