import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  static const routeName = '/edit-profile';
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _emailController.text = user.email;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token tidak tersedia. Silakan login ulang.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = AuthService();
      final body = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };
      await service.updateProfile(auth.token!, body);
      await auth.refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui profil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token tidak tersedia. Silakan login ulang.')),
        );
      }
      return;
    }

    final dialogFormKey = GlobalKey<FormState>();

    // Show dialog to collect password input; perform network call after dialog closes
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ubah Kata Sandi'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password Saat Ini'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Password saat ini diperlukan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password Baru'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Password baru diperlukan';
                    }
                    if (value.trim().length < 8) {
                      return 'Password harus minimal 8 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Konfirmasi Password'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Konfirmasi password diperlukan';
                    }
                    if (value.trim() != _newPasswordController.text.trim()) {
                      return 'Password konfirmasi tidak cocok';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!dialogFormKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop({
                  'current': _currentPasswordController.text.trim(),
                  'password': _newPasswordController.text.trim(),
                  'password_confirmation': _confirmPasswordController.text.trim(),
                });
              },
              child: const Text('Simpan Password'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    try {
      final service = AuthService();
      await service.updatePassword(
        auth.token!,
        result['current']!,
        result['password']!,
        result['password_confirmation']!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diperbarui')),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui kata sandi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Nama diperlukan' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Telepon'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Telepon diperlukan' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v ?? '').contains('@') ? null : 'Email tidak valid',
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _showChangePasswordDialog,
                child: const Text('Ubah Kata Sandi'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan Perubahan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
