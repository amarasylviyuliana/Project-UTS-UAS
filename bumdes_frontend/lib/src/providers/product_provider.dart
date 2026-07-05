import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  final List<ProductModel> _products = [];
  final ProductService _productService = ProductService();
  List<ProductModel> _filtered = [];
  bool isLoading = false;
  bool isUsingSampleData = false;
  String selectedCategory = 'Semua';

  List<ProductModel> get products => _filtered;
  List<ProductModel> get featured => _products.take(6).toList();
// FIX: kategori diambil dinamis dari data produk asli (sesuai tabel
  // `categories` di backend), bukan daftar hardcoded yang gampang basi
  // kalau admin menambah/mengubah kategori.
  List<String> get categories {
    final names = _products
        .map((p) => p.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Semua', ...names];
  }
  ProductProvider() {
    _loadProducts();
  }

  Future<void> refresh() async {
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    isLoading = true;
    notifyListeners();

    try {
      final fetchedProducts = await _productService.fetchProducts();
      _products.clear();
      if (fetchedProducts.isNotEmpty) {
        _products.addAll(fetchedProducts);
        isUsingSampleData = false;
      } else {
        _loadSampleProducts();
      }
    } catch (_) {
      _loadSampleProducts();
    }

    _filtered = List.of(_products);
    isLoading = false;
    notifyListeners();
  }

  void _loadSampleProducts() {
    _products.clear();
    isUsingSampleData = true;
    _products.addAll([
      ProductModel(
        id: 1,
        name: 'Kerupuk Kulit dari BUMDes Garut',
        storeName: 'BUMDes Garut',
        location: 'Garut',
        category: 'Kuliner Desa',
        price: 25000,
        stock: 15,
        description:
            'Kerupuk kulit khas Garut dengan cita rasa gurih, renyah, dan siap dipasarkan.',
        imageUrl: 'https://picsum.photos/seed/kerupuk/400/300',
        isService: false,
        isSample: true,
      ),
      ProductModel(
        id: 2,
        name: 'Sayuran Segar dari BUMDes Ciwdey',
        storeName: 'BUMDes Ciwdey',
        location: 'Ciwdey',
        category: 'Pertanian & Perkebunan',
        price: 18000,
        stock: 25,
        description:
            'Sayuran segar hasil panen lokal dari BUMDes Ciwdey untuk kebutuhan harian.',
        imageUrl: 'https://picsum.photos/seed/sayur/400/300',
        isService: false,
        isSample: true,
      ),
      ProductModel(
        id: 3,
        name: 'Sus Lezat dari BUMDes Pangalengan',
        storeName: 'BUMDes Pangalengan',
        location: 'Pangalengan',
        category: 'Kuliner Desa',
        price: 30000,
        stock: 12,
        description:
            'Sus lembut dan nikmat khas Pangalengan, cocok untuk camilan keluarga.',
        imageUrl: 'https://picsum.photos/seed/sus/400/300',
        isService: false,
        isSample: true,
      ),
    ]);
  }

  void search(String query) {
    final lower = query.toLowerCase();
    List<ProductModel> base = List.of(_products);
    if (selectedCategory != 'Semua') {
      base = base.where((p) => p.category == selectedCategory).toList();
    }
    if (query.isEmpty) {
      _filtered = base;
    } else {
      _filtered = base.where((product) {
        return product.name.toLowerCase().contains(lower) ||
            product.storeName.toLowerCase().contains(lower) ||
            product.location.toLowerCase().contains(lower);
      }).toList();
    }
    notifyListeners();
  }

  void filterByCategory(String category) {
    selectedCategory = category;
    if (category == 'Semua') {
      _filtered = List.of(_products);
    } else {
      _filtered = _products.where((p) => p.category == category).toList();
    }
    notifyListeners();
  }

  ProductModel? findById(int id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ProductModel> get allProducts => List.unmodifiable(_products);

  void addProduct(ProductModel product) {
    _products.insert(0, product);
    filterByCategory(selectedCategory);
    notifyListeners();
  }

  // FIX: imageUrl (String path) diganti imageFile (XFile?) + imageBytes
  // (Uint8List?, khusus web) supaya upload foto aman dipanggil dari web
  // maupun mobile/desktop. Lihat product_service.dart untuk detail kenapa
  // String path tidak bisa dipakai lagi di web.
  Future<ProductModel> createProductOnServer(
    String token,
    String name,
    int categoryId,
    String type,
    double price,
    int stock,
    String description,
    XFile? imageFile, {
    Uint8List? imageBytes,
  }) async {
    final product = await _productService.createProduct(
      token,
      name,
      categoryId,
      type,
      price,
      stock,
      description,
      imageFile,
      imageBytes: imageBytes,
    );
    _products.insert(0, product);
    filterByCategory(selectedCategory);
    notifyListeners();
    return product;
  }

  void updateProduct(ProductModel product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index >= 0) {
      _products[index] = product;
      filterByCategory(selectedCategory);
      notifyListeners();
    }
  }

  // FIX: sama seperti createProductOnServer — imageFile (XFile?) bukan
  // String path. imageFile == null artinya foto lama dipertahankan di server.
  Future<void> updateProductOnServer(
    String token,
    int productId,
    String name,
    int categoryId,
    String type,
    double price,
    int stock,
    String description,
    XFile? imageFile, {
    Uint8List? imageBytes,
  }) async {
    final product = await _productService.updateProduct(
      token,
      productId,
      name,
      categoryId,
      type,
      price,
      stock,
      description,
      imageFile,
      imageBytes: imageBytes,
    );
    final index = _products.indexWhere((item) => item.id == productId);
    if (index >= 0) {
      _products[index] = product;
      filterByCategory(selectedCategory);
      notifyListeners();
    }
  }

  // FIX: deleteProduct sekarang panggil API backend dulu, baru hapus local state
  Future<void> deleteProduct(String token, int id) async {
    await _productService.deleteProduct(token, id);
    _products.removeWhere((product) => product.id == id);
    filterByCategory(selectedCategory);
    notifyListeners();
  }
}