import 'product_model.dart';

class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final DateTime createdAt;
  final double total;
  final List<ProductModel> products;
  final String? recipientName;
  final String? recipientPhone;
  final String? recipientAddress;
  final String? paymentProof;
  final String? bankAccount;
  final String? notes;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.total,
    required this.products,
    this.recipientName,
    this.recipientPhone,
    this.recipientAddress,
    this.paymentProof,
    this.bankAccount,
    this.notes,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ??
        (json['order_items'] as List<dynamic>?) ??
        (json['products'] as List<dynamic>?) ??
        [];

    final products = rawItems.map((item) {
      if (item is Map<String, dynamic>) {
        final productJson = item['product'];
        if (productJson is Map<String, dynamic>) {
          return ProductModel.fromJson(productJson);
        }
        return ProductModel.fromJson(Map<String, dynamic>.from(item));
      }
      return ProductModel.empty();
    }).toList();

    // Try to parse total; if missing or zero, compute from order items as fallback
    double parsedTotal = _parseDouble(json['total'] ?? json['amount']);
    if ((parsedTotal == 0) && json['items'] is List) {
      try {
      parsedTotal = (json['items'] as List).fold<double>(0, (sum, item) {
        if (item is Map<String, dynamic>) {
        final qty = item['quantity'];
        final unit = item['unit_price'] ?? (item['product'] is Map ? item['product']['price'] : null);
        final q = qty is num ? qty.toDouble() : double.tryParse(qty?.toString() ?? '0') ?? 0;
        final u = unit is num ? unit.toDouble() : double.tryParse(unit?.toString() ?? '0') ?? 0;
        return sum + (q * u);
        }
        return sum;
      });
      } catch (_) {
      // ignore and keep parsedTotal
      }
    }

    return OrderModel(
      id: json['id'] as int? ?? 0,
      orderNumber: json['order_number'] as String?
        ?? json['order_code'] as String?
        ?? 'N/A',
      status: json['status'] as String?
        ?? json['order_status'] as String?
        ?? 'Menunggu Pembayaran',
      createdAt: DateTime.tryParse(json['created_at'] as String? ??
          json['createdAt'] as String? ??
          '') ??
        DateTime.now(),
      total: parsedTotal,
      products: products,
      recipientName: json['recipient_name'] as String?
        ?? json['recipientName'] as String?,
      recipientPhone: json['recipient_phone'] as String?
        ?? json['recipientPhone'] as String?,
      recipientAddress: json['recipient_address'] as String?
        ?? json['recipientAddress'] as String?,
      paymentProof: json['payment_proof'] as String?
        ?? json['paymentProof'] as String?,
      bankAccount: json['bank_account'] as String?
        ?? json['bankAccount'] as String?,
      notes: json['notes'] as String?,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    if (value is num) return value.toDouble();
    return 0;
  }
}
