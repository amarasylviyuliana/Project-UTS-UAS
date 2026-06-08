import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/order_service.dart';
import '../models/order_model.dart';
import 'order_detail_screen.dart';
import '../providers/auth_provider.dart';

class SellerOrdersScreen extends StatefulWidget {
  static const routeName = '/seller-orders';
  final List<String>? statusFilters;
  final String? screenTitle;
  const SellerOrdersScreen({super.key, this.statusFilters, this.screenTitle});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final OrderService _service = OrderService();
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token;
      final res = await _service.getSellerOrders(token ?? '');
      setState(() => _orders = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat pesanan: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.statusFilters == null 
      ? _orders 
      : _orders.where((o) => widget.statusFilters!.contains(o.status)).toList();
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.screenTitle ?? 'Pesanan Masuk')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final o = filtered[i];
            return ListTile(
              title: Text('Order #${o.id} - ${o.recipientName ?? ''}'),
              subtitle: Text('Rp ${o.total.toStringAsFixed(0)} • ${o.status}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, OrderDetailScreen.routeName, arguments: {'order': o}),
            );
          },
        ),
      ),
    );
  }
}
