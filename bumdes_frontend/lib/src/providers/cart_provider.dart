import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List.unmodifiable(_items);

  double get total => _items.fold(0, (sum, item) => sum + item.totalPrice);

  void addProduct(ProductModel product, int quantity) {
    final existing = _items.where((item) => item.product.id == product.id).toList();
    if (existing.isNotEmpty) {
      existing.first.quantity += quantity;
    } else {
      _items.add(CartItemModel(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeItem(ProductModel product) {
    _items.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  void updateQuantity(ProductModel product, int newQuantity) {
    final item = _items.firstWhere((item) => item.product.id == product.id, orElse: () => CartItemModel.empty());
    if (item.isEmpty) return;
    if (newQuantity <= 0) {
      removeItem(product);
    } else {
      item.quantity = newQuantity;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
