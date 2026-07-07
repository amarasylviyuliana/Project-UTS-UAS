import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
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

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with RouteAware, SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<OrderModel>> _ordersFuture;
  bool _isInitialized = false;
  bool _isRouteObserverSubscribed = false;

  final List<String> _tabLabels = [
    'Semua',
    'Menunggu Bayar',
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
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadOrders();
      _isInitialized = true;
    }
    if (!_isRouteObserverSubscribed) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        routeObserver.subscribe(this, modalRoute);
        _isRouteObserverSubscribed = true;
      }
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

  @override
  void didPopNext() {
    _refreshOrders();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu pembayaran':
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

  Widget _buildOrderList(List<OrderModel> orders, String? filter) {
    final filtered = filter == null
        ? orders
        : orders.where((o) => o.status == filter).toList();

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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final order = filtered[index];
          final statusColor = _getStatusColor(order.status);
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0.5,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: order),
                ),
              ).then((_) => _refreshOrders()),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 0.5),
                ),
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
                              color: Color(0xFF2D5016),
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
                    if (order.items.isNotEmpty)
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: order.items.first.product.imageUrl.isNotEmpty
                                ? Image.network(
                                    order.items.first.product.imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.grey[100],
                                        child: const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.items.first.product.name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (order.items.length > 1)
                                  Text(
                                    '+${order.items.length - 1} produk lainnya',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black45,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status Pembayaran',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                            ),
                            Text(
                              order.paymentStatus ?? 'Belum Lunas',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: order.paymentStatus == 'Lunas'
                                    ? const Color(0xFF2A7F41)
                                    : order.paymentStatus == 'Ditolak'
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2D5016),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFF52B788),
          indicatorWeight: 3,
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (!auth.isAuthenticated) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Silakan login untuk melihat riwayat pesanan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Login', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<OrderModel>>(
            future: _ordersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Gagal memuat riwayat pesanan.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D5016),
                        ),
                        onPressed: _refreshOrders,
                        child: const Text('Coba lagi', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              }

              final orders = snapshot.data ?? [];

              return TabBarView(
                controller: _tabController,
                children: List.generate(
                  _tabFilters.length,
                  (i) => _buildOrderList(orders, _tabFilters[i]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}