import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';
import 'midtrans_web_interop.dart';

class MidtransService {
  static const String _clientKey = 'Mid-client-5LTBgOeDFtKhl8OZ';
  static const bool _production = false;
  static const String _snapScriptUrl =
      'https://app.sandbox.midtrans.com/snap/snap.js';

  // FIX (penyebab web freeze / tidak bisa diklik): sebelumnya snap.js
  // di-load lewat <script> tag di web/index.html, yang artinya script itu
  // aktif di SETIAP halaman aplikasi, bukan cuma di halaman pembayaran.
  // snap.js mencoba menjalankan sub-script internal (tracking/fraud
  // detection) yang diblokir oleh Content-Security-Policy browser, dan
  // karena ini berjalan terus-menerus di background di semua halaman, ini
  // yang membuat seluruh web jadi freeze/tidak responsif terhadap klik.
  //
  // Sekarang snap.js di-load secara dinamis lewat kode ini, HANYA saat
  // MidtransService.initialize() benar-benar dipanggil (yaitu cuma saat
  // pengguna membuka halaman pembayaran). Kalau elemen <script> untuk
  // snap.js sudah pernah ditambahkan sebelumnya (mis. pengguna keluar-masuk
  // halaman pembayaran berkali-kali), tidak akan ditambahkan dua kali.
  static Future<bool> _ensureSnapScriptLoaded() {
    final existing = html.document.getElementById('midtrans-snap-script');
    if (existing != null) {
      // Elemen script sudah pernah disisipkan sebelumnya di sesi ini.
      return Future.value(true);
    }

    final completer = Completer<bool>();
    final script = html.ScriptElement()
      ..id = 'midtrans-snap-script'
      ..src = _snapScriptUrl
      ..setAttribute('data-client-key', _clientKey);

    script.onLoad.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
    });
    script.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(false);
    });

    html.document.head!.append(script);

    // Jaga-jaga kalau event load/error tidak pernah terpicu (jaringan
    // lambat dsb.) supaya initialize() tidak menggantung selamanya.
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
  }

  /// Lepas script Midtrans dari halaman. Panggil ini saat meninggalkan
  /// halaman pembayaran (mis. di dispose()), supaya snap.js tidak terus
  /// aktif di background selama pengguna menjelajah halaman lain.
  static void teardownWeb() {
    if (!kIsWeb) return;
    try {
      final existing = html.document.getElementById('midtrans-snap-script');
      existing?.remove();
    } catch (_) {}
  }

  static Future<bool> initialize() async {
    try {
      if (kIsWeb) {
        final loaded = await _ensureSnapScriptLoaded();
        debugPrint(
          loaded
              ? 'Midtrans web initialized (Snap SDK loaded on demand)'
              : 'Gagal memuat Snap SDK (cek koneksi/CSP)',
        );
        return loaded;
      }

      // Mobile platforms
      await MidtransSDK.init(
        config: MidtransConfig(
          clientKey: _clientKey,
          merchantBaseUrl: _production
              ? 'https://app.midtrans.com'
              : 'https://app.sandbox.midtrans.com',
          enableLog: true,
        ),
      );

      debugPrint('Midtrans initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing Midtrans: $e');
      return false;
    }
  }

  /// Start payment with platform-specific handling
  static Future<Map<String, dynamic>?> startPayment(
    String snapToken, {
    required String orderId,
    required double amount,
    required String customerName,
  }) async {
    try {
      debugPrint('Starting Midtrans payment with token: ${snapToken.substring(0, 20)}...');

      if (kIsWeb) {
        // Use web interop for web platform
        return await MidtransWebInterop.startPayment(snapToken);
      }

      // Mobile platforms - use native SDK
      final completer = Completer<Map<String, dynamic>>();

      void listener(TransactionResult result) {
        final status = result.status;

        completer.complete({
          'success': status == 'settlement',
          'status': status,
          'message': status == 'settlement'
              ? 'Pembayaran berhasil!'
              : status == 'pending'
                  ? 'Pembayaran menunggu konfirmasi'
                  : (result.message ?? 'Pembayaran dibatalkan'),
          'order_id': orderId,
          'result': {
            'status': result.status,
            'transactionId': result.transactionId,
            'paymentType': result.paymentType,
            'message': result.message,
          },
        });
      }

      MidtransSDK().setTransactionFinishedCallback(listener);

      await MidtransSDK().startPaymentUiFlow(token: snapToken);

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => {
          'success': false,
          'status': 'timeout',
          'message': 'Waktu respons payment habis',
          'order_id': orderId,
        },
      );
    } catch (e) {
      debugPrint('Error during Midtrans payment: $e');
      return {
        'success': false,
        'status': 'error',
        'message': 'Gagal memproses pembayaran: $e',
        'order_id': orderId,
      };
    } finally {
      try {
        if (!kIsWeb) {
          MidtransSDK().removeTransactionFinishedCallback();
        }
      } catch (_) {}
    }
  }
}