import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

/// Service untuk real-time synchronization status pesanan
/// Menggunakan polling mechanism dengan jitter untuk efficient backend load
class OrderSyncService extends ChangeNotifier {
  Timer? _syncTimer;
  Timer? _jitterTimer;

  final Duration _pollInterval = const Duration(seconds: 30);
  final Duration _maxJitter = const Duration(seconds: 5);

  Map<int, OrderModel> _ordersCache = {};
  bool _isPolling = false;
  String? _currentToken;
  Future<List<OrderModel>> Function(String token)? _fetchOrders;

  // Event callbacks
  Function(OrderModel)? onOrderUpdated;
  Function(OrderModel)? onOrderCancelled;
  Function(OrderModel)? onStatusChanged;

  /// Mulai polling untuk order updates
  void startPolling(
    String token, {
    required Future<List<OrderModel>> Function(String token) fetchOrders,
  }) {
    if (_isPolling && _currentToken == token) {
      return; // Sudah polling dengan token yang sama
    }

    _currentToken = token;
    _fetchOrders = fetchOrders;
    // Initial sync immediately
    _performSync(token);

    // Setup periodic polling dengan jitter untuk menghindari thundering herd
    _syncTimer = Timer.periodic(_pollInterval, (_) {
      _performSync(token);
    });
  }

  /// Stop polling
  void stopPolling() {
    _syncTimer?.cancel();
    _jitterTimer?.cancel();
    _isPolling = false;
    _currentToken = null;
  }

  /// Perform synchronization dengan jitter
  Future<void> _performSync(String token) async {
    if (!_isPolling || _currentToken != token) {
      return;
    }

    try {
      // Add jitter untuk distributed polling
      final jitterMs =
          (DateTime.now().millisecondsSinceEpoch % _maxJitter.inMilliseconds);
      final jitter = Duration(milliseconds: jitterMs);

      await Future.delayed(jitter);

      if (!_isPolling || _currentToken != token) {
        return;
      }

      final fetchOrders = _fetchOrders;
      if (fetchOrders == null) {
        return;
      }

      final orders = await fetchOrders(token);

      // Detect perubahan status
      for (final order in orders) {
        if (_ordersCache.containsKey(order.id)) {
          final cached = _ordersCache[order.id]!;

          if (cached.status != order.status) {
            // Status berubah
            if (order.status == 'Dibatalkan' && cached.status != 'Dibatalkan') {
              onOrderCancelled?.call(order);
            }
            onStatusChanged?.call(order);
          }
        }

        _ordersCache[order.id] = order;
        onOrderUpdated?.call(order);
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('OrderSyncService error during sync: $e');
      }
    }
  }

  /// Get cached order
  OrderModel? getCachedOrder(int id) => _ordersCache[id];

  /// Get all cached orders
  List<OrderModel> getCachedOrders() => _ordersCache.values.toList();

  /// Clear cache
  void clearCache() {
    _ordersCache.clear();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
