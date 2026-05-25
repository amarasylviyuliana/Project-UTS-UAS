// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import 'order_history_screen.dart';

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
      return const Center(child: Text('Keranjang Anda kosong'));
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildOrderForm(cart, auth, orderService)),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: _buildOrderSummary(cart)),
                ],
              ),
            );
          }
          return ListView(
            children: [
              _buildOrderForm(cart, auth, orderService),
              const SizedBox(height: 24),
              _buildOrderSummary(cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderForm(CartProvider cart, AuthProvider auth, OrderService orderService) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Checkout Sekarang', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nama Penerima'),
                    validator: (value) => value == null || value.isEmpty ? 'Nama penerima wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'No. HP Penerima'),
                    validator: (value) => value == null || value.isEmpty ? 'Nomor HP wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Alamat Pengiriman'),
                    maxLines: 4,
                    validator: (value) => value == null || value.isEmpty ? 'Alamat wajib diisi' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _placeOrder(context, cart, auth, orderService),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Checkout Sekarang', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, CartProvider cart, AuthProvider auth, OrderService orderService) async {
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final currentContext = context;
    try {
      print('DEBUG: Starting checkout...');
      print('DEBUG: Token: ${auth.token}');
      print('DEBUG: Items count: ${cart.items.length}');
      print('DEBUG: Total: ${cart.total}');

      final response = await orderService.createOrder(
        auth.token!,
        cart.items,
        cart.total,
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _addressController.text.trim(),
      );

      print('DEBUG: Checkout response: $response');

      cart.clear();

      if (!mounted) return;
      await showDialog(
        context: currentContext,
        builder: (context) => AlertDialog(
          title: const Text('Pesanan Diterima'),
          content: Text(response['message'] ?? 'Pesanan Anda sedang diproses.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, OrderHistoryScreen.routeName);
              },
              child: const Text('Lihat Riwayat Pesanan'),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      print('DEBUG: Checkout error: $e');
      print('DEBUG: Stack trace: $stackTrace');
      final msg = e is Exception ? e.toString() : 'Gagal membuat pesanan: $e';
      if (!mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildOrderSummary(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ringkasan Pesanan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...cart.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                item.product.imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  width: 80,
                                  height: 80,
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
                                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                                        onPressed: item.quantity > 1
                                            ? () => cart.updateQuantity(item.product, item.quantity - 1)
                                            : () => cart.removeItem(item.product),
                                        color: Colors.grey[700],
                                      ),
                                      Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 20),
                                        onPressed: item.quantity < item.product.stock
                                            ? () => cart.updateQuantity(item.product, item.quantity + 1)
                                            : null,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => cart.removeItem(item.product),
                                        child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text('Rp ${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Rp ${cart.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
