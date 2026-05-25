import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import 'product_form_screen.dart';

class StoreDashboardScreen extends StatelessWidget {
  static const routeName = '/store-dashboard';
  const StoreDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    final rootProducts = provider.allProducts;
    return Scaffold(
      appBar: AppBar(title: const Text('Dasbor Toko BUMDes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Produk & Jasa', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                  onPressed: () {
                    Navigator.pushNamed(context, ProductFormScreen.routeName);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: rootProducts.length,
                itemBuilder: (context, index) {
                  final product = rootProducts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Image.network(product.imageUrl, width: 60, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Icon(Icons.image_not_supported)),
                      title: Text(product.name),
                      subtitle: Text('${product.category} • Rp ${product.price.toStringAsFixed(0)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.pushNamed(context, ProductFormScreen.routeName, arguments: {'product': product});
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
