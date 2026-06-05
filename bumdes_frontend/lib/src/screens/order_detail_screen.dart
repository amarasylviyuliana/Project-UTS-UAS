import 'package:flutter/material.dart';
import '../models/order_model.dart';
import 'payment_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  static const routeName = '/order-detail';
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu pembayaran':
        return Colors.orange;
      case 'dikonfirmasi':
      case 'diproses':
        return Colors.blue;
      case 'dikirim':
        return Colors.indigo;
      case 'selesai':
        return Colors.green;
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderNumber,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tanggal: ${order.createdAt.toLocal().toString().split(' ').first}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status).withAlpha((0.2 * 255).round()),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getStatusColor(order.status)),
                            ),
                            child: Text(
                              order.status,
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Daftar Produk
              const Text(
                'Daftar Produk',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: order.items.isEmpty
                      ? const Text('Tidak ada produk dalam pesanan ini')
                      : Column(
                          children: order.items
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          item.product.imageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image_not_supported),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.product.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 6),
                                            Text('Rp ${item.unitPrice.toStringAsFixed(0)} x ${item.quantity}', style: const TextStyle(color: Colors.black54)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Rp ${item.totalPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Informasi Pengiriman
              const Text(
                'Informasi Pengiriman',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.recipientName != null) ...[
                        const Text('Penerima:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(order.recipientName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                      ],
                      if (order.recipientPhone != null) ...[
                        const Text('No. HP:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(order.recipientPhone ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                      ],
                      if (order.recipientAddress != null) ...[
                        const Text('Alamat Pengiriman:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(order.recipientAddress ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                      ],
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        const Text('Catatan:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(order.notes ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Total Pembayaran
              Card(
                elevation: 1,
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rp ${order.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Aksi Pembayaran
              if (order.status.toLowerCase().contains('pembayaran') || order.status.toLowerCase().contains('pending'))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentScreen(order: order),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Bayar Sekarang', style: TextStyle(fontSize: 16)),
                  ),
                ),

              if (order.status.toLowerCase() == 'dikirim')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Konfirmasi Penerimaan'),
                          content: const Text('Apakah Anda yakin telah menerima barang?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pesanan dikonfirmasi selesai')),
                                );
                              },
                              child: const Text('Konfirmasi'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Konfirmasi Penerimaan', style: TextStyle(fontSize: 16)),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
