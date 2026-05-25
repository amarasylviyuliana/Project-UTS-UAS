import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<OrderModel>> _ordersFuture;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadOrders();
      _isInitialized = true;
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (!auth.isAuthenticated) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Silakan login untuk melihat riwayat pesanan.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Login'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: FutureBuilder<List<OrderModel>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const Text('Gagal memuat riwayat pesanan.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _refreshOrders,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  );
                }

                final orders = snapshot.data ?? [];

                return ListView(
                  children: [
                    const Text('Riwayat Pesanan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (orders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24.0),
                        child: Center(child: Text('Belum ada riwayat pesanan.')), 
                      ),
                    ...orders.map((order) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            onTap: () => _showOrderDetails(order),
                            title: Text(order.orderNumber),
                            subtitle: Text('Status: ${order.status}'),
                            trailing: Text('Rp ${order.total.toStringAsFixed(0)}'),
                          ),
                        )),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
