import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import 'payment_gateway_screen.dart';
import 'order_history_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  static const routeName = '/order-detail';
  final OrderModel? order;
  final int? orderId;

  const OrderDetailScreen({super.key, this.order, this.orderId})
    : assert(
        order != null || orderId != null,
        'Order atau orderId harus diisi',
      );

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  bool _isRefreshing = false;
  bool _isLoadingOrder = false;
  bool _isPerformingAction = false;
  String? _refreshError;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    if (_order == null && widget.orderId != null) {
      _loadOrder();
    } else {
      _refreshOrder();
    }
  }

  @override
  void didUpdateWidget(covariant OrderDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orderId != null && widget.orderId != oldWidget.orderId) {
      _order = widget.order;
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Jika token belum dimuat (misal buka via deep link langsung), muat dulu
    if (!auth.isAuthenticated && auth.token == null && !auth.isLoading) {
      await auth.loadToken();
    }

    if (!auth.isAuthenticated || auth.token == null) {
      setState(() {
        _loadError = 'Silakan login untuk melihat detail pesanan.';
      });
      return;
    }

    setState(() {
      _isLoadingOrder = true;
      _loadError = null;
    });

    try {
      final orderId = widget.orderId!;
      final loadedOrder = await OrderService().getOrder(
        auth.token!,
        orderId,
        timeout: const Duration(seconds: 15),
      );

      if (!mounted) return;
      setState(() {
        _order = loadedOrder;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Gagal memuat detail pesanan. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrder = false;
        });
      }
    }
  }

  Future<void> _refreshOrder() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });

    try {
      final updatedOrder = await OrderService().getOrder(
        auth.token!,
        _order!.id,
      );
      if (!mounted) return;
      setState(() {
        _order = updatedOrder;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _refreshError =
              'Gagal memperbarui status pesanan. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _updateOrderStatus(String status) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null || _order == null) {
      return;
    }

    setState(() {
      _isPerformingAction = true;
      _refreshError = null;
    });

    try {
      await OrderService().updateOrderStatus(auth.token!, _order!.id, status);
      await _refreshOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status pesanan diperbarui ke "$status".')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _refreshError =
              'Gagal memperbarui status pesanan. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  Future<void> _confirmReceipt() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null || _order == null) {
      return;
    }

    setState(() {
      _isPerformingAction = true;
      _refreshError = null;
    });

    try {
      await OrderService().confirmReceipt(auth.token!, _order!.id);
      await _refreshOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penerimaan pesanan berhasil dikonfirmasi.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _refreshError = 'Gagal mengkonfirmasi penerimaan. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isPerformingAction = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final orderService = OrderService();
      await orderService.cancelOrder(auth.token!, _order!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibatalkan'),
            backgroundColor: Colors.red,
          ),
        );
        await _refreshOrder();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membatalkan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

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
    if (_order == null) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          Navigator.pushReplacementNamed(context, OrderHistoryScreen.routeName);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Detail Pesanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF2D5016),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          backgroundColor: const Color(0xFFFAFAFA),
          body: Center(
            child: _isLoadingOrder
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _loadError ?? 'Detail pesanan tidak tersedia.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_loadError != null)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D5016),
                            ),
                            onPressed: _loadOrder,
                            child: const Text('Coba lagi', style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }

    final order = _order!;
    final statusColor = _getStatusColor(order.status);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, OrderHistoryScreen.routeName);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Detail Pesanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2D5016),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshOrder,
            tooltip: 'Segarkan status pesanan',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D5016),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tanggal: ${order.createdAt.toLocal().toString().split(' ').first}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(
                              (0.18 * 255).round(),
                              (statusColor.r * 255).round(),
                              (statusColor.g * 255).round(),
                              (statusColor.b * 255).round(),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            order.status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          'Rp ${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_refreshError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    _refreshError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 18),

              _buildSectionTitle('Daftar Produk'),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: order.items.isEmpty
                      ? const Text('Tidak ada produk dalam pesanan ini')
                      : Column(
                          children: order.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      item.product.imageUrl,
                                      width: 62,
                                      height: 62,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                width: 62,
                                                height: 62,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Rp ${item.unitPrice.toStringAsFixed(0)} x ${item.quantity}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Rp ${item.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 18),

              _buildSectionTitle('Informasi Pengiriman'),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.recipientName != null) ...[
                        _buildDetailRow('Penerima', order.recipientName ?? '-'),
                        const SizedBox(height: 10),
                      ],
                      if (order.recipientPhone != null) ...[
                        _buildDetailRow('No. HP', order.recipientPhone ?? '-'),
                        const SizedBox(height: 10),
                      ],
                      if (order.recipientAddress != null) ...[
                        _buildDetailRow(
                          'Alamat',
                          order.recipientAddress ?? '-',
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        _buildDetailRow('Catatan', order.notes ?? '-'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              if (order.paymentStatus != null)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 1,
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildDetailRow(
                      'Status Pembayaran',
                      order.paymentStatus ?? order.status,
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              if ((order.status.toLowerCase().contains('pembayaran') ||
                      order.status.toLowerCase().contains('pending')) &&
                  Provider.of<AuthProvider>(context, listen: false).user?.role != 'seller' &&
                  Provider.of<AuthProvider>(context, listen: false).user?.role != 'admin')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PaymentGatewayScreen(order: order),
                        ),
                      );
                      await _refreshOrder();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A7F41),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Bayar Sekarang',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              // Tombol Batalkan untuk Pembeli
              if ((order.status.toLowerCase().contains('pembayaran') ||
                      order.status.toLowerCase().contains('pending') ||
                      order.status.toLowerCase() == 'menunggu konfirmasi') &&
                  Provider.of<AuthProvider>(context, listen: false).user?.role != 'seller' &&
                  Provider.of<AuthProvider>(context, listen: false).user?.role != 'admin' &&
                  order.status.toLowerCase() != 'dibatalkan')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isPerformingAction ? null : _cancelOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Batalkan Pesanan',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),

              if (order.status.toLowerCase() == 'dikirim' &&
                  Provider.of<AuthProvider>(context).user?.role != 'seller')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPerformingAction ? null : _confirmReceipt,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isPerformingAction
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Konfirmasi Penerimaan',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              if (Provider.of<AuthProvider>(context).user?.role == 'seller')
                Column(
                  children: [
                    if (order.status.toLowerCase() == 'menunggu konfirmasi')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isPerformingAction
                                ? null
                                : () => _updateOrderStatus('Dikonfirmasi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isPerformingAction
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Konfirmasi Pesanan',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                      ),

                    if (order.status.toLowerCase() == 'dikonfirmasi')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isPerformingAction
                                ? null
                                : () => _updateOrderStatus('Diproses'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Pesanan Sedang Disiapkan',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),

                    if (order.status.toLowerCase() == 'dikonfirmasi' ||
                        order.status.toLowerCase() == 'diproses')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isPerformingAction
                                ? null
                                : () => _updateOrderStatus('Dikirim'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isPerformingAction
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Kirim Pesanan',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                      ),

                    if (order.status.toLowerCase() == 'dikirim')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPerformingAction
                              ? null
                              : () => _updateOrderStatus('Selesai'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _isPerformingAction
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Tandai Selesai',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    // Tombol Batalkan untuk Penjual
                    if (order.status.toLowerCase() == 'menunggu konfirmasi' ||
                        order.status.toLowerCase() == 'menunggu pembayaran')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isPerformingAction ? null : _cancelOrder,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Tolak / Batalkan Pesanan',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}