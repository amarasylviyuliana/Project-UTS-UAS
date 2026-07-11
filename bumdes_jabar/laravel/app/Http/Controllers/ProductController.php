class UserModel {
  // ── BASE URL BACKEND ───────────────────────────────────────────────────
  // Base URL API (tanpa trailing slash, tanpa "/storage").
  // Dipakai untuk melengkapi photoUrl kalau backend cuma balikin path
  // relatif (contoh: "profile-photos/xxx.jpg") bukan URL lengkap.
  static const String _apiBaseUrl =
      'https://project-uts-uas-production.up.railway.app';

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
  // Backend bisa mengembalikan photo_url dalam beberapa bentuk:
  //   1. URL absolut lewat storage langsung:
  //      https://xxx.up.railway.app/storage/profile-photos/a.jpg
  //   2. URL absolut lewat proxy /api/image/ (dipakai ProductController):
  //      https://xxx.up.railway.app/api/image/profile-photos/a.jpg
  //   3. Path relatif saja:
  //      profile-photos/a.jpg  atau  storage/profile-photos/a.jpg
  //
  // Kalau path relatif dipakai langsung di Image.network/NetworkImage,
  // Flutter Web akan nembak ke domain FRONTEND (vercel.app), bukan ke
  // backend — sehingga yang kebaca adalah HTML index.html, bukan gambar
  // (errornya biasanya: "Failed to detect image file format using the
  // file header" / header berupa "<!DOCTYPE").
  //
  // Fungsi ini memastikan photoUrl SELALU jadi URL absolut yang valid,
  // dari bentuk apa pun sumbernya, dan tidak mengubah URL yang sudah
  // absolut (baik lewat /storage/ maupun /api/image/).
  static String? _normalizePhotoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    // Sudah URL absolut (http/https) -> pakai apa adanya, jangan diubah.
    // Ini mencakup URL yang sudah lewat proxy /api/image/ dari backend.
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    // Path relatif -> gabungkan dengan base API.
    // Buang leading slash biar tidak dobel slash saat digabung.
    var cleanedPath = value.startsWith('/') ? value.substring(1) : value;

    // Kalau path relatif sudah diawali 'storage/', biarkan apa adanya
    // (jangan ditambah 'storage/' lagi di depan -> hindari duplikasi).
    if (!cleanedPath.startsWith('storage/')) {
      cleanedPath = 'storage/$cleanedPath';
    }

    return '$_apiBaseUrl/$cleanedPath';
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