import 'package:flutter/foundation.dart';

String get backendUrl {
  const String apiUrlDefine = String.fromEnvironment('API_URL');
  if (apiUrlDefine.isNotEmpty) return apiUrlDefine;

  if (kIsWeb) {
    return 'https://bumdes-api-production.up.railway.app';
  }

  if (kDebugMode) {
    return 'http://127.0.0.1:8000';
  }

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