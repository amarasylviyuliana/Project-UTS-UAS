import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';
import 'midtrans_web_interop.dart';
import 'midtrans_snap_loader.dart';

class MidtransService {
  static const String _clientKey = 'Mid-client-5LTBgOeDFtKhl8OZ';
  static const bool _production = false;
  static const String _snapScriptUrl =
      'https://app.sandbox.midtrans.com/snap/snap.js';

  static void teardownWeb() {
    if (!kIsWeb) return;
    MidtransSnapLoader.teardownWeb();
  }

  static Future<bool> initialize() async {
    try {
      if (kIsWeb) {
        final loaded = await MidtransSnapLoader.ensureSnapScriptLoaded(
          scriptUrl: _snapScriptUrl,
          clientKey: _clientKey,
        );
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
      debugPrint(
        'Starting Midtrans payment with token: ${snapToken.substring(0, 20)}...',
      );

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