// Backend URL configuration
// Automatically detect if running in Docker or local development
String get backendUrl {
  // Production: use IP server (http://192.168.1.17:8000)
  // For local development: use localhost (http://localhost:8000)
  if (kIsWeb) {
    // Web: use IP server for remote access
    return 'http://192.168.1.17:8000';
  }
  
  // Mobile/Desktop: use IP server
  // In Docker container, change this to: 'http://backend:8000'
  // In local development, use: 'http://localhost:8000'
  // For remote server, use: 'http://192.168.1.17:8000'
  return const String.fromEnvironment('API_URL', defaultValue: 'http://192.168.1.17:8000');
}

const String apiPrefix = '/api';

String apiUrl(String path) => '$backendUrl$apiPrefix$path';

