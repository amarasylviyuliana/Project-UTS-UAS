import 'api_service.dart';
import '../models/order_tracking_model.dart';

class OrderTrackingService {
  /// Ambil posisi terbaru kurir untuk pesanan [orderId].
  Future<OrderTrackingModel> fetchTrackingLocation(
    String token,
    int orderId,
  ) async {
    final api = ApiService(token: token);
    final response = await api.get('/orders/$orderId/tracking-location');

    final data = response['data'];
    if (data is! Map) {
      throw Exception('Data pelacakan tidak valid');
    }

    return OrderTrackingModel.fromJson(Map<String, dynamic>.from(data));
  }
}