import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class MidtransWebInterop {
  static Future<Map<String, dynamic>> startPayment(String snapToken) async {
    final completer = Completer<Map<String, dynamic>>();
    bool completed = false;

    // Define JavaScript callbacks
    final onSuccess = (dynamic result) {
      if (!completed) {
        completed = true;
        debugPrint('Midtrans payment success: $result');
        completer.complete({
          'success': true,
          'status': 'settlement',
          'message': 'Pembayaran berhasil!',
          'result': result,
        });
      }
    };

    final onPending = (dynamic result) {
      if (!completed) {
        completed = true;
        debugPrint('Midtrans payment pending: $result');
        completer.complete({
          'success': false,
          'status': 'pending',
          'message': 'Pembayaran menunggu konfirmasi',
          'result': result,
        });
      }
    };

    final onError = (dynamic result) {
      if (!completed) {
        completed = true;
        debugPrint('Midtrans payment error: $result');
        completer.complete({
          'success': false,
          'status': 'error',
          'message': 'Pembayaran gagal',
          'result': result,
        });
      }
    };

    final onClose = () {
      if (!completed) {
        completed = true;
        debugPrint('Midtrans payment dialog closed');
        completer.complete({
          'success': false,
          'status': 'cancelled',
          'message': 'Pembayaran dibatalkan',
        });
      }
    };

    try {
      debugPrint('Starting Midtrans web payment with token: ${snapToken.substring(0, 20)}...');

      // Set up the callback handler BEFORE calling snap.pay()
      js.context['midtransPaymentCallback'] = (String type, dynamic result) {
        if (type == 'success') {
          onSuccess(result);
        } else if (type == 'pending') {
          onPending(result);
        } else if (type == 'error') {
          onError(result);
        } else if (type == 'close') {
          onClose();
        }
      };

      // Call window.snap.pay() with callbacks
      js.context.callMethod('eval', ['''
        (function(token) {
          window.snap.pay('$snapToken', {
            onSuccess: function(result) {
              window.midtransPaymentCallback('success', result);
            },
            onPending: function(result) {
              window.midtransPaymentCallback('pending', result);
            },
            onError: function(result) {
              window.midtransPaymentCallback('error', result);
            },
            onClose: function() {
              window.midtransPaymentCallback('close', null);
            }
          });
        })('$snapToken');
      ''']);

      return await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          if (!completed) {
            completed = true;
            return {
              'success': false,
              'status': 'timeout',
              'message': 'Waktu respons payment habis',
            };
          }
          return {};
        },
      );
    } catch (e) {
      debugPrint('Error during Midtrans web payment: $e');
      return {
        'success': false,
        'status': 'error',
        'message': 'Gagal memproses pembayaran: $e',
      };
    }
  }
}
