import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  final http.Client _client;
  final String? token;

  /// FIX: callback global — dipanggil otomatis kalau server balas 401
  /// (token expired/invalid) dari MANAPUN di aplikasi, supaya user
  /// langsung diarahkan ke Login dengan rapi, bukan nyangkut lihat pesan
  /// error teknis "Unauthenticated" di tengah layar.
  /// Di-set sekali di main.dart/app.dart saat aplikasi start.
  static void Function()? onUnauthorized;

  ApiService({http.Client? client, this.token})
    : _client = client ?? http.Client();

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Header untuk multipart request — TIDAK menyertakan Content-Type
  // karena http.MultipartRequest akan set sendiri (multipart/form-data;
  // boundary=...). Kalau kita paksa 'application/json' di sini, server
  // akan gagal parse file yang dikirim.
  Map<String, String> get _multipartHeaders {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client.get(
      Uri.parse(apiUrl(path)),
      headers: _headers,
    );
    return _normalizeResponse(response);
  }

  Future<dynamic> getRaw(String path) async {
    final response = await _client.get(
      Uri.parse(apiUrl(path)),
      headers: _headers,
    );
    return _normalizeRawResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse(apiUrl(path));
    final response = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode(body),
    );
    return _normalizeResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.put(
      Uri.parse(apiUrl(path)),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _normalizeResponse(response);
  }

  // ── TAMBAHAN: method delete ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _client.delete(
      Uri.parse(apiUrl(path)),
      headers: _headers,
    );
    return _normalizeResponse(response);
  }

  // ── TAMBAHAN: upload file (multipart/form-data) ─────────────────────────────
  // Dipakai untuk endpoint yang menerima file, misal foto profil atau
  // foto toko/produk. Sengaja pakai bytes (Uint8List), BUKAN dart:io File,
  // supaya kompatibel di semua platform termasuk Flutter Web — dart:io.File
  // tidak didukung di web dan akan membuat `flutter build web` gagal total.
  // [fileField] adalah nama field yang divalidasi backend (contoh: 'photo'
  // untuk /profile/photo), [fields] adalah data teks tambahan (kalau ada).
  Future<Map<String, dynamic>> postMultipartBytes(
    String path,
    String fileField,
    Uint8List bytes,
    String filename, {
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(apiUrl(path)));
    request.headers.addAll(_multipartHeaders);
    if (fields != null) request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return _normalizeResponse(response);
  }

  dynamic _normalizeRawResponse(http.Response response) {
    try {
      final body = response.body.isEmpty ? '{}' : response.body;
      final data = jsonDecode(body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      if (data is Map<String, dynamic>) {
        if (response.statusCode == 401) onUnauthorized?.call();
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Unknown server error',
          errors: data['errors'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['errors'])
              : null,
        );
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Unknown server error',
      );
    } on FormatException {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Respons server tidak valid. Coba lagi sebentar.',
      );
    }
  }

  Future<Map<String, dynamic>> _normalizeResponse(
    http.Response response,
  ) async {
    try {
      final body = response.body.isEmpty ? '{}' : response.body;
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Respons server tidak valid.',
        );
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      if (response.statusCode == 401) onUnauthorized?.call();
      throw ApiException(
        statusCode: response.statusCode,
        message: data['message'] ?? 'Unknown server error',
        errors: data['errors'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['errors'])
            : null,
      );
    } on FormatException {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Respons server tidak valid. Coba lagi sebentar.',
      );
    }
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