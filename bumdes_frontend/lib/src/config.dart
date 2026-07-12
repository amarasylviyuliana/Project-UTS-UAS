import 'package:flutter/foundation.dart';

String get backendUrl {
  // FIX: Gunakan --dart-define saat build untuk inject URL
  const String apiUrlDefine = String.fromEnvironment('API_URL');
  if (apiUrlDefine.isNotEmpty) return apiUrlDefine;

  // Untuk Flutter Web, gunakan backend produksi jika API_URL tidak di-set.
  // Ini mencegah browser mencoba fetch ke localhost saat server lokal tidak aktif.
  if (kIsWeb) {
    return 'https://bumdes-api-production.up.railway.app';
  }

  // Ketika debug di device/mobile, gunakan backend lokal jika tersedia.
  if (kDebugMode) {
    return 'http://127.0.0.1:8000';
  }

  return 'https://bumdes-api-production.up.railway.app';
}

const String apiPrefix = '/api';
String apiUrl(String path) => '$backendUrl$apiPrefix$path';

/// FIX CORS: Konvert URL gambar /storage/... ke /api/image/... (proxy Laravel)
/// Browser Flutter Web tidak bisa load langsung dari /storage karena CORS tidak
/// terset di nginx Railway. Route /api/image/ di-handle PHP → CORS header otomatis.
String resolveImageUrlWithProxy(String url) {
  if (url.isEmpty) return url;

  // Kalau sudah pakai proxy, kembalikan apa adanya
  if (url.contains('/api/image/')) return url;

  // Kalau URL dari /storage/ Railway → konvert ke proxy
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