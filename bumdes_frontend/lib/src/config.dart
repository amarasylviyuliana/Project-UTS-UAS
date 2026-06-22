// Backend URL configuration
// Automatically detect if running in Docker or local development

import 'package:flutter/foundation.dart';

String get backendUrl {
  // Use API_URL from build-time define if provided (Docker build args)
  const String apiUrlDefine = String.fromEnvironment('API_URL');
  
  if (apiUrlDefine.isNotEmpty) {
    return apiUrlDefine;
  }

  // Fallback to environment variable
  const String envApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );
  
  if (envApiUrl.isNotEmpty) {
    return envApiUrl;
  }

  // Default fallback based on platform
  if (kIsWeb) {
    // Web: try to use localhost first (works if frontend and backend on same machine)
    // For production: update docker-compose.yml to pass correct API_URL
    return 'hhttps://project-uts-uas-production.up.railway.app';
  }

  // Mobile/Desktop fallback
  return 'https://project-uts-uas-production.up.railway.app';
}

const String apiPrefix = '/api';

String apiUrl(String path) => '$backendUrl$apiPrefix$path';
