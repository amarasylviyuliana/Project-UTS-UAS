import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/order_tracking_model.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import '../widgets/courier_tracking_map.dart';
import 'payment_gateway_screen.dart';

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

  // Progress pengiriman terakhir yang dilaporkan oleh CourierTrackingMap.
  // Dipakai untuk mengunci tombol "Tandai Selesai" / "Konfirmasi Penerimaan"
  // selama kurir belum benar-benar sampai (progress < 100%).
  OrderTrackingModel? _tracking;

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
      _tracking = null;
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
      final messenger = ScaffoldMessenger.of(context);
      final orderService = OrderService();
      await orderService.cancelOrder(auth.token!, _order!.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil dibatalkan'),
          backgroundColor: Colors.red,
        ),
      );
      await _refreshOrder();
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

  // Dipanggil oleh CourierTrackingMap setiap kali data lokasi kurir
  // ter-update (polling, tiap ~8 detik). Dipakai untuk menentukan apakah
  // tombol "Tandai Selesai" / "Konfirmasi Penerimaan" sudah boleh ditekan.
  //
  // FIX (optimasi lanjutan): sebelumnya setState() dipanggil di SETIAP
  // update tracking (tiap 8 detik), padahal itu me-rebuild SELURUH
  // OrderDetailScreen — daftar produk, info pengiriman, semua tombol —
  // padahal yang benar-benar dibutuhkan halaman ini cuma tahu apakah
  // status "kurir sudah sampai" berubah atau belum (progress 7% -> 15%
  // -> 23% dst tidak perlu bikin seluruh halaman render ulang).
  // Sekarang setState() cuma dipanggil kalau status itu benar-benar
  // berpindah (dari belum sampai -> sudah sampai, atau sebaliknya).
  void _handleTrackingUpdate(OrderTrackingModel tracking) {
    if (!mounted) return;

    final wasComplete =
        _tracking != null && (_tracking!.isCompleted || _tracking!.progress >= 1.0);
    final isComplete = tracking.isCompleted || tracking.progress >= 1.0;

    if (_tracking == null || wasComplete != isComplete) {
      // Data pertama kali masuk, atau status delivery-complete berubah:
      // perlu rebuild supaya tombol aksi enable/disable dengan benar.
      setState(() => _tracking = tracking);
    } else {
      // Cuma progress/posisi yang berubah, status belum sampai/sudah
      // sampai tetap sama -> update data tanpa memicu rebuild halaman.
      _tracking = tracking;
    }
  }

  /// True hanya jika kurir sudah benar-benar sampai (progress 100% atau
  /// flag isCompleted dari server). Selama data tracking belum termuat
  /// sama sekali, defaultnya FALSE (aman) — bukan diasumsikan selesai.
  bool get _isDeliveryComplete {
    final tracking = _tracking;
    if (tracking == null) return false;
    return tracking.isCompleted || tracking.progress >= 1.0;
  }

  @override
  Widget build(BuildContext context) {
    if (_order == null) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          // If possible, just pop to previous route. If not (opened
          // as a standalone page), navigate back to Home's order tab.
          final popped = await Navigator.maybePop(context);
          if (!popped) {
            Navigator.pushReplacementNamed(context, '/home');
          }
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
    final deliveryComplete = _isDeliveryComplete;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Prefer to pop to the previous route so we don't create duplicate
        // history entries. If there's nothing to pop (opened standalone),
        // send user back to Home (orders tab).
        final navigator = Navigator.of(context);
        final popped = await navigator.maybePop();
        if (!popped) {
          navigator.pushReplacementNamed('/home');
        }
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

              // FIX: sebelumnya kondisi ini di-hardcode jadi `if (false)`
              // (kemungkinan sisa dari testing manual), yang bikin section
              // "Lokasi Kurir" TIDAK PERNAH muncul apapun status
              // pesanannya. Dikembalikan ke kondisi yang benar: peta
              // hanya tampil kalau status pesanan "Dikirim" atau
              // "Estimasi Sampai".
              if (order.status.toLowerCase() == 'dikirim' ||
                  order.status.toLowerCase() == 'estimasi sampai') ...[
                _buildSectionTitle('Lokasi Kurir'),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final token = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).token;
                    if (token == null) {
                      return const SizedBox.shrink();
                    }
                    return CourierTrackingMap(
                      token: token,
                      orderId: order.id,
                      onTrackingUpdate: _handleTrackingUpdate,
                    );
                  },
                ),
                const SizedBox(height: 18),
              ],

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
              // Tombol "Bayar Sekarang" — foregroundColor: Colors.white
              // diberikan eksplisit supaya teksnya tidak ikut warna hijau
              // default dari theme (yang sebelumnya nyaris tak terlihat
              // di atas background tombol yang juga hijau).
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
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFBDBDBD),
                      disabledForegroundColor: const Color(0xFF616161),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Bayar Sekarang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

              // Tombol Konfirmasi Penerimaan (pembeli) — terkunci selama
              // kurir belum benar-benar sampai (progress < 100%).
              // FIX: sebelumnya tidak ada backgroundColor eksplisit, dan
              // tidak ada warna khusus untuk state disabled, sehingga
              // kontrasnya bisa jadi jelek tergantung theme default.
              if (order.status.toLowerCase() == 'dikirim' &&
                  Provider.of<AuthProvider>(context).user?.role != 'seller')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isPerformingAction || !deliveryComplete)
                            ? null
                            : _confirmReceipt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A7F41),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFBDBDBD),
                          disabledForegroundColor: const Color(0xFF616161),
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
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                    if (!deliveryComplete)
                      const Padding(
                        padding: EdgeInsets.only(top: 6.0, left: 4.0),
                        child: Text(
                          'Tombol aktif setelah kurir sampai di lokasi tujuan (100%).',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
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
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFBDBDBD),
                              disabledForegroundColor: const Color(0xFF616161),
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
                                    style: TextStyle(fontSize: 16, color: Colors.white),
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
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFBDBDBD),
                              disabledForegroundColor: const Color(0xFF616161),
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
                                    style: TextStyle(fontSize: 16, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),

                    // Tombol Tandai Selesai (penjual) — terkunci selama
                    // kurir belum benar-benar sampai (progress < 100%).
                    // FIX: warna disabled ditambahkan eksplisit supaya saat
                    // aktif (100%) teksnya putih jelas di atas hijau, dan
                    // saat masih terkunci warnanya tetap terbaca (abu tua
                    // di atas abu muda), bukan abu pucat di atas abu pucat.
                    if (order.status.toLowerCase() == 'dikirim')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_isPerformingAction || !deliveryComplete)
                                  ? null
                                  : () => _updateOrderStatus('Selesai'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A7F41),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFBDBDBD),
                                disabledForegroundColor: const Color(0xFF616161),
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
                                      style: TextStyle(fontSize: 16, color: Colors.white),
                                    ),
                            ),
                          ),
                          if (!deliveryComplete)
                            const Padding(
                              padding: EdgeInsets.only(top: 6.0, left: 4.0),
                              child: Text(
                                'Tombol aktif setelah kurir sampai di lokasi tujuan (100%).',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ),
                        ],
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