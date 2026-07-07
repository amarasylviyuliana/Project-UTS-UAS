import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';

class SecurityScreen extends StatefulWidget {
  static const routeName = '/security';
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Fitur Ubah Password sekarang hanya tersedia di Edit Profil.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, EditProfileScreen.routeName);
              },
              child: const Text('Buka Edit Profil'),
            ),
          ],
        ),
      ),
    );
  }
}
