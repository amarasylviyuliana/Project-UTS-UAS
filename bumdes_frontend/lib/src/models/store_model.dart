class StoreModel {
  final int id;
  final String storeName;
  final String village;
  final String? district;
  final String? regency;
  final String? storePhotoUrl;
  final int productCount;
  final List<String> categories;

  StoreModel({
    required this.id,
    required this.storeName,
    required this.village,
    this.district,
    this.regency,
    this.storePhotoUrl,
    this.productCount = 0,
    this.categories = const [],
  });

  // TAMBAHAN: label wilayah gabungan untuk ditampilkan di kartu, mis.
  // "Kec. Lembang, Kab. Bandung Barat". Kalau district/regency kosong,
  // fallback ke village supaya tidak tampil kosong.
  String get regionLabel {
    final parts = <String>[];
    if (district != null && district!.isNotEmpty) {
      parts.add('Kec. $district');
    } else if (village.isNotEmpty) {
      parts.add(village);
    }
    if (regency != null && regency!.isNotEmpty) {
      parts.add('Kab. $regency');
    }
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final rawPhoto = json['store_photo_url'] as String?;
    return StoreModel(
      id: _parseInt(json['id']),
      storeName: json['store_name'] as String? ?? '',
      village: json['village'] as String? ?? '',
      district: json['district'] as String?,
      regency: json['regency'] as String?,
      storePhotoUrl: (rawPhoto != null && rawPhoto.isNotEmpty)
          ? rawPhoto
          : null,
      productCount: _parseInt(json['product_count']),
      categories: (json['categories'] is List)
          ? List<String>.from(
              (json['categories'] as List).map((e) => e.toString()),
            )
          : const [],
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }
}