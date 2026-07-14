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
