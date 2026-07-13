import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'api_service.dart';
import 'profile_service.dart';
import '../models/product_model.dart';
import '../config.dart';

class ProductService {
  final ApiService api = ApiService();

  /// Ambil persentase biaya admin/pajak platform (endpoint publik).
  /// Dipakai di form tambah produk agar Penjual tahu dari awal.
  Future<double> getPlatformFeePercentage() async {
    try {
      final response = await api.get('/platform/fee-info');
      final data = response['data'] ?? {};
      return (data['tax_percentage'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<ProductModel>> fetchProducts() async {
    final response = await api.getRaw('/products');
    final rawProducts = _extractProductList(response);
    return rawProducts
        .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductModel>> fetchProductsByStore(String token) async {
    final profileService = ProfileService();
    final storeResponse = await profileService.getStore(token);
    // FIX: getStore sekarang return {message, data} — ambil dari 'data'
    final store = storeResponse['data'] ?? storeResponse;
    final storeId = store['id'];

    if (storeId == null) return [];

    final apiWithToken = ApiService(token: token);
    final response = await apiWithToken.getRaw('/stores/$storeId/products');
    final rawProducts = _extractProductList(response);
    return rawProducts
        .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ALUR BARU: Toko dibuat langsung oleh Admin dan otomatis aktif, jadi
  // tidak ada lagi status "menunggu persetujuan" / "ditolak".
  // null  = toko belum dibuat Admin untuk akun ini
  // true  = toko ada dan aktif
  // false = toko ada tapi dinonaktifkan Admin
  Future<bool?> isStoreApproved(String token) async {
    try {
      final profileService = ProfileService();
      final storeResponse = await profileService.getStore(token);

      final store = storeResponse['data'] ?? storeResponse;

      // Toko belum dibuat oleh Admin
      if (store == null || store['id'] == null) return null;

      return store['is_active'] == true;
    } catch (e) {
      // 404 = toko belum dibuat oleh Admin untuk akun ini
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return null;
      }
      return null;
    }
  }

  Future<void> _attachPhoto(
    http.MultipartRequest request,
    XFile? imageFile,
    Uint8List? imageBytes,
  ) async {
    if (imageFile == null) return;

    final bytes = imageBytes ?? await imageFile.readAsBytes();
    final fileName =
        imageFile.name.isNotEmpty ? imageFile.name : 'photo.jpg';
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );
  }

  // TAMBAHAN: ambil pesan error yang SEBENARNYA dari response validasi
  // Laravel. Sebelumnya createProduct/updateProduct cuma baca data['message'],
  // yang isinya generik ("The given data was invalid."). Alasan asli
  // kegagalan (misal "The photo must not be greater than 5120 kilobytes.")
  // ada di data['errors'], jadi tidak pernah terlihat oleh pengguna — ini
  // salah satu penyebab keluhan "gagal upload foto produk" tanpa penjelasan.
  String _extractErrorMessage(Map<String, dynamic> data, String fallback) {
    final errors = data['errors'];
    if (errors is Map<String, dynamic> && errors.isNotEmpty) {
      final firstKey = errors.keys.first;
      final firstValue = errors[firstKey];
      if (firstValue is List && firstValue.isNotEmpty) {
        return firstValue.first.toString();
      }
      if (firstValue is String && firstValue.isNotEmpty) {
        return firstValue;
      }
    }
    return (data['message'] as String?) ?? fallback;
  }

  Future<ProductModel> createProduct(
    String token,
    String name,
    int categoryId,
    String type,
    double price,
    int stock,
    String description,
    XFile? imageFile, {
    Uint8List? imageBytes,
    // TAMBAHAN: status aktif. Dipakai sebagai toggle "Tersedia/Tidak
    // Tersedia" untuk Jasa (form yang mengontrol nilai ini), dan tetap
    // true default untuk Produk.
    bool isActive = true,
  }) async {
    final uri = Uri.parse(apiUrl('/products'));
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['name'] = name;
    request.fields['category_id'] = categoryId.toString();
    request.fields['type'] = type;
    request.fields['price'] = price.toString();
    request.fields['stock'] = stock.toString();
    request.fields['description'] = description;
    // TAMBAHAN: kirim is_active ke backend. Laravel 'boolean' rule
    // menerima string "1"/"0".
    request.fields['is_active'] = isActive ? '1' : '0';

    await _attachPhoto(request, imageFile, imageBytes);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      final data = jsonDecode(resp.body);
      final productData = data['data'] ?? data;
      return ProductModel.fromJson(productData as Map<String, dynamic>);
    } else {
      final data = jsonDecode(resp.body);
      throw Exception(_extractErrorMessage(data, 'Gagal membuat produk'));
    }
  }

  Future<ProductModel> updateProduct(
    String token,
    int productId,
    String name,
    int categoryId,
    String type,
    double price,
    int stock,
    String description,
    XFile? imageFile, {
    Uint8List? imageBytes,
    // TAMBAHAN: sama seperti createProduct — dipakai untuk toggle
    // Tersedia/Tidak Tersedia pada Jasa.
    bool isActive = true,
  }) async {
    final uri = Uri.parse(apiUrl('/products/$productId'));
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['_method'] = 'PUT';
    request.fields['name'] = name;
    request.fields['category_id'] = categoryId.toString();
    request.fields['type'] = type;
    request.fields['price'] = price.toString();
    request.fields['stock'] = stock.toString();
    request.fields['description'] = description;
    request.fields['is_active'] = isActive ? '1' : '0';

    await _attachPhoto(request, imageFile, imageBytes);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      final data = jsonDecode(resp.body);
      final productData = data['data'] ?? data;
      return ProductModel.fromJson(productData as Map<String, dynamic>);
    } else {
      final data = jsonDecode(resp.body);
      throw Exception(_extractErrorMessage(data, 'Gagal memperbarui produk'));
    }
  }

  Future<void> deleteProduct(String token, int productId) async {
    final apiWithToken = ApiService(token: token);
    await apiWithToken.delete('/products/$productId');
  }

  List<dynamic> _extractProductList(dynamic response) {
    if (response is List) return response;
    if (response is Map<String, dynamic>) {
      if (response['data'] is List) return response['data'] as List<dynamic>;
      if (response['data'] is Map<String, dynamic> &&
          response['data']['data'] is List) {
        return response['data']['data'] as List<dynamic>;
      }
      if (response['products'] is List) return response['products'] as List<dynamic>;
      if (response['items'] is List) return response['items'] as List<dynamic>;
    }
    return [];
  }
}