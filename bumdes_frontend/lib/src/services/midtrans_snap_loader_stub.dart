// Stub implementation used on non-web platforms (Android, iOS, VM, tests).
// This file must NOT import dart:html, since dart:html is only available
// when compiling for the web.

class MidtransSnapLoader {
  static Future<bool> ensureSnapScriptLoaded({
    required String scriptUrl,
    required String clientKey,
  }) async {
    // No-op on non-web platforms; the Midtrans native SDK is used instead.
    return false;
  }

  static void teardownWeb() {
    // No-op on non-web platforms.
  }
}