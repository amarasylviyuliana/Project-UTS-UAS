import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'bumdes_detail_screen.dart';

const Color _kPrimaryGreen = Color(0xFF2D5016);
const Color _kBg = Color(0xFFFAFAFA);

class ProductDetailScreen extends StatefulWidget {
  static const routeName = '/product-detail';
  final ProductModel? product;
  const ProductDetailScreen({super.key, this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Produk')),
        body: const Center(child: Text('Produk tidak ditemukan')),
      );
    }
    final cart = Provider.of<CartProvider>(context, listen: false);

    // FIX BUG "Tidak Tersedia"/"Stok Habis" padahal di dashboard penjual
    // "Tersedia": sebelumnya ketersediaan di halaman detail ini SELALU
    // dihitung dari `product.stock` (stock > 0 => tersedia), termasuk
    // untuk Jasa. Padahal dashboard penjual & kartu produk (ProductCard)
    // menentukan status Jasa dari field `is_active`, bukan dari stock.
    // Untuk Jasa lama yang stock-nya masih 0 di database, dua sisi jadi
    // tidak sinkron: penjual bilang "Tersedia" (is_active = true) tapi
    // halaman ini bilang "Stok Habis" (stock = 0).
    //
    // Sekarang untuk Jasa, ketersediaan SELALU dibaca dari
    // `product.isActive` (sama seperti ProductCard & dashboard penjual).
    // Stock cuma tetap relevan untuk Produk fisik.
    final available = product.isService ? product.isActive : product.stock > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _kPrimaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, HomeScreen.routeName),
            icon: const Icon(Icons.home_outlined, color: Colors.white),
            tooltip: 'Beranda',
          ),
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, HomeScreen.routeName),
            icon: const Icon(Icons.search_outlined, color: Colors.white),
            tooltip: 'Pencarian',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, CartScreen.routeName),
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            tooltip: 'Keranjang',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, OrderHistoryScreen.routeName),
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
            tooltip: 'Pesanan',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, ProfileScreen.routeName),
            icon: const Icon(Icons.person_outline, color: Colors.white),
            tooltip: 'Profil',
          ),
        ],
      ),
      backgroundColor: _kBg,
      body: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final content = isWide
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildImageSection(product, available)),
                        const SizedBox(width: 32),
                        Expanded(flex: 5, child: _buildDetailSection(product, available, cart, isWide)),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageSection(product, available),
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: _buildDetailSection(product, available, cart, isWide),
                      ),
                    ],
                  );
            return isWide
                ? content
                : Padding(padding: const EdgeInsets.only(bottom: 90), child: content);
          },
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) return const SizedBox.shrink();
          return _buildStickyBuyBar(product, available, cart);
        },
      ),
    );
  }

  Widget _buildImageSection(ProductModel product, bool available) {
    // TAMBAHAN: label badge sekarang dibedakan antara Jasa dan Produk
    // fisik, sama seperti stockLabel di ProductCard. Jasa memakai
    // "Tersedia"/"Tidak Tersedia", Produk fisik tetap memakai info stok.
    final badgeLabel = product.isService
        ? (available ? 'Tersedia' : 'Tidak Tersedia')
        : (available ? 'Stok tersedia: ${product.stock}' : 'Stok Habis');

    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Image.network(
            product.imageUrl,
            height: 340,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 340,
                color: const Color(0xFFE8F5E9),
                child: const Center(child: CircularProgressIndicator(color: _kPrimaryGreen)),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              height: 340,
              color: const Color(0xFFE8F5E9),
              child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 64, color: _kPrimaryGreen)),
            ),
          ),
          // gradient overlay so text/badges are readable over any photo
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.35)],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: available ? _kPrimaryGreen : Colors.red[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FIX: kartu toko sekarang benar-benar bisa diklik dan membuka halaman
  // BumdesDetailScreen milik BUMDes tersebut. Sebelumnya ikon panah
  // (chevron_right) di kartu ini cuma dekorasi, tidak dibungkus
  // GestureDetector/InkWell apa pun.
  //
  // ProductModel sudah punya storeId (id BUMDes pemilik produk ini), jadi
  // kita bisa langsung buat objek StoreModel "ringan" dari data yang sudah
  // ada di produk (nama toko, foto, lokasi) tanpa perlu request tambahan
  // ke server — BumdesDetailScreen sendiri yang nanti mengambil daftar
  // produk BUMDes ini dari API begitu halaman dibuka.
  void _goToStore(BuildContext context, ProductModel product) {
    if (product.storeId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BumdesDetailScreen(
          store: StoreModel(
            id: product.storeId!,
            storeName: product.storeName,
            village: product.location,
            storePhotoUrl: product.storePhotoUrl,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreCard(ProductModel product) {
    const double avatarSize = 48;
    final hasPhoto = product.storePhotoUrl != null && product.storePhotoUrl!.isNotEmpty;
    final canNavigate = product.storeId != null;

    Widget avatar;
    if (hasPhoto) {
      avatar = ClipOval(
        child: Image.network(
          product.storePhotoUrl!,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            width: avatarSize,
            height: avatarSize,
            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Icon(Icons.store, color: _kPrimaryGreen),
          ),
        ),
      );
    } else {
      avatar = Container(
        width: avatarSize,
        height: avatarSize,
        decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
        child: const Icon(Icons.store, color: _kPrimaryGreen),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: canNavigate ? () => _goToStore(context, product) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAF6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimaryGreen.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.storeName.isNotEmpty ? product.storeName : 'Toko tidak diketahui',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kPrimaryGreen),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.location,
                            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (canNavigate) const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(ProductModel product, bool available, CartProvider cart, bool isWide) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isWide ? 0 : 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.25),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Rp ${product.price.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _kPrimaryGreen),
              ),
              if (product.isService) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Jasa', style: TextStyle(fontSize: 12, color: _kPrimaryGreen, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _buildStoreCard(product),
          const SizedBox(height: 22),
          const Text('Deskripsi Produk', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            product.description,
            style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
          ),
          if (!product.isService && available) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                const Text('Jumlah', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                _QuantitySelector(
                  initialValue: _quantity,
                  maxValue: product.stock,
                  onChanged: (value) => setState(() => _quantity = value),
                ),
              ],
            ),
          ],
          if (isWide) ...[
            const SizedBox(height: 28),
            _buildActionButtons(product, available, cart),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(ProductModel product, bool available, CartProvider cart) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: available
                ? () {
                    cart.addProduct(product, _quantity);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Produk ditambahkan ke keranjang')),
                    );
                  }
                : null,
            icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
            label: const Text('Keranjang'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: _kPrimaryGreen),
              foregroundColor: _kPrimaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: available
                ? () {
                    cart.addProduct(product, _quantity);
                    Navigator.pushNamed(context, CartScreen.routeName);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _kPrimaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Pesan Sekarang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBuyBar(ProductModel product, bool available, CartProvider cart) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: _buildActionButtons(product, available, cart),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int initialValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const _QuantitySelector({required this.initialValue, required this.maxValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final value = initialValue;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text('$value', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: value < maxValue ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}