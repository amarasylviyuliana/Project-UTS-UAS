import 'package:flutter/foundation.dart';

String get backendUrl {
  const String apiUrlDefine = String.fromEnvironment('API_URL');
  if (apiUrlDefine.isNotEmpty) return apiUrlDefine;

  // Debug mode (e.g. `flutter run -d chrome` or on a device/emulator) always
  // points to the local backend first, regardless of platform. This is what
  // makes "flutter run" work out of the box against `php artisan serve` or
  // the docker-compose backend without extra flags.
  if (kDebugMode) {
    return 'http://127.0.0.1:8000';
  }

  // Release/production builds (e.g. `flutter build web`, or the Docker
  // frontend image) use the production backend unless overridden above by
  // --dart-define=API_URL=...
  return 'https://bumdes-api-production.up.railway.app';
}

const String apiPrefix = '/api';
String apiUrl(String path) => '$backendUrl$apiPrefix$path';

String resolveImageUrlWithProxy(String url) {
  if (url.isEmpty) return url;

  if (url.contains('/api/image/')) return url;

  final storagePattern = RegExp(
    r'https?://[^/]+/storage/(.+)',
    caseSensitive: false,
  );
  final match = storagePattern.firstMatch(url);
  if (match != null) {
    final path = match.group(1)!;
    return '$backendUrl/api/image/$path';
  }

  return url;
}