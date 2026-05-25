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

    return await api.post('/checkout', payload);
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
