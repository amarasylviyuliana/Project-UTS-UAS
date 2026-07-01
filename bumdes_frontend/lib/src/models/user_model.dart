class UserModel {
  final int? id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? address;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.role = 'buyer',
    this.phone,
    this.address,
  });

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
    );
  }
}
