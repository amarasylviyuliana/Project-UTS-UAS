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
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'security_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSellerOrders();
    _loadSellerProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        // Load financial report after orders are loaded
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
      // Calculate report from orders
      if (_sellerOrders.isNotEmpty) {
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
      } else {
        // Try to load from API
        try {
          final report = await _reportService.getStoreReport(
            token: auth.token!,
          );
          if (mounted) {
            setState(() {
              _financialReport = report;
              _loadingReport = false;
            });
          }
        } catch (e) {
          // Fallback: create empty report
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
    } catch (e) {
      debugPrint('Error loading financial report: $e');
      if (mounted) {
        setState(() => _loadingReport = false);
      }
    }
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
          _selectedCategory == 'Semua' || product.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    if (auth.user?.role != 'seller' && auth.user?.role != 'Penjual') {
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

    return Scaffold(
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
    );
  }

  Widget _buildHeader(AuthProvider auth) {
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
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFF2A7F41),
            child: Icon(Icons.storefront, size: 28, color: Colors.white),
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
            onPressed: () => _showHeaderOptions(context),
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
      case 5:
        return _buildSavingsTab();
      case 6:
        return _buildTourismTab();
      default:
        return _buildDashboardTab();
    }
  }

  void _onMenuTap(String label) {
    switch (label) {
      case 'Profil Toko':
        setState(() => _selectedIndex = 0);
        break;
      case 'Katalog':
        setState(() => _selectedIndex = 1);
        break;
      case 'Pesanan':
        setState(() => _selectedIndex = 2);
        break;
      case 'Pembayaran':
        setState(() => _selectedIndex = 3);
        break;
      case 'Akun':
        setState(() => _selectedIndex = 4);
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
      }
    });
  }

  Widget _buildDashboardTab() {
    final waitingConfirmation = _sellerOrders
        .where(
          (order) =>
              order.status == 'Menunggu Pembayaran' ||
              order.status == 'Menunggu Konfirmasi',
        )
        .length;
    final processingOrders = _sellerOrders
        .where(
          (order) =>
              order.status == 'Dikonfirmasi' || order.status == 'Diproses',
        )
        .length;
    final shippingOrders = _sellerOrders
        .where((order) => order.status == 'Dikirim')
        .length;
    final completedOrders = _sellerOrders
        .where((order) => order.status == 'Selesai')
        .length;
    final totalOrders = _sellerOrders.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Halo Penjual',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Lihat ringkasan toko dan pesanan terbaru Anda di sini.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A7F41),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                ),
                onPressed: () => _onMenuTap('Pesanan'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Lihat Pesanan'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildSummaryCard('Total Pesanan', '$totalOrders', Colors.green),
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
              _buildSummaryCard('Selesai', '$completedOrders', Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
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
    );
  }

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
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
                onPressed: () {
                  if (auth.token == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Silakan login terlebih dahulu'),
                      ),
                    );
                    return;
                  }
                  Navigator.pushNamed(context, ProductFormScreen.routeName);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildSearchInput(),
              const SizedBox(height: 12),
              _buildCategoryChips(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingProducts && !_sellerProductsLoaded
              ? const Center(child: CircularProgressIndicator())
              : filteredProducts.isEmpty
              ? const Center(child: Text('Belum ada produk sesuai pencarian.'))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(
                      product: product,
                      onEdit: () {
                        Navigator.pushNamed(
                          context,
                          ProductFormScreen.routeName,
                          arguments: {'product': product},
                        );
                      },
                      onDelete: () =>
                          _confirmDeleteProduct(context, product, provider),
                    );
                  },
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        provider.deleteProduct(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk ${product.name} berhasil dihapus.')),
        );
      });
    }
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
          if (onTap != null) ...[
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
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

  Widget _buildOrdersTab() {
    // Count orders by individual statuses
    final pendingCount = _sellerOrders
        .where(
          (o) =>
              o.status == 'Menunggu Pembayaran' ||
              o.status == 'Menunggu Konfirmasi',
        )
        .length;
    final confirmingCount = _sellerOrders
        .where((o) => o.status == 'Dikonfirmasi')
        .length;
    final processingCount = _sellerOrders
        .where((o) => o.status == 'Diproses')
        .length;
    final shippingCount = _sellerOrders
        .where((o) => o.status == 'Dikirim')
        .length;
    final completedCount = _sellerOrders
        .where((o) => o.status == 'Selesai')
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pesanan Masuk',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // First row - Menunggu Konfirmasi, Sedang Diproses, Selesai
          Row(
            children: [
              Expanded(
                child: _buildOrderStatusCard(
                  'Menunggu Konfirmasi',
                  '$pendingCount Pesanan',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOrderStatusCard(
                  'Sedang Diproses',
                  '${confirmingCount + processingCount} Pesanan',
                  const Color(0xFFFFC107),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOrderStatusCard(
                  'Selesai',
                  '$completedCount Pesanan',
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row - Sedang Dikirim
          Row(
            children: [
              Expanded(
                child: _buildOrderStatusCard(
                  'Sedang Dikirim',
                  '$shippingCount Pesanan',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _loadingOrders
                ? const Center(child: CircularProgressIndicator())
                : _sellerOrders.isEmpty
                ? const Center(child: Text('Belum ada pesanan'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromRGBO(0, 0, 0, 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pesanan Terbaru',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._sellerOrders.take(4).map((order) {
                              final paymentStatus =
                                  order.paymentStatus ??
                                  (order.status == 'Dikonfirmasi'
                                      ? 'Lunas'
                                      : 'Belum Lunas');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            order.orderNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Status: ${order.status}',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Rp ${order.total.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          paymentStatus,
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (_sellerOrders.length > 4)
                              Text(
                                '+${_sellerOrders.length - 4} pesanan lainnya',
                                style: const TextStyle(color: Colors.black54),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Daftar Pesanan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _sellerOrders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = _sellerOrders[index];
                            final paymentStatus =
                                order.paymentStatus ??
                                (order.status == 'Dikonfirmasi'
                                    ? 'Lunas'
                                    : 'Belum Lunas');
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromRGBO(0, 0, 0, 0.04),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.orderNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          order.recipientName ??
                                              order.sellerName ??
                                              '',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total: Rp ${order.total.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        order.status,
                                        style: TextStyle(
                                          color: order.status == 'Selesai'
                                              ? Colors.green
                                              : order.status == 'Dikirim'
                                              ? Colors.blue
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        paymentStatus,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_loadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_financialReport == null) {
      return const Center(child: Text('Data laporan tidak tersedia'));
    }

    final report = _financialReport!;

    return SingleChildScrollView(
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
            'Periode: ${FormatHelper.formatDateRange(report.startDate, report.endDate)} - ${report.endDate.difference(report.startDate).inDays} hari',
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
            'Pengeluaran',
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
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
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
    );
  }

  void _navigateToDetailReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialReportDetailScreen()),
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
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
      return const Text('Belum ada data penjualan bulanan');
    }

    // Get max value for scaling
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

  Widget _buildSavingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simpan Pinjam',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            title: 'Total Tabungan Desa',
            subtitle: 'Saldo tersedia untuk pinjaman dan operasional',
            amount: 'Rp 112.500.000',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Pinjaman Tersalur',
            subtitle: 'Jumlah pinjaman yang telah disetujui',
            amount: 'Rp 34.200.000',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Pinjaman Tertunggak',
            subtitle: 'Pinjaman yang perlu ditagih kembali',
            amount: 'Rp 7.100.000',
          ),
          const SizedBox(height: 24),
          const Text(
            'Layanan Simpan Pinjam',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Layanan simpan pinjam memudahkan anggota desa untuk meminjam modal usaha dengan proses yang transparan dan mudah.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTourismTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wisata Desa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            title: 'Paket Wisata Terpopuler',
            subtitle: 'Paket wisata desa yang paling banyak dibeli',
            amount: 'Rp 150.000',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Kunjungan Bulan Ini',
            subtitle: 'Jumlah wisatawan lokal dan mancanegara',
            amount: '1.324 pengunjung',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Pendapatan Wisata',
            subtitle: 'Pendapatan dari kegiatan wisata desa',
            amount: 'Rp 53.700.000',
          ),
          const SizedBox(height: 24),
          const Text(
            'Deskripsi Wisata',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kelola paket wisata desa, pendaftaran pengunjung, dan proses pembayaran dengan mudah untuk mendukung pariwisata lokal.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(AuthProvider auth) {
    final user = auth.user;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF2A7F41),
                  child: Icon(Icons.person, size: 30, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'BUMDes Ciwidey',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.phone ?? '0812 3456 7890',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'bumdes.ciwidey@gmail.com',
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
            label: 'Edit Profil',
            onTap: () =>
                Navigator.pushNamed(context, EditProfileScreen.routeName),
          ),
          _ProfileOptionTile(
            label: 'Pengaturan',
            onTap: () => Navigator.pushNamed(context, SettingsScreen.routeName),
          ),
          _ProfileOptionTile(
            label: 'Keamanan',
            onTap: () => Navigator.pushNamed(context, SecurityScreen.routeName),
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
              onPressed: () {
                _handleLogout();
              },
              child: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A7F41),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Saldo Kas Desa',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 12),
          Text(
            'Rp 125.750.000',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Per 20 Mei 2024',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
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
    const categories = ['Semua', 'Pangan', 'Pertanian', 'Kerajinan', 'Jasa'];
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
    final items = [
      _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined),
      _NavItem(label: 'Produk', icon: Icons.shopping_bag_outlined),
      _NavItem(label: 'Pesanan', icon: Icons.receipt_long_outlined),
      _NavItem(label: 'Laporan', icon: Icons.bar_chart_outlined),
      _NavItem(label: 'Akun', icon: Icons.person_outline),
    ];

    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: const Color(0xFF2A7F41),
      unselectedItemColor: Colors.grey[600],
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      onTap: (index) => setState(() => _selectedIndex = index),
      items: items
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }

  Widget _buildOrderStatusCard(String title, String subtitle, Color color) {
    return InkWell(
      onTap: () {
        List<String> filters = [];
        String screenTitle = title;

        switch (title) {
          case 'Menunggu Konfirmasi':
            filters = ['Menunggu Pembayaran', 'Menunggu Konfirmasi'];
            break;
          case 'Sedang Diproses':
            filters = ['Dikonfirmasi', 'Diproses'];
            screenTitle = 'Sedang Diproses';
            break;
          case 'Sedang Dikirim':
            filters = ['Dikirim'];
            screenTitle = 'Sedang Dikirim';
            break;
          case 'Selesai':
            filters = ['Selesai'];
            break;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SellerOrdersScreen(
              statusFilters: filters,
              screenTitle: screenTitle,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

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
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: Image.network(
              product.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                height: 120,
                color: Colors.grey[200],
                child: const Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rp ${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.category,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit,
                        child: const Text(
                          'Ubah',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text(
                          'Hapus',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
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

  const _NavItem({required this.label, required this.icon});
}
