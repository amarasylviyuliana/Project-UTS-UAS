import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../config/app_config.dart';
import '../widgets/skeleton_loading.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            LoginScreen.routeName,
            (r) => false,
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = auth.user?.role.toLowerCase() ?? '';
    if (role == 'seller') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/store-dashboard');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (role == 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = <Widget>[
      const HomeTab(),
      const SearchTab(),
      const CartScreen(),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];

    final menuLabels = [
      'Beranda',
      'Pencarian',
      'Keranjang',
      'Pesanan',
      'Profil',
    ];
    final menuIcons = [
      Icons.home_outlined,
      Icons.search_outlined,
      Icons.shopping_cart_outlined,
      Icons.receipt_long_outlined,
      Icons.person_outline,
    ];
    final menuIconsFilled = [
      Icons.home,
      Icons.search,
      Icons.shopping_cart,
      Icons.receipt_long,
      Icons.person,
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;
    final isCompact = screenWidth < 360;
    final isTablet = screenWidth >= 600;
    final navHeight = isCompact
        ? 72.0
        : isNarrow
        ? 76.0
        : 82.0;
    final labelFontSize = isCompact
        ? 10.5
        : isTablet
        ? 11.5
        : 12.0;
    final iconSize = isCompact
        ? 21.5
        : isTablet
        ? 24.0
        : 23.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        // If the user is on a secondary bottom tab (pencarian, keranjang,
        // pesanan, profil), treat back press as "go to dashboard" by
        // switching to the main tab (index 0).
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }

        final now = DateTime.now();
        final isSecondPress =
            _lastBackPressTime != null &&
            now.difference(_lastBackPressTime!) < const Duration(seconds: 2);
        if (isSecondPress) {
          SystemNavigator.pop();
        } else {
          _lastBackPressTime = now;
          // Intentional: removed the visible "Tekan sekali lagi" SnackBar
          // so back press won't show a snackbar. Behavior remains double
          // press to exit but without the notification.
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        // Pindahkan header AppBar ke SliverAppBar supaya ikut digulung
        // bersama isi halaman. NestedScrollView akan mengkoordinasikan
        // scroll header dan body sehingga header tidak lagi tetap.
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: const Color(0xFF1B5E20),
              elevation: 0,
              pinned: false,
              floating: false,
              snap: false,
              toolbarHeight: isNarrow ? 60 : 68,
              titleSpacing: 16,
              automaticallyImplyLeading: false,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset(
                      'assets/logo.jpeg',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.eco, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'BUMDES JABAR',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          body: pages[_selectedIndex],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: const Color(0xFFF8FBF9),
              surfaceTintColor: Colors.white,
              indicatorColor: const Color(0xFF2A7F41).withValues(alpha: 0.14),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.06),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.2,
                  color: isSelected
                      ? const Color(0xFF2A7F41)
                      : const Color(0xFF64748B),
                  letterSpacing: 0.1,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: iconSize,
                  color: isSelected
                      ? const Color(0xFF2A7F41)
                      : const Color(0xFF64748B),
                );
              }),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact
                    ? 8
                    : isTablet
                    ? 16
                    : 20,
                vertical: isCompact ? 6 : 8,
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                height: navHeight,
                elevation: 2,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (int i = 0; i < menuLabels.length; i++)
                    NavigationDestination(
                      icon: Icon(menuIcons[i]),
                      selectedIcon: Icon(menuIconsFilled[i]),
                      label: menuLabels[i],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ProductProvider>(context, listen: false).refresh();
      }
    });
  }

  // TAMBAHAN: buka aplikasi email default dengan alamat sudah terisi.
  Future<void> _openEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka aplikasi email')),
      );
    }
  }

  // TAMBAHAN: buka Google Maps dengan query lokasi.
  Future<void> _openMaps(String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka peta')));
    }
  }

  Widget _buildHeroText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BUMDES_JABAR',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Koperasi Umat Berdaulat',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white60,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Adalah aplikasi penyokong usaha pada tiap desa yang mana menjual dan memasarkan produk barang atau jasa unggulan di desanya.',
          style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildHeroIllustration() {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageSize = constraints.maxWidth < 360 ? 150.0 : 180.0;
                return Image.asset(
                  'assets/logo.jpeg',
                  height: imageSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.eco,
                        size: 72,
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'BUMDES JABAR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Text(
                        'Koperasi Umat Berdaulat',
                        style: TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Cari produk, toko, desa...',
          hintStyle: const TextStyle(color: Colors.black45),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5E20)),
          suffixIcon: IconButton(
            tooltip: 'Filter kategori',
            icon: const Icon(Icons.filter_list, color: Color(0xFF1B5E20)),
            onPressed: () => _showFilterSheet(context, provider),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          provider.search(value);
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, ProductProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const Text(
                    'Filter Kategori',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.categories.map((category) {
                      final selected = provider.selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        selectedColor: const Color(0xFF1B5E20),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          provider.filterByCategory(category);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  // ── FIX: sebelumnya childAspectRatio dipatok angka tetap (0.56) yang
  // dihitung berdasarkan asumsi card sempit (2-3 kolom). Padahal gambar
  // produk pakai AspectRatio 1 (kotak, ikut lebar card), sedangkan tinggi
  // area teks di bawahnya (nama, toko, harga, badge stok) itu TETAP dalam
  // pixel berapapun lebar card-nya. Akibatnya, di layar lebar (4-5 kolom),
  // card jadi lebar → gambar kotaknya ikut membesar → tapi teks di
  // bawahnya tetap segitu-segitu saja → sisa ruang di bawah jadi kosong
  // putih panjang (persis yang di-screenshot).
  //
  // Sekarang aspect ratio dihitung ULANG tiap kali lebar layar berubah:
  // cellHeight = cellWidth (untuk gambar kotak) + tinggi area teks yang
  // konsisten (textAreaHeight), lalu aspectRatio = cellWidth / cellHeight.
  // Dengan begini, berapapun jumlah kolomnya, tinggi card selalu pas
  // mengikuti isinya — tidak ada lagi ruang kosong di bawah.
  Widget _buildProductGrid(List<ProductModel> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 2;
        if (width >= 1100) {
          crossAxisCount = 5;
        } else if (width >= 800) {
          crossAxisCount = 4;
        } else if (width >= 550) {
          crossAxisCount = 3;
        }
        const spacing = 14.0;
        // Perkiraan tinggi area teks di bawah gambar: padding(16) +
        // nama 2 baris (~33) + nama toko (~16) + baris harga (~20) +
        // badge stok (~20) + sedikit slack (~15).
        const textAreaHeight = 120.0;
        final cellWidth =
            (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
        final cellHeight = cellWidth + textAreaHeight;
        final aspectRatio = cellWidth / cellHeight;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) =>
              ProductCard(product: products[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth < 550
                      ? 16.0
                      : 24.0;
                  if (constraints.maxWidth > 900) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: horizontalPadding,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildHeroText()),
                          const SizedBox(width: 32),
                          Expanded(child: _buildHeroIllustration()),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroText(),
                        const SizedBox(height: 24),
                        _buildHeroIllustration(),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSearchBar(context),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSectionHeader('Produk Unggulan'),
            ),
            const SizedBox(height: 16),

            if (provider.isLoading)
              const ProductRowSkeleton()
            else if (provider.featured.isEmpty)
              const SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Belum ada produk tersedia',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              SizedBox(
                height: 350,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.featured.length,
                  itemBuilder: (context, index) {
                    final product = provider.featured[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: SizedBox(
                        width: 220,
                        child: ProductCard(product: product),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Semua Produk'),
                  if (provider.isUsingSampleData)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Contoh data',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (provider.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(
                    4,
                    (_) => const ProductCardSkeleton(width: 220),
                  ),
                ),
              )
            else if (provider.products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Belum ada produk',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildProductGrid(provider.products),
              ),

            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              color: const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo.jpeg',
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.eco,
                          color: Colors.white70,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BUMDES JABAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Koperasi Umat Berdaulat',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24, thickness: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Marketplace Produk & Jasa Unggulan Desa di Jawa Barat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 8,
                    children: [
                      InkWell(
                        onTap: () => _openMaps('Jawa Barat, Indonesia'),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.white70,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Jawa Barat, Indonesia',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _openEmail('bumdesjabar5@gmail.com'),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.email,
                                color: Colors.white70,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'bumdesjabar5@gmail.com',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24, thickness: 1),
                  const SizedBox(height: 12),
                  const Text(
                    '© 2026 BUMDES Jabar — Koperasi Umat Berdaulat. Hak cipta dilindungi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
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

// ─── SEARCH TAB ──────────────────────────────────────────────────────────────

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari produk, toko, desa...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          provider.search('');
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white70),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.white70,
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (value) {
                provider.search(value);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: provider.categories
                    .map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            category,
                            style: TextStyle(
                              color: provider.selectedCategory == category
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 12,
                              fontWeight: provider.selectedCategory == category
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFF1B5E20),
                          selected: provider.selectedCategory == category,
                          side: BorderSide(
                            color: provider.selectedCategory == category
                                ? Colors.transparent
                                : Colors.white,
                          ),
                          onSelected: (_) =>
                              provider.filterByCategory(category),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              '${provider.products.length} produk ditemukan',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),

            // ── FIX: sama seperti grid di HomeTab, aspect ratio card di
            // hasil pencarian sekarang juga dihitung dinamis mengikuti
            // lebar card sesungguhnya, supaya tidak ada ruang kosong
            // putih di bawah badge stok.
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.products.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.white30,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Tidak ada produk yang cocok',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        int crossAxisCount = 2;
                        if (width >= 1100) {
                          crossAxisCount = 5;
                        } else if (width >= 800) {
                          crossAxisCount = 4;
                        } else if (width >= 550) {
                          crossAxisCount = 3;
                        }
                        const spacing = 14.0;
                        const textAreaHeight = 120.0;
                        final cellWidth =
                            (width - spacing * (crossAxisCount - 1)) /
                            crossAxisCount;
                        final cellHeight = cellWidth + textAreaHeight;
                        final aspectRatio = cellWidth / cellHeight;
                        return GridView.builder(
                          itemCount: provider.products.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: spacing,
                                crossAxisSpacing: spacing,
                                childAspectRatio: aspectRatio,
                              ),
                          itemBuilder: (context, index) =>
                              ProductCard(product: provider.products[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PRODUCT CARD ─────────────────────────────────────────────────────────────

class ProductCard extends StatelessWidget {
  final ProductModel product;
  const ProductCard({required this.product, super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: produk jasa (isService == true) tidak punya konsep "stok"
    // dalam arti barang, jadi label & maknanya diganti jadi
    // "Tersedia" / "Tidak Tersedia" alih-alih "Stok X" / "Stok Habis".
    final stockLabel = product.isService
        ? (product.stock > 0 ? 'Tersedia' : 'Tidak Tersedia')
        : (product.stock == 0 ? 'Stok Habis' : 'Stok ${product.stock}');
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/product-detail',
        arguments: {'product': product},
      ),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 32,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 32,
                      ),
                    ),
            ),
            // ── FIX: bungkus dengan Expanded (bukan Flexible +
            // mainAxisSize.min) supaya area teks selalu mengisi sisa
            // tinggi card, dan mainAxisAlignment.spaceBetween menyebar
            // konten secara merata dari atas (nama/toko) sampai bawah
            // (badge stok) — jadi kalaupun ada sisa ruang, terisi rapi,
            // bukan menumpuk jadi blok putih kosong di paling bawah.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.storeName,
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Text(
                      'Rp ${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1B5E20),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: product.stock == 0
                            ? Colors.red.withAlpha(20)
                            : Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stockLabel,
                        style: TextStyle(
                          color: product.stock == 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MISC WIDGETS ─────────────────────────────────────────────────────────────

class CategoryChip extends StatelessWidget {
  final String label;
  const CategoryChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const FeatureTile({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.02),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.15),
              child: Icon(icon, color: const Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class ChoicePill extends StatelessWidget {
  final String label;
  const ChoicePill({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    final selected = provider.selectedCategory == label;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: selected,
      onSelected: (_) => provider.filterByCategory(label),
    );
  }
} 