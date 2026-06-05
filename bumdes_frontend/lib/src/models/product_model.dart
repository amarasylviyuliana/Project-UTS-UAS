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
    return ProductModel(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? '',
      storeName: json['store_name'] as String? ?? json['storeName'] as String? ?? '',
      location: json['location'] as String? ?? '',
      category: json['category'] as String? ?? '',
      price: _parseDouble(json['price']),
      stock: _parseInt(json['stock']),
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String? ?? '',
      isService: json['is_service'] as bool? ?? json['isService'] as bool? ?? false,
      isSample: false,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
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
