// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import '../models/order_model.dart';
import 'order_history_screen.dart';
import 'payment_gateway_screen.dart';

class CartScreen extends StatefulWidget {
  static const routeName = '/cart';
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final orderService = OrderService();

    if (cart.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pembayaran Pesanan')),
        body: const Center(child: Text('Keranjang Anda kosong')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran Pesanan'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildOrderForm(cart, auth, orderService),
                    ),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: _buildOrderSummary(cart)),
                  ],
                ),
              );
            }
            return ListView(
              children: [
                _buildOrderSummary(cart),
                const SizedBox(height: 24),
                _buildOrderForm(cart, auth, orderService),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderForm(
    CartProvider cart,
    AuthProvider auth,
    OrderService orderService,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Checkout Sekarang',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Penerima',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Nama penerima wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'No. HP Penerima',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Nomor HP wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Alamat Pengiriman',
                    ),
                    maxLines: 4,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Alamat wajib diisi'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _placeOrder(context, cart, auth, orderService),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Checkout Sekarang',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(
    BuildContext context,
    CartProvider cart,
    AuthProvider auth,
    OrderService orderService,
  ) async {
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (cart.items.any((item) => item.product.id <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Produk di keranjang tidak valid. Silakan muat ulang aplikasi dan coba lagi.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final currentContext = context;
    try {
      debugPrint('DEBUG: Starting checkout...');
      debugPrint('DEBUG: Token: ${auth.token}');
      debugPrint('DEBUG: Items count: ${cart.items.length}');
      debugPrint('DEBUG: Total: ${cart.total}');

      final response = await orderService.createOrder(
        auth.token!,
        cart.items,
        cart.total,
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _addressController.text.trim(),
      );

      debugPrint('DEBUG: Checkout response: $response');

      final orderData = _extractOrderData(response);
      final createdOrder = orderData != null
          ? OrderModel.fromJson(orderData)
          : null;
      cart.clear();

      if (!mounted) return;
      if (createdOrder != null) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentGatewayScreen(order: createdOrder),
          ),
        );
      } else {
        await showDialog(
          context: currentContext,
          builder: (context) => AlertDialog(
            title: const Text('Pesanan Diterima'),
            content: Text(
              response['message'] ?? 'Pesanan Anda sedang diproses.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                    context,
                    OrderHistoryScreen.routeName,
                  );
                },
                child: const Text('Lihat Riwayat Pesanan'),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: Checkout error: $e');
      debugPrint('DEBUG: Stack trace: $stackTrace');
      final msg = e is Exception ? e.toString() : 'Gagal membuat pesanan: $e';
      if (!mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Map<String, dynamic>? _extractOrderData(Map<String, dynamic> response) {
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

  Widget _buildOrderSummary(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Pesanan',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Periksa kembali detail pesanan Anda sebelum lanjut ke pembayaran.',
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 20),
                ...cart.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 18.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            item.product.imageUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              width: 72,
                              height: 72,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Qty ${item.quantity} • Rp ${item.product.price.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Rp ${item.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24, thickness: 1.2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(color: Colors.black54),
                    ),
                    Text(
                      'Rp ${cart.total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Ongkos Kirim',
                      style: TextStyle(color: Colors.black54),
                    ),
                    Text('Rp 0', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rp ${cart.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pesanan Anda akan dilanjutkan ke gateway pembayaran profesional Xendit setelah checkout.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
