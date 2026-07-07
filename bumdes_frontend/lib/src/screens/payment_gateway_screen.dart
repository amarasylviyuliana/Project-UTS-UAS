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
        _errorMessage = 'Silakan login terlebih dahulu untuk melanjutkan pembayaran.';
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
                content: Text('Pembayaran berhasil! Terima kasih telah berbelanja.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushNamed(context, OrderHistoryScreen.routeName);
          } else if (paymentResult?['status'] == 'pending') {
            // Sinkronisasi: set payment waiting = pending
            try {
              await OrderService().submitPayment(
                auth.token!,
                int.tryParse(widget.order.orderNumber.toString()) ?? widget.order.id,
                status: 'pending',
              );
            } catch (e) {
              debugPrint('WARN: submitPayment pending failed: $e');
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pembayaran menunggu konfirmasi. Sedang diproses...'),
              ),
            );
            Navigator.pushNamed(context, OrderHistoryScreen.routeName);
          } else {

            final message = paymentResult?['message'] as String? ?? 'Pembayaran dibatalkan.';
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
                  Text('Order ID', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text('Total Pembayaran', style: TextStyle(color: Colors.grey.shade700)),
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
                  Text('Nama Penerima', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.recipientName ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  const Text(
                    'Tekan "Bayar Sekarang" untuk membuka halaman pembayaran Midtrans. Anda dapat memilih berbagai metode pembayaran seperti transfer bank, e-wallet, dan lainnya.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _payNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A7F41),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  disabledBackgroundColor: Colors.grey.shade400,
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
