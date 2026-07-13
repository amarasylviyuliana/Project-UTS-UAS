import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../services/profile_service.dart';
import '../services/product_service.dart';
import 'store_form_screen.dart';


class ProductFormScreen extends StatefulWidget {
  static const routeName = '/product-form';
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'product';
  String _category = 'Kuliner Desa';
  ProductModel? _product;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();
 bool _isSaving = false;
  bool _argsLoaded = false;
  double _platformFeePercentage = 0;
  // TAMBAHAN: status Tersedia/Tidak Tersedia, khusus dipakai untuk tipe
  // Jasa (menggantikan field Stok yang memang tidak relevan untuk Jasa).
  // Untuk tipe Produk, nilai ini tetap diteruskan ke server apa adanya
  // (default true untuk produk baru, atau status is_active yang sudah
  // ada kalau sedang mengedit) supaya tidak diam-diam mengubah status
  // aktif produk lewat form ini.
  bool _isActive = true;

  static const List<String> _validCategories = [
    'Pertanian & Perkebunan',
    'Kerajinan Tangan',
    'Kuliner Desa',
    'Jasa Lokal',
  ];

  static const Map<String, int> _categoryMap = {
    'Pertanian & Perkebunan': 1,
    'Kerajinan Tangan': 2,
    'Kuliner Desa': 3,
    'Jasa Lokal': 4,
  };

 @override
  void initState() {
    super.initState();
    _loadPlatformFeePercentage();
  }

  Future<void> _loadPlatformFeePercentage() async {
    final fee = await ProductService().getPlatformFeePercentage();
    if (!mounted) return;
    setState(() => _platformFeePercentage = fee);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
  
    _argsLoaded = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['product'] is ProductModel) {
      _product = args['product'] as ProductModel;
      _nameController.text = _product!.name;
      _priceController.text = _product!.price.toStringAsFixed(0);
      _stockController.text = _product!.stock.toString();
      _descriptionController.text = _product!.description;
      _type = _product!.isService ? 'service' : 'product';
      // TAMBAHAN: bawa status aktif produk/jasa yang sedang diedit.
      _isActive = _product!.isActive;

      final imageUrl = _product!.imageUrl;
      if (imageUrl.isNotEmpty) {
        _existingImageUrl = imageUrl;
      }

      final cat = _product!.category;
      _category = _validCategories.contains(cat) ? cat : 'Kuliner Desa';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // FIX: dibatasi lebar/tinggi maksimal + kualitas, sama seperti foto
      // profil (lihat edit_profile_screen.dart). Sebelumnya pickImage
      // dipanggil TANPA maxWidth/maxHeight, jadi foto langsung dari galeri
      // HP (apalagi iPhone) bisa berukuran 5-10MB dan ditolak backend, yang
      // membatasi ukuran foto produk maksimal 5120 KB (lihat validasi
      // 'photo' => 'sometimes|image|mimes:jpeg,png,jpg|max:5120' di
      // ProductController@store dan @update). Upload jadi gagal tanpa
      // pesan yang jelas ke pengguna.
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    // FIX: Selalu baca bytes — aman untuk Web, Android, iOS
    final bytes = await picked.readAsBytes();

    setState(() {
      _imageFile = picked;
      _imageBytes = bytes;
      _existingImageUrl = null; // ganti gambar lama
    });
  }

  // FIX: Preview gambar — tidak pakai dart:io File sama sekali
  Widget _buildImagePreview() {
    // Prioritas 1: File baru yang dipilih — pakai bytes (aman semua platform)
    if (_imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _imageBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    // Prioritas 2: URL gambar lama dari server
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _existingImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.grey[100],
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 8),
                    Text('Memuat gambar...',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
          errorBuilder: (_, error, __) {
            debugPrint('Gagal memuat gambar: $error | URL: $_existingImageUrl');
            return Container(
              color: Colors.grey[200],
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Gagal memuat gambar',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(height: 4),
                  Text('Tap untuk pilih foto baru',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            );
          },
        ),
      );
    }

    // Prioritas 3: Placeholder
    return Container(
      color: Colors.grey[50],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Tap untuk pilih foto', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 4),
          Text('(Opsional)', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final provider = Provider.of<ProductProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isAuthenticated || auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan login terlebih dahulu')));
      setState(() => _isSaving = false);
      return;
    }

    // Cek status toko & approval — skip kalau sedang edit produk yang sudah ada
    if (_product == null) {
      try {
        final profileService = ProfileService();
        final storeResponse = await profileService.getStore(auth.token!);
        if (!mounted) return;

        final store = storeResponse['data'] ?? storeResponse;
        if (store == null || store['id'] == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Anda perlu mendaftarkan toko terlebih dahulu')));
          Navigator.pushNamed(context, StoreFormScreen.routeName);
          setState(() => _isSaving = false);
          return;
        }

        final isActive = store['is_active'] == true;
        final approval = store['store_approval'];
        final approvalStatus = approval?['status'] as String?;

        final bool storeApproved = approvalStatus != null
            ? approvalStatus == 'Disetujui'
            : isActive;

        if (!storeApproved) {
          if (!mounted) return;
          final msg = approvalStatus == 'Ditolak'
              ? 'Toko Anda ditolak admin. Silakan daftar ulang toko.'
              : 'Toko Anda belum disetujui admin. Mohon tunggu persetujuan.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor:
                approvalStatus == 'Ditolak' ? Colors.red : Colors.orange,
            duration: const Duration(seconds: 3),
          ));
          setState(() => _isSaving = false);
          return;
        }
      } catch (e) {
        debugPrint('getStore error: \$e');
        if (e.toString().contains('404') || e.toString().contains('not found')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Anda perlu mendaftarkan toko terlebih dahulu')));
          Navigator.pushNamed(context, StoreFormScreen.routeName);
          setState(() => _isSaving = false);
          return;
        }
      }
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final stock = _type == 'service'
        ? 0
        : (int.tryParse(_stockController.text.trim()) ?? 0);
    final categoryId = _categoryMap[_category] ?? 1;
    final type = _type == 'service' ? 'jasa' : 'produk';

    try {
      if (_product == null) {
        await provider.createProductOnServer(
          auth.token!,
          _nameController.text.trim(),
          categoryId,
          type,
          price,
          stock,
          _descriptionController.text.trim(),
          _imageFile,
          imageBytes: _imageBytes,
          // TAMBAHAN: kirim status Tersedia/Tidak Tersedia (khusus Jasa,
          // lewat switch di form). Untuk Produk baru, defaultnya true.
          isActive: _isActive,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        await provider.updateProductOnServer(
          auth.token!,
          _product!.id,
          _nameController.text.trim(),
          categoryId,
          type,
          price,
          stock,
          _descriptionController.text.trim(),
          _imageFile,
          imageBytes: _imageBytes,
          isActive: _isActive,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan produk: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _product != null;
    final hasImage = _imageBytes != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isEditing ? 'Ubah Produk / Jasa' : 'Tambah Produk / Jasa'),
        backgroundColor: const Color(0xFF2A7F41),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _isSaving ? null : _pickImage,
                child: Container(
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFF2A7F41).withAlpha(150),
                        width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildImagePreview(),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: hasImage
                    ? TextButton.icon(
                        onPressed: _isSaving ? null : _pickImage,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Ganti Foto'),
                      )
                    : Text(
                        'Tap pada kotak di atas untuk memilih foto produk (opsional)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
              ),

              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk / Jasa',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _validCategories
                    .map((cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _category = v);
                      },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'product', child: Text('Produk Fisik')),
                  DropdownMenuItem(
                      value: 'service', child: Text('Jasa Lokal')),
                ],
                onChanged: _isSaving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _type = v);
                      },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _priceController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga (IDR)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Harga wajib diisi';
                  final p = double.tryParse(v.trim());
                  if (p == null || p <= 0) return 'Harga harus lebih dari 0';
                  return null;
                },
              ),
              if (_platformFeePercentage > 0) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Setiap pesanan yang Selesai akan dipotong biaya admin/pajak platform sebesar ${_platformFeePercentage.toStringAsFixed(0)}% dari harga di atas. Sisanya baru masuk ke saldo Anda, jadi saldo Anda tidak akan tiba-tiba berkurang tanpa alasan.',
                          style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Stok hanya relevan untuk Produk Fisik. Jasa/layanan tidak
              // memiliki stok — sebagai gantinya, Jasa pakai toggle
              // Tersedia/Tidak Tersedia (field is_active), karena yang
              // relevan untuk Jasa bukan "berapa jumlahnya" tapi "lagi
              // bisa diambil pesanan atau tidak".
              if (_type == 'product') ...[
                TextFormField(
                  controller: _stockController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stok',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Stok wajib diisi';
                    final p = int.tryParse(v.trim());
                    if (p == null || p < 0) return 'Stok tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: (_isActive ? const Color(0xFF2A7F41) : Colors.grey)
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_isActive
                              ? const Color(0xFF2A7F41)
                              : Colors.grey)
                          .withOpacity(0.4),
                    ),
                  ),
                  child: SwitchListTile(
                    value: _isActive,
                    onChanged: _isSaving
                        ? null
                        : (v) => setState(() => _isActive = v),
                    activeColor: const Color(0xFF2A7F41),
                    title: Text(
                      _isActive ? 'Tersedia' : 'Tidak Tersedia',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _isActive
                          ? 'Jasa ini tampil dan bisa dipesan pembeli.'
                          : 'Jasa ini disembunyikan sementara dan tidak bisa dipesan pembeli.',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    secondary: Icon(
                      _isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
                      color: _isActive ? const Color(0xFF2A7F41) : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Deskripsi wajib diisi'
                    : null,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A7F41),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          isEditing ? 'Perbarui Produk' : 'Tambah Produk',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
}