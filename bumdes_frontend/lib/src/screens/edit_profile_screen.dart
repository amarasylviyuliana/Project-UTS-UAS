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
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pickedPhotoBytes; // preview lokal sebelum/selama upload
  String? _pickedPhotoName;
  bool _uploadingPhoto = false;

  static const _primary = Color(0xFF2D5016);
  static const _accent = Color(0xFF52B788);
  static const _border = Color(0xFFC8E6C9);

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

  // ── hapus foto profil ─────────────────────────────────────────
  Future<void> _deletePhoto() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token tidak tersedia. Silakan login ulang.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Foto Profil', style: TextStyle(color: _primary)),
        content: const Text('Yakin mau hapus foto profil? Foto akan kembali ke default.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal', style: TextStyle(color: _accent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _uploadingPhoto = true);
    try {
      final service = AuthService();
      await service.deleteProfilePhoto(auth.token!);
      await auth.refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _pickedPhotoBytes = null;
        });
      }
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

    final hasPhoto = _pickedPhotoBytes != null ||
        (auth.user?.photoUrl != null && auth.user!.photoUrl!.isNotEmpty);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Ubah Foto Profil',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _primary),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _primary),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _primary),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus Foto Profil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deletePhoto();
                },
              ),
            const SizedBox(height: 8),
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
      final result = await service.uploadProfilePhoto(auth.token!, bytes, xfile.name);
      debugPrint('uploadProfilePhoto response: $result');
      await auth.refreshProfile();
      debugPrint('photoUrl setelah refreshProfile: ${auth.user?.photoUrl}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui')),
        );
      }
    } catch (e) {
      debugPrint('Gagal upload foto profil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _pickedPhotoBytes = null;
        });
      }
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

  // ── DIALOG UBAH PASSWORD (dengan toggle lihat password) ─────────────────
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

    // state lokal khusus dialog untuk toggle show/hide tiap field
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    InputDecoration passwordDecoration(
      String label, {
      required bool obscure,
      required VoidCallback onToggle,
    }) =>
        InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _primary),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent, width: 2),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _primary,
            ),
            onPressed: onToggle,
          ),
        );

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Ubah Kata Sandi', style: TextStyle(color: _primary)),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: passwordDecoration(
                        'Password Saat Ini',
                        obscure: obscureCurrent,
                        onToggle: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password saat ini diperlukan';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: obscureNew,
                      decoration: passwordDecoration(
                        'Password Baru',
                        obscure: obscureNew,
                        onToggle: () => setDialogState(() => obscureNew = !obscureNew),
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
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: passwordDecoration(
                        'Konfirmasi Password',
                        obscure: obscureConfirm,
                        onToggle: () => setDialogState(() => obscureConfirm = !obscureConfirm),
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
                  child: const Text('Batal', style: TextStyle(color: _accent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  // ── AVATAR DENGAN FALLBACK YANG BENAR ───────────────────────────────────
  Widget _buildAvatarContent(String? photoUrl, double radius) {
    final double diameter = radius * 2;

    if (_pickedPhotoBytes != null) {
      return ClipOval(
        child: Image.memory(
          _pickedPhotoBytes!,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
        ),
      );
    }

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Gagal load foto profil dari "$photoUrl": $error');
            return Icon(Icons.person, size: radius, color: _primary);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: diameter,
              height: diameter,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    }

    return Icon(Icons.person, size: radius, color: _primary);
  }

  Widget _sectionCard({
    required String title,
    IconData? icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EFE2)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: _primary),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPhotoSection(AuthProvider auth) {
    final user = auth.user;
    const double radius = 48;
    const double diameter = radius * 2;

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withOpacity(0.15),
                ),
                child: _buildAvatarContent(user?.photoUrl, radius),
              ),
              if (_uploadingPhoto)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black45,
                    ),
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
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
            icon: const Icon(Icons.camera_alt_outlined, size: 16, color: _primary),
            label: const Text('Ubah Foto Profil', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _primary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF3F5F1),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard(
              title: 'Foto Profil',
              icon: Icons.photo_camera_outlined,
              child: _buildPhotoSection(auth),
            ),
            _sectionCard(
              title: 'Data Diri',
              icon: Icons.person_outline,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Nama'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Nama diperlukan' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    decoration: _inputDecoration('Telepon'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Telepon diperlukan' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration('Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v ?? '').contains('@') ? null : 'Email tidak valid',
                  ),
                ],
              ),
            ),
            _sectionCard(
              title: 'Notifikasi Telegram',
              icon: Icons.telegram,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _telegramChatIdController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Telegram Chat ID (opsional)').copyWith(
                      hintText: 'Contoh: 123456789',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _accent.withOpacity(0.2)),
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
                ],
              ),
            ),
            _sectionCard(
              title: 'Keamanan Akun',
              icon: Icons.lock_outline,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _accent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showChangePasswordDialog,
                  icon: const Icon(Icons.password, color: _primary, size: 18),
                  label: const Text('Ubah Kata Sandi', style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}