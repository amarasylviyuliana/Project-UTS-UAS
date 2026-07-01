import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  static const routeName = '/product-detail';
  final ProductModel? product;
  const ProductDetailScreen({super.key, this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Produk')),
        body: const Center(child: Text('Produk tidak ditemukan')),
      );
    }
    final cart = Provider.of<CartProvider>(context, listen: false);
    final available = product.stock > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, HomeScreen.routeName),
            icon: const Icon(Icons.home_outlined, color: Colors.black87),
            tooltip: 'Beranda',
          ),
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, HomeScreen.routeName),
            icon: const Icon(Icons.search_outlined, color: Colors.black87),
            tooltip: 'Pencarian',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, CartScreen.routeName),
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
            tooltip: 'Keranjang',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, OrderHistoryScreen.routeName),
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.black87),
            tooltip: 'Pesanan',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, ProfileScreen.routeName),
            icon: const Icon(Icons.person_outline, color: Colors.black87),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildImageSection(product)),
                  const SizedBox(width: 32),
                  Expanded(flex: 5, child: _buildDetailSection(product, available, cart)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(product),
                const SizedBox(height: 24),
                _buildDetailSection(product, available, cart),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageSection(ProductModel product) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        product.imageUrl,
        height: 420,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          height: 420,
          color: Colors.grey[200],
          child: const Center(child: Icon(Icons.image_not_supported, size: 88)),
        ),
      ),
    );
  }

  Widget _buildDetailSection(ProductModel product, bool available, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Harga: Rp ${product.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 8),
          Text('Toko: ${product.storeName}', style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 4),
          Text('Asal: ${product.location}', style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 16),
          Text(product.stock == 0 ? 'Stok Habis' : 'Stok tersedia: ${product.stock}', style: TextStyle(color: product.stock == 0 ? Colors.red : Colors.green, fontSize: 16)),
          const SizedBox(height: 24),
          const Text('Deskripsi Produk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(product.description, style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 24),
          if (!product.isService && available)
            Row(
              children: [
                const Text('Jumlah:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 12),
                _QuantitySelector(initialValue: _quantity, maxValue: product.stock, onChanged: (value) => setState(() => _quantity = value)),
              ],
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: available
                  ? () {
                      cart.addProduct(product, _quantity);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk ditambahkan ke keranjang')));
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: const BorderSide(color: Colors.green),
              ),
              child: const Text('Masukkan ke Keranjang', style: TextStyle(fontSize: 16, color: Colors.green)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: available
                  ? () {
                      cart.addProduct(product, _quantity);
                      Navigator.pushNamed(context, CartScreen.routeName);
                    }
                  : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              child: const Text('Pesan Sekarang', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int initialValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const _QuantitySelector({required this.initialValue, required this.maxValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final value = initialValue;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Container(
          width: 34,
          alignment: Alignment.center,
          child: Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < maxValue ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
