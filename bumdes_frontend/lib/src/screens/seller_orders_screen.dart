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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token;
      
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Token tidak ditemukan. Silakan login kembali.';
          _loading = false;
        });
        return;
      }
      
      final res = await _service.getSellerOrders(token);
      if (mounted) {
        setState(() {
          _orders = res;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading seller orders: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat pesanan: $e';
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pesanan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.statusFilters == null 
      ? _orders 
      : _orders.where((o) => widget.statusFilters!.contains(o.status)).toList();
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.screenTitle ?? 'Pesanan Masuk')),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          )
        : filtered.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada pesanan dengan status ini',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Segarkan'),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final o = filtered[i];
            return ListTile(
              title: Text('Order #${o.id} - ${o.recipientName ?? 'N/A'}'),
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
