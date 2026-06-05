import 'product_model.dart';

class OrderItemModel {
  final ProductModel product;
  final int quantity;
  final double unitPrice;

  OrderItemModel({required this.product, required this.quantity, required this.unitPrice});

  double get totalPrice => quantity * unitPrice;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'];
    final product = productJson is Map<String, dynamic>
        ? ProductModel.fromJson(productJson)
        : ProductModel.empty();

    final quantityValue = json['quantity'] ?? json['qty'] ?? json['quantity_order'] ?? 0;
    final unitValue = json['unit_price'] ?? json['price'] ?? json['product_price'] ?? product.price;

    return OrderItemModel(
      product: product,
      quantity: _parseInt(quantityValue),
      unitPrice: _parseDouble(unitValue),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    if (value is num) return value.toDouble();
    return 0;
  }
}
