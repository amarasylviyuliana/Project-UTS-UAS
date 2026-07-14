import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/store_provider.dart';
import '../providers/auth_provider.dart';
import '../models/store_model.dart';
import 'bumdes_detail_screen.dart';

class BumdesListScreen extends StatefulWidget {
  static const routeName = '/bumdes-list';
  const BumdesListScreen({super.key});

  @override
  State<BumdesListScreen> createState() => _BumdesListScreenState();
}

class _BumdesListScreenState extends State<BumdesListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // FIX: endpoint /stores butuh token — ambil token dari
        // AuthProvider (user yang sedang login) dan set ke StoreProvider
        // sebelum loadStores() dipanggil, supaya request tidak lagi 401.
        final authToken =
            Provider.of<AuthProvider>(context, listen: false).token;
        final storeProvider =
            Provider.of<StoreProvider>(context, listen: false);
        storeProvider.setToken(authToken);
        storeProvider.loadStores();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<StoreProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        title: const Text(
          'BUMDes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari BUMDes...',
                  hintStyle: const TextStyle(color: Colors.black45),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5E20)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                ),
                onChanged: (value) => provider.search(value),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildRegionDropdown(provider),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadStores(),
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    )
                  : provider.stores.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            'Belum ada BUMDes ditemukan',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: provider.stores.length,
                      itemBuilder: (context, index) =>
                          _BumdesCard(store: provider.stores[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionDropdown(StoreProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.regionOptions.contains(provider.selectedRegion)
              ? provider.selectedRegion
              : 'Semua Wilayah',
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1B5E20)),
          style: const TextStyle(
            color: Color(0xFF1B5E20),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: provider.regionOptions
              .map(
                (region) =>
                    DropdownMenuItem(value: region, child: Text(region)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) provider.filterByRegion(value);
          },
        ),
      ),
    );
  }
}

// TAMBAHAN: beberapa pasangan warna gradient yang dipilih otomatis
// berdasarkan nama toko, supaya tiap card BUMDes punya "identitas warna"
// sendiri (tidak semua kartu keliatan sama persis), tanpa bergantung
// pada foto profil kecil yang gampang pecah kalau dipaksa jadi banner
// besar.
const List<List<Color>> _kBannerPalettes = [
  [Color(0xFF1B5E20), Color(0xFF66BB6A)],
  [Color(0xFF2E7D32), Color(0xFF9CCC65)],
  [Color(0xFF00695C), Color(0xFF4DB6AC)],
  [Color(0xFF33691E), Color(0xFFAED581)],
  [Color(0xFF1565C0), Color(0xFF64B5F6)],
  [Color(0xFF4E342E), Color(0xFFA1887F)],
];

List<Color> _bannerColorsFor(String seed) {
  if (seed.isEmpty) return _kBannerPalettes.first;
  final sum = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return _kBannerPalettes[sum % _kBannerPalettes.length];
}

class _BumdesCard extends StatelessWidget {
  final StoreModel store;
  const _BumdesCard({required this.store});

  // TAMBAHAN: fallback huruf awal nama toko, dipakai kalau BUMDes belum
  // punya foto atau fotonya gagal dimuat.
  Widget _buildInitialAvatar() {
    return Container(
      color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        store.storeName.isNotEmpty ? store.storeName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFF1B5E20),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  // FIX TAMPILAN BANNER: sebelumnya banner besar di atas card memakai
  // foto yang SAMA dengan avatar bulat (store.storePhotoUrl). Karena foto
  // itu sering kali cuma foto profil kecil hasil fallback (bukan foto
  // cover toko yang memang didesain untuk ukuran besar), Image.network
  // dengan BoxFit.cover memaksa foto kecil itu di-upscale jadi lebar
  // penuh -> hasilnya pecah/blur.
  //
  // Sekarang banner TIDAK lagi bergantung pada foto sama sekali. Banner
  // memakai gradient dekoratif (warnanya konsisten per toko, dihitung
  // dari nama toko) plus pola ikon transparan di pojok, supaya tetap
  // terlihat "didesain" dan bervariasi antar kartu tanpa risiko foto
  // pecah. Foto profil pemilik toko tetap dipakai di avatar bulat kecil
  // di bawah, karena di ukuran kecil foto itu masih terlihat wajar.
  Widget _buildBanner() {
    final colors = _bannerColorsFor(store.storeName);
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -18,
            top: -22,
            child: Icon(
              Icons.storefront_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            left: -14,
            bottom: -26,
            child: Icon(
              Icons.eco_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BumdesDetailScreen(store: store)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildBanner(),
                Positioned(
                  left: 16,
                  bottom: -28,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    // Avatar bulat: tetap coba tampilkan foto (foto toko
                    // atau fallback foto profil pemilik dari backend),
                    // baru fallback ke huruf inisial kalau memang belum
                    // ada foto atau gagal dimuat. Di ukuran 50x50 ini
                    // foto kecil masih terlihat wajar, tidak pecah.
                    child: ClipOval(
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: store.storePhotoUrl != null
                            ? Image.network(
                                store.storePhotoUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: const Color(
                                      0xFF1B5E20,
                                    ).withValues(alpha: 0.08),
                                  );
                                },
                                errorBuilder: (_, __, ___) =>
                                    _buildInitialAvatar(),
                              )
                            : _buildInitialAvatar(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.storeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.black38),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    store.regionLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (store.categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: store.categories
                          .take(3)
                          .map(
                            (c) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${store.productCount} Produk',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}