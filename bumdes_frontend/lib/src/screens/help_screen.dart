import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  static const routeName = '/help';
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {'q': 'Bagaimana cara menghubungi dukungan?', 'a': 'Kirim email ke support@bumdes.example'},
      {'q': 'Bagaimana memulihkan kata sandi?', 'a': 'Gunakan fitur lupa kata sandi pada layar login.'},
      {'q': 'Bagaimana menambahkan produk?', 'a': 'Pergi ke Katalog → Tambah.'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan & FAQ')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final item = faqs[index];
          return ExpansionTile(
            title: Text(item['q']!),
            children: [Padding(padding: const EdgeInsets.all(12), child: Text(item['a']!))],
          );
        },
      ),
    );
  }
}
