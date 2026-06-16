import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  final List<ProductModel> _products = [];
  final ProductService _productService = ProductService();
  List<ProductModel> _filtered = [];
  bool isLoading = false;
  bool isUsingSampleData = false;
  String selectedCategory = 'Semua';

  List<ProductModel> get products => _filtered.isEmpty ? _products : _filtered;
  List<ProductModel> get featured => _products.take(3).toList();

  ProductProvider() {
    _loadProducts();
  }

  void _loadProducts() async {
    isLoading = true;
    notifyListeners();

    try {
      final fetchedProducts = await _productService.fetchProducts();
      if (fetchedProducts.isNotEmpty) {
        _products.clear();
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
    _filtered = _products.where((product) {
      return product.name.toLowerCase().contains(lower) ||
          product.storeName.toLowerCase().contains(lower) ||
          product.location.toLowerCase().contains(lower);
    }).toList();
    if (selectedCategory != 'Semua') {
      _filtered = _filtered
          .where((product) => product.category == selectedCategory)
          .toList();
    }
    notifyListeners();
  }

  void filterByCategory(String category) {
    selectedCategory = category;
    if (category == 'Semua') {
      _filtered = List.of(_products);
    } else {
      _filtered = _products
          .where((product) => product.category == category)
          .toList();
    }
    notifyListeners();
  }

  ProductModel? findById(int id) {
    return _products.firstWhere(
      (product) => product.id == id,
      orElse: () => ProductModel.empty(),
    );
  }

  List<ProductModel> get allProducts => List.unmodifiable(_products);

  void addProduct(ProductModel product) {
    _products.add(product);
    filterByCategory(selectedCategory);
    notifyListeners();
  }

  Future<ProductModel> createProductOnServer(
    String token,
    String name,
    int categoryId,
    String type,
    double price,
    int stock,
    String description,
  ) async {
    final product = await _productService.createProduct(
      token,
      name,
      categoryId,
      type,
      price,
      stock,
      description,
    );
    _products.add(product);
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

  Future<void> updateProductOnServer(
    String token,
    int productId,
    String name,
    int categoryId,
    String type,
    double price,
    int stock,
    String description,
  ) async {
    final product = await _productService.updateProduct(
      token,
      productId,
      name,
      categoryId,
      type,
      price,
      stock,
      description,
    );
    final index = _products.indexWhere((item) => item.id == productId);
    if (index >= 0) {
      _products[index] = product;
      filterByCategory(selectedCategory);
      notifyListeners();
    }
  }

  void deleteProduct(int id) {
    _products.removeWhere((product) => product.id == id);
    filterByCategory(selectedCategory);
  }
}
