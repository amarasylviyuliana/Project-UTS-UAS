import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'store_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  static const routeName = '/profile';
  const ProfileScreen({super.key});

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
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF2D5016).withValues(alpha: 0.1),
                    backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 40, color: Color(0xFF2D5016))
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Container(
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