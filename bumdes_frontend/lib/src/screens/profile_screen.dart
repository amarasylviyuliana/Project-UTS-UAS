import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'store_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  static const routeName = '/profile';
  const ProfileScreen({super.key});

  // ── AVATAR DENGAN FALLBACK YANG BENAR ───────────────────────────────────
  // Sebelumnya pakai CircleAvatar(backgroundImage: NetworkImage(...)): kalau
  // gambar gagal dimuat, Flutter TIDAK otomatis balik ke icon person, jadi
  // yang muncul cuma warna background polos (bulatan hijau tanpa icon).
  //
  // Sekarang pakai Image.network + errorBuilder supaya kalau gagal load,
  // otomatis fallback ke icon, dan errornya di-print ke console supaya
  // kelihatan penyebab aslinya (CORS / URL salah / dll).
  Widget _buildAvatar(String? photoUrl) {
    const double radius = 40;
    const double diameter = radius * 2;

    Widget content;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          photoUrl,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Gagal load foto profil dari "$photoUrl": $error');
            return const Icon(Icons.person, size: radius, color: Color(0xFF2D5016));
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(
              width: diameter,
              height: diameter,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      );
    } else {
      content = const Icon(Icons.person, size: radius, color: Color(0xFF2D5016));
    }

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2D5016).withValues(alpha: 0.1),
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final profileContent = user == null
        ? const Center(child: Text('Profil pengguna tidak tersedia'))
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profil Saya', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D5016))),
                const SizedBox(height: 20),
                Center(child: _buildAvatar(user.photoUrl)),
                const SizedBox(height: 20),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              user.photoUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D5016).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.person, color: Color(0xFF2D5016)),
                                );
                              },
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D5016).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person, color: Color(0xFF2D5016)),
                          ),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D5016))),
                    subtitle: Text(user.email, style: const TextStyle(color: Colors.black54)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF52B788).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.badge, color: Color(0xFF52B788)),
                    ),
                    title: const Text('Peran', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D5016))),
                    subtitle: Text(user.role == 'seller' ? 'Penjual BUMDes' : 'Pembeli Umum', style: const TextStyle(color: Colors.black54)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 28),
                if (user.role == 'seller') ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.store),
                    label: const Text('Kelola Toko BUMDes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF52B788),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, StoreDashboardScreen.routeName);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/edit-profile');
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    auth.logout();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: profileContent,
    );
  }
}