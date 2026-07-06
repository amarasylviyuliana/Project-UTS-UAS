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
  bool _isLoadingProducts = false;
  bool _isLoadingStores = false;
  bool _isLoadingStoreApprovals = false;

  String? _statsError;
  String? _ordersError;
  String? _usersError;
  String? _productsError;
  String? _storesError;
  String? _storeApprovalsError;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _storeApprovals = [];

  double _platformBalance = 0;
  double _taxPercentage = 0;
  bool _isLoadingWallet = false;

  final _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  void _loadAll() {
    _loadStats();
    _loadOrders();
    _loadUsers();
    _loadProducts();
    _loadStores();
    _loadStoreApprovals();
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
    setState(() { _isLoadingStats = true; _statsError = null; });
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
    setState(() { _isLoadingOrders = true; _ordersError = null; });
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
    setState(() { _isLoadingUsers = true; _usersError = null; });
    try {
      final data = await _adminService.getAdminUsers(token);
      if (mounted) setState(() => _users = data);
    } catch (e) {
      if (mounted) setState(() => _usersError = 'Gagal memuat pengguna: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadProducts() async {
    final token = _token;
    if (token == null) return;
    setState(() { _isLoadingProducts = true; _productsError = null; });
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
    setState(() { _isLoadingStores = true; _storesError = null; });
    try {
      final data = await _adminService.getAdminStores(token);
      if (mounted) setState(() => _stores = data);
    } catch (e) {
      if (mounted) setState(() => _storesError = 'Gagal memuat toko: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _loadStoreApprovals() async {
    final token = _token;
    if (token == null) return;
    setState(() { _isLoadingStoreApprovals = true; _storeApprovalsError = null; });
    try {
      final data = await _adminService.getStoreApprovals(token);
      if (mounted) setState(() => _storeApprovals = data);
    } catch (e) {
      if (mounted) setState(() => _storeApprovalsError = 'Gagal memuat persetujuan toko: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStoreApprovals = false);
    }
  }

  int get _pendingApprovalsCount => _storeApprovals.where((s) {
    final status = (s['status'] ?? '').toString().toLowerCase();
    return status.contains('menunggu') || status.contains('pending') || status.isEmpty;
  }).length;

  List<Map<String, dynamic>> get _sellerUsers => _users.where((u) {
    final role = (u['role'] ?? '').toString().toLowerCase();
    return role == 'seller' || role == 'penjual';
  }).toList();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final role = auth.user?.role?.toLowerCase() ?? '';

    if (role != 'admin') {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(title: const Text('Akses Tidak Diizinkan')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Hanya admin yang dapat mengakses halaman ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, HomeScreen.routeName),
            child: const Text('Kembali ke Beranda'),
          ),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: isMobile
          ? SafeArea(child: Column(children: [
              _buildHeader(auth),
              Expanded(child: _buildTabContent()),
            ]))
          : SafeArea(child: Row(children: [
              _buildSidebar(),
              Expanded(child: Column(children: [
                _buildHeaderDesktop(auth),
                Expanded(child: _buildTabContent()),
              ])),
            ])),
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      child: Row(children: [
        const CircleAvatar(radius: 28, backgroundColor: Color(0xFF2A7F41),
            child: Icon(Icons.admin_panel_settings, size: 28, color: Colors.white)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Admin Platform', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text(auth.user?.name ?? 'Administrator',
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ])),
        IconButton(
            onPressed: () => Navigator.pushNamed(context, AdminWalletScreen.routeName),
            tooltip: 'Saldo & Pajak',
            icon: const Icon(Icons.account_balance_wallet, color: Color(0xFF2A7F41))),
        IconButton(onPressed: _handleLogout, tooltip: 'Keluar', icon: const Icon(Icons.logout, color: Colors.red)),
      ]),
    );
  }

  Widget _buildHeaderDesktop(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dashboard Admin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          Text(auth.user?.name ?? 'Administrator',
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
        ]),
        IconButton(
            onPressed: () => Navigator.pushNamed(context, AdminWalletScreen.routeName),
            tooltip: 'Saldo & Pajak',
            icon: const Icon(Icons.account_balance_wallet, color: Color(0xFF2A7F41), size: 28)),
        IconButton(onPressed: _handleLogout, tooltip: 'Keluar',
            icon: const Icon(Icons.logout, color: Colors.red, size: 28)),
      ]),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(color: Color(0xFF2A3F4B),
          boxShadow: [BoxShadow(color: Color.fromRGBO(0,0,0,0.1), blurRadius: 8, offset: Offset(2,0))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xFF2A7F41)),
          child: const Column(children: [
            CircleAvatar(radius: 24, backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, size: 24, color: Color(0xFF2A7F41))),
            SizedBox(height: 8),
            Text('BUMDES ADMIN',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          _sidebarItem(Icons.dashboard_outlined, 'DASHBOARD', 0),
          _sidebarItem(Icons.shopping_cart_outlined, 'PRODUK', 1),
          _sidebarItemWithBadge(Icons.store_outlined, 'BUMDES', 2, _pendingApprovalsCount),
          _sidebarItem(Icons.receipt_outlined, 'PESANAN', 3),
          _sidebarItem(Icons.attach_money_outlined, 'KEUANGAN', 4),
          _sidebarItem(Icons.people_outline, 'PENGGUNA', 5),
          // FIX: Tab Verifikasi dihapus dari sidebar
        ])),
      ]),
    );
  }

  Widget _sidebarItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Material(color: Colors.transparent,
      child: InkWell(onTap: () => setState(() => _selectedIndex = index), hoverColor: Colors.white10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withAlpha(25) : Colors.transparent,
            border: isSelected ? const Border(right: BorderSide(color: Color(0xFF4CAF50), width: 4)) : null,
          ),
          child: Row(children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12, letterSpacing: 0.5,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _sidebarItemWithBadge(IconData icon, String label, int index, int badgeCount) {
    final isSelected = _selectedIndex == index;
    return Material(color: Colors.transparent,
      child: InkWell(onTap: () => setState(() => _selectedIndex = index), hoverColor: Colors.white10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withAlpha(25) : Colors.transparent,
            border: isSelected ? const Border(right: BorderSide(color: Color(0xFF4CAF50), width: 4)) : null,
          ),
          child: Row(children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12, letterSpacing: 0.5,
            ))),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                child: Text('$badgeCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardTab();
      case 1: return _buildProductsTab();
      case 2: return _buildStoresTab();
      case 3: return _buildOrdersTab();
      case 4: return _buildReportsTab();
      case 5: return _buildUsersTab();
      default: return _buildDashboardTab();
    }
  }

  // ── DASHBOARD TAB ────────────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    final balance = _parseDouble(_stats['total_revenue'] ?? _stats['current_balance'] ?? 0);
    final totalTransactions = (_stats['total_orders'] ?? _stats['total_transactions'] ?? _orders.length) as num;
    final totalUsers = (_stats['total_users'] ?? _users.length) as num;
    final totalStores = (_stats['total_stores'] ?? _stores.length) as num;

    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ringkasan Platform', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_statsError != null) _buildErrorBanner(_statsError!, _loadStats),
          if (_isLoadingStats) const Padding(padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 3)),
          Row(children: [
            Expanded(child: _buildStatCard('Saldo Admin', _formatRupiah(balance), Colors.green, Icons.account_balance_wallet)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Total Toko', totalStores.toString(), Colors.teal, Icons.store)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildStatCard('Pesanan', totalTransactions.toString(), Colors.orange, Icons.receipt_long)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Pengguna', totalUsers.toString(), Colors.purple, Icons.people)),
          ]),
          const SizedBox(height: 12),
          if (_pendingApprovalsCount > 0)
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 2),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.withAlpha(100))),
                child: Row(children: [
                  const Icon(Icons.store, color: Colors.teal, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$_pendingApprovalsCount toko menunggu persetujuan',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    const Text('Tap untuk review', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ])),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
                ]),
              ),
            ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Aktivitas Terbaru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(onPressed: _loadAll,
                icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
          ]),
          const SizedBox(height: 12),
          _buildRecentActivity(),
        ]),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(38), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ]),
    );
  }

  Widget _buildRecentActivity() {
    final recentOrders = _orders.take(5).toList();
    if (_isLoadingOrders) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    if (recentOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
        child: const Center(child: Text('Belum ada aktivitas terbaru')),
      );
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
      child: ListView.separated(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: recentOrders.length, separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final order = recentOrders[index];
          return Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            const CircleAvatar(radius: 20, backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.receipt_outlined, color: Color(0xFF2A7F41), size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pesanan #${order['order_number'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${order['recipient_name'] ?? order['user']?['name'] ?? 'Pembeli'} • ${_formatRupiah(_parseDouble(order['total'] ?? order['total_price']))}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ])),
            _buildStatusChip(order['status'] ?? '-'),
          ]));
        },
      ),
    );
  }

  // ── STORES TAB ───────────────────────────────────────────────────────────────

  Widget _buildStoresTab() {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(color: Colors.white,
          child: TabBar(
            labelColor: const Color(0xFF2A7F41),
            unselectedLabelColor: Colors.black54,
            indicatorColor: const Color(0xFF2A7F41),
            tabs: [
              const Tab(text: 'Semua Toko'),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Persetujuan'),
                if (_pendingApprovalsCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    child: Text('$_pendingApprovalsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ])),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _buildAllStoresTab(),
          _buildStoreApprovalsTab(),
        ])),
      ]),
    );
  }

  Widget _buildAllStoresTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kelola Toko / BUMDes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('${_stores.length} toko terdaftar', style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ]),
          IconButton(onPressed: _loadStores, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        if (_storesError != null) _buildErrorBanner(_storesError!, _loadStores),
        if (_isLoadingStores)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_stores.isEmpty)
          _buildEmptyState('Belum ada toko terdaftar', Icons.store_outlined)
        else
          PaginatedListView<Map<String, dynamic>>(
            items: _stores,
            pageSize: 10,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, store, index) => _buildStoreCard(store),
          ),
      ]),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    final name = store['store_name'] ?? store['name'] ?? '-';
    final owner = store['user']?['name'] ?? store['owner_name'] ?? '-';
    final ownerEmail = store['user']?['email'] ?? '-';
    final isActive = store['is_active'] == true;
    final approvalStatus = store['approval_status'] as String?;
    // Tampilkan approval_status jika ada, kalau tidak pakai is_active
    final displayStatus = (approvalStatus != null && approvalStatus.isNotEmpty)
        ? approvalStatus
        : (isActive ? 'Aktif' : 'Nonaktif');
    // Tombol aktifkan/nonaktifkan hanya muncul jika sudah disetujui admin
    final isApproved = approvalStatus == 'Disetujui';
    final revenue = _formatRupiah(_parseDouble(store['total_revenue'] ?? store['revenue']));
    final storeId = store['id'] as int?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.store, color: Color(0xFF2A7F41))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('Pemilik: $owner', style: const TextStyle(color: Colors.black54, fontSize: 13)),
            Text(ownerEmail, style: const TextStyle(color: Colors.black38, fontSize: 12)),
            Text('Revenue: $revenue', style: const TextStyle(color: Color(0xFF2A7F41), fontWeight: FontWeight.w600, fontSize: 13)),
          ])),
          // FIX: chip berdasarkan approval_status
          _buildStatusChip(displayStatus),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: isApproved
              ? OutlinedButton.icon(
                  icon: Icon(isActive ? Icons.block : Icons.check_circle,
                      color: isActive ? Colors.red : Colors.green, size: 16),
                  label: Text(isActive ? 'Nonaktifkan' : 'Aktifkan',
                      style: TextStyle(color: isActive ? Colors.red : Colors.green)),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isActive ? Colors.red : Colors.green)),
                  onPressed: storeId == null ? null : () => _toggleStoreStatus(storeId, !isActive, name),
                )
              : OutlinedButton.icon(
                  icon: const Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
                  label: Text(
                    approvalStatus == 'Ditolak' ? 'Ditolak' : 'Menunggu Persetujuan',
                    style: const TextStyle(color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange)),
                  onPressed: null,
                ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red, size: 16),
            label: const Text('Hapus', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            onPressed: storeId == null ? null : () async {
              final confirm = await _showConfirmDialog('Hapus toko $name?');
              if (confirm == true && _token != null) {
                await _adminService.deleteStore(_token!, storeId);
                _loadStores();
              }
            },
          ),
        ]),
      ]),
    );
  }

  Future<void> _toggleStoreStatus(int storeId, bool activate, String name) async {
    final token = _token;
    if (token == null) return;
    try {
      await _adminService.updateStore(token, storeId, {'is_active': activate});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Toko $name berhasil ${activate ? 'diaktifkan' : 'dinonaktifkan'}'),
        ));
        _loadStores();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  // ── STORE APPROVALS TAB ──────────────────────────────────────────────────────

  Widget _buildStoreApprovalsTab() {
    final pending = _storeApprovals.where((s) {
      final status = (s['status'] ?? '').toString().toLowerCase();
      return status.contains('menunggu') || status.contains('pending') || status.isEmpty;
    }).toList();

    final processed = _storeApprovals.where((s) {
      final status = (s['status'] ?? '').toString().toLowerCase();
      return status == 'disetujui' || status == 'ditolak';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Persetujuan Toko', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('${pending.length} menunggu persetujuan',
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ]),
          IconButton(onPressed: _loadStoreApprovals, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        if (_storeApprovalsError != null) _buildErrorBanner(_storeApprovalsError!, _loadStoreApprovals),
        if (_isLoadingStoreApprovals)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (pending.isEmpty && processed.isEmpty)
          _buildEmptyState('Tidak ada permohonan persetujuan toko', Icons.store_outlined)
        else ...[
          if (pending.isNotEmpty) ...[
            const Text('Menunggu Persetujuan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.orange)),
            const SizedBox(height: 12),
            PaginatedListView<Map<String, dynamic>>(
              items: pending,
              pageSize: 10,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, item, index) => _buildStoreApprovalCard(item),
            ),
            const SizedBox(height: 24),
          ],
          if (processed.isNotEmpty) ...[
            const Text('Sudah Diproses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 12),
            PaginatedListView<Map<String, dynamic>>(
              items: processed,
              pageSize: 10,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, item, index) =>
                  _buildStoreApprovalCard(item, readonly: true),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _buildStoreApprovalCard(Map<String, dynamic> approval, {bool readonly = false}) {
    final id = approval['id'] as int?;
    // FIX: Data store ada di approval['store']
    final store = approval['store'] as Map<String, dynamic>?;
    final storeName = store?['store_name'] ?? approval['store_name'] ?? '-';

    // FIX: Biodata penjual dari store.user
    final user = store?['user'] as Map<String, dynamic>?;
    final ownerName = user?['name'] ?? '-';
    final ownerEmail = user?['email'] ?? '-';

    // FIX: Info toko dari store object
    final village = store?['village'] ?? '-';
    final district = store?['district'] ?? '-';
    final regency = store?['regency'] ?? '-';
    final phone = store?['contact_phone'] ?? '-';
    final bankName = store?['bank_name'] ?? '-';
    final bankNumber = store?['bank_account_number'] ?? '-';
    final bankHolder = store?['bank_account_holder'] ?? '-';
    final description = store?['description'] ?? '';

    final status = approval['status'] ?? 'Menunggu Persetujuan';
    final rejectedReason = approval['rejected_reason'] ?? '';
    final createdAt = approval['created_at'] != null
        ? approval['created_at'].toString().substring(0, 10) : '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: Colors.teal[100],
              child: const Icon(Icons.store, color: Colors.teal)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('Pemilik: $ownerName', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            Text(ownerEmail, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            Text('Daftar: $createdAt', style: const TextStyle(color: Colors.black38, fontSize: 11)),
          ])),
          _buildStatusChip(status),
        ]),
        const SizedBox(height: 12),
        // FIX: Tampilkan biodata lengkap toko
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Info Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            if (description.isNotEmpty) _infoRow(Icons.description_outlined, description),
            _infoRow(Icons.location_on_outlined, '$village, $district, $regency'),
            _infoRow(Icons.phone_outlined, phone),
            const SizedBox(height: 4),
            const Text('Rekening Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            _infoRow(Icons.account_balance_outlined, '$bankName — $bankNumber a/n $bankHolder'),
          ]),
        ),
        if (rejectedReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text('Alasan: $rejectedReason',
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
            ]),
          ),
        ],
        if (!readonly) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text('Tolak', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                onPressed: id == null ? null : () => _handleStoreApproval(id, 'Ditolak', storeName),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Setujui'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A7F41)),
                onPressed: id == null ? null : () => _handleStoreApproval(id, 'Disetujui', storeName),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54))),
      ]),
    );
  }

  Future<void> _handleStoreApproval(int approvalId, String status, String storeName) async {
    final token = _token;
    if (token == null) return;

    String? reason;
    if (status == 'Ditolak') {
      reason = await _showRejectReasonDialog();
      if (reason == null) return;
    }

    try {
      await _adminService.approveStore(token, approvalId, status, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'Disetujui'
              ? 'Toko $storeName telah disetujui' : 'Toko $storeName ditolak'),
          backgroundColor: status == 'Disetujui' ? Colors.green : Colors.red,
        ));
        // FIX: Auto-refresh setelah approve/reject
        _loadStoreApprovals();
        _loadStores();
        _loadStats();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  // ── PRODUCTS TAB ─────────────────────────────────────────────────────────────

  Widget _buildProductsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Manajemen Produk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          IconButton(onPressed: _loadProducts, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        if (_productsError != null) _buildErrorBanner(_productsError!, _loadProducts),
        if (_isLoadingProducts)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_products.isEmpty)
          _buildEmptyState('Belum ada produk', Icons.shopping_cart_outlined)
        else _buildProductList(),
      ]),
    );
  }

  Widget _buildProductList() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(16), child: Row(children: [
          Expanded(flex: 3, child: Text('Produk', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Toko', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Harga', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 60),
        ])),
        const Divider(height: 1),
        PaginatedListView<Map<String, dynamic>>(
          items: _products,
          pageSize: 10,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, p, index) {
            final productId = p['id'] as int?;
            return Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              Expanded(flex: 3, child: Text(p['name'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Text(p['store']?['store_name'] ?? '-',
                  style: const TextStyle(color: Colors.black54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Expanded(child: Text(_formatRupiah(_parseDouble(p['price'])), style: const TextStyle(fontSize: 13))),
              Expanded(child: _buildStatusChip(p['product_approval']?['status'] ?? (p['is_active'] == true ? 'Aktif' : 'Nonaktif'))),
              SizedBox(width: 60, child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: productId == null ? null : () async {
                  final confirm = await _showConfirmDialog('Hapus produk ${p['name']}?');
                  if (confirm == true && _token != null) {
                    await _adminService.deleteProduct(_token!, productId);
                    _loadProducts();
                  }
                },
              )),
            ]));
          },
        ),
      ]),
    );
  }

  // ── ORDERS TAB ───────────────────────────────────────────────────────────────

  Widget _buildOrdersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Daftar Pesanan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        if (_ordersError != null) _buildErrorBanner(_ordersError!, _loadOrders),
        if (_isLoadingOrders)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_orders.isEmpty)
          _buildEmptyState('Belum ada pesanan', Icons.receipt_outlined)
        else _buildOrderList(),
      ]),
    );
  }

  Widget _buildOrderList() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
      child: PaginatedListView<Map<String, dynamic>>(
        items: _orders,
        pageSize: 10,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, order, index) {
          final id = order['id'] as int?;
          final status = order['status'] ?? '-';
          return Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(flex: 2, child: Text('#${order['order_number'] ?? 'N/A'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(flex: 2, child: Text(order['recipient_name'] ?? order['user']?['name'] ?? 'Pembeli',
                style: const TextStyle(fontSize: 13))),
            Expanded(child: Text(_formatRupiah(_parseDouble(order['total'] ?? order['total_price'])),
                style: const TextStyle(fontSize: 13))),
            Expanded(child: _buildStatusChip(status)),
           Row(mainAxisSize: MainAxisSize.min, children: [
              // FIX: sebelumnya tombol ini muncul untuk SEMUA status selain
              // Dikonfirmasi/Selesai/Dibatalkan — termasuk "Menunggu Pembayaran",
              // sehingga Admin bisa "mengkonfirmasi" pesanan yang belum benar-benar
              // dibayar. Sekarang hanya muncul saat pesanan sudah "Menunggu
              // Konfirmasi" (bukti pembayaran sudah diunggah Pembeli), sesuai alur
              // bisnis yang seharusnya diverifikasi lewat proses pembayaran.
              if (status == 'Menunggu Konfirmasi')
                TextButton(onPressed: id == null || _token == null ? null : () async {
                  await _adminService.updateOrderStatus(_token!, id, 'Dikonfirmasi');
                  _loadOrders();
                }, child: const Text('Konfirmasi', style: TextStyle(fontSize: 11))),
            ]),
          ]));
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Laporan & Analitik', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh)),
        ]),
        if (_statsError != null) _buildErrorBanner(_statsError!, _loadStats),
        if (_isLoadingStats) const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 16),
        _buildReportCard('Total Revenue', _formatRupiah(totalRevenue), 'Seluruh waktu', Colors.green),
        const SizedBox(height: 12),
        _buildReportCard('Total Pesanan', totalOrders.toString(), 'Seluruh waktu', Colors.blue),
        const SizedBox(height: 12),
        _buildReportCard('Total Pengguna', totalUsers.toString(), 'Saat ini', Colors.purple),
        const SizedBox(height: 24),
        const Text('Saldo & Pajak Platform', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Saldo ini berasal dari akumulasi biaya admin/pajak yang dipotong dari setiap pesanan penjual berstatus Selesai.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildPlatformWalletCard(),
      ]),
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
          const Text('Saldo Platform Tersedia', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          _isLoadingWallet
              ? const SizedBox(
                  height: 26,
                  width: 26,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _formatRupiah(_platformBalance),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
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
                    await Navigator.pushNamed(context, AdminWalletScreen.routeName);
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
                    await Navigator.pushNamed(context, AdminWalletScreen.routeName);
                    _loadWalletSummary();
                  },
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                  label: const Text('Lihat Detail', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(String title, String value, String period, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withAlpha(38), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.show_chart, color: color, size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(period, style: const TextStyle(fontSize: 12, color: Colors.black38)),
        ])),
      ]),
    );
  }

  // ── USERS TAB ────────────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    final sellers = _sellerUsers;
    final buyers = _users.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase();
      return role == 'buyer' || role == 'pembeli';
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Container(color: Colors.white, child: TabBar(
          labelColor: const Color(0xFF2A7F41),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF2A7F41),
          tabs: [Tab(text: 'Semua (${_users.length})'),
            Tab(text: 'Penjual (${sellers.length})'),
            Tab(text: 'Pembeli (${buyers.length})')],
        )),
        Expanded(child: TabBarView(children: [
          _buildUserList(_users),
          _buildUserList(sellers, showStoreInfo: true),
          _buildUserList(buyers),
        ])),
      ]),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> userList, {bool showStoreInfo = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${userList.length} Pengguna', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Row(children: [
            IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh)),
            ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Tambah'),
                onPressed: () => _showUserFormDialog()),
          ]),
        ]),
        const SizedBox(height: 16),
        if (_usersError != null) _buildErrorBanner(_usersError!, _loadUsers),
        if (_isLoadingUsers)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (userList.isEmpty)
          _buildEmptyState('Belum ada pengguna', Icons.people_outline)
        else Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.05), blurRadius: 12, offset: Offset(0,4))]),
          child: PaginatedListView<Map<String, dynamic>>(
            items: userList,
            pageSize: 10,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, user, index) {
              final name = user['name'] ?? '-';
              final id = user['id'] as int?;
              final store = user['store'];
              return Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                CircleAvatar(backgroundColor: Colors.grey[200],
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(user['email'] ?? '-', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  if (showStoreInfo && store != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.store, size: 13, color: Colors.black38),
                      const SizedBox(width: 4),
                      Expanded(child: Text(store['store_name'] ?? '-',
                          style: const TextStyle(fontSize: 12, color: Colors.black54), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      _buildStatusChip(store['store_approval']?['status'] ?? (store['is_active'] == true ? 'Aktif' : 'Nonaktif')),
                    ]),
                  ] else if (showStoreInfo && store == null) ...[
                    const SizedBox(height: 4),
                    const Text('Belum punya toko', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ],
                ])),
                const SizedBox(width: 8),
                Chip(label: Text(user['role'] ?? '-', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.blue.withAlpha(50)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () => _showUserFormDialog(user: user, userId: id)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: id == null ? null : () async {
                        final confirm = await _showConfirmDialog('Hapus pengguna $name?');
                        if (confirm == true && _token != null) {
                          await _adminService.deleteUser(_token!, id);
                          _loadUsers();
                        }
                      }),
                ]),
              ]));
            },
          ),
        ),
      ]),
    );
  }

  // ── BOTTOM NAV (FIX: hapus tab Verifikasi) ────────────────────────────────────

  Widget _buildBottomNav() {
    final destinations = [
      const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard'),
      const NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart),
          label: 'Produk'),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _pendingApprovalsCount > 0,
          smallSize: 8,
          backgroundColor: Colors.red,
          child: const Icon(Icons.store_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: _pendingApprovalsCount > 0,
          smallSize: 8,
          backgroundColor: Colors.red,
          child: const Icon(Icons.store),
        ),
        label: 'BUMDes',
      ),
      const NavigationDestination(
          icon: Icon(Icons.receipt_outlined),
          selectedIcon: Icon(Icons.receipt),
          label: 'Pesanan'),
      const NavigationDestination(
          icon: Icon(Icons.attach_money_outlined),
          selectedIcon: Icon(Icons.attach_money),
          label: 'Keuangan'),
      const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Pengguna'),
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
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
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

  Widget _buildErrorBanner(String message, VoidCallback onRetry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.red, fontSize: 13))),
        TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
      ]),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(child: Padding(padding: const EdgeInsets.all(48), child: Column(children: [
      Icon(icon, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(color: Colors.black45, fontSize: 16)),
    ])));
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'aktif': case 'selesai': case 'dikonfirmasi': case 'terverifikasi': case 'disetujui':
        color = Colors.green; break;
      case 'diproses': case 'dikirim': case 'menunggu verifikasi':
      case 'menunggu persetujuan': case 'menunggu pembayaran': case 'menunggu konfirmasi':
        color = Colors.orange; break;
      case 'nonaktif': case 'ditolak': case 'dibatalkan':
        color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(38), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
          overflow: TextOverflow.ellipsis),
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
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    if (value is num) return value.toDouble();
    return 0;
  }

  Future<bool?> _showConfirmDialog(String message) {
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Konfirmasi'), content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
      ],
    ));
  }

  Future<String?> _showRejectReasonDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Alasan Penolakan'),
      content: TextField(controller: ctrl,
          decoration: const InputDecoration(hintText: 'Tulis alasan penolakan...'),
          maxLines: 3),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Kirim')),
      ],
    ));
  }

  Future<void> _showUserFormDialog({Map<String, dynamic>? user, int? userId}) async {
    final isEditing = user != null;
    final nameCtrl = TextEditingController(text: user?['name'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    String selectedRole = user?['role'] ?? 'pembeli';
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(isEditing ? 'Ubah Pengguna' : 'Tambah Pengguna'),
        content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama'),
              validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
          TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: selectedRole,
              decoration: const InputDecoration(labelText: 'Peran'),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'seller', child: Text('Penjual')),
                DropdownMenuItem(value: 'buyer', child: Text('Pembeli')),
              ],
              onChanged: (v) { if (v != null) setDialogState(() => selectedRole = v); }),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () async {
            if (formKey.currentState?.validate() ?? false) {
              final data = {'name': nameCtrl.text.trim(), 'email': emailCtrl.text.trim(), 'role': selectedRole};
              if (isEditing && userId != null && _token != null) {
                await _adminService.updateUser(_token!, userId, data);
              } else if (_token != null) {
                await _adminService.createUser(_token!, data);
              }
              if (mounted) Navigator.pop(ctx);
              _loadUsers();
            }
          }, child: Text(isEditing ? 'Simpan' : 'Tambah')),
        ],
      ),
    ));
  }

  Future<void> _handleLogout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
}