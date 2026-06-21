import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../services/profile_service.dart';
import '../config.dart';
import 'store_form_screen.dart';

class ProductFormScreen extends StatefulWidget {
  static const routeName = '/product-form';
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;
  late String _type;
  late String _category;
  ProductModel? _product;
  XFile? _imageFile;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _type = 'product';
    _category = 'Kuliner Desa';
    _nameController = TextEditingController();
    _priceController = TextEditingController();
    _stockController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['product'] is ProductModel) {
      _product = args['product'] as ProductModel;
      _nameController.text = _product!.name;
      _priceController.text = _product!.price.toStringAsFixed(0);
      _stockController.text = _product!.stock.toString();
      _descriptionController.text = _product!.description;
      _type = _product!.isService ? 'service' : 'product';
      _category = _product!.category;
      _imageUrl = _product!.imageUrl;
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
      imageQuality: 80,
    );
    if (picked != null) setState(() => _imageFile = picked);
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isAuthenticated || auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    String? uploadedImageUrl;
    try {
      final profileService = ProfileService();
      final storeResponse = await profileService.getStore(auth.token!);
      if (!mounted) return;
      final store = storeResponse['data'] ?? storeResponse;
      if (store == null || store['id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda perlu mendaftarkan toko terlebih dahulu'),
          ),
        );
        Navigator.pushNamed(context, StoreFormScreen.routeName);
        return;
      }
      if (_imageFile != null) {
        try {
          final uri = Uri.parse(apiUrl('/products/upload-image'));
          final request = http.MultipartRequest('POST', uri);
          request.headers['Authorization'] = 'Bearer ${auth.token}';
          request.files.add(
            await http.MultipartFile.fromPath('image', _imageFile!.path),
          );
          final streamed = await request.send();
          final resp = await http.Response.fromStream(streamed);
          if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
            final data = jsonDecode(resp.body);
            final payload = data is Map<String, dynamic>
                ? (data['data'] ?? data)
                : data;
            uploadedImageUrl =
                payload['image_url'] ?? payload['image'] ?? payload['url'];
          }
        } catch (e) {
          debugPrint('Image upload error: $e');
        }
      }
    } catch (e) {
      debugPrint('getStore error: $e');
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda perlu mendaftarkan toko terlebih dahulu'),
          ),
        );
        if (!mounted) return;
        Navigator.pushNamed(context, StoreFormScreen.routeName);
        return;
      }
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final categoryId = _getCategoryId(_category);
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
          uploadedImageUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil ditambahkan')),
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
          uploadedImageUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil diperbarui')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan produk: $e')));
      }
    }
  }

  int _getCategoryId(String categoryName) {
    const categoryMap = {
      'Pertanian & Perkebunan': 1,
      'Kerajinan Tangan': 2,
      'Kuliner Desa': 3,
      'Jasa Lokal': 4,
    };
    return categoryMap[categoryName] ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _product == null ? 'Tambah Produk / Jasa' : 'Ubah Produk / Jasa',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _imageFile!.path,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : _imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap untuk pilih foto',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk / Jasa',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(
                    value: 'Pertanian & Perkebunan',
                    child: Text('Pertanian & Perkebunan'),
                  ),
                  DropdownMenuItem(
                    value: 'Kerajinan Tangan',
                    child: Text('Kerajinan Tangan'),
                  ),
                  DropdownMenuItem(
                    value: 'Kuliner Desa',
                    child: Text('Kuliner Desa'),
                  ),
                  DropdownMenuItem(
                    value: 'Jasa Lokal',
                    child: Text('Jasa Lokal'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipe'),
                items: const [
                  DropdownMenuItem(
                    value: 'product',
                    child: Text('Produk Fisik'),
                  ),
                  DropdownMenuItem(value: 'service', child: Text('Jasa Lokal')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga (IDR)'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Harga wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              if (_type == 'product')
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Stok wajib diisi'
                      : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Deskripsi wajib diisi'
                    : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
