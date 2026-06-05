import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';

class OrderService {
  Future<Map<String, dynamic>> createOrder(
    String token,
    List<CartItemModel> items,
    double total,
    String recipientName,
    String recipientPhone,
    String recipientAddress,
  ) async {
    final invalidItems = items.where((item) => item.product.id <= 0).toList();
    if (invalidItems.isNotEmpty) {
      throw Exception(
        'Produk dalam keranjang tidak valid. Silakan muat ulang aplikasi dan coba lagi.',
      );
    }

    final api = ApiService(token: token);

    final orderItems = items
        .map(
          (i) => {
            'product_id': i.product.id,
            'quantity': i.quantity,
            'unit_price': i.product.price,
          },
        )
        .toList();

    final payload = {
      'total': total,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'recipient_address': recipientAddress,
      'order_items': orderItems,
    };

    debugPrint('DEBUG OrderService: Sending payload to /checkout: $payload');
    debugPrint(
      'DEBUG OrderService: Product IDs: ${orderItems.map((item) => item["product_id"]).toList()}',
    );

    final response = await api.post('/checkout', payload);
    final orderData = _extractOrderFromResponse(response);
    if (orderData != null) {
      response['order'] = orderData;
    }
    return response;
  }

  Future<Map<String, dynamic>> submitPayment(String token, int orderId) async {
    final api = ApiService(token: token);
    final response = await api.post('/payments/$orderId/submit', {});
    return response;
  }

  Map<String, dynamic>? _extractOrderFromResponse(
    Map<String, dynamic> response,
  ) {
    if (response['order'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(
        response['order'] as Map<String, dynamic>,
      );
    }

    if (response['data'] is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>;
      if (data['order'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['order'] as Map<String, dynamic>);
      }
      if (data['id'] != null) {
        return Map<String, dynamic>.from(data);
      }
    }

    if (response['id'] != null) {
      return Map<String, dynamic>.from(response);
    }

    return null;
  }

  Future<List<OrderModel>> fetchOrders(String token) async {
    final api = ApiService(token: token);
    try {
      final response = await api.getRaw('/orders');
      final rawOrders = _extractOrderList(response);

      return rawOrders
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<OrderModel>> getSellerOrders(String token) async {
    final api = ApiService(token: token);
    try {
      final response = await api.getRaw('/seller/orders');
      final rawOrders = _extractOrderList(response);

      return rawOrders
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  List<dynamic> _extractOrderList(dynamic response) {
    if (response is List) {
      return response;
    }

    if (response is! Map<String, dynamic>) {
      return [];
    }

    List<dynamic> candidates = [];

    if (response['data'] is List) {
      candidates = response['data'] as List<dynamic>;
    } else if (response['orders'] is List) {
      candidates = response['orders'] as List<dynamic>;
    } else if (response['items'] is List) {
      candidates = response['items'] as List<dynamic>;
    } else if (response['data'] is Map<String, dynamic>) {
      final nested = response['data'] as Map<String, dynamic>;
      if (nested['data'] is List) {
        candidates = nested['data'] as List<dynamic>;
      } else if (nested['orders'] is List) {
        candidates = nested['orders'] as List<dynamic>;
      } else if (nested['items'] is List) {
        candidates = nested['items'] as List<dynamic>;
      }
    }

    return List<dynamic>.from(candidates);
  }
}
