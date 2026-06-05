import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import 'home_screen.dart';
import 'product_form_screen.dart';
import 'profile_screen.dart';
import 'seller_orders_screen.dart';

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
      }
    } catch (e) {
      debugPrint('Error loading seller orders: $e');
      if (mounted) {
        setState(() => _loadingOrders = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);\r\n    final products = _sellerProductsLoaded ? _sellerProducts : [];
    final filteredProducts = products.where((product) {
      final matchesQuery =
          _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'Semua' || product.category == _selectedCategory;
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(auth),
            Expanded(child: _buildTabContent(auth, provider, filteredProducts)),
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
    ProductProvider provider,
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
        return _buildDashboardTab(provider);
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
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
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

    switch (selected) {
      case 'profile':
        Navigator.pushNamed(context, ProfileScreen.routeName);
        break;
      case 'settings':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buka pengaturan aplikasi')),
        );
        break;
      case 'help':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buka halaman bantuan')),
        );
        break;
    }
  }

  Widget _buildDashboardTab(ProductProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 20),
          const Text(
            'Dashboard Penjual',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kelola toko, katalog, pesanan masuk, dan konfirmasi pembayaran di sini.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MenuTile(
                icon: Icons.storefront,
                label: 'Profil Toko',
                onTap: () => _onMenuTap('Profil Toko'),
              ),
              _MenuTile(
                icon: Icons.shopping_bag,
                label: 'Katalog',
                onTap: () => _onMenuTap('Katalog'),
              ),
              _MenuTile(
                icon: Icons.receipt_long,
                label: 'Pesanan',
                onTap: () => _onMenuTap('Pesanan'),
              ),
              _MenuTile(
                icon: Icons.payment,
                label: 'Pembayaran',
                onTap: () => _onMenuTap('Pembayaran'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Statistik Cepat',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard('Produk Aktif', '24', Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard('Pesanan Baru', '8', Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard('Pembayaran Pending', '3', Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Pendapatan',
                  'Rp 12.450.000',
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Tugas Hari Ini',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTaskCard(
            'Konfirmasi pembayaran',
            '3 transaksi menunggu.',
            Icons.payment,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildTaskCard(
            'Kelola katalog produk',
            'Tambahkan atau perbarui katalog toko.',
            Icons.edit,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildTaskCard(
            'Tinjau pesanan masuk',
            'Buka tab Pesanan untuk update status.',
            Icons.receipt,
            Colors.blue,
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
                      const SnackBar(content: Text('Silakan login terlebih dahulu')),
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
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
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
      provider.deleteProduct(product.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk ${product.name} berhasil dihapus.')),
      );
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
    Color color,
  ) {
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
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pesanan Masuk',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildOrderStatusCard(
            'Menunggu Konfirmasi',
            '${_sellerOrders.where((o) => o.status == 'Menunggu Konfirmasi').length} Pesanan baru',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildOrderStatusCard(
            'Dalam Pengiriman',
            '${_sellerOrders.where((o) => o.status == 'Dikirim').length} Pesanan diproses',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildOrderStatusCard(
            'Selesai',
            '${_sellerOrders.where((o) => o.status == 'Selesai').length} Pesanan selesai',
            Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            'Riwayat Pesanan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingOrders
                ? const Center(child: CircularProgressIndicator())
                : _sellerOrders.isEmpty
                    ? const Center(child: Text('Belum ada pesanan'))
                    : ListView.builder(
                        itemCount: _sellerOrders.length,
                        itemBuilder: (context, index) {
                          final order = _sellerOrders[index];
                          return _OrderHistoryTile(
                            orderNumber: order.id.toString(),
                            status: order.status,
                            total: 'Rp ${order.total.toStringAsFixed(0)}',
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Laporan Keuangan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildReportCard('Pendapatan', 'Rp 68.350.000', Colors.green),
          const SizedBox(height: 12),
          _buildReportCard('Pengeluaran', 'Rp 32.600.000', Colors.red),
          const SizedBox(height: 12),
          _buildReportCard('Laba Bersih', 'Rp 35.750.000', Colors.indigo),
          const SizedBox(height: 24),
          const Text(
            'Grafik Pendapatan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            height: 180,
            width: double.infinity,
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
            child: Center(
              child: Text(
                'Grafik mini',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
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
            onTap: () => Navigator.pushNamed(context, ProfileScreen.routeName),
          ),
          _ProfileOptionTile(
            label: 'Pengaturan',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buka pengaturan aplikasi')),
              );
            },
          ),
          _ProfileOptionTile(
            label: 'Keamanan',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kelola keamanan akun')),
              );
            },
          ),
          _ProfileOptionTile(
            label: 'Bantuan & FAQ',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buka halaman bantuan')),
              );
            },
          ),
          _ProfileOptionTile(
            label: 'Tentang Aplikasi',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Informasi tentang aplikasi')),
              );
            },
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
        String filter = title;
        if (title == 'Dalam Pengiriman') filter = 'Dikirim';
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SellerOrdersScreen(statusFilter: filter)),
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

  Widget _buildReportCard(String title, String amount, Color color) {
    return Container(
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
            child: Icon(Icons.trending_up, color: color, size: 24),
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
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MenuTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 72) / 3,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F3E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: const Color(0xFF2A7F41), size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
        onTap: onTap ?? () {
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

class _OrderHistoryTile extends StatelessWidget {
  final String orderNumber;
  final String status;
  final String total;

  const _OrderHistoryTile({
    required this.orderNumber,
    required this.status,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F3E8),
          child: Icon(Icons.receipt_long, color: Color(0xFF2A7F41)),
        ),
        title: Text(orderNumber),
        subtitle: Text(status),
        trailing: Text(
          total,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem({required this.label, required this.icon});
}



