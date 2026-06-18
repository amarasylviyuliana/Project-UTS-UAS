// Backend URL configuration
// The frontend will always point to the local backend address used in your setup.
// Change this only if your backend runs on a different host or port.

const String backendUrl = 'http://localhost:8000';
const String apiPrefix = '/api';

String apiUrl(String path) => '$backendUrl$apiPrefix$path';
