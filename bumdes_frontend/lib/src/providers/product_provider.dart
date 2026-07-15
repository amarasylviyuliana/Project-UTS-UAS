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

  // TAMBAHAN: state untuk fitur pencarian AI (Gemini).
  // isAiSearchActive: true kalau hasil yang ditampilkan sekarang berasal
  // dari pencarian AI (bukan filter lokal biasa), dipakai UI untuk
  // menampilkan ringkasan kriteria + badge "Hasil AI".
  bool isAiSearching = false;
  bool isAiSearchActive = false;
  String? aiSearchError;
  List<String> aiKeywords = [];
  String? aiCategory;
  double? aiMinPrice;
  double? aiMaxPrice;
  String? aiSort;
  // TAMBAHAN: atribut produk (mis. "pedas") & daerah (mis. "Garut") yang
  // dipahami AI dari query, plus mesin pencarian yang dipakai backend
  // ("algolia" atau "database-fallback").
  List<String> aiTags = [];
  String? aiRegion;
  String? aiEngine;

  List<ProductModel> get products => _filtered;
  List<ProductModel> get featured => _products.take(6).toList();
  // FIX: kategori diambil dinamis dari data produk asli (sesuai tabel
  // `categories` di backend), bukan daftar hardcoded yang gampang basi
  // kalau admin menambah/mengubah kategori.
  List<String> get categories => buildCategoryNames(_products);

  static String normalizeCategoryName(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> buildCategoryNames(
    List<ProductModel> products, [
    List<String>? fallbackCategories,
  ]) {
    final names = <String>{};
    for (final product in products) {
      final normalized = normalizeCategoryName(product.category);
      if (normalized.isNotEmpty) {
        names.add(normalized);
      }
    }

    if (fallbackCategories != null) {
      for (final category in fallbackCategories) {
        final normalized = normalizeCategoryName(category);
        if (normalized.isNotEmpty) {
          names.add(normalized);
        }
      }
    }

    final sorted = names.toList()..sort();
    return ['Semua', ...sorted];
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
    isAiSearchActive = false;
    final lower = query.toLowerCase();
    final normalizedSelectedCategory = normalizeCategoryName(selectedCategory);
    List<ProductModel> base = List.of(_products);
    if (normalizedSelectedCategory != 'Semua' &&
        normalizedSelectedCategory.isNotEmpty) {
      base = base.where((p) {
        final normalizedCategory = normalizeCategoryName(p.category);
        return normalizedCategory.toLowerCase() ==
            normalizedSelectedCategory.toLowerCase();
      }).toList();
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

  // TAMBAHAN: pencarian produk pakai AI (Gemini) — query bahasa natural
  // (mis. "sepatu murah buat lari") dikirim ke backend, hasilnya (sudah
  // diinterpretasi jadi keyword/kategori/rentang harga oleh AI) dipakai
  // langsung sebagai daftar produk yang ditampilkan.
  Future<void> searchWithAI(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      // Query kosong: kembali ke pencarian lokal biasa.
      resetAiSearch();
      return;
    }

    isAiSearching = true;
    aiSearchError = null;
    notifyListeners();

    try {
      final result = await _productService.searchWithAI(trimmed);
      _filtered = result.products;
      aiKeywords = result.keywords;
      aiCategory = result.category;
      aiMinPrice = result.minPrice;
      aiMaxPrice = result.maxPrice;
      aiSort = result.sort;
      aiTags = result.tags;
      aiRegion = result.region;
      aiEngine = result.engine;
      isAiSearchActive = true;
      // FIX: SEBELUMNYA baris ini nyimpen seluruh kalimat bahasa natural
      // (mis. "cari sepatu murah buat lari") ke `_lastQuery`. Masalahnya,
      // `_lastQuery` juga dipakai `filterByCategory()` buat pencarian teks
      // literal (lihat `search()` di atas: mencocokkan substring ke nama
      // produk). Kalimat AI itu hampir pasti tidak match nama produk apa
      // pun, jadi begitu user pilih kategori SETELAH pernah pakai AI
      // search, hasilnya selalu kosong — kelihatan seperti "filter
      // kategori tidak berfungsi", padahal kategori sudah benar, cuma
      // ketiban filter teks sisa AI yang tidak nyambung. Sekarang
      // `_lastQuery` TIDAK diisi kalimat AI, jadi tetap bersih untuk
      // dipakai ulang oleh filter kategori.
    } catch (e) {
      aiSearchError = 'Pencarian AI gagal, coba lagi ya.';
      // Fallback: tetap tampilkan hasil pencarian teks biasa supaya user
      // tidak mentok tanpa hasil sama sekali.
      search(trimmed);
      isAiSearchActive = false;
    }

    isAiSearching = false;
    notifyListeners();
  }

  // TAMBAHAN: keluar dari mode hasil AI, balik ke pencarian/filter lokal.
  void resetAiSearch() {
    isAiSearchActive = false;
    aiSearchError = null;
    aiKeywords = [];
    aiCategory = null;
    aiMinPrice = null;
    aiMaxPrice = null;
    aiSort = null;
    aiTags = [];
    aiRegion = null;
    aiEngine = null;
    search(_lastQuery);
  }

  void filterByCategory(String category) {
    selectedCategory = normalizeCategoryName(category);
    // Memilih kategori chip berarti keluar dari mode hasil AI (kriteria AI
    // sebelumnya sudah tidak relevan lagi), balik ke pencarian/filter lokal.
    isAiSearchActive = false;
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
    // TAMBAHAN: diteruskan ke service — dipakai untuk toggle
    // Tersedia/Tidak Tersedia pada Jasa.
    bool isActive = true,
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
      isActive: isActive,
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
    // TAMBAHAN: sama seperti createProductOnServer.
    bool isActive = true,
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
      isActive: isActive,
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