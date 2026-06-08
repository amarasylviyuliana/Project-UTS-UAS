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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: user == null
          ? const Center(child: Text('Profil pengguna tidak tersedia'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profil Saya', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Peran'),
                    subtitle: Text(user.role == 'seller' ? 'Penjual BUMDes' : 'Pembeli Umum'),
                  ),
                ),
                const SizedBox(height: 12),
                if (user.role == 'seller')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.store),
                    label: const Text('Kelola Toko BUMDes'),
                    onPressed: () {
                      Navigator.pushNamed(context, StoreDashboardScreen.routeName);
                    },
                  ),
                const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profil'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/edit-profile');
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      auth.logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
              ],
            ),
    );
  }
}
