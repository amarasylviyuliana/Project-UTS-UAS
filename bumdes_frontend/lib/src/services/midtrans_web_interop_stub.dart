import 'dart:async';
import 'package:flutter/foundation.dart';

class MidtransWebInterop {
  /// Stub implementation for non-web platforms (tests, VM).
  /// Returns an immediate failure indicating web payment is unavailable.
  static Future<Map<String, dynamic>> startPayment(String snapToken) async {
    debugPrint('Midtrans web interop called on non-web platform.');
    return {
      'success': false,
      'status': 'unsupported_platform',
      'message': 'Midtrans web payment is only available on web builds.',
    };
  }
}
