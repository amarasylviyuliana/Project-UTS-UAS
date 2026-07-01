import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  String _language = 'Indonesia';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Notifikasi'),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Bahasa Aplikasi'),
            subtitle: Text(_language),
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (_) => SimpleDialog(
                  title: const Text('Pilih Bahasa'),
                  children: [
                    SimpleDialogOption(onPressed: () => Navigator.pop(context, 'Indonesia'), child: const Text('Indonesia')),
                    SimpleDialogOption(onPressed: () => Navigator.pop(context, 'English'), child: const Text('English')),
                  ],
                ),
              );
              if (result != null) setState(() => _language = result);
            },
          ),
          const SizedBox(height: 12),
          const Text('Pengaturan lainnya akan ditambahkan di versi berikutnya.'),
        ],
      ),
    );
  }
}
