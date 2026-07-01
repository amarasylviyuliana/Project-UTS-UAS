import 'package:flutter/material.dart';

class SecurityScreen extends StatefulWidget {
  static const routeName = '/security';
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan ubah kata sandi dikirim')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentController,
                decoration: const InputDecoration(labelText: 'Kata Sandi Saat Ini'),
                obscureText: true,
                validator: (v) => (v ?? '').isEmpty ? 'Diperlukan' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                decoration: const InputDecoration(labelText: 'Kata Sandi Baru'),
                obscureText: true,
                validator: (v) => (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _loading ? null : _changePassword, child: _loading ? const CircularProgressIndicator() : const Text('Ubah Kata Sandi')),
            ],
          ),
        ),
      ),
    );
  }
}
