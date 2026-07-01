import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'store_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadToken();
    if (!mounted) return;
    setState(() => _isCheckingAuth = false);

    if (authProvider.isAuthenticated) {
      _continueToApp();
    }
  }

  void _continueToApp() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      return;
    }

    // FIX: Kalau di web, cek URL fragment dulu
    // Ini supaya refresh di /store-dashboard → tetap di store-dashboard
    if (kIsWeb) {
      final uri = Uri.base;
      final fragment = uri.fragment; // bagian setelah #

      // Kalau ada fragment yang valid (bukan splash/root), redirect ke sana
      if (fragment.isNotEmpty &&
          fragment != '/' &&
          fragment != '/splash' &&
          !fragment.startsWith('/splash')) {
        final targetRoute = fragment.startsWith('/') ? fragment : '/$fragment';
        // Strip query params dari route name
        final routeName = targetRoute.split('?').first;
        Navigator.pushReplacementNamed(context, routeName);
        return;
      }
    }

    // FIX: Redirect berdasarkan role jika tidak ada fragment
    final role = authProvider.user?.role?.toLowerCase() ?? '';
    if (role == 'seller') {
      Navigator.pushReplacementNamed(context, StoreDashboardScreen.routeName);
    } else if (role == 'admin') {
      Navigator.pushReplacementNamed(context, AdminDashboardScreen.routeName);
    } else {
      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFF8FFF9)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.jpeg',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.eco,
                    size: 100,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('BUMDes Jabar',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20))),
                const SizedBox(height: 8),
                const Text('Marketplace Produk & Jasa Desa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Aplikasi ini dibuat agar para pengusaha desa dapat mempromosikan barang dan jasa unggul di setiap desa di Jawa Barat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isCheckingAuth)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.green),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _continueToApp,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Mulai Jelajahi Aplikasi',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}