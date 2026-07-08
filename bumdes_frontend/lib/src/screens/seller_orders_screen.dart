import 'dart:async';
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

class _SellerOrdersScreenState extends State<SellerOrdersScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _service = OrderService();
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _errorMessage;
  late TabController _tabController;
  Timer? _autoRefreshTimer;

  final List<String> _tabLabels = [
    'Semua',
    'Menunggu',
    'Dikonfirmasi',
    'Diproses',
    'Dikirim',
    'Selesai',
    'Dibatalkan',
  ];

  final List<String?> _tabFilters = [
    null,
    'Menunggu Pembayaran',
    'Dikonfirmasi',
    'Diproses',
    'Dikirim',
    'Selesai',
    'Dibatalkan',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.statusFilters != null) {
      _tabController = TabController(length: 1, vsync: this);
    } else {
      _tabController = TabController(length: _tabLabels.length, vsync: this);
    }
    _load();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoRefresh(String token) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _load();
      }
    });
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
      _startAutoRefresh(token);
      final res = await _service.getSellerOrders(token);
      if (mounted) {
        setState(() {
          _orders = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat pesanan: $e';
          _loading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu pembayaran':
      case 'menunggu konfirmasi':
        return Colors.orange;
      case 'dikonfirmasi':
        return Colors.blue;
      case 'diproses':
        return Colors.purple;
      case 'dikirim':
        return Colors.indigo;
      case 'selesai':
        return const Color(0xFF2A7F41);
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // FIX: paymentStatus dari OrderModel sudah dinormalisasi jadi 'Lunas'/'Belum Lunas'
  // Tidak perlu cek 'confirmed'/'pending' lagi — langsung pakai nilai dari model
  String _getPaymentLabel(String? paymentStatus) {
    if (paymentStatus == null || paymentStatus.isEmpty) return 'Belum Lunas';

    final normalized = paymentStatus.toLowerCase().trim();

    // Nilai yang sudah dinormalisasi oleh OrderModel._parsePaymentStatus
    if (normalized == 'lunas') return 'Lunas';
    if (normalized == 'belum lunas') return 'Belum Lunas';
    if (normalized == 'ditolak') return 'Ditolak';

    // Fallback: nilai mentah dari backend (jika model belum normalisasi)
    if (normalized == 'paid' || normalized == 'confirmed') return 'Lunas';
    if (normalized == 'pending' || normalized == 'pending_payment')
      return 'Belum Lunas';
    if (normalized == 'rejected' || normalized == 'failed') return 'Ditolak';

    return paymentStatus; // tampilkan apa adanya
  }

  Widget _buildOrderList(List<OrderModel> orders, String? filter) {
    List<OrderModel> filtered;
    if (widget.statusFilters != null) {
      filtered = orders
          .where((o) => widget.statusFilters!.contains(o.status))
          .toList();
    } else if (filter != null) {
      filtered = orders.where((o) => o.status == filter).toList();
    } else {
      filtered = orders;
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Belum ada pesanan${filter != null ? ' "$filter"' : ''}.',
              style: const TextStyle(color: Colors.black45, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Segarkan')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final order = filtered[index];
          final statusColor = _getStatusColor(order.status);
          final paymentLabel = _getPaymentLabel(order.paymentStatus);

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 1.5,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: order),
                ),
              ).then((_) => _load()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.recipientName ?? '-',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (order.items.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.items.map((i) => i.product.name).join(', '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: paymentLabel == 'Lunas'
                                    ? Colors.green.withOpacity(0.1)
                                    : paymentLabel == 'Ditolak'
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                paymentLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: paymentLabel == 'Lunas'
                                      ? Colors.green
                                      : paymentLabel == 'Ditolak'
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Rp ${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2A7F41),
                          ),
                        ),
                      ],
                    ),
                    if (order.status == 'Menunggu Pembayaran' ||
                        order.status == 'Menunggu Konfirmasi' ||
                        order.status == 'Dikonfirmasi' ||
                        order.status == 'Diproses') ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(order: order),
                            ),
                          ).then((_) => _load()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: statusColor,
                            side: BorderSide(color: statusColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(
                            _getActionLabel(order.status),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getActionLabel(String status) {
    switch (status) {
      case 'Menunggu Pembayaran':
      case 'Menunggu Konfirmasi':
        return 'Konfirmasi Pesanan';
      case 'Dikonfirmasi':
        return 'Proses Pesanan';
      case 'Diproses':
        return 'Kirim Pesanan';
      default:
        return 'Lihat Detail';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.statusFilters != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.screenTitle ?? 'Pesanan'),
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            : _buildOrderList(_orders, null),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.screenTitle ?? 'Pesanan Masuk'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF2A7F41),
          unselectedLabelColor: Colors.black45,
          indicatorColor: const Color(0xFF2A7F41),
          tabs: _tabLabels.map((label) {
            final count = label == 'Semua'
                ? _orders.length
                : _orders
                      .where(
                        (o) =>
                            o.status == _tabFilters[_tabLabels.indexOf(label)],
                      )
                      .length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A7F41),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: List.generate(
                _tabFilters.length,
                (i) => _buildOrderList(_orders, _tabFilters[i]),
              ),
            ),
    );
  }
}
