import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import '../services/midtrans_service.dart';
import 'order_history_screen.dart';

class PaymentGatewayScreen extends StatefulWidget {
  static const routeName = '/payment-gateway';
  final OrderModel order;

  const PaymentGatewayScreen({super.key, required this.order});

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMidtrans();
  }

  // FIX: lepas script Midtrans (snap.js) saat pengguna meninggalkan
  // halaman ini, supaya tidak terus aktif di background selama pengguna
  // menjelajah halaman lain di app (itu yang sebelumnya menyebabkan web
  // freeze/tidak bisa diklik).
  @override
  void dispose() {
    MidtransService.teardownWeb();
    super.dispose();
  }

  Future<void> _initializeMidtrans() async {
    final initialized = await MidtransService.initialize();
    if (!initialized && mounted) {
      setState(() {
        _errorMessage = 'Gagal menginisialisasi Midtrans. Silakan coba lagi.';
      });
    }
  }

  Future<void> _payNow() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) {
      debugPrint('❌ ERROR: User tidak terautentikasi');
      setState(() {
        _errorMessage =
            'Silakan login terlebih dahulu untuk melanjutkan pembayaran.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔄 Starting Midtrans payment process...');
      debugPrint('📦 Order: ${widget.order.orderNumber}');
      debugPrint('💰 Amount: ${widget.order.total}');
      debugPrint('👤 Token: ${auth.token!.substring(0, 20)}...');

      final service = OrderService();
      final response = await service.createMidtransPayment(
        auth.token!,
        widget.order.orderNumber,
      );

      debugPrint('📨 Response from backend: $response');

      if (!mounted) return;

      if (response['success'] == true) {
        final snapToken = response['snap_token'] as String?;

        if (snapToken != null && snapToken.isNotEmpty) {
          debugPrint('✅ Snap token received: ${snapToken.substring(0, 30)}...');

          final paymentResult = await MidtransService.startPayment(
            snapToken,
            orderId: widget.order.orderNumber,
            amount: widget.order.total,
            customerName: widget.order.recipientName ?? 'Pembeli',
          );

          debugPrint('💳 Payment result: $paymentResult');

          // FIX: sebelumnya pembersihan script/overlay Midtrans (snap.js)
          // hanya dilakukan di dispose(), tapi setelah pembayaran
          // sukses/pending kita pindah halaman pakai Navigator.pushNamed
          // (BUKAN pop/replace) — artinya PaymentGatewayScreen tidak
          // pernah di-dispose, dan snap.js beserta overlay-nya tertinggal
          // aktif SELAMANYA di background, mengunci klik & scroll di
          // SELURUH halaman lain (termasuk Detail Pesanan). Sekarang kita
          // langsung bersihkan begitu hasil pembayaran didapat, tidak
          // menunggu dispose().
          MidtransService.teardownWeb();

          if (!mounted) return;

          if (paymentResult?['success'] == true ||
              paymentResult?['status'] == 'settlement') {
            // Sinkronisasi ke backend: set status pembayaran = success
            try {
              await OrderService().submitPayment(
                auth.token!,
                widget.order.id,
                status: 'success',
              );
            } catch (e) {
              debugPrint('WARN: submitPayment success failed: $e');
            }

            // Redirect ke riwayat dan biarkan status tampil sesuai backend
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Pembayaran berhasil! Terima kasih telah berbelanja.',
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushNamed(context, OrderHistoryScreen.routeName);
          } else if (paymentResult?['status'] == 'pending') {
            // Sinkronisasi: set payment waiting = pending
            try {
              await OrderService().submitPayment(
                auth.token!,
                int.tryParse(widget.order.orderNumber.toString()) ??
                    widget.order.id,
                status: 'pending',
              );
            } catch (e) {
              debugPrint('WARN: submitPayment pending failed: $e');
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Pembayaran menunggu konfirmasi. Sedang diproses...',
                ),
              ),
            );
            Navigator.pushNamed(context, OrderHistoryScreen.routeName);
          } else {
            final message =
                paymentResult?['message'] as String? ??
                'Pembayaran dibatalkan.';
            debugPrint('❌ Payment failed: $message');
            setState(() {
              _errorMessage = message;
            });
          }
          return;
        } else {
          debugPrint('❌ ERROR: snap_token is empty or null');
          setState(() {
            _errorMessage = 'Token pembayaran tidak valid. Silakan coba lagi.';
          });
        }
      } else {
        final message = response['message'] as String?;
        final error = response['error'] as String?;
        debugPrint('❌ Backend error: $message');
        debugPrint('❌ Error detail: $error');

        setState(() {
          _errorMessage = '$message\n\nDetail: $error';
        });
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      setState(() {
        _errorMessage = 'Gagal membuat transaksi: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await OrderService().cancelOrder(auth.token!, widget.order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil dibatalkan'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushNamed(context, OrderHistoryScreen.routeName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal membatalkan pesanan: $e';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, OrderHistoryScreen.routeName);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran Midtrans'),
          backgroundColor: const Color(0xFF2A7F41),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFF5FBF6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pembayaran Pesanan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Order ID',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.orderNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total Pembayaran',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${widget.order.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF2A7F41),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nama Penerima',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.recipientName ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A7F41), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFF2A7F41)),
                      SizedBox(width: 8),
                      Text(
                        'Midtrans Payment Gateway',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2A7F41),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // FIX: teks sebelumnya berwarna putih di atas background
                  // terang (Color(0xFFF0F8F6)) sehingga nyaris tak terbaca.
                  // Diganti jadi warna gelap agar kontrasnya jelas.
                  const Text(
                    'Tekan "Bayar Sekarang" untuk membuka halaman pembayaran Midtrans. Anda dapat memilih berbagai metode pembayaran seperti transfer bank, e-wallet, dan lainnya.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF2D5016)),
                  ),
                 ],
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final orderStatusLower = widget.order.status.toLowerCase();
                final paymentRejected =
                    widget.order.paymentStatus != null &&
                    widget.order.paymentStatus!.toLowerCase().contains(
                      'ditolak',
                    );
                final unpaidOrder =
                    orderStatusLower.contains('pembayaran') ||
                    orderStatusLower.contains('pending');
                final showCancelWidget =
                    _errorMessage != null || paymentRejected || unpaidOrder;

                return showCancelWidget
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _errorMessage ??
                                    (paymentRejected
                                        ? 'Pembayaran ditolak. Tekan Batalkan untuk membatalkan pesanan.'
                                        : unpaidOrder
                                        ? 'Pesanan belum dibayar. Tekan Batalkan jika Anda tidak jadi membeli.'
                                        : 'Pembayaran dibatalkan.'),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : _cancelOrder,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Batalkan Pesanan',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox();
              },
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _payNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A7F41),
                  // FIX: foregroundColor tidak pernah di-set sebelumnya,
                  // sehingga warna teks tombol ikut default theme (nyaris
                  // sewarna dengan background hijau tombol → tidak kebaca).
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFBDBDBD),
                  disabledForegroundColor: const Color(0xFF616161),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
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
                        'Bayar Sekarang',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }
}