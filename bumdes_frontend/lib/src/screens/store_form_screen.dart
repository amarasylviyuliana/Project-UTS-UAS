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
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _regencyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankName = TextEditingController();
  final _bankNumber = TextEditingController();
  final _bankHolder = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _regencyCtrl.dispose();
    _phoneCtrl.dispose();
    _bankName.dispose();
    _bankNumber.dispose();
    _bankHolder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final service = ProfileService();
      final body = {
        'store_name': _nameCtrl.text.trim(),
        'village': _villageCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
        'regency': _regencyCtrl.text.trim(),
        'contact_phone': _phoneCtrl.text.trim(),
        'bank_name': _bankName.text.trim(),
        'bank_account_number': _bankNumber.text.trim(),
        'bank_account_holder': _bankHolder.text.trim(),
      };
      await service.saveStore(auth.token!, body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toko berhasil disimpan')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan toko: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftarkan Toko')), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nama Toko'), validator: (v) => v==null||v.isEmpty? 'Nama wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _villageCtrl, decoration: const InputDecoration(labelText: 'Desa / Kelurahan'), validator: (v) => v==null||v.isEmpty? 'Wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _districtCtrl, decoration: const InputDecoration(labelText: 'Kecamatan'), validator: (v) => v==null||v.isEmpty? 'Wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _regencyCtrl, decoration: const InputDecoration(labelText: 'Kabupaten / Kota'), validator: (v) => v==null||v.isEmpty? 'Wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'No. Kontak'), validator: (v) => v==null||v.isEmpty? 'Wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _bankName, decoration: const InputDecoration(labelText: 'Nama Bank'), validator: (v) => v==null||v.isEmpty? 'Wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _bankNumber, decoration: const InputDecoration(labelText: 'No. Rekening'), validator: (v) => v==null||v.isEmpty? 'Wajib' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _bankHolder, decoration: const InputDecoration(labelText: 'Nama Pemilik Rekening'), validator: (v) => v==null||v.isEmpty? 'Wajib' : null),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _isSubmitting? null: _save, child: _isSubmitting? const CircularProgressIndicator(): const Text('Simpan')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
