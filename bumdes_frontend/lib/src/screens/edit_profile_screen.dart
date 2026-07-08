import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _telegramChatIdController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;

  // ── FOTO PROFIL ────────────────────────────────────────────────────────────
  // Sengaja pakai Uint8List (bytes), BUKAN dart:io File, supaya kode ini
  // aman dikompilasi & dijalankan di Flutter Web maupun mobile sekaligus.
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pickedPhotoBytes; // preview lokal sebelum/selama upload
  String? _pickedPhotoName;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _telegramChatIdController.dispose();
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
      _telegramChatIdController.text = user.telegramChatId ?? '';
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token tidak tersedia. Silakan login ulang.')),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();

    setState(() {
      _pickedPhotoBytes = bytes;
      _pickedPhotoName = xfile.name;
      _uploadingPhoto = true;
    });

    try {
      final service = AuthService();
      await service.uploadProfilePhoto(auth.token!, bytes, xfile.name);
      await auth.refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
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
        'telegram_chat_id': _telegramChatIdController.text.trim(),
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

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ubah Kata Sandi', style: TextStyle(color: Color(0xFF2D5016))),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password Saat Ini',
                    labelStyle: const TextStyle(color: Color(0xFF2D5016)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC8E6C9)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
                    ),
                  ),
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
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    labelStyle: const TextStyle(color: Color(0xFF2D5016)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC8E6C9)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
                    ),
                  ),
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
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password',
                    labelStyle: const TextStyle(color: Color(0xFF2D5016)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC8E6C9)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
                    ),
                  ),
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
              child: const Text('Batal', style: TextStyle(color: Color(0xFF52B788))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5016),
              ),
              onPressed: () {
                if (!dialogFormKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop({
                  'current': _currentPasswordController.text.trim(),
                  'password': _newPasswordController.text.trim(),
                  'password_confirmation': _confirmPasswordController.text.trim(),
                });
              },
              child: const Text('Simpan Password', style: TextStyle(color: Colors.white)),
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

  Widget _buildPhotoSection(AuthProvider auth) {
    final user = auth.user;
    ImageProvider? backgroundImage;
    if (_pickedPhotoBytes != null) {
      backgroundImage = MemoryImage(_pickedPhotoBytes!);
    } else if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(user.photoUrl!);
    }

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFF52B788).withOpacity(0.15),
                backgroundImage: backgroundImage,
                child: backgroundImage == null
                    ? const Icon(Icons.person, size: 48, color: Color(0xFF2D5016))
                    : null,
              ),
              if (_uploadingPhoto)
                Positioned.fill(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.black45,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D5016),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
            child: const Text('Ubah Foto Profil', style: TextStyle(color: Color(0xFF2D5016))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2D5016),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildPhotoSection(auth),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  labelStyle: const TextStyle(color: Color(0xFF2D5016)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC8E6C9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
                  ),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Nama diperlukan' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Telepon',
                  labelStyle: const TextStyle(color: Color(0xFF2D5016)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC8E6C9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
                  ),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Telepon diperlukan' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFF2D5016)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC8E6C9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
                  ),
                ),
                validator: (v) => (v ?? '').contains('@') ? null : 'Email tidak valid',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telegramChatIdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Telegram Chat ID (opsional)',
                  hintText: 'Contoh: 123456789',
                  labelStyle: const TextStyle(color: Color(0xFF2D5016)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC8E6C9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF52B788).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF52B788).withOpacity(0.2)),
                ),
                child: const Text(
                  'Isi ini kalau mau dapat notifikasi pesanan lewat Telegram.\n\n'
                  'Cara dapat Chat ID:\n'
                  '1. Cari bot BUMDes Jabar di Telegram\n'
                  '2. Ketik /start ke bot tersebut\n'
                  '3. Bot akan membalas dengan Chat ID kamu\n'
                  '4. Salin nomor itu ke kolom di atas',
                  style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF52B788), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showChangePasswordDialog,
                child: const Text('Ubah Kata Sandi', style: TextStyle(color: Color(0xFF2D5016), fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5016),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}