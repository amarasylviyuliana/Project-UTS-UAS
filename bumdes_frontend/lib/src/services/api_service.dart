import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  final http.Client _client;
  final String? token;

  ApiService({http.Client? client, this.token}) : _client = client ?? http.Client();

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client.get(Uri.parse(apiUrl(path)), headers: _headers);
    return _normalizeResponse(response);
  }

  Future<dynamic> getRaw(String path) async {
    final response = await _client.get(Uri.parse(apiUrl(path)), headers: _headers);
    return _normalizeRawResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse(apiUrl(path));
    final response = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode(body),
    );
    return _normalizeResponse(response);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await _client.put(
      Uri.parse(apiUrl(path)),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _normalizeResponse(response);
  }

  dynamic _normalizeRawResponse(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final data = jsonDecode(body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      throw ApiException(
        statusCode: response.statusCode,
        message: data['message'] ?? 'Unknown server error',
        errors: data['errors'] as Map<String, dynamic>?,
      );
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unknown server error',
    );
  }

  Future<Map<String, dynamic>> _normalizeResponse(http.Response response) async {
    final body = response.body.isEmpty ? '{}' : response.body;
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: data['message'] ?? 'Unknown server error',
      errors: data['errors'] as Map<String, dynamic>?,
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException({required this.statusCode, required this.message, this.errors});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
