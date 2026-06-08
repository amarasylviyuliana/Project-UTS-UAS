import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  static const routeName = '/orders';
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with RouteAware {
  late Future<List<OrderModel>> _ordersFuture;
  bool _isInitialized = false;
  bool _isRouteObserverSubscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadOrders();
      _isInitialized = true;
    }

    if (!_isRouteObserverSubscribed) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        routeObserver.subscribe(this, modalRoute);
        _isRouteObserverSubscribed = true;
      }
    }
  }

  void _loadOrders() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated && auth.token != null) {
      _ordersFuture = OrderService().fetchOrders(auth.token!);
    } else {
      _ordersFuture = Future.value([]);
    }
  }

  Future<void> _refreshOrders() async {
    _loadOrders();
    setState(() {});
    await _ordersFuture;
  }

  void _showOrderDetails(OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: order),
      ),
    );
  }

  @override
  void didPopNext() {
    _refreshOrders();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (!auth.isAuthenticated) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Silakan login untuk melihat riwayat pesanan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: FutureBuilder<List<OrderModel>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Gagal memuat riwayat pesanan.', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshOrders,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data ?? [];

                return orders.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24.0),
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Belum ada riwayat pesanan.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              onTap: () => _showOrderDetails(order),
                              title: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status: ${order.status}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: Rp ${order.total.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                            ),
                          );
                        },
                      );
              },
            ),
          );
        },
      ),
    );
  }
}
