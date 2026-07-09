class UserModel {
  // ── BASE URL BACKEND ───────────────────────────────────────────────────
  // Dipakai untuk melengkapi photoUrl kalau backend cuma balikin path
  // relatif (contoh: "profile-photos/xxx.jpg") bukan URL lengkap.
  // Sesuaikan kalau base URL backend kamu beda / dipindah ke .env.
  static const String _storageBaseUrl =
      'https://project-uts-uas-production.up.railway.app/storage';

  final int? id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? address;
  final String? telegramChatId;
  final String? photoUrl;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.role = 'buyer',
    this.phone,
    this.address,
    this.telegramChatId,
    this.photoUrl,
  });

  // ── NORMALISASI photoUrl ────────────────────────────────────────────────
  // Backend kadang balikin URL lengkap (saat upload) dan kadang cuma path
  // relatif (saat GET profile), contoh:
  //   - Lengkap : https://xxx.up.railway.app/storage/profile-photos/a.jpg
  //   - Relatif : profile-photos/a.jpg
  //
  // Kalau path relatif dipakai langsung di Image.network/NetworkImage,
  // Flutter Web akan nembak ke domain frontend (vercel.app) bukan ke
  // backend, sehingga yang kebaca adalah HTML index.html, bukan gambar
  // (errornya: "Failed to detect image file format using the file
  // header" / file header [0x3c ...] = "<!DOCTYPE").
  //
  // Fungsi ini memastikan photoUrl SELALU jadi URL absolut yang valid,
  // dari mana pun sumbernya.
  static String? _normalizePhotoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    // Sudah URL absolut (http/https) -> pakai apa adanya.
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    // Path relatif -> gabungkan dengan base storage URL.
    // Buang leading slash biar tidak dobel slash saat digabung.
    final cleanedPath = value.startsWith('/') ? value.substring(1) : value;

    // Kalau path relatif sudah mengandung 'storage/' di depannya, jangan
    // ditambah base yang sudah termasuk '/storage' (hindari duplikasi).
    if (cleanedPath.startsWith('storage/')) {
      final base = _storageBaseUrl.replaceFirst(RegExp(r'/storage$'), '');
      return '$base/$cleanedPath';
    }

    return '$_storageBaseUrl/$cleanedPath';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] as String? ?? 'buyer').toLowerCase();
    final normalizedRole =
        rawRole.contains('penjual') || rawRole.contains('seller')
        ? 'seller'
        : rawRole.contains('pembeli') || rawRole.contains('buyer')
        ? 'buyer'
        : rawRole.contains('admin')
        ? 'admin'
        : rawRole;
    return UserModel(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: normalizedRole,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      telegramChatId: json['telegram_chat_id'] as String?,
      photoUrl: _normalizePhotoUrl(json['photo_url'] as String?),
    );
  }
}