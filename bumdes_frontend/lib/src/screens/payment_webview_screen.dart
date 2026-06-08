import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'order_history_screen.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  final String orderNumber;

  const PaymentWebViewScreen({super.key, required this.url, required this.orderNumber});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasWebFallbackOpened = false;
  String? _fallbackError;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInvoiceInBrowser();
      });
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
          onWebResourceError: (_) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openInvoiceInBrowser() async {
    final success = await launchUrlString(widget.url, mode: LaunchMode.externalApplication);
    if (!success) {
      setState(() {
        _fallbackError = 'Tidak dapat membuka halaman pembayaran di browser. Silakan salin tautan dan buka secara manual.';
      });
      return;
    }

    setState(() {
      _hasWebFallbackOpened = true;
    });

    if (!mounted) return;
    Navigator.pushNamed(context, OrderHistoryScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bayar ${widget.orderNumber}'),
        backgroundColor: const Color(0xFF2A7F41),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: kIsWeb
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_browser, size: 72, color: Color(0xFF2A7F41)),
                    const SizedBox(height: 20),
                    const Text(
                      'Pembayaran web tidak mendukung tampilan WebView.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Halaman pembayaran akan dibuka di tab baru.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_fallbackError != null)
                      Text(
                        _fallbackError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    if (!_hasWebFallbackOpened)
                      ElevatedButton(
                        onPressed: _openInvoiceInBrowser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A7F41),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: const Text('Buka Halaman Pembayaran', style: TextStyle(fontSize: 16)),
                      ),
                    if (_hasWebFallbackOpened)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Jika tab baru tidak muncul, buka ulang halaman dan tekan tombol di bawah.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }
}
