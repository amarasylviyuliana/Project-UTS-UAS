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

  // FIX KRITIS: getStore sekarang return {message, data: {store_approval...}}
  // Sebelumnya baca store langsung dari root response → approval tidak ketemu
  // null = belum daftar toko, false = menunggu/ditolak, true = disetujui
  Future<bool?> isStoreApproved(String token) async {
    try {
      final profileService = ProfileService();
      final storeResponse = await profileService.getStore(token);

      final store = storeResponse['data'] ?? storeResponse;

      // Toko tidak ditemukan
      if (store == null || store['id'] == null) return null;

      // Cek store_approval.status
      final approval = store['store_approval'];
      if (approval != null) {
        final status = (approval['status'] ?? '').toString();
        if (status == 'Disetujui') return true;
        return false; // Menunggu atau Ditolak
      }

      // Fallback: kalau tidak ada approval data, cek is_active
      return store['is_active'] == true ? true : null;
    } catch (e) {
      // 404 = toko belum terdaftar
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

    await _attachPhoto(request, imageFile, imageBytes);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      final data = jsonDecode(resp.body);
      final productData = data['data'] ?? data;
      return ProductModel.fromJson(productData as Map<String, dynamic>);
    } else {
      final data = jsonDecode(resp.body);
      throw Exception(data['message'] ?? 'Gagal membuat produk');
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

    await _attachPhoto(request, imageFile, imageBytes);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      final data = jsonDecode(resp.body);
      final productData = data['data'] ?? data;
      return ProductModel.fromJson(productData as Map<String, dynamic>);
    } else {
      final data = jsonDecode(resp.body);
      throw Exception(data['message'] ?? 'Gagal memperbarui produk');
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