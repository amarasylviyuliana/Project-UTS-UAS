import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/financial_report_model.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/report_service.dart';
import '../utils/format_helper.dart';
import 'home_screen.dart';
import 'product_form_screen.dart';
import 'store_form_screen.dart';
import 'seller_wallet_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'seller_orders_screen.dart';
import 'financial_report_detail_screen.dart';

class StoreDashboardScreen extends StatefulWidget {
  static const routeName = '/store-dashboard';
  const StoreDashboardScreen({super.key});

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  final _searchController = TextEditingController();
  final ProductService _productService = ProductService();
  List<ProductModel> _sellerProducts = [];
  bool _sellerProductsLoaded = false;
  bool _loadingProducts = false;
  List<OrderModel> _sellerOrders = [];
  bool _loadingOrders = false;
  FinancialReportModel? _financialReport;
  bool _loadingReport = false;
  final ReportService _reportService = ReportService();

  // Status aktif/nonaktif toko (ditentukan Admin), bukan lagi status approval.
  // null  = toko belum dibuat Admin untuk akun ini
  // true  = toko aktif
  // false = toko dinonaktifkan Admin
  bool? _isStoreApproved;
  bool _checkingStoreStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSellerOrders();
      _loadSellerProducts();
      _checkStoreApprovalStatus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkStoreApprovalStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _checkingStoreStatus = true);
    try {
      final approved = await _productService.isStoreApproved(auth.token!);
      if (mounted) {
        setState(() {
          _isStoreApproved = approved;
          _checkingStoreStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStoreApproved = false;
          _checkingStoreStatus = false;
        });
      }
    }
  }

  Future<void> _loadSellerProducts() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _loadingProducts = true);
    try {
      final products = await _productService.fetchProductsByStore(auth.token!);
      if (mounted) {
        setState(() {
          _sellerProducts = products;
          _loadingProducts = false;
          _sellerProductsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading seller products: $e');
      if (mounted) {
        setState(() {
          _loadingProducts = false;
          _sellerProductsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadSellerOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _loadingOrders = true);
    try {
      final orderService = OrderService();
      final orders = await orderService.getSellerOrders(auth.token!);
      if (mounted) {
        setState(() {
          _sellerOrders = orders;
          _loadingOrders = false;
        });
        _loadFinancialReport();
      }
    } catch (e) {
      debugPrint('Error loading seller orders: $e');
      if (mounted) {
        setState(() => _loadingOrders = false);
      }
    }
  }

  Future<void> _loadFinancialReport() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _loadingReport = true);
    try {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, now.day);
      final report = _reportService.calculateFromOrders(
        _sellerOrders,
        startDate: lastMonth,
        endDate: now,
      );
      if (mounted) {
        setState(() {
          _financialReport = report;
          _loadingReport = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading financial report: $e');
      if (mounted) {
        setState(() {
          _financialReport = FinancialReportModel(
            totalRevenue: 0,
            totalExpense: 0,
            netProfit: 0,
            totalOrders: 0,
            completedOrders: 0,
            transactions: [],
            period: 'Custom',
            startDate: DateTime.now().subtract(const Duration(days: 30)),
            endDate: DateTime.now(),
          );
          _loadingReport = false;
        });
      }
    }
  }

  String _bulanIndo(int bulan) {
    const bulanList = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return bulanList[bulan];
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final products = _sellerProductsLoaded ? _sellerProducts : <ProductModel>[];
    final filteredProducts = products.where((product) {
      final matchesQuery =
          _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'Semua' ||
          product.category.contains(_selectedCategory) ||
          _selectedCategory.contains(product.category);
      return matchesQuery && matchesCategory;
    }).toList();

    if (auth.user?.role != 'seller') {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(title: const Text('Akses Tidak Diizinkan')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hanya penjual yang dapat mengakses halaman ini.',
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
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final popped = await Navigator.maybePop(context);
        if (!popped && mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            HomeScreen.routeName,
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(auth),
              Expanded(child: _buildTabContent(auth, filteredProducts)),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    final photoUrl = auth.user?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      width: double.infinity,
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
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF2A7F41),
            backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
            child: hasPhoto
                ? null
                : const Icon(Icons.storefront, size: 28, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  auth.user?.name ?? 'Penjual BUMDes',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              _loadSellerOrders();
              _loadSellerProducts();
              _checkStoreApprovalStatus();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data diperbarui'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => _showHeaderOptions(context),
            tooltip: 'Menu Lainnya',
            icon: const Icon(Icons.more_vert, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    AuthProvider auth,
    List<ProductModel> filteredProducts,
  ) {
    switch (_selectedIndex) {
      case 1:
        return _buildProductsTab(auth, filteredProducts);
      case 2:
        return _buildOrdersTab();
      case 3:
        return _buildReportsTab();
      case 4:
        return _buildProfileTab(auth);
      default:
        return _buildDashboardTab();
    }
  }

  void _onMenuTap(String label) {
    switch (label) {
      case 'Katalog':
        setState(() => _selectedIndex = 1);
        break;
      case 'Pesanan':
        setState(() => _selectedIndex = 2);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label - Fitur sedang dikembangkan'),
            duration: const Duration(milliseconds: 1200),
          ),
        );
    }
  }

  Future<void> _handleLogout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showHeaderOptions(BuildContext context) async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
      items: [
        const PopupMenuItem(value: 'profile', child: Text('Lihat Profil')),
        const PopupMenuItem(value: 'settings', child: Text('Pengaturan')),
        const PopupMenuItem(value: 'help', child: Text('Bantuan & FAQ')),
        const PopupMenuItem(
          value: 'logout',
          child: Text('Keluar', style: TextStyle(color: Colors.red)),
        ),
      ],
    );

    if (selected == null) return;
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (selected) {
        case 'profile':
          Navigator.pushNamed(context, EditProfileScreen.routeName);
          break;
        case 'settings':
          Navigator.pushNamed(context, SettingsScreen.routeName);
          break;
        case 'help':
          Navigator.pushNamed(context, HelpScreen.routeName);
          break;
        case 'logout':
          _handleLogout();
          break;
      }
    });
  }

  // ── DASHBOARD TAB ──────────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    final waitingConfirmation = _sellerOrders
        .where(
          (o) =>
              o.status == 'Menunggu Pembayaran' ||
              o.status == 'Menunggu Konfirmasi',
        )
        .length;
    final processingOrders = _sellerOrders
        .where((o) => o.status == 'Dikonfirmasi' || o.status == 'Diproses')
        .length;
    final shippingOrders = _sellerOrders
        .where((o) => o.status == 'Dikirim')
        .length;
    final completedOrders = _sellerOrders
        .where((o) => o.status == 'Selesai')
        .length;
    final totalOrders = _sellerOrders.length;
    final cancelledOrders = _sellerOrders
        .where((o) => o.status == 'Dibatalkan')
        .length;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadSellerOrders();
        await _loadSellerProducts();
        await _checkStoreApprovalStatus();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStoreStatusBanner(),
            _buildBalanceCard(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Produk Saya',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _loadingProducts
                ? const Center(child: CircularProgressIndicator())
                : _sellerProducts.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Belum ada produk',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _sellerProducts.take(5).length,
                      itemBuilder: (context, index) {
                        final product = _sellerProducts[index];
                        return Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                                child: _buildProductImage(
                                  product.imageUrl,
                                  100,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rp ${product.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo Penjual',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Lihat ringkasan toko dan pesanan terbaru Anda di sini.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    shadowColor: Colors.black26,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _onMenuTap('Pesanan'),
                  icon: const Icon(Icons.receipt_long, size: 20),
                  label: const Text(
                    'Lihat Pesanan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loadingOrders)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _buildSummaryCard(
                    'Total Pesanan',
                    '$totalOrders',
                    Colors.green,
                  ),
                  _buildSummaryCard(
                    'Menunggu Konfirmasi',
                    '$waitingConfirmation',
                    Colors.orange,
                  ),
                  _buildSummaryCard(
                    'Sedang Diproses',
                    '$processingOrders',
                    const Color(0xFFFFC107),
                  ),
                  _buildSummaryCard(
                    'Sedang Dikirim',
                    '$shippingOrders',
                    Colors.blue,
                  ),
                  _buildSummaryCard(
                    'Selesai',
                    '$completedOrders',
                    Colors.purple,
                  ),
                  _buildSummaryCard(
                    'Dibatalkan',
                    '$cancelledOrders',
                    Colors.red,
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.06),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktivitas Terbaru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTaskCard(
                    'Konfirmasi pembayaran',
                    '$waitingConfirmation transaksi menunggu konfirmasi.',
                    Icons.payment,
                    Colors.orange,
                    onTap: () => _onMenuTap('Pesanan'),
                  ),
                  const SizedBox(height: 12),
                  _buildTaskCard(
                    'Produk unggulan',
                    'Periksa dan perbarui stok produk terlaris.',
                    Icons.shopping_bag,
                    Colors.green,
                    onTap: () => _onMenuTap('Katalog'),
                  ),
                  const SizedBox(height: 12),
                  _buildTaskCard(
                    'Buka pesanan',
                    'Lihat detail pesanan masuk dan proses pengiriman.',
                    Icons.local_shipping,
                    Colors.blue,
                    onTap: () => _onMenuTap('Pesanan'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── STORE STATUS BANNER ────────────────────────────────────────────────────

  Widget _buildStoreStatusBanner() {
    // Sekarang toko dibuat langsung oleh Admin dan otomatis aktif,
    // jadi Penjual tidak bisa lagi "mendaftarkan" toko sendiri.
    if (_checkingStoreStatus) {
      // Masih loading, jangan tampilkan apa-apa
      return const SizedBox.shrink();
    }

    if (_isStoreApproved == null) {
      // Toko belum dibuat oleh Admin untuk akun ini
      return _buildBanner(
        'Toko belum dibuat oleh Admin',
        'Akun Penjual Anda belum memiliki data toko/BUMDes. '
            'Silakan hubungi Admin BUMDes untuk mengaktifkan toko Anda.',
        Colors.orange,
        Icons.store_outlined,
        null,
        null,
      );
    }

    if (_isStoreApproved == true) {
      // Toko aktif — tidak perlu tampilkan banner apapun
      return const SizedBox.shrink();
    }

    // _isStoreApproved == false → toko ada tapi dinonaktifkan Admin
    return _buildBanner(
      'Toko dinonaktifkan Admin',
      'Toko Anda saat ini dinonaktifkan oleh Admin BUMDes. '
          'Hubungi Admin jika Anda merasa ini keliru.',
      Colors.red,
      Icons.pause_circle_outline,
      null,
      null,
    );
  }

  Widget _buildBanner(
    String title,
    String subtitle,
    Color color,
    IconData icon,
    String? buttonLabel,
    VoidCallback? onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (buttonLabel != null && onTap != null) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final totalRevenue = _sellerOrders
        .where((o) => o.status == 'Selesai' || o.status == 'Dikonfirmasi')
        .fold(0.0, (sum, o) => sum + o.total);

    final pendingRevenue = _sellerOrders
        .where((o) => o.status == 'Diproses' || o.status == 'Dikirim')
        .fold(0.0, (sum, o) => sum + o.total);

    final now = DateTime.now();
    final dateStr = 'Per ${now.day} ${_bulanIndo(now.month)} ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A7F41),
        borderRadius: BorderRadius.circular(24),
      ),
      child: _loadingOrders
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo Kas Toko',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rp ${totalRevenue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (pendingRevenue > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Dalam proses: Rp ${pendingRevenue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  // ── PRODUCTS TAB (FIX: Cek status toko + fix popup menu) ──────────────────

  Widget _buildProductsTab(AuthProvider auth, List<ProductModel> products) {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final filteredProducts = products.where((product) {
      final matchesQuery =
          _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'Semua' || product.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Katalog Produk',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // FIX: Tombol tambah hanya aktif jika toko sudah disetujui
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
                onPressed: () async {
                  if (auth.token == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Silakan login terlebih dahulu'),
                      ),
                    );
                    return;
                  }

                  // Blokir tambah produk jika toko belum dibuat/dinonaktifkan Admin
                  final isActive = _isStoreApproved ?? false;
                  if (!isActive) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Toko Anda belum aktif. Hubungi Admin BUMDes '
                          'untuk mengaktifkan toko sebelum menambah produk.',
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }

                  final result = await Navigator.pushNamed(
                    context,
                    ProductFormScreen.routeName,
                  );
                  if (result == true && mounted) {
                    await _loadSellerProducts();
                  }
                },
              ),
            ],
          ),
        ),
        // Banner peringatan jika toko belum aktif
        if (_isStoreApproved == false)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withAlpha(100)),
            ),
            child: Row(
              children: const [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toko belum aktif. Anda tidak dapat menambah produk.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              _buildSearchInput(),
              const SizedBox(height: 12),
              _buildCategoryChips(),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loadingProducts && !_sellerProductsLoaded
              ? const Center(child: CircularProgressIndicator())
              : filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _sellerProducts.isEmpty
                            ? 'Belum ada produk'
                            : 'Tidak ada produk sesuai pencarian',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSellerProducts,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // FIX: kolom grid menyesuaikan lebar layar, bukan
                      // di-hardcode 2 terus — di HP tetap 2, tapi di
                      // tablet/desktop otomatis nambah biar tidak boros
                      // ruang kosong dan card tidak melebar aneh.
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 1100
                          ? 5
                          : width >= 850
                          ? 4
                          : width >= 600
                          ? 3
                          : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _ProductCard(
                            product: product,
                            onEdit: () {
                              final ctx = context;
                              WidgetsBinding.instance.addPostFrameCallback((
                                _,
                              ) async {
                                if (!mounted) return;
                                final updated = await Navigator.of(ctx)
                                    .pushNamed(
                                      ProductFormScreen.routeName,
                                      arguments: {'product': product},
                                    );
                                if (updated == true && mounted) {
                                  await _loadSellerProducts();
                                }
                              });
                            },
                            onDelete: () => _confirmDeleteProduct(
                              context,
                              product,
                              provider,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    ProductModel product,
    ProductProvider provider,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Produk'),
          content: Text('Anda yakin ingin menghapus ${product.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (shouldDelete == true) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      try {
        await provider.deleteProduct(auth.token!, product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Produk ${product.name} berhasil dihapus.')),
          );
          await _loadSellerProducts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menghapus produk: $e')));
        }
      }
    }
  }

  // ── ORDERS TAB (FIX: layout card pesanan dirapikan) ───────────────────────

  Widget _buildOrdersTab() {
    final pendingCount = _sellerOrders
        .where(
          (o) =>
              o.status == 'Menunggu Pembayaran' ||
              o.status == 'Menunggu Konfirmasi',
        )
        .length;
    final processingCount = _sellerOrders
        .where((o) => o.status == 'Dikonfirmasi' || o.status == 'Diproses')
        .length;
    final shippingCount = _sellerOrders
        .where((o) => o.status == 'Dikirim')
        .length;
    final completedCount = _sellerOrders
        .where((o) => o.status == 'Selesai')
        .length;
    final cancelledCount = _sellerOrders
        .where((o) => o.status == 'Dibatalkan')
        .length;

    return RefreshIndicator(
      onRefresh: _loadSellerOrders,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pesanan Masuk',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildOrderStatusCard(
              'Menunggu Konfirmasi',
              '$pendingCount Pesanan',
              Colors.orange,
              ['Menunggu Pembayaran', 'Menunggu Konfirmasi'],
            ),
            const SizedBox(height: 12),
            _buildOrderStatusCard(
              'Sedang Diproses',
              '$processingCount Pesanan',
              const Color(0xFFFFC107),
              ['Dikonfirmasi', 'Diproses'],
            ),
            const SizedBox(height: 12),
            _buildOrderStatusCard(
              'Sedang Dikirim',
              '$shippingCount Pesanan',
              Colors.blue,
              ['Dikirim'],
            ),
            const SizedBox(height: 12),
            _buildOrderStatusCard(
              'Selesai',
              '$completedCount Pesanan',
              Colors.green,
              ['Selesai'],
            ),
            const SizedBox(height: 12),
            _buildOrderStatusCard(
              'Dibatalkan',
              '$cancelledCount Pesanan',
              Colors.red,
              ['Dibatalkan'],
            ),
            const SizedBox(height: 24),
            if (_loadingOrders)
              const Center(child: CircularProgressIndicator())
            else if (_sellerOrders.isEmpty)
              const Center(child: Text('Belum ada pesanan'))
            else ...[
              const Text(
                'Daftar Pesanan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sellerOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = _sellerOrders[index];
                  final paymentStatus =
                      order.paymentStatus ??
                      (order.status == 'Dikonfirmasi'
                          ? 'Lunas'
                          : 'Belum Lunas');

                  Color statusColor = Colors.orange;
                  if (order.status == 'Selesai') statusColor = Colors.green;
                  if (order.status == 'Dikirim') statusColor = Colors.blue;
                  if (order.status == 'Dibatalkan') statusColor = Colors.red;

                  // FIX: Card dirombak jadi Column 2 baris supaya rapi:
                  // - Baris atas: ikon + nomor pesanan (1 baris, ellipsis) + badge status
                  // - Baris bawah: nama penerima & total (kiri), status pembayaran (kanan)
                  // Sebelumnya semua disatukan dalam 1 Row sehingga nomor
                  // pesanan yang panjang wrap ke 2 baris dan mendorong
                  // badge status jadi tidak sejajar / berantakan.
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.04),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Baris atas: ikon + nomor pesanan + badge status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                order.status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Baris bawah: nama penerima + total (kiri),
                        // status pembayaran (kanan). Diberi indent kiri 48
                        // supaya sejajar dengan teks di atas, bukan ikon.
                        Padding(
                          padding: const EdgeInsets.only(left: 48),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.recipientName ?? '-',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: Rp ${order.total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                paymentStatus,
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
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── REPORTS TAB ────────────────────────────────────────────────────────────

  Widget _buildReportsTab() {
    if (_loadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    final report = _financialReport;
    if (report == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Data laporan tidak tersedia'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadFinancialReport,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => await _loadSellerOrders(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Laporan Keuangan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Periode: ${FormatHelper.formatDateRange(report.startDate, report.endDate)}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _buildClickableReportCard(
              'Pendapatan',
              FormatHelper.formatCurrency(report.totalRevenue),
              Colors.green,
              Icons.trending_up,
              () => _navigateToDetailReport(),
            ),
            const SizedBox(height: 12),
            _buildClickableReportCard(
              'Pengeluaran (Estimasi)',
              FormatHelper.formatCurrency(report.totalExpense),
              Colors.red,
              Icons.trending_down,
              () => _navigateToDetailReport(),
            ),
            const SizedBox(height: 12),
            _buildClickableReportCard(
              'Laba Bersih',
              FormatHelper.formatCurrency(report.netProfit),
              const Color(0xFF2A7F41),
              Icons.attach_money,
              () => _navigateToDetailReport(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ringkasan Metrik',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    'Total Pesanan',
                    '${report.totalOrders}',
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricBox(
                    'Pesanan Selesai',
                    '${report.completedOrders}',
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricBox(
              'Margin Laba',
              '${report.profitMargin.toStringAsFixed(1)}%',
              Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Grafik Penjualan Bulanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tren Penjualan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildMonthlySalesChart(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A7F41),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lihat Laporan Lengkap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Akses analisis detail, transaksi, dan wawasan keuangan lengkap',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2A7F41),
                      ),
                      onPressed: _navigateToDetailReport,
                      child: const Text('Buka Laporan Lengkap'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigateToDetailReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialReportDetailScreen()),
    );
  }

  // ── PROFILE TAB ────────────────────────────────────────────────────────────

  Widget _buildProfileTab(AuthProvider auth) {
    final user = auth.user;
    final photoUrl = user?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    // FIX: dibungkus SingleChildScrollView + padding bawah ekstra supaya
    // item terakhir (Bantuan & FAQ / Tentang Aplikasi / tombol Keluar)
    // tidak lagi ketutup bottom navigation bar. Sebelumnya cuma Padding
    // biasa tanpa scroll, jadi kalau kontennya lebih tinggi dari layar,
    // bagian bawah langsung terpotong tanpa bisa di-scroll.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profil Saya',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.04),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF2A7F41),
                  backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                  child: hasPhoto
                      ? null
                      : const Icon(Icons.person, size: 30, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'BUMDes',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.phone ?? '-',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '-',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ProfileOptionTile(
            label: 'Profil Toko',
            onTap: () =>
                Navigator.pushNamed(context, StoreFormScreen.routeName),
          ),
          _ProfileOptionTile(
            label: 'Saldo & Penarikan',
            onTap: () =>
                Navigator.pushNamed(context, SellerWalletScreen.routeName),
          ),
          _ProfileOptionTile(
            label: 'Edit Profil',
            onTap: () =>
                Navigator.pushNamed(context, EditProfileScreen.routeName),
          ),
          _ProfileOptionTile(
            label: 'Pengaturan',
            onTap: () => Navigator.pushNamed(context, SettingsScreen.routeName),
          ),
          _ProfileOptionTile(
            label: 'Bantuan & FAQ',
            onTap: () => Navigator.pushNamed(context, HelpScreen.routeName),
          ),
          _ProfileOptionTile(
            label: 'Tentang Aplikasi',
            onTap: () => Navigator.pushNamed(context, AboutScreen.routeName),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _handleLogout,
              child: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }
  // ── HELPER WIDGETS ─────────────────────────────────────────────────────────

  // FIX: Helper untuk tampilkan gambar produk dengan fallback yang benar
  Widget _buildProductImage(String imageUrl, double height) {
    if (imageUrl.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 36,
        ),
      );
    }
    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      // FIX: Tampilkan loading indicator sementara gambar dimuat
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: height,
          width: double.infinity,
          color: Colors.grey[100],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withAlpha(40),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: card,
          )
        : card;
  }

  Widget _buildOrderStatusCard(
    String title,
    String subtitle,
    Color color,
    List<String> filters,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SellerOrdersScreen(statusFilters: filters, screenTitle: title),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.inventory_2_outlined, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableReportCard(
    String title,
    String amount,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha((0.14 * 255).round()),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySalesChart() {
    final monthlySales = _reportService.getMonthlySalesData(_sellerOrders);

    if (monthlySales.isEmpty) {
      return const Text(
        'Belum ada data penjualan bulanan',
        style: TextStyle(color: Colors.black54),
      );
    }

    final maxSales = monthlySales.fold(
      0.0,
      (prev, current) => current.sales > prev ? current.sales : prev,
    );

    return Column(
      children: monthlySales.take(6).map((month) {
        final percentage = maxSales > 0 ? (month.sales / maxSales) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(month.month, style: const TextStyle(fontSize: 12)),
                  Text(
                    '${month.orders} order',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    FormatHelper.formatCurrency(month.sales),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withAlpha(50),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2A7F41),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Cari produk...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    const categories = [
      'Semua',
      'Kuliner Desa',
      'Pertanian & Perkebunan',
      'Kerajinan Tangan',
      'Jasa Lokal',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = category),
              selectedColor: const Color(0xFF2A7F41),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
              elevation: 2,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;
    final isTablet = screenWidth >= 600;
    final navHeight = isCompact
        ? 72.0
        : isTablet
        ? 80.0
        : 76.0;
    final labelFontSize = isCompact
        ? 10.5
        : isTablet
        ? 11.5
        : 12.0;
    final iconSize = isCompact
        ? 21.5
        : isTablet
        ? 24.0
        : 23.0;

    const items = [
      _NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        iconFilled: Icons.dashboard,
      ),
      _NavItem(
        label: 'Produk',
        icon: Icons.shopping_bag_outlined,
        iconFilled: Icons.shopping_bag,
      ),
      _NavItem(
        label: 'Pesanan',
        icon: Icons.receipt_long_outlined,
        iconFilled: Icons.receipt_long,
      ),
      _NavItem(
        label: 'Laporan',
        icon: Icons.bar_chart_outlined,
        iconFilled: Icons.bar_chart,
      ),
      _NavItem(
        label: 'Akun',
        icon: Icons.person_outline,
        iconFilled: Icons.person,
      ),
    ];

    return SafeArea(
      top: false,
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFFF8FBF9),
          surfaceTintColor: Colors.white,
          indicatorColor: const Color(0xFF2A7F41).withValues(alpha: 0.14),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black.withValues(alpha: 0.06),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: labelFontSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              height: 1.2,
              color: isSelected
                  ? const Color(0xFF2A7F41)
                  : const Color(0xFF64748B),
              letterSpacing: 0.1,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: iconSize,
              color: isSelected
                  ? const Color(0xFF2A7F41)
                  : const Color(0xFF64748B),
            );
          }),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact
                ? 8
                : isTablet
                ? 16
                : 20,
            vertical: isCompact ? 6 : 8,
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            height: navHeight,
            elevation: 2,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: items
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.iconFilled),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ── SUBWIDGETS ────────────────────────────────────────────────────────────────

class _ProfileOptionTile extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ProfileOptionTile({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap:
            onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label - Fitur sedang dikembangkan')),
              );
            },
      ),
    );
  }
}

// FIX: _ProductCard sekarang pakai tombol aksi langsung, bukan PopupMenuButton
// yang bug akibat konteks hilang saat rebuild
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIX: Gambar produk dengan loading & error handler
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: product.imageUrl.isNotEmpty
                ? Image.network(
                    product.imageUrl,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 110,
                        width: double.infinity,
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 110,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Container(
                    height: 110,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp ${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.category,
                  style: const TextStyle(color: Colors.black54, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // FIX: Tombol aksi langsung (bukan PopupMenuButton yang bug)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      side: const BorderSide(color: Color(0xFF2A7F41)),
                    ),
                    child: const Text(
                      'Ubah',
                      style: TextStyle(color: Color(0xFF2A7F41), fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(
                      'Hapus',
                      style: TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData iconFilled;

  const _NavItem({
    required this.label,
    required this.icon,
    IconData? iconFilled,
  }) : iconFilled = iconFilled ?? icon;
}
