import 'package:flutter/material.dart';
import '../models/store_model.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../providers/product_provider.dart';
import 'home_screen.dart'; // reuse ProductCard widget yang sudah ada

class BumdesDetailScreen extends StatefulWidget {
  final StoreModel store;
  const BumdesDetailScreen({required this.store, super.key});

  @override
  State<BumdesDetailScreen> createState() => _BumdesDetailScreenState();
}

class _BumdesDetailScreenState extends State<BumdesDetailScreen>
    with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();

  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _error;
  TabController? _tabController;
  List<String> _categoryTabs = const ['Semua Produk'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final products = await _productService.fetchProductsForStore(
        widget.store.id,
      );
      // TAMBAHAN: nama-nama kategori (selain "Semua") dihitung ulang dari
      // produk milik BUMDes ini, memakai method yang SAMA dengan
      // ProductProvider di Beranda — supaya tidak ada logika kategori
      // ganda yang bisa berbeda hasilnya.
      final categoryNames = ProductProvider.buildCategoryNames(products)
          .where((c) => c != 'Semua')
          .toList();

      _tabController?.dispose();
      final tabs = ['Semua Produk', ...categoryNames];
      final controller = TabController(length: tabs.length, vsync: this);

      if (!mounted) return;
      setState(() {
        _products = products;
        _categoryTabs = tabs;
        _tabController = controller;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat produk BUMDes ini';
        _isLoading = false;
      });
    }
  }

  List<ProductModel> _productsForTab(int index) {
    if (index == 0) return _products;
    final category = _categoryTabs[index];
    return _products.where((p) {
      return ProductProvider.normalizeCategoryName(
            p.category,
          ).toLowerCase() ==
          category.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          store.storeName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: (!_isLoading && _tabController != null)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF1B5E20),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xFF1B5E20),
                    tabs: _categoryTabs.map((c) => Tab(text: c)).toList(),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // Header info BUMDes: foto + nama toko + wilayah
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1B5E20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: store.storePhotoUrl != null
                        ? Image.network(
                            store.storePhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white24,
                              child: const Icon(
                                Icons.storefront,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.white24,
                            child: const Icon(
                              Icons.storefront,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.storeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        store.regionLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                : _tabController == null
                ? const Center(child: Text('Belum ada produk'))
                : TabBarView(
                    controller: _tabController,
                    children: List.generate(_categoryTabs.length, (index) {
                      final items = _productsForTab(index);
                      if (items.isEmpty) {
                        return const Center(
                          child: Text(
                            'Belum ada produk di kategori ini',
                            style: TextStyle(color: Colors.black54),
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.62,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            ProductCard(product: items[i]),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}