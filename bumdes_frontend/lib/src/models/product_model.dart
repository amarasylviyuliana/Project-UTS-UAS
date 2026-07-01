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
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Resolve URL gambar dulu
    final rawImageUrl =
        json['photo_url'] as String? ??
        json['image_url'] as String? ??
        json['imageUrl'] as String? ??
        '';

    // Parse kategori (bisa berupa Map atau String)
    final rawCategory = json['category'];
    final String categoryName;
    if (rawCategory is Map) {
      categoryName = rawCategory['name'] as String? ?? '';
    } else {
      categoryName = rawCategory as String? ?? '';
    }

    // Parse storeName dari nested object atau flat field
    final storeObj = json['store'];
    final String storeName;
    if (storeObj is Map) {
      storeName = storeObj['store_name'] as String? ?? '';
    } else {
      storeName =
          json['store_name'] as String? ??
          json['storeName'] as String? ??
          '';
    }

    // Parse lokasi dari nested store object
    final String location;
    if (storeObj is Map) {
      location = storeObj['village'] as String? ?? '';
    } else {
      location = json['location'] as String? ?? '';
    }

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
    );
  }

  /// Pastikan URL gambar selalu absolute dan bersih.
  static String _resolveImageUrl(String url) {
    if (url.isEmpty) return '';
    // Bersihkan escaped slash dari JSON (\/ -> /)
    final cleaned = url.replaceAll(r'\/', '/');
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) return cleaned;
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