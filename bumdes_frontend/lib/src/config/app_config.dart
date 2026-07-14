import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Production Configuration
/// Mengatur behavior aplikasi berdasarkan environment
class AppConfig {
  static const String appName = 'BUMDES_JABAR';
  static const String version = '1.0.0';

  // Environment
  static bool get isProduction => !kDebugMode;
  static bool get isDevelopment => kDebugMode;
  static bool get isWeb => !kIsWeb ? false : true;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  // API Configuration
  static String get apiBaseUrl {
    // Production backend
    if (isProduction) {
      return 'https://bumdes-api-production.up.railway.app/api';
    }
    // Development: gunakan localhost atau development server
    return 'http://localhost:8000/api';
  }

  // TAMBAHAN: base URL untuk file media (foto), yaitu apiBaseUrl tanpa
  // akhiran "/api" — karena file yang di-upload (storage/...) biasanya
  // disajikan langsung dari root domain, bukan dari path /api.
  static String get _mediaBaseUrl {
    final base = apiBaseUrl;
    return base.endsWith('/api')
        ? base.substring(0, base.length - '/api'.length)
        : base;
  }

  // TAMBAHAN: gabungkan path foto dari backend (yang kadang berupa path
  // relatif, mis. "storage/photos/x.jpg") menjadi URL lengkap yang bisa
  // dimuat Image.network(). Kalau path yang dikirim backend TERNYATA
  // sudah berupa URL lengkap (diawali http:// atau https://), fungsi ini
  // tidak mengubah apa-apa dan langsung mengembalikannya apa adanya.
  static String resolveMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$_mediaBaseUrl$normalizedPath';
  }

  // Debug Configuration
  static bool get enableDebugLogging => kDebugMode;
  static bool get enableVerboseLogging =>
      false; // Disable verbose logging in production
  static bool get showSampleDataBadge => isDevelopment;

  // Feature Flags
  static bool get enableRealTimeSync => true;
  static bool get enableOrderPolling => true;
  static const Duration orderSyncInterval = Duration(seconds: 30);
  static const Duration orderSyncMaxJitter = Duration(seconds: 5);

  // UI Configuration
  static bool get useCompactUI => isMobile;
  static bool get showPlaceholderImages => isDevelopment;
  static bool get enableProductPlaceholders => true;
  static bool get showDebugInfo => isDevelopment;

  // Timing
  static const Duration snackbarDuration = Duration(seconds: 3);
  static const Duration dialogDuration = Duration(milliseconds: 300);
  static const Duration animationDuration = Duration(milliseconds: 200);

  /// Check if feature is enabled
  static bool isFeatureEnabled(String featureName) {
    switch (featureName) {
      case 'real-time-sync':
        return enableRealTimeSync;
      case 'order-polling':
        return enableOrderPolling;
      case 'sample-data-badge':
        return showSampleDataBadge;
      default:
        return true;
    }
  }

  /// Get log level
  static String getLogLevel() {
    if (isDevelopment) return 'DEBUG';
    return 'INFO';
  }
}