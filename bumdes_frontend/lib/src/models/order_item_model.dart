import 'product_model.dart';

class OrderItemModel {
  final ProductModel product;
  final int quantity;
  final double unitPrice;

  OrderItemModel({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // Backend kadang mengirim data produk sebagai object bersarang
    // ('product' / 'Product'), tapi kadang juga mengirim field-field
    // produk langsung rata (flat) di level item pesanan itu sendiri
    // (mis. 'product_name', 'product_image', 'product_photo', dst).
    // Sebelumnya kode ini HANYA mencoba 'product'/'Product' — kalau
    // backend mengirim bentuk flat, hasilnya selalu ProductModel.empty()
    // (nama & foto kosong), padahal datanya sebenarnya ada di JSON.
    final rawProductJson = json['product'] ?? json['Product'];

    ProductModel product;
    if (rawProductJson is Map<String, dynamic>) {
      // Bentuk bersarang: parse langsung lewat ProductModel.fromJson,
      // tapi tetap disempurnakan (lihat _mergeFallbackImage) kalau-kalau
      // field foto di dalam object ini kosong sementara ada info foto
      // di level item.
      product = ProductModel.fromJson(rawProductJson);
      product = _mergeFallbackImage(product, json);
    } else {
      // Bentuk flat: bangun ProductModel manual dari field-field yang
      // ada langsung di level item pesanan.
      product = _buildProductFromFlatItem(json);
    }

    final quantityValue =
        json['quantity'] ?? json['qty'] ?? json['quantity_order'] ?? 0;
    final unitValue =
        json['unit_price'] ??
        json['price'] ??
        json['product_price'] ??
        product.price;

    return OrderItemModel(
      product: product,
      quantity: _parseInt(quantityValue),
      unitPrice: _parseDouble(unitValue),
    );
  }

  // Kalau object 'product' bersarang sudah ke-parse tapi imageUrl-nya
  // kosong, coba cari foto dari field alternatif yang mungkin ada di
  // level item (bukan di dalam 'product').
  //
  // FIX: 'image_url' dipindah ke urutan PALING ATAS. Field ini sudah
  // diresolve backend jadi URL proxy yang valid (/api/image/...),
  // sedangkan field lain seperti 'photo_url'/'photo'/'product_photo'
  // seringkali berupa path mentah dari database yang tidak bisa
  // langsung dimuat sebagai gambar. Kalau path mentah ini tidak sengaja
  // terpilih duluan, hasilnya foto blank walau 'image_url' yang valid
  // sebenarnya tersedia di JSON yang sama.
  static ProductModel _mergeFallbackImage(
    ProductModel product,
    Map<String, dynamic> json,
  ) {
    if (product.imageUrl.isNotEmpty) return product;

    final fallbackImage = _firstNonEmptyString(json, [
      'image_url',
      'product_image',
      'product_photo_url',
      'product_photo',
      'image',
      'photo_url',
      'photo',
    ]);

    if (fallbackImage == null || fallbackImage.isEmpty) return product;

    return ProductModel(
      id: product.id,
      name: product.name,
      storeName: product.storeName,
      location: product.location,
      category: product.category,
      price: product.price,
      stock: product.stock,
      description: product.description,
      imageUrl: fallbackImage,
      isService: product.isService,
      isSample: product.isSample,
      storeId: product.storeId,
      storePhotoUrl: product.storePhotoUrl,
    );
  }

  // Bangun ProductModel dari field-field flat di level item pesanan,
  // untuk backend yang tidak mengirim object 'product' bersarang.
  static ProductModel _buildProductFromFlatItem(Map<String, dynamic> json) {
    final name =
        _firstNonEmptyString(json, [
          'product_name',
          'name',
          'productName',
        ]) ??
        '';

    // FIX: 'image_url' diprioritaskan (lihat penjelasan di
    // _mergeFallbackImage di atas).
    final imageUrl =
        _firstNonEmptyString(json, [
          'image_url',
          'product_image',
          'product_photo_url',
          'product_photo',
          'image',
          'photo_url',
          'photo',
        ]) ??
        '';

    final productId = json['product_id'] ?? json['productId'] ?? json['id'];

    return ProductModel(
      id: _parseInt(productId),
      name: name,
      storeName:
          _firstNonEmptyString(json, ['store_name', 'storeName']) ?? '',
      location: '',
      category: '',
      price: _parseDouble(
        json['unit_price'] ?? json['price'] ?? json['product_price'],
      ),
      stock: 0,
      description: '',
      imageUrl: imageUrl,
      isService: false,
      isSample: false,
    );
  }

  static String? _firstNonEmptyString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
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
}