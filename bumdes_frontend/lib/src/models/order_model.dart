import 'product_model.dart';
import 'order_item_model.dart';

class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final DateTime createdAt;
  final double total;
  final List<OrderItemModel> items;
  final List<ProductModel> products;
  final String? recipientName;
  final String? recipientPhone;
  final String? recipientAddress;
  final String? paymentProof;
  final String? bankAccount;
  final String? notes;
  final String? sellerName;
  final String? paymentStatus;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.total,
    required this.items,
    required this.products,
    this.recipientName,
    this.recipientPhone,
    this.recipientAddress,
    this.paymentProof,
    this.bankAccount,
    this.notes,
    this.sellerName,
    this.paymentStatus,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems =
        (json['items'] as List<dynamic>?) ??
        (json['order_items'] as List<dynamic>?) ??
        (json['orderItems'] as List<dynamic>?) ??
        (json['products'] as List<dynamic>?) ??
        [];

    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((item) => OrderItemModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final products = items.map((item) => item.product).toList();

    // Try to parse total; support several field names and compute from items as fallback
    double parsedTotal = _parseDouble(
      json['total'] ?? json['total_price'] ?? json['amount'],
    );

    final computedTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );

    if (computedTotal > 0 && parsedTotal != computedTotal) {
      parsedTotal = computedTotal;
    }

    return OrderModel(
      id: json['id'] as int? ?? 0,
      orderNumber:
          json['order_number'] as String? ??
          json['order_code'] as String? ??
          'N/A',
      status:
          json['status'] as String? ??
          json['order_status'] as String? ??
          'Menunggu Pembayaran',
      createdAt:
          DateTime.tryParse(
            json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      total: parsedTotal,
      items: items,
      products: products,
      recipientName:
          json['recipient_name'] as String? ?? json['recipientName'] as String?,
      recipientPhone:
          json['recipient_phone'] as String? ??
          json['recipientPhone'] as String?,
      recipientAddress:
          json['recipient_address'] as String? ??
          json['recipientAddress'] as String?,
      paymentProof:
          json['payment_proof'] as String? ?? json['paymentProof'] as String?,
      bankAccount:
          json['bank_account'] as String? ?? json['bankAccount'] as String?,
      notes: json['notes'] as String?,
      sellerName: _parseSellerName(json),
      paymentStatus: _parsePaymentStatus(json),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static String? _parseSellerName(Map<String, dynamic> json) {
    if (json['store'] is Map<String, dynamic>) {
      final storeJson = json['store'] as Map<String, dynamic>;
      return storeJson['store_name'] as String? ??
          storeJson['name'] as String? ??
          storeJson['storeName'] as String?;
    }
    return json['store_name'] as String? ?? json['storeName'] as String?;
  }

  static String? _parsePaymentStatus(Map<String, dynamic> json) {
    String? status;

    if (json['payment'] is Map<String, dynamic>) {
      // Backend kadang mengirim:
      // - payment.status: Pending/Confirmed
      // - payment.payment_status: PAID/PENDING
      status = json['payment']['payment_status'] as String? ??
          json['payment']['status'] as String?;
    } else {
      status = json['payment_status'] as String? ??
          json['paymentStatus'] as String?;
    }

    if (status == null) return null;

    final normalized = status.toUpperCase();

    // Normalisasi agar logika ReportService (yang berharap 'Lunas') konsisten.
    if (normalized == 'PAID' || normalized == 'CONFIRMED') {
      return 'Lunas';
    }

    // Pending / belum dibayar
    if (normalized == 'PENDING' || normalized == 'PENDING_PAYMENT' ||
        normalized == 'PENDING_UPLOAD' || normalized == 'PENDING_WAITING') {
      return 'Belum Lunas';
    }

    // Untuk kasus lain, kembalikan apa adanya supaya UI tetap bisa menampilkan.
    // Contoh: 'REJECTED', 'FAILED', dll.
    if (normalized == 'REJECTED' || normalized == 'FAILED' || normalized == 'EXPIRED') {
      return 'Ditolak';
    }

    return status;
  }

}
