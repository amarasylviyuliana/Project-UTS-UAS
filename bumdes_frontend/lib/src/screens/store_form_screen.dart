import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/profile_service.dart';

class StoreFormScreen extends StatefulWidget {
  static const routeName = '/store-form';
  const StoreFormScreen({super.key});

  @override
  State<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends State<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _regencyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankNumberCtrl = TextEditingController();
  final _bankHolderCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _storeNotFound = false;

  Map<String, dynamic>? _existingStore;
  bool get _isEditing =>
      _existingStore != null && _existingStore!['id'] != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingStore());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _regencyCtrl.dispose();
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankNumberCtrl.dispose();
    _bankHolderCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingStore() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final service = ProfileService();
      final response = await service.getStore(auth.token!);
      if (!mounted) return;

      final store = response['data'] ?? response;
      if (store != null && store['id'] != null) {
        _existingStore = store;
        _nameCtrl.text = store['store_name'] ?? '';
        _descCtrl.text = store['description'] ?? '';
        _villageCtrl.text = store['village'] ?? '';
        _districtCtrl.text = store['district'] ?? '';
        _regencyCtrl.text = store['regency'] ?? '';
        _phoneCtrl.text = store['contact_phone'] ?? '';
        _bankNameCtrl.text = store['bank_name'] ?? '';
        _bankNumberCtrl.text = store['bank_account_number'] ?? '';
        _bankHolderCtrl.text = store['bank_account_holder'] ?? '';
      } else {
        _storeNotFound = true;
      }
    } catch (e) {
      debugPrint('Load store error: $e');
      // 404 = toko memang belum dibuat oleh Admin untuk akun ini
      _storeNotFound = true;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_isLoading) return; // Tunggu sampai data selesai dimuat
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final service = ProfileService();
      final body = {
        'store_name': _nameCtrl.text.trim(),
        // FIX: Selalu kirim description sebagai string, minimal string kosong
        // Backend Laravel validasi 'description' must be a string
        // Kalau null/tidak dikirim → 422 error
        'description': _descCtrl.text.trim(),
        'village': _villageCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
        'regency': _regencyCtrl.text.trim(),
        'contact_phone': _phoneCtrl.text.trim(),
        'bank_name': _bankNameCtrl.text.trim(),
        'bank_account_number': _bankNumberCtrl.text.trim(),
        'bank_account_holder': _bankHolderCtrl.text.trim(),
      };

      await service.saveStore(auth.token!, body, isUpdate: _isEditing);

      if (!mounted) return;

      final message = 'Toko berhasil diperbarui';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan toko: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Toko'),
        backgroundColor: const Color(0xFF2A7F41),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _storeNotFound
              ? _buildStoreNotFoundState()
              : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildStatusBanner(),

                    _buildSectionTitle('Informasi Toko'),

                    _buildField(
                      controller: _nameCtrl,
                      label: 'Nama Toko',
                      icon: Icons.store_outlined,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nama toko wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // FIX: Field description wajib ada di form dan selalu
                    // dikirim ke backend (meski kosong = string kosong '')
                    _buildField(
                      controller: _descCtrl,
                      label: 'Deskripsi Toko (opsional)',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Lokasi'),

                    _buildField(
                      controller: _villageCtrl,
                      label: 'Desa / Kelurahan',
                      icon: Icons.location_on_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _districtCtrl,
                      label: 'Kecamatan',
                      icon: Icons.map_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _regencyCtrl,
                      label: 'Kabupaten / Kota',
                      icon: Icons.location_city_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _phoneCtrl,
                      label: 'No. Kontak',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Rekening Bank'),

                    _buildField(
                      controller: _bankNameCtrl,
                      label: 'Nama Bank',
                      icon: Icons.account_balance_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _bankNumberCtrl,
                      label: 'No. Rekening',
                      icon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _bankHolderCtrl,
                      label: 'Nama Pemilik Rekening',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A7F41),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Perbarui Toko',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStoreNotFoundState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_mall_directory_outlined,
                size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Toko Anda belum dibuat oleh Admin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Akun Penjual dan data toko/BUMDes sekarang dibuat langsung '
              'oleh Admin. Silakan hubungi Admin BUMDes untuk mengaktifkan '
              'toko Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isActive = _existingStore?['is_active'] == true;

    final color = isActive ? Colors.green : Colors.red;
    final icon = isActive ? Icons.check_circle_outline : Icons.pause_circle_outline;
    final message = isActive
        ? 'Toko Anda aktif dan dapat berjualan'
        : 'Toko Anda dinonaktifkan oleh Admin. Hubungi Admin BUMDes jika ini keliru.';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2A7F41),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSubmitting,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: validator,
    );
  }
}