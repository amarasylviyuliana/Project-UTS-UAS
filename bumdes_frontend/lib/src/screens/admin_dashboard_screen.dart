import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../widgets/paginated_list.dart';
import 'admin_wallet_screen.dart';
import 'home_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  static const routeName = '/admin-dashboard';
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  bool _isLoadingStats = false;
  bool _isLoadingOrders = false;
  bool _isLoadingUsers = false;
  bool _isLoadingBuyers = false;
  bool _isLoadingProducts = false;
  bool _isLoadingStores = false;

  String? _statsError;
  String? _ordersError;
  String? _usersError;
  String? _buyersError;
  String? _productsError;
  String? _storesError;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _buyers = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _stores = [];

  double _platformBalance = 0;
  double _taxPercentage = 0;
  bool _isLoadingWallet = false;

  // Sub-tab di menu PENGGUNA: 0 = Penjual, 1 = Pembeli
  int _userSubTab = 0;

  Timer? _autoRefreshTimer;

  final _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadAll();
      }
    });
  }

  // ALUR BARU: toko sekarang dibuat langsung oleh Admin lewat menu Pengguna
  // dan otomatis aktif — tidak ada lagi proses approval/verifikasi terpisah.
  void _loadAll() {
    _loadStats();
    _loadOrders();
    _loadUsers();
    _loadBuyers();
    _loadProducts();
    _loadStores();
    _loadWalletSummary();
  }

  Future<void> _loadWalletSummary() async {
    final token = _token;
    if (token == null) return;
    setState(() => _isLoadingWallet = true);
    try {
      final summary = await _adminService.getWalletSummary(token);
      if (!mounted) return;
      setState(() {
        final income = (summary['platform_income'] as num?)?.toDouble() ?? 0;
        _platformBalance =
            (summary['platform_balance'] as num?)?.toDouble() ?? income;
        _taxPercentage = (summary['tax_percentage'] as num?)?.toDouble() ?? 0;
      });
    } catch (_) {
      // Diamkan — kartu saldo cukup tampilkan 0 kalau gagal, tab Keuangan tetap terbuka.
    } finally {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  String? get _token {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.isAuthenticated ? auth.token : null;
  }

  Future<void> _loadStats() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });
    try {
      final data = await _adminService.getDashboardStats(token);
      if (mounted) setState(() => _stats = data);
    } catch (e) {
      if (mounted) setState(() => _statsError = 'Gagal memuat statistik: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadOrders() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });
    try {
      final data = await _adminService.getAdminOrders(token);
      if (mounted) setState(() => _orders = data);
    } catch (e) {
      if (mounted) setState(() => _ordersError = 'Gagal memuat pesanan: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _loadUsers() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });
    try {
      final data = await _adminService.getAdminUsers(token);
      if (mounted) setState(() => _users = data);
    } catch (e) {
      if (mounted) setState(() => _usersError = 'Gagal memuat pengguna: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadBuyers() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _isLoadingBuyers = true;
      _buyersError = null;
    });
    try {
      final data = await _adminService.getAdminBuyers(token);
      if (mounted) setState(() => _buyers = data);
    } catch (e) {
      if (mounted) setState(() => _buyersError = 'Gagal memuat pembeli: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBuyers = false);
    }
  }

  Future<void> _loadProducts() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final data = await _adminService.getAdminProducts(token);
      if (mounted) setState(() => _products = data);
    } catch (e) {
      if (mounted) setState(() => _productsError = 'Gagal memuat produk: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadStores() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _isLoadingStores = true;
      _storesError = null;
    });
    try {
      final data = await _adminService.getAdminStores(token);
      if (mounted) setState(() => _stores = data);
    } catch (e) {
      if (mounted) setState(() => _storesError = 'Gagal memuat toko: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  List<Map<String, dynamic>> get _sellerUsers => _users.where((u) {
    final role = (u['role'] ?? '').toString().toLowerCase();
    return role == 'seller' || role == 'penjual';
  }).toList();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final role = auth.user?.role.toLowerCase() ?? '';

    if (role != 'admin') {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(title: const Text('Akses Tidak Diizinkan')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hanya admin yang dapat mengakses halaman ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  HomeScreen.routeName,
                ),
                child: const Text('Kembali ke Beranda'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: isMobile
          ? SafeArea(
              child: Column(
                children: [
                  _buildHeader(auth),
                  Expanded(child: _buildTabContent()),
                ],
              ),
            )
          : SafeArea(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _buildHeaderDesktop(auth),
                        Expanded(child: _buildTabContent()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFF2A7F41),
            child: Icon(
              Icons.admin_panel_settings,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Platform',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(
                  auth.user?.name ?? 'Administrator',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleLogout,
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDesktop(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard Admin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              Text(
                auth.user?.name ?? 'Administrator',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          IconButton(
            onPressed: _handleLogout,
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, color: Colors.red, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF2A3F4B),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 8,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFF2A7F41)),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 24,
                    color: Color(0xFF2A7F41),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'BUMDES ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _sidebarItem(Icons.dashboard_outlined, 'DASHBOARD', 0),
                _sidebarItem(Icons.shopping_cart_outlined, 'PRODUK', 1),
                _sidebarItem(Icons.store_outlined, 'BUMDES', 2),
                _sidebarItem(Icons.receipt_outlined, 'PESANAN', 3),
                _sidebarItem(Icons.attach_money_outlined, 'KEUANGAN', 4),
                _sidebarItem(Icons.people_outline, 'PENGGUNA', 5),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        hoverColor: Colors.white10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withAlpha(25) : Colors.transparent,
            border: isSelected
                ? const Border(
                    right: BorderSide(color: Color(0xFF4CAF50), width: 4),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildProductsTab();
      case 2:
        return _buildStoresTab();
      case 3:
        return _buildOrdersTab();
      case 4:
        return _buildReportsTab();
      case 5:
        return _buildUsersTab();
      default:
        return _buildDashboardTab();
    }
  }

  // ── DASHBOARD TAB ────────────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    final balance = _platformBalance;
    final totalTransactions =
        (_stats['total_orders'] ??
                _stats['total_transactions'] ??
                _orders.length)
            as num;
    final totalUsers = (_stats['total_users'] ?? _users.length) as num;
    final totalStores = (_stats['total_stores'] ?? _stores.length) as num;

    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Platform',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_statsError != null)
              _buildErrorBanner(_statsError!, _loadStats),
            if (_isLoadingStats)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Saldo Admin',
                    _isLoadingWallet ? 'Memuat...' : _formatRupiah(balance),
                    Colors.green,
                    Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Toko',
                    totalStores.toString(),
                    Colors.teal,
                    Icons.store,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pesanan',
                    totalTransactions.toString(),
                    Colors.orange,
                    Icons.receipt_long,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pengguna',
                    totalUsers.toString(),
                    Colors.purple,
                    Icons.people,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aktivitas Terbaru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
Widget _buildRecentActivity() {
    final recentOrders = _orders.take(5).toList();
    if (_isLoadingOrders) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (recentOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: Text('Belum ada aktivitas terbaru')),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentOrders.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final order = recentOrders[index];
          // FIX: crossAxisAlignment.start + nomor pesanan dibatasi 1 baris
          // (ellipsis). Sebelumnya Row tanpa batas baris membuat nomor
          // pesanan yang panjang wrap ke 2-3 baris, dan karena Row
          // default-nya center, badge status jadi kelihatan naik/tidak
          // sejajar dengan teksnya.
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(
                    Icons.receipt_outlined,
                    color: Color(0xFF2A7F41),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pesanan #${order['order_number'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order['recipient_name'] ?? order['user']?['name'] ?? 'Pembeli'} • ${_formatRupiah(_parseDouble(order['total'] ?? order['total_price']))}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(order['status'] ?? '-'),
              ],
            ),
          );
        },
      ),
    );
  }
  // ── STORES TAB ───────────────────────────────────────────────────────────────

  Widget _buildStoresTab() => _buildAllStoresTab();

  Widget _buildAllStoresTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kelola Toko / BUMDes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_stores.length} toko terdaftar',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadStores,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_storesError != null)
            _buildErrorBanner(_storesError!, _loadStores),
          if (_isLoadingStores)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_stores.isEmpty)
            _buildEmptyState('Belum ada toko terdaftar', Icons.store_outlined)
          else
            PaginatedListView<Map<String, dynamic>>(
              items: _stores,
              pageSize: 10,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, store, index) => _buildStoreCard(store),
            ),
        ],
      ),
    );
  }

  // ── TAMBAHAN: helper avatar dari URL foto ────────────────────────────────
  // Dipakai untuk avatar Pembeli, Penjual, dan Toko di dashboard Admin.
  // Kalau [photoUrl] ada dan gambarnya berhasil dimuat, tampilkan foto asli
  // (dibulatkan). Kalau tidak ada atau gagal dimuat, tampilkan [fallback]
  // (inisial huruf atau icon generik) seperti sebelumnya.
  Widget _buildAvatarFromUrl(
    String? photoUrl, {
    required Widget fallback,
    double radius = 20,
  }) {
    if (photoUrl == null || photoUrl.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        photoUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }

Widget _buildStoreCard(Map<String, dynamic> store) {
    final name = store['store_name'] ?? store['name'] ?? '-';
    final owner = store['user']?['name'] ?? store['owner_name'] ?? '-';
    final ownerEmail = store['user']?['email'] ?? '-';
    final isActive = store['is_active'] == true;
    final revenue = _formatRupiah(
      _parseDouble(store['total_revenue'] ?? store['revenue']),
    );
    final storeId = store['id'] as int?;
    // FIX: sebelumnya cuma baca store['store_photo_url'] yang biasanya
    // belum diisi backend, jadi selalu jatuh ke ikon toko generik.
    // Sekarang diutamakan foto pemilik toko (user['photo_url']) — ini
    // yang sama dipakai di halaman Akun/Pengguna dan sudah terbukti ada
    // datanya (mis. foto BUMDes Garut) — baru fallback ke store_photo_url
    // kalau suatu saat backend punya foto toko sendiri yang terpisah.
    final storePhotoUrl =
        (store['user']?['photo_url'] as String?) ??
        (store['store_photo_url'] as String?);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE8F5E9),
                child: _buildAvatarFromUrl(
                  storePhotoUrl,
                  fallback: const Icon(Icons.store, color: Color(0xFF2A7F41)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Pemilik: $owner',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      ownerEmail,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Revenue: $revenue',
                      style: const TextStyle(
                        color: Color(0xFF2A7F41),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(isActive ? 'Aktif' : 'Nonaktif'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    isActive ? Icons.block : Icons.check_circle,
                    color: isActive ? Colors.red : Colors.green,
                    size: 16,
                  ),
                  label: Text(
                    isActive ? 'Nonaktifkan' : 'Aktifkan',
                    style: TextStyle(
                      color: isActive ? Colors.red : Colors.green,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isActive ? Colors.red : Colors.green,
                    ),
                  ),
                  onPressed: storeId == null
                      ? null
                      : () => _toggleStoreStatus(storeId, !isActive, name),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: storeId == null
                    ? null
                    : () async {
                        final confirm = await _showConfirmDialog(
                          'Hapus toko $name?',
                        );
                        if (confirm == true && _token != null) {
                          try {
                            await _adminService.deleteStore(_token!, storeId);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Toko $name berhasil dihapus'),
                                ),
                              );
                            }
                            _loadStores();
                          } catch (e) {
                            if (mounted) {
                              _showDeleteFailedDialog(
                                'Tidak Bisa Menghapus Toko',
                                e,
                              );
                            }
                          }
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
  Future<void> _toggleStoreStatus(
    int storeId,
    bool activate,
    String name,
  ) async {
    final token = _token;
    if (token == null) return;
    try {
      await _adminService.updateStore(token, storeId, {'is_active': activate});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Toko $name berhasil ${activate ? 'diaktifkan' : 'dinonaktifkan'}',
            ),
          ),
        );
        _loadStores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  // ── PRODUCTS TAB ─────────────────────────────────────────────────────────────

  Widget _buildProductsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manajemen Produk',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_productsError != null)
            _buildErrorBanner(_productsError!, _loadProducts),
          if (_isLoadingProducts)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_products.isEmpty)
            _buildEmptyState('Belum ada produk', Icons.shopping_cart_outlined)
          else
            _buildProductList(),
        ],
      ),
    );
  }

  // ── DIUBAH: layout responsif — card di HP, tabel di layar lebar ──────────
  Widget _buildProductList() {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: PaginatedListView<Map<String, dynamic>>(
          items: _products,
          pageSize: 10,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, p, index) => _buildProductCardMobile(p),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Produk',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Toko',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Harga',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 60),
              ],
            ),
          ),
          const Divider(height: 1),
          PaginatedListView<Map<String, dynamic>>(
            items: _products,
            pageSize: 10,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, p, index) => _buildProductRowDesktop(p),
          ),
        ],
      ),
    );
  }

  // TAMBAHAN: card produk untuk layar HP.
  Widget _buildProductCardMobile(Map<String, dynamic> p) {
    final productId = p['id'] as int?;
    final name = p['name'] ?? '-';
    final storeName = p['store']?['store_name'] ?? '-';
    final price = _formatRupiah(_parseDouble(p['price']));
    final status = p['product_approval']?['status'] ??
        (p['is_active'] == true ? 'Aktif' : 'Nonaktif');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.store, size: 13, color: Colors.black38),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        storeName,
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF2A7F41),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: productId == null
                ? null
                : () async {
                    final confirm = await _showConfirmDialog(
                      'Hapus produk ${p['name']}?',
                    );
                    if (confirm == true && _token != null) {
                      try {
                        await _adminService.deleteProduct(_token!, productId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Produk ${p['name']} berhasil dihapus',
                              ),
                            ),
                          );
                        }
                        _loadProducts();
                      } catch (e) {
                        if (mounted) {
                          _showDeleteFailedDialog(
                            'Tidak Bisa Menghapus Produk',
                            e,
                          );
                        }
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }

  // TAMBAHAN: baris tabel produk untuk layar lebar (logika sama seperti semula).
  Widget _buildProductRowDesktop(Map<String, dynamic> p) {
    final productId = p['id'] as int?;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              p['name'] ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              p['store']?['store_name'] ?? '-',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              _formatRupiah(_parseDouble(p['price'])),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: _buildStatusChip(
              p['product_approval']?['status'] ??
                  (p['is_active'] == true ? 'Aktif' : 'Nonaktif'),
            ),
          ),
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
                size: 20,
              ),
              onPressed: productId == null
                  ? null
                  : () async {
                      final confirm = await _showConfirmDialog(
                        'Hapus produk ${p['name']}?',
                      );
                      if (confirm == true && _token != null) {
                        try {
                          await _adminService.deleteProduct(
                            _token!,
                            productId,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Produk ${p['name']} berhasil dihapus',
                                ),
                              ),
                            );
                          }
                          _loadProducts();
                        } catch (e) {
                          if (mounted) {
                            _showDeleteFailedDialog(
                              'Tidak Bisa Menghapus Produk',
                              e,
                            );
                          }
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  // ── ORDERS TAB ───────────────────────────────────────────────────────────────

  Widget _buildOrdersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Pesanan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_ordersError != null)
            _buildErrorBanner(_ordersError!, _loadOrders),
          if (_isLoadingOrders)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_orders.isEmpty)
            _buildEmptyState('Belum ada pesanan', Icons.receipt_outlined)
          else
            _buildOrderList(),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: PaginatedListView<Map<String, dynamic>>(
        items: _orders,
        pageSize: 10,
        separatorBuilder: (_, __) => const Divider(height: 1),
        // FIX: dirombak dari Row 4-kolom rata (yang bikin nomor pesanan
        // panjang wrap dan badge status tidak sejajar) jadi card 2-baris:
        // baris atas = nomor pesanan (1 baris, ellipsis) + badge status,
        // baris bawah = nama pembeli (kiri) + total harga (kanan).
        itemBuilder: (context, order, index) {
          final status = order['status'] ?? '-';
          final buyerName =
              order['recipient_name'] ?? order['user']?['name'] ?? 'Pembeli';
          final total = _formatRupiah(
            _parseDouble(order['total'] ?? order['total_price']),
          );

          return Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '#${order['order_number'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        buyerName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      total,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A7F41),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── REPORTS TAB ───────────────────────────────────────────────────────────────

  Widget _buildReportsTab() {
    final totalRevenue = _parseDouble(_stats['total_revenue'] ?? 0);
    final totalOrders = (_stats['total_orders'] ?? _orders.length) as num;
    final totalUsers = (_stats['total_users'] ?? _users.length) as num;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Laporan & Analitik',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_statsError != null) _buildErrorBanner(_statsError!, _loadStats),
          if (_isLoadingStats) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 16),
          _buildReportCard(
            'Total Revenue',
            _formatRupiah(totalRevenue),
            'Seluruh waktu (omzet kotor, bukan saldo)',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'Total Pesanan',
            totalOrders.toString(),
            'Seluruh waktu',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'Total Pengguna',
            totalUsers.toString(),
            'Saat ini',
            Colors.purple,
          ),
          const SizedBox(height: 24),
          const Text(
            'Saldo & Pajak Platform',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Saldo ini berasal dari akumulasi biaya admin/pajak yang dipotong dari setiap pesanan penjual berstatus Selesai, DIKURANGI penarikan yang sudah dilakukan.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildPlatformWalletCard(),
        ],
      ),
    );
  }

  Widget _buildPlatformWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Platform Tersedia',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _isLoadingWallet
              ? const SizedBox(
                  height: 26,
                  width: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _formatRupiah(_platformBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 6),
          Text(
            'Tarif biaya admin saat ini: ${_taxPercentage.toStringAsFixed(0)}% dari tiap transaksi Selesai',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      AdminWalletScreen.routeName,
                    );
                    _loadWalletSummary();
                  },
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Tarik Saldo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1565C0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      AdminWalletScreen.routeName,
                    );
                    _loadWalletSummary();
                  },
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                  label: const Text(
                    'Lihat Detail',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String value,
    String period,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.show_chart, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  period,
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── USERS TAB ────────────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Penjual'),
                icon: Icon(Icons.store, size: 16),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Pembeli'),
                icon: Icon(Icons.person, size: 16),
              ),
            ],
            selected: {_userSubTab},
            onSelectionChanged: (s) => setState(() => _userSubTab = s.first),
          ),
        ),
        Expanded(
          child: _userSubTab == 0
              ? _buildUserList(_sellerUsers, showStoreInfo: true)
              : _buildBuyerList(),
        ),
      ],
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> userList, {
    bool showStoreInfo = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${userList.length} Penjual',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.refresh),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah'),
                    onPressed: () => _showUserFormDialog(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_usersError != null) _buildErrorBanner(_usersError!, _loadUsers),
          if (_isLoadingUsers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (userList.isEmpty)
            _buildEmptyState(
              'Belum ada penjual terdaftar',
              Icons.people_outline,
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: PaginatedListView<Map<String, dynamic>>(
                items: userList,
                pageSize: 10,
                separatorBuilder: (_, __) => const Divider(height: 1),
                // ── DIUBAH: layout responsif — card 2-baris di HP, Row lama di layar lebar
                itemBuilder: (context, user, index) {
                  final name = user['name'] ?? '-';
                  final id = user['id'] as int?;
                  final store = user['store'];
                  // TAMBAHAN: foto profil penjual, kalau backend sudah kirim photo_url
                  final photoUrl = user['photo_url'] as String?;
                  final isMobile = MediaQuery.of(context).size.width < 700;

                  if (isMobile) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Baris 1: avatar + nama + email — dapat lebar penuh
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.grey[200],
                                child: _buildAvatarFromUrl(
                                  photoUrl,
                                  fallback: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      user['email'] ?? '-',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Baris 2: info toko di kiri, role chip + aksi di kanan
                          Row(
                            children: [
                              Expanded(
                                child: showStoreInfo
                                    ? (store != null
                                        ? Row(
                                            children: [
                                              const Icon(
                                                Icons.store,
                                                size: 13,
                                                color: Colors.black38,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  store['store_name'] ?? '-',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black54,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _buildStatusChip(
                                                store['is_active'] == true
                                                    ? 'Aktif'
                                                    : 'Nonaktif',
                                              ),
                                            ],
                                          )
                                        : const Text(
                                            'Belum punya toko',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange,
                                            ),
                                          ))
                                    : const SizedBox.shrink(),
                              ),
                              Chip(
                                label: Text(
                                  user['role'] ?? '-',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: Colors.blue.withAlpha(50),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () => _showUserFormDialog(
                                  user: user,
                                  userId: id,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: id == null
                                    ? null
                                    : () async {
                                        final confirm =
                                            await _showConfirmDialog(
                                          'Hapus pengguna $name?',
                                        );
                                        if (confirm == true &&
                                            _token != null) {
                                          try {
                                            await _adminService.deleteUser(
                                              _token!,
                                              id,
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Pengguna $name berhasil dihapus',
                                                  ),
                                                ),
                                              );
                                            }
                                            _loadUsers();
                                          } catch (e) {
                                            if (mounted) {
                                              _showDeleteFailedDialog(
                                                'Tidak Bisa Menghapus Pengguna',
                                                e,
                                              );
                                            }
                                          }
                                        }
                                      },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  // ── Layout lama untuk layar lebar (tidak berubah) ──
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: _buildAvatarFromUrl(
                            photoUrl,
                            fallback: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user['email'] ?? '-',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              if (showStoreInfo && store != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.store,
                                      size: 13,
                                      color: Colors.black38,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        store['store_name'] ?? '-',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildStatusChip(
                                      store['is_active'] == true
                                          ? 'Aktif'
                                          : 'Nonaktif',
                                    ),
                                  ],
                                ),
                              ] else if (showStoreInfo && store == null) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Belum punya toko',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            user['role'] ?? '-',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue.withAlpha(50),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _showUserFormDialog(user: user, userId: id),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: id == null
                                  ? null
                                  : () async {
                                      final confirm = await _showConfirmDialog(
                                        'Hapus pengguna $name?',
                                      );
                                      if (confirm == true && _token != null) {
                                        try {
                                          await _adminService.deleteUser(
                                            _token!,
                                            id,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Pengguna $name berhasil dihapus',
                                                ),
                                              ),
                                            );
                                          }
                                          _loadUsers();
                                        } catch (e) {
                                          if (mounted) {
                                            _showDeleteFailedDialog(
                                              'Tidak Bisa Menghapus Pengguna',
                                              e,
                                            );
                                          }
                                        }
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Daftar Pembeli — read-only, cuma tombol hapus, tanpa tombol Tambah/Ubah.
  Widget _buildBuyerList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_buyers.length} Pembeli',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _loadBuyers,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_buyersError != null)
            _buildErrorBanner(_buyersError!, _loadBuyers),
          if (_isLoadingBuyers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_buyers.isEmpty)
            _buildEmptyState(
              'Belum ada pembeli terdaftar',
              Icons.person_outline,
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: PaginatedListView<Map<String, dynamic>>(
                items: _buyers,
                pageSize: 10,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, buyer, index) {
                  final name = buyer['name'] ?? '-';
                  final id = buyer['id'] as int?;
                  // TAMBAHAN: foto profil pembeli, kalau backend sudah kirim photo_url
                  final photoUrl = buyer['photo_url'] as String?;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: _buildAvatarFromUrl(
                            photoUrl,
                            fallback: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                buyer['email'] ?? '-',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${buyer['total_orders'] ?? 0} pesanan',
                                style: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: id == null
                              ? null
                              : () async {
                                  final confirm = await _showConfirmDialog(
                                    'Hapus pembeli $name?',
                                  );
                                  if (confirm == true && _token != null) {
                                    try {
                                      await _adminService.deleteUser(
                                        _token!,
                                        id,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Pembeli $name berhasil dihapus',
                                            ),
                                          ),
                                        );
                                      }
                                      _loadBuyers();
                                    } catch (e) {
                                      if (mounted) {
                                        _showDeleteFailedDialog(
                                          'Tidak Bisa Menghapus Pembeli',
                                          e,
                                        );
                                      }
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;
    final labelFontSize = isCompact ? 10.0 : 11.5;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.shopping_cart_outlined),
        selectedIcon: Icon(Icons.shopping_cart),
        label: 'Produk',
      ),
      const NavigationDestination(
        icon: Icon(Icons.store_outlined),
        selectedIcon: Icon(Icons.store),
        label: 'BUMDes',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_outlined),
        selectedIcon: Icon(Icons.receipt),
        label: 'Pesanan',
      ),
      const NavigationDestination(
        icon: Icon(Icons.attach_money_outlined),
        selectedIcon: Icon(Icons.attach_money),
        label: 'Keuangan',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Pengguna',
      ),
    ];

    return SafeArea(
      top: false,
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          indicatorColor: const Color(0xFF2A7F41).withValues(alpha: 0.16),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: labelFontSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF2A7F41)
                  : const Color(0xFF64748B),
              letterSpacing: 0.1,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: isCompact ? 22 : 24,
              color: isSelected
                  ? const Color(0xFF2A7F41)
                  : const Color(0xFF64748B),
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex > 5 ? 0 : _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          elevation: 8,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: destinations,
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────────

  Widget _buildErrorBanner(String message, VoidCallback onRetry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.black45, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'aktif':
      case 'selesai':
      case 'dikonfirmasi':
        color = Colors.green;
        break;
      case 'diproses':
      case 'dikirim':
      case 'menunggu pembayaran':
      case 'menunggu konfirmasi':
        color = Colors.orange;
        break;
      case 'nonaktif':
      case 'ditolak':
      case 'dibatalkan':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatRupiah(double value) {
    if (value == 0) return 'Rp 0';
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    final chars = str.split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    if (value is num) return value.toDouble();
    return 0;
  }

  Future<bool?> _showConfirmDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  String _cleanErrorMessage(Object error) {
    final raw = error.toString();
    final match = RegExp(
      r'^[A-Za-z_]+\(\d+\):\s*(.*)$',
      dotAll: true,
    ).firstMatch(raw);
    if (match != null &&
        match.group(1) != null &&
        match.group(1)!.trim().isNotEmpty) {
      return match.group(1)!.trim();
    }
    return raw.replaceFirst('Exception: ', '').trim();
  }

  Future<void> _showDeleteFailedDialog(String title, Object error) {
    final message = _cleanErrorMessage(error);
    final isBusinessRule =
        message.contains('pesanan yang sedang berjalan') ||
        message.contains('data terkait') ||
        message.contains('riwayat pesanan');

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isBusinessRule ? Icons.info_outline : Icons.error_outline,
          color: isBusinessRule ? Colors.orange : Colors.red,
          size: 36,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  // ── DIROMBAK TOTAL: dialog "Tambah/Ubah Penjual" (ini juga yang jadi
  // form "Daftarkan Toko Penjual") sebelumnya semua field ditumpuk rapat
  // tanpa jarak/border yang jelas dan dialog tidak dibatasi lebarnya —
  // itu penyebab tampilan "berantakan" di HP/web. Sekarang:
  //   1) Lebar & tinggi dialog dibatasi rapi (ConstrainedBox) supaya tidak
  //      mepet ke tepi layar dan tidak terlalu tinggi.
  //   2) Tiap field dikasih border kotak (OutlineInputBorder) + jarak antar
  //      field yang konsisten (12px).
  //   3) Tiap bagian (Akun, Toko, Rekening) dibungkus card abu-abu supaya
  //      jelas kelompoknya — bukan cuma judul teks nempel ke field.
  Future<void> _showUserFormDialog({
    Map<String, dynamic>? user,
    int? userId,
  }) async {
    final isEditing = user != null;
    final existingStore = user?['store'] as Map<String, dynamic>?;

    final nameCtrl = TextEditingController(text: user?['name'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');

    final storeNameCtrl = TextEditingController(
      text: existingStore?['store_name'] ?? '',
    );
    final storeDescCtrl = TextEditingController(
      text: existingStore?['description'] ?? '',
    );
    final villageCtrl = TextEditingController(
      text: existingStore?['village'] ?? '',
    );
    final districtCtrl = TextEditingController(
      text: existingStore?['district'] ?? '',
    );
    final regencyCtrl = TextEditingController(
      text: existingStore?['regency'] ?? '',
    );
    final storePhoneCtrl = TextEditingController(
      text: existingStore?['contact_phone'] ?? '',
    );
    final storeAddressCtrl = TextEditingController(
      text: existingStore?['address'] ?? '',
    );
    final bankNameCtrl = TextEditingController(
      text: existingStore?['bank_name'] ?? '',
    );
    final bankNumberCtrl = TextEditingController(
      text: existingStore?['bank_account_number'] ?? '',
    );
    final bankHolderCtrl = TextEditingController(
      text: existingStore?['bank_account_holder'] ?? '',
    );

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    const labelColor = Color(0xFF2A7F41);
    OutlineInputBorder fieldBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    InputDecoration fieldDecoration(String label, {String? helper}) =>
        InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: fieldBorder(const Color(0xFFCBD5C0)),
          enabledBorder: fieldBorder(const Color(0xFFCBD5C0)),
          focusedBorder: fieldBorder(labelColor, width: 1.6),
          errorBorder: fieldBorder(Colors.red),
        );

    Widget sectionCard({
      required String title,
      String? subtitle,
      required List<Widget> fields,
    }) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE7D8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: labelColor,
                fontSize: 14,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            for (int i = 0; i < fields.length; i++) ...[
              fields[i],
              if (i != fields.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final screenSize = MediaQuery.of(ctx).size;
          final dialogWidth = screenSize.width < 560
              ? screenSize.width * 0.94
              : 520.0;
          final dialogMaxHeight = screenSize.height * 0.85;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: dialogMaxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                    decoration: const BoxDecoration(
                      color: labelColor,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isEditing ? Icons.edit : Icons.store,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEditing
                                ? 'Ubah Penjual & Toko'
                                : 'Daftarkan Toko Penjual',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.white),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  // Body (scrollable)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionCard(
                              title: 'Data Akun',
                              fields: [
                                TextFormField(
                                  controller: nameCtrl,
                                  decoration: fieldDecoration('Nama'),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                TextFormField(
                                  controller: emailCtrl,
                                  decoration: fieldDecoration('Email'),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                TextFormField(
                                  controller: phoneCtrl,
                                  decoration:
                                      fieldDecoration('Nomor Telepon'),
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                TextFormField(
                                  controller: passwordCtrl,
                                  obscureText: true,
                                  decoration: fieldDecoration(
                                    isEditing
                                        ? 'Password Baru (opsional)'
                                        : 'Password',
                                    helper: isEditing
                                        ? 'Kosongkan jika tidak ingin mengubah password'
                                        : 'Minimal 8 karakter, dipakai Penjual untuk login',
                                  ),
                                  validator: (v) {
                                    if (!isEditing &&
                                        (v == null || v.isEmpty)) {
                                      return 'Wajib diisi';
                                    }
                                    if (v != null &&
                                        v.isNotEmpty &&
                                        v.length < 8) {
                                      return 'Minimal 8 karakter';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            sectionCard(
                              title: 'Data Toko / BUMDes',
                              subtitle: isEditing
                                  ? 'Data toko akan diperbarui bersamaan dengan akun ini.'
                                  : 'Toko akan dibuat otomatis dan langsung aktif bersamaan dengan akun ini.',
                              fields: [
                                TextFormField(
                                  controller: storeNameCtrl,
                                  decoration:
                                      fieldDecoration('Nama BUMDes/Toko'),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                TextFormField(
                                  controller: storeDescCtrl,
                                  decoration: fieldDecoration(
                                    'Deskripsi (opsional)',
                                  ),
                                  maxLines: 2,
                                ),
                                TextFormField(
                                  controller: storePhoneCtrl,
                                  decoration:
                                      fieldDecoration('Nomor Telepon Toko'),
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                TextFormField(
                                  controller: storeAddressCtrl,
                                  decoration: fieldDecoration(
                                    'Alamat Toko (opsional)',
                                  ),
                                  maxLines: 2,
                                ),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: villageCtrl,
                                        decoration:
                                            fieldDecoration('Desa'),
                                        validator: (v) =>
                                            v == null || v.isEmpty
                                                ? 'Wajib'
                                                : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: districtCtrl,
                                        decoration:
                                            fieldDecoration('Kecamatan'),
                                        validator: (v) =>
                                            v == null || v.isEmpty
                                                ? 'Wajib'
                                                : null,
                                      ),
                                    ),
                                  ],
                                ),
                                TextFormField(
                                  controller: regencyCtrl,
                                  decoration:
                                      fieldDecoration('Kabupaten/Kota'),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                              ],
                            ),
                            sectionCard(
                              title: 'Data Rekening (Opsional)',
                              fields: [
                                TextFormField(
                                  controller: bankNameCtrl,
                                  decoration: fieldDecoration('Nama Bank'),
                                ),
                                TextFormField(
                                  controller: bankNumberCtrl,
                                  decoration:
                                      fieldDecoration('No. Rekening'),
                                  keyboardType: TextInputType.number,
                                ),
                                TextFormField(
                                  controller: bankHolderCtrl,
                                  decoration: fieldDecoration(
                                    'Nama Pemilik Rekening',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Footer actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFE3E9E1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: labelColor,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!(formKey.currentState?.validate() ??
                                        false)) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Mohon lengkapi semua field yang wajib diisi',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() => isSaving = true);
                                    try {
                                      final data = <String, dynamic>{
                                        'name': nameCtrl.text.trim(),
                                        'email': emailCtrl.text.trim(),
                                        'phone': phoneCtrl.text.trim(),
                                        if (passwordCtrl.text.isNotEmpty)
                                          'password': passwordCtrl.text,
                                        'role': 'Penjual',
                                        'store_name':
                                            storeNameCtrl.text.trim(),
                                        'description':
                                            storeDescCtrl.text.trim(),
                                        'contact_phone':
                                            storePhoneCtrl.text.trim(),
                                        'store_address':
                                            storeAddressCtrl.text.trim(),
                                        'village': villageCtrl.text.trim(),
                                        'district':
                                            districtCtrl.text.trim(),
                                        'regency': regencyCtrl.text.trim(),
                                        if (bankNameCtrl.text.isNotEmpty)
                                          'bank_name':
                                              bankNameCtrl.text.trim(),
                                        if (bankNumberCtrl.text.isNotEmpty)
                                          'bank_account_number':
                                              bankNumberCtrl.text.trim(),
                                        if (bankHolderCtrl.text.isNotEmpty)
                                          'bank_account_holder':
                                              bankHolderCtrl.text.trim(),
                                      };

                                      if (isEditing &&
                                          userId != null &&
                                          _token != null) {
                                        await _adminService.updateUser(
                                          _token!,
                                          userId,
                                          data,
                                        );
                                      } else if (_token != null) {
                                        await _adminService.createUser(
                                          _token!,
                                          data,
                                        );
                                      }

                                      if (mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isEditing
                                                  ? 'Penjual ${nameCtrl.text.trim()} berhasil diperbarui'
                                                  : 'Penjual ${nameCtrl.text.trim()} berhasil ditambahkan dan toko langsung aktif',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                      _loadUsers();
                                      _loadStores();
                                    } catch (e) {
                                      setDialogState(() => isSaving = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(ctx)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Gagal menyimpan pengguna: ${_cleanErrorMessage(e)}',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isEditing ? 'Simpan' : 'Daftarkan',
                                    style:
                                        const TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
}