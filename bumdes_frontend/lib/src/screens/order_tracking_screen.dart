import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/courier_tracking_map.dart';

class OrderTrackingScreen extends StatelessWidget {
  static const routeName = '/order-tracking';
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  // Peta kurir hanya relevan begitu paket benar-benar dalam perjalanan.
  bool get _isInTransit =>
      order.status == 'Dikirim' || order.status == 'Estimasi Sampai';

  @override
  Widget build(BuildContext context) {
    final estimatedArrival = order.createdAt.add(const Duration(days: 3));
    final statusSteps = [
      'Menunggu Pembayaran',
      'Dikonfirmasi',
      'Diproses',
      'Dikemas',
      'Dikirim',
      'Estimasi Sampai',
      'Selesai',
    ];

    final currentIndex = statusSteps.indexOf(order.status);
    final safeIndex = currentIndex >= 0 ? currentIndex : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lacak Pesanan'),
        backgroundColor: const Color(0xFF2A7F41),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF5FBF6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Status sekarang: ${order.status}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Estimasi sampai: ${estimatedArrival.day}/${estimatedArrival.month}/${estimatedArrival.year}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_isInTransit) ...[
              const SizedBox(height: 18),
              const Text(
                'Lokasi Kurir',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final token =
                      Provider.of<AuthProvider>(context, listen: false).token;
                  if (token == null) {
                    return const SizedBox.shrink();
                  }
                  return CourierTrackingMap(token: token, orderId: order.id);
                },
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Keadaan Produk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(
                  label: Text('Dikemas'),
                  backgroundColor: Color(0xFFE8F5E9),
                ),
                Chip(
                  label: Text('Dikirim'),
                  backgroundColor: Color(0xFFE3F2FD),
                ),
                Chip(
                  label: Text('Estimasi Sampai'),
                  backgroundColor: Color(0xFFFFF3E0),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Tahapan status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...List.generate(statusSteps.length, (index) {
              final isActive = index <= safeIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isActive
                          ? const Color(0xFF2A7F41)
                          : Colors.grey.shade300,
                      child: Icon(
                        isActive ? Icons.check : Icons.circle_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusSteps[index],
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive ? Colors.black87 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}