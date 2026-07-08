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
  // last search query to allow combined search + category filtering
  String _lastQuery = '';
  // selected category for SearchTab filtering
  String selectedCategory = 'Semua';

  List<ProductModel> get products => _filtered;
  List<ProductModel> get featured => _products.take(6).toList();
  // FIX: kategori diambil dinamis dari data produk asli (sesuai tabel
  // `categories` di backend), bukan daftar hardcoded yang gampang basi
  // kalau admin menambah/mengubah kategori.
  List<String> get categories {
    final names =
        _products
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
    isUsingSampleData = false;
  }

  void search(String query) {
    _lastQuery = query;
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
    // reuse last query so selecting category doesn't clear user's search
    search(_lastQuery);
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
    _filtered = List.of(_products);
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
    _filtered = List.of(_products);
    notifyListeners();
    return product;
  }

  void updateProduct(ProductModel product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index >= 0) {
      _products[index] = product;
      _filtered = List.of(_products);
      notifyListeners();
    }
  }

  // FIX: sama seperti createProductOnServer — imageFile (String path) diganti XFile?
  // imageFile == null artinya foto lama dipertahankan di server.
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
      _filtered = List.of(_products);
      notifyListeners();
    }
  }

  // FIX: deleteProduct sekarang panggil API backend dulu, baru hapus local state
  Future<void> deleteProduct(String token, int id) async {
    await _productService.deleteProduct(token, id);
    _products.removeWhere((product) => product.id == id);
    _filtered = List.of(_products);
    notifyListeners();
  }
}
