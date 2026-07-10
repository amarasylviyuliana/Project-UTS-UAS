// ignore_for_file: avoid_web_libraries_in_flutter
import '../config.dart';

class ProductModel {
  final int id;
  final String name;
  final String storeName;
  final String location;
  final String category;
  final double price;
  final int stock;
  final String description;
  final String imageUrl;
  final bool isService;
  final bool isSample;
  // TAMBAHAN: identitas toko, dipakai untuk kartu toko ala Shopee di
  // halaman detail produk (foto toko + nama + lokasi).
  final int? storeId;
  final String? storePhotoUrl;

  ProductModel({
    required this.id,
    required this.name,
    required this.storeName,
    required this.location,
    required this.category,
    required this.price,
    required this.stock,
    required this.description,
    required this.imageUrl,
    this.isService = false,
    this.isSample = false,
    this.storeId,
    this.storePhotoUrl,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Resolve URL gambar dulu
    final rawImageUrl =
        json['photo_url'] as String? ??
        json['image_url'] as String? ??
        json['imageUrl'] as String? ??
        '';

    // Parse kategori (bisa berupa Map, String, atau nilai lain dari backend)
    final rawCategory = json['category'];
    final String categoryName = normalizeCategoryName(rawCategory);

    // Parse storeName dari nested object atau flat field
    final storeObj = json['store'];
    final String storeName;
    if (storeObj is Map) {
      storeName = storeObj['store_name'] as String? ?? '';
    } else {
      storeName =
          json['store_name'] as String? ?? json['storeName'] as String? ?? '';
    }

    // Parse lokasi dari nested store object
    final String location;
    if (storeObj is Map) {
      location = storeObj['village'] as String? ?? '';
    } else {
      location = json['location'] as String? ?? '';
    }

    // TAMBAHAN: id toko dan foto toko, dari nested store object atau
    // fallback ke field flat store_id / store_photo_url kalau ada.
    int? storeId;
    if (storeObj is Map && storeObj['id'] != null) {
      storeId = _parseInt(storeObj['id']);
    } else if (json['store_id'] != null) {
      storeId = _parseInt(json['store_id']);
    }

    String? rawStorePhotoUrl;
    if (storeObj is Map) {
      rawStorePhotoUrl = storeObj['store_photo_url'] as String?;
    }
    rawStorePhotoUrl ??= json['store_photo_url'] as String?;
    final storePhotoUrl =
        (rawStorePhotoUrl != null && rawStorePhotoUrl.isNotEmpty)
        ? resolveImageUrlWithProxy(_resolveImageUrl(rawStorePhotoUrl))
        : null;

    // Parse isService dari field 'type' atau 'is_service'
    final typeVal = json['type'] as String? ?? '';
    final isService =
        typeVal == 'jasa' ||
        typeVal == 'service' ||
        json['is_service'] == true ||
        json['isService'] == true;

    return ProductModel(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? '',
      storeName: storeName,
      location: location,
      category: categoryName,
      price: _parseDouble(json['price']),
      stock: _parseInt(json['stock']),
      description: json['description'] as String? ?? '',
      // FIX: Resolve URL gambar ke absolute URL
      imageUrl: resolveImageUrlWithProxy(_resolveImageUrl(rawImageUrl)),
      isService: isService,
      isSample: false,
      storeId: storeId,
      storePhotoUrl: storePhotoUrl,
    );
  }

  static String normalizeCategoryName(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      final name =
          value['name'] ?? value['category_name'] ?? value['slug'] ?? '';
      return _normalizeCategoryText(name.toString());
    }
    return _normalizeCategoryText(value.toString());
  }

  static String _normalizeCategoryText(String value) {
    final trimmed = value.trim();
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Pastikan URL gambar selalu absolute dan bersih.
  static String _resolveImageUrl(String url) {
    if (url.isEmpty) return '';
    // Bersihkan escaped slash dari JSON (\/ -> /)
    final cleaned = url.replaceAll(r'\/', '/');
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://'))
      return cleaned;
    // Path relatif — tambahkan base URL backend
    if (cleaned.startsWith('/')) return '\$backendUrl\$cleaned';
    return '\$backendUrl/\$cleaned';
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    if (value is num) return value.toInt();
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    if (value is num) return value.toDouble();
    return 0;
  }

  factory ProductModel.empty() {
    return ProductModel(
      id: 0,
      name: '',
      storeName: '',
      location: '',
      category: '',
      price: 0,
      stock: 0,
      description: '',
      imageUrl: '',
      isSample: false,
    );
  }
}
