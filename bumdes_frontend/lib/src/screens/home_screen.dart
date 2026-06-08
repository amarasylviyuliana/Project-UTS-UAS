import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // Role check - hanya pembeli yang boleh akses home
    if (auth.user?.role != 'buyer' && auth.isAuthenticated) {
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
                  'Halaman ini hanya untuk pembeli.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await auth.logout();
                    if (!mounted) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
                    });
                  },
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = <Widget>[
      const HomeTab(),
      const SearchTab(),
      const CartScreen(),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];

    final menuLabels = ['Beranda', 'Pencarian', 'Keranjang', 'Pesanan', 'Profil'];
    final menuIcons = [
      Icons.home_outlined,
      Icons.search_outlined,
      Icons.shopping_cart_outlined,
      Icons.receipt_long_outlined,
      Icons.person_outline,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text('DE.UP', style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                menuLabels.length,
                (index) {
                  final isSelected = _selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: IconButton(
                      onPressed: () => setState(() => _selectedIndex = index),
                      icon: Icon(
                        menuIcons[index],
                        color: isSelected ? Colors.black87 : Colors.grey[600],
                      ),
                      tooltip: menuLabels[index],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: pages[_selectedIndex],
    );

  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE6E8E7),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildHeroText()),
                      const SizedBox(width: 32),
                      Expanded(child: _buildHeroIllustration()),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroText(),
                    const SizedBox(height: 24),
                    _buildHeroIllustration(),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildSearchBar(),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildSectionHeader('Produk Unggulan'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: provider.featured.length,
              itemBuilder: (context, index) {
                final product = provider.featured[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ProductCard(product: product),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildSectionHeader('Kategori Populer'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                CategoryChip(label: 'Pertanian & Perkebunan'),
                CategoryChip(label: 'Kerajinan Tangan'),
                CategoryChip(label: 'Kuliner Desa'),
                CategoryChip(label: 'Jasa Lokal'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildSectionHeader('Toko BUMDes Terpopuler'),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: provider.featured.map((product) => SizedBox(width: 280, child: ProductCard(product: product))).toList(),
            ),
          ),
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: const Text('Credit & logo logo', style: TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('DE.UP', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        Text(
          'Adalah aplikasi penyokong usaha pada tiap desa yang mana menjual dan memasarkan produk barang atau jasa unggulan di desanya.',
          style: TextStyle(fontSize: 18, color: Colors.black87, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildHeroIllustration() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: const Center(
        child: Text('disini tar icon atau elemen desain', style: TextStyle(color: Colors.black45)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: const [
          Icon(Icons.search, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text('Cari produk, toko, desa', style: TextStyle(color: Colors.black45)),
          ),
          Icon(Icons.filter_list, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Cari produk, toko, desa',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: provider.search,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                        'Semua',
                        'Pertanian & Perkebunan',
                        'Kerajinan Tangan',
                        'Kuliner Desa',
                        'Jasa Lokal',
                      ]
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: provider.selectedCategory == category,
                            onSelected: (_) =>
                                provider.filterByCategory(category),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: provider.products.isEmpty
                ? const Center(child: Text('Tidak ada produk yang cocok'))
                : ListView.builder(
                    itemCount: provider.products.length,
                    itemBuilder: (context, index) =>
                        ProductCard(product: provider.products[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const FeatureTile({required this.label, required this.icon, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFDCF1D7),
              child: Icon(icon, color: const Color(0xFF2F7A23)),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final ProductModel product;
  const ProductCard({required this.product, super.key});

  @override
  Widget build(BuildContext context) {
    final stockLabel = product.stock == 0 ? 'Stok Habis' : 'Stok ${product.stock}';
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/product-detail',
        arguments: {'product': product},
      ),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(product.storeName, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rp ${product.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(stockLabel, style: TextStyle(color: product.stock == 0 ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String label;

  const CategoryChip({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    final selected = provider.selectedCategory == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => provider.filterByCategory(label),
    );
  }
}
