import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';

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
  late String _imageUrl;
  ProductModel? _product;

  @override
  void initState() {
    super.initState();
    _type = 'product';
    _category = 'Kuliner Desa';
    _imageUrl = 'https://picsum.photos/seed/new/400/300';
    _nameController = TextEditingController();
    _priceController = TextEditingController();
    _stockController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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

  void _saveProduct() {
    if (!_formKey.currentState!.validate()) return;
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final newProduct = ProductModel(
      id: _product?.id ?? DateTime.now().millisecondsSinceEpoch,
      name: _nameController.text.trim(),
      storeName: 'BUMDes Mitra',
      location: 'Jawa Barat',
      category: _category,
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      description: _descriptionController.text.trim(),
      imageUrl: _imageUrl,
      isService: _type == 'service',
    );
    if (_product == null) {
      provider.addProduct(newProduct);
    } else {
      provider.updateProduct(newProduct);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_product == null ? 'Tambah Produk / Jasa' : 'Ubah Produk / Jasa')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Produk / Jasa'),
                validator: (value) => value == null || value.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(value: 'Pertanian & Perkebunan', child: Text('Pertanian & Perkebunan')),
                  DropdownMenuItem(value: 'Kerajinan Tangan', child: Text('Kerajinan Tangan')),
                  DropdownMenuItem(value: 'Kuliner Desa', child: Text('Kuliner Desa')),
                  DropdownMenuItem(value: 'Jasa Lokal', child: Text('Jasa Lokal')),
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
                  DropdownMenuItem(value: 'product', child: Text('Produk Fisik')),
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
                validator: (value) => value == null || value.isEmpty ? 'Harga wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              if (_type == 'product')
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok'),
                  validator: (value) => value == null || value.isEmpty ? 'Stok wajib diisi' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
                validator: (value) => value == null || value.isEmpty ? 'Deskripsi wajib diisi' : null,
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
