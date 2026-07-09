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
    // FIX: sebelumnya kartu "Saldo Admin" memakai `total_revenue`, yaitu
    // TOTAL NILAI SEMUA PESANAN BERSTATUS SELESAI (omzet kotor seluruh
    // waktu) — bukan saldo platform yang sebenarnya, dan tidak pernah
    // berkurang meskipun saldo sudah ditarik lewat menu Keuangan. Itu
    // sebabnya angkanya tetap "Rp 25.000" walau saldo asli di halaman
    // Keuangan sudah Rp 0 setelah ditarik.
    // Sekarang kartu ini memakai `_platformBalance`, yaitu saldo platform
    // yang SUDAH memperhitungkan penarikan — sama seperti yang ditampilkan
    // di halaman Keuangan (Saldo Platform Tersedia).
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
                    _isLoadingWallet
                        ? 'Memuat...'
                        : _formatRupiah(balance),
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
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                      ),
                      Text(
                        '${order['recipient_name'] ?? order['user']?['name'] ?? 'Pembeli'} • ${_formatRupiah(_parseDouble(order['total'] ?? order['total_price']))}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(order['status'] ?? '-'),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── STORES TAB ───────────────────────────────────────────────────────────────
  // ALUR BARU: toko selalu aktif sejak dibuat Admin, jadi tab BUMDES cukup
  // satu daftar "Semua Toko" — tidak ada lagi sub-tab Persetujuan.

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

  Widget _buildStoreCard(Map<String, dynamic> store) {
    final name = store['store_name'] ?? store['name'] ?? '-';
    final owner = store['user']?['name'] ?? store['owner_name'] ?? '-';
    final ownerEmail = store['user']?['email'] ?? '-';
    final isActive = store['is_active'] == true;
    final revenue = _formatRupiah(
      _parseDouble(store['total_revenue'] ?? store['revenue']),
    );
    final storeId = store['id'] as int?;

    // 👈 sesuaikan nama field: coba beberapa kemungkinan lokasi foto toko
    // (foto toko sendiri, atau foto pemilik/user-nya sebagai fallback).
    final photoUrl = _extractPhotoUrl(store) ?? _extractPhotoUrl(store['user']);

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
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE8F5E9),
                child: _buildAvatarContent(
                  photoUrl,
                  size: 48,
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

  Widget _buildProductList() {
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
            itemBuilder: (context, p, index) {
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
            },
          ),
        ],
      ),
    );
  }

  // ── ORDERS TAB ───────────────────────────────────────────────────────────────
  // ALUR BARU: Admin hanya MEMANTAU pesanan (read-only). Perubahan status
  // pesanan (konfirmasi, kirim, selesai, batal) sepenuhnya menjadi tanggung
  // jawab Penjual lewat aplikasinya sendiri, jadi tombol "Konfirmasi" yang
  // dulu ada di sini sudah dihapus.

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
        itemBuilder: (context, order, index) {
          final status = order['status'] ?? '-';
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '#${order['order_number'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    order['recipient_name'] ??
                        order['user']?['name'] ??
                        'Pembeli',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatRupiah(
                      _parseDouble(order['total'] ?? order['total_price']),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(child: _buildStatusChip(status)),
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
            // Catatan: ini omzet KOTOR seluruh waktu (jumlah total_price
            // semua pesanan Selesai), sengaja TIDAK berkurang walau saldo
            // sudah ditarik lewat menu Keuangan — ini metrik historis, bukan
            // saldo yang bisa ditarik. Untuk saldo yang bisa ditarik, lihat
            // kartu "Saldo Platform Tersedia" di bawah.
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
  // ALUR BARU: menu Pengguna sekarang punya sub-tab Semua/Penjual/Pembeli.
  // Pembeli read-only, cuma bisa dilihat + dihapus, karena Pembeli daftar
  // sendiri lewat app.

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
            _buildEmptyState('Belum ada penjual terdaftar', Icons.people_outline)
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
                itemBuilder: (context, user, index) {
                  final name = user['name'] ?? '-';
                  final id = user['id'] as int?;
                  final store = user['store'];
                  // 👈 sesuaikan nama field kalau backend kamu pakai key lain
                  final photoUrl = _extractPhotoUrl(user);
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: _buildAvatarContent(
                            photoUrl,
                            size: 40,
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
                              // FIX: dulu tidak ada try/catch di sini, jadi
                              // kalau backend menolak (mis. penjual ini masih
                              // punya toko/produk/pesanan terkait), error-nya
                              // hilang begitu saja dan admin tidak tahu
                              // kenapa data tidak terhapus.
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
  // Pembeli daftar sendiri lewat app, bukan dibuatkan Admin.
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
                  // 👈 sesuaikan nama field kalau backend kamu pakai key lain
                  final photoUrl = _extractPhotoUrl(buyer);
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: _buildAvatarContent(
                            photoUrl,
                            size: 40,
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
                        // FIX UTAMA: dulu error 409 dari backend (mis.
                        // "Pengguna ini masih memiliki N pesanan yang
                        // sedang berjalan...") ditampilkan APA ADANYA lewat
                        // e.toString(), termasuk prefix teknis semacam
                        // "ApiException(409): ...". Sekarang pesannya
                        // dibersihkan dulu lewat _cleanErrorMessage() dan
                        // ditampilkan sebagai dialog yang rapi lewat
                        // _showDeleteFailedDialog(), bukan SnackBar merah
                        // berisi detail teknis.
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

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF2A7F41) : Colors.black54,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex > 5 ? 0 : _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        elevation: 8,
        height: 68,
        indicatorColor: const Color(0xFF2A7F41).withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: destinations,
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────────

  /// Ambil URL foto dari sebuah map user/toko, mencoba beberapa
  /// kemungkinan nama field yang umum dipakai backend (photo_url, photo,
  /// avatar, image, logo, dst). Kembalikan null kalau tidak ada satupun
  /// yang cocok / isinya kosong.
  ///
  /// 👈 CATATAN: kalau setelah dicoba foto tetap tidak muncul, print salah
  /// satu item map user/toko (mis. `print(_users.first)`) untuk lihat nama
  /// field foto yang sebenarnya dikirim backend, lalu tambahkan ke daftar
  /// kandidat di bawah ini.
  String? _extractPhotoUrl(dynamic source) {
    if (source is! Map<String, dynamic>) return null;
    const candidateKeys = [
      'photo_url',
      'photo',
      'avatar',
      'avatar_url',
      'image',
      'image_url',
      'logo',
      'logo_url',
      'profile_photo_url',
    ];
    for (final key in candidateKeys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  /// Widget isi avatar: kalau ada [photoUrl], tampilkan gambarnya (dengan
  /// fallback otomatis ke [fallback] kalau gagal dimuat / masih loading
  /// ditampilkan spinner kecil). Kalau [photoUrl] null/kosong, langsung
  /// tampilkan [fallback].
  Widget _buildAvatarContent(
    String? photoUrl, {
    required Widget fallback,
    double size = 40,
  }) {
    if (photoUrl == null || photoUrl.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Gagal load foto dari "$photoUrl": $error');
          return fallback;
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

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

  /// Ambil pesan error yang "bersih" dari sebuah Exception, tanpa embel-embel
  /// nama class teknis seperti "ApiException(409): " di depannya — supaya
  /// yang tampil ke Admin cuma kalimat penjelasannya saja, bukan detail
  /// implementasi (nama class exception, kode status, dsb).
  String _cleanErrorMessage(Object error) {
    final raw = error.toString();
    // Pola umum exception di project ini: "NamaClass(kode): pesan".
    final match = RegExp(
      r'^[A-Za-z_]+\(\d+\):\s*(.*)$',
      dotAll: true,
    ).firstMatch(raw);
    if (match != null &&
        match.group(1) != null &&
        match.group(1)!.trim().isNotEmpty) {
      return match.group(1)!.trim();
    }
    // Fallback: buang prefix generik "Exception: " kalau ada.
    return raw.replaceFirst('Exception: ', '').trim();
  }

  /// Tampilkan dialog rapi saat suatu penghapusan gagal, alih-alih SnackBar
  /// merah berisi detail teknis (nama class exception, kode status, dsb).
  ///
  /// - Kalau pesannya adalah aturan bisnis yang wajar (mis. "masih ada
  ///   pesanan yang sedang berjalan" / "masih ada data terkait"), dialog
  ///   dipakaikan ikon info berwarna oranye — ini bukan bug, cuma aturan.
  /// - Selain itu, dipakaikan ikon error merah seperti biasa.
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

  // ── FORM TAMBAH/EDIT PENGGUNA ────────────────────────────────────────────────
  // ALUR BARU: Admin bisa membuat akun dengan peran Admin, Penjual, atau
  // Pembeli. Kalau peran Penjual, data toko/BUMDes wajib diisi sekaligus di
  // form ini — backend membuat User + Store dalam satu transaksi dan
  // langsung aktif (tidak ada lagi proses approval).
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

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Ubah Penjual' : 'Tambah Penjual'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data Akun',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2A7F41),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nama'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Telepon',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEditing
                            ? 'Password Baru (opsional)'
                            : 'Password',
                        helperText: isEditing
                            ? 'Kosongkan jika tidak ingin mengubah password'
                            : 'Minimal 8 karakter, digunakan Penjual untuk login',
                      ),
                      validator: (v) {
                        if (!isEditing && (v == null || v.isEmpty)) {
                          return 'Wajib diisi';
                        }
                        if (v != null && v.isNotEmpty && v.length < 8) {
                          return 'Minimal 8 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Data Toko / BUMDes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2A7F41),
                      ),
                    ),
                    Text(
                      isEditing
                          ? 'Data toko akan diperbarui bersamaan dengan akun ini.'
                          : 'Toko akan dibuat otomatis dan langsung aktif bersamaan dengan akun ini.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: storeNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama BUMDes/Toko',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    TextFormField(
                      controller: storeDescCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi (opsional)',
                      ),
                      maxLines: 2,
                    ),
                    TextFormField(
                      controller: storePhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Telepon Toko',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    TextFormField(
                      controller: storeAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Toko (opsional)',
                      ),
                      maxLines: 2,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: villageCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Desa',
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Wajib' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: districtCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Kecamatan',
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Wajib' : null,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: regencyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kabupaten/Kota',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Data Rekening (Opsional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2A7F41),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: bankNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Bank',
                      ),
                    ),
                    TextFormField(
                      controller: bankNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'No. Rekening',
                      ),
                    ),
                    TextFormField(
                      controller: bankHolderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pemilik Rekening',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
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
                            'store_name': storeNameCtrl.text.trim(),
                            'description': storeDescCtrl.text.trim(),
                            'contact_phone': storePhoneCtrl.text.trim(),
                            'store_address': storeAddressCtrl.text.trim(),
                            'village': villageCtrl.text.trim(),
                            'district': districtCtrl.text.trim(),
                            'regency': regencyCtrl.text.trim(),
                            if (bankNameCtrl.text.isNotEmpty)
                              'bank_name': bankNameCtrl.text.trim(),
                            if (bankNumberCtrl.text.isNotEmpty)
                              'bank_account_number':
                                  bankNumberCtrl.text.trim(),
                            if (bankHolderCtrl.text.isNotEmpty)
                              'bank_account_holder':
                                  bankHolderCtrl.text.trim(),
                          };

                          if (isEditing && userId != null && _token != null) {
                            await _adminService.updateUser(
                              _token!,
                              userId,
                              data,
                            );
                          } else if (_token != null) {
                            await _adminService.createUser(_token!, data);
                          }

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
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
                            ScaffoldMessenger.of(ctx).showSnackBar(
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
                    : Text(isEditing ? 'Simpan' : 'Tambah'),
              ),
            ],
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