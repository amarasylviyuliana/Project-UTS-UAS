import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import 'order_history_screen.dart';
import 'payment_webview_screen.dart';

class PaymentGatewayScreen extends StatefulWidget {
  static const routeName = '/payment-gateway';
  final OrderModel order;

  const PaymentGatewayScreen({super.key, required this.order});

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  String _selectedMethod = 'btn_va';
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _payNow() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) {
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
      final service = OrderService();
      final response = await service.createInvoice(
        auth.token!,
        widget.order.orderNumber,
        widget.order.total,
        widget.order.recipientName ?? 'Pembeli',
        _selectedMethod,
      );

      if (response['success'] == true) {
        final invoiceUrl = response['invoice_url'] as String?;
        if (invoiceUrl != null && invoiceUrl.isNotEmpty) {
          if (!mounted) return;

          if (kIsWeb) {
            final opened = await launchUrlString(
              invoiceUrl,
              mode: LaunchMode.externalApplication,
            );

            if (opened) {
              if (!mounted) return;
              Navigator.pushNamed(context, OrderHistoryScreen.routeName);
              return;
            }
          }

          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentWebViewScreen(
                url: invoiceUrl,
                orderNumber: widget.order.orderNumber,
              ),
            ),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Silakan selesaikan pembayaran di halaman Xendit.')),
          );
          return;
        }
      }

      setState(() {
        _errorMessage = response['message'] as String? ?? 'Gagal membuat invoice pembayaran.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal membuat invoice: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildPaymentOption(String key, String title, String subtitle, IconData icon) {
    final selected = _selectedMethod == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? const Color(0xFFE6F4E8) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF2A7F41) : Colors.grey.shade300,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            if (!selected)
              const BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: selected ? const Color(0xFF2A7F41) : Colors.grey.shade200,
              child: Icon(icon, color: selected ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF2A7F41)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Gateway Xendit'),
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
                  const Text('Pembayaran Pesanan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Order ID', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text(widget.order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  Text('Total Pembayaran', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${widget.order.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF2A7F41)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text('Pilih Metode Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('🏦 Transfer Bank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildPaymentOption('btn_va', 'BTN Virtual Account', 'Bayar dengan Virtual Account BTN', Icons.account_balance),
            const SizedBox(height: 20),
            const Text('📱 E-Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildPaymentOption('dana', 'DANA', 'Bayar dengan DANA', Icons.wallet),
            const SizedBox(height: 12),
            _buildPaymentOption('gopay', 'GoPay', 'Bayar dengan GoPay', Icons.payments),
            const SizedBox(height: 12),
            _buildPaymentOption('shopeepay', 'ShopeePay', 'Bayar dengan ShopeePay', Icons.shopping_bag),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _payNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A7F41),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Bayar Sekarang', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pilih metode pembayaran di atas lalu tekan Bayar Sekarang untuk memproses invoice Xendit.',
              style: TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
