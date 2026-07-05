import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'services/api_service.dart';
import 'models/order_model.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/store_dashboard_screen.dart';
import 'screens/store_form_screen.dart';
import 'screens/seller_orders_screen.dart';
import 'screens/seller_wallet_screen.dart';
import 'screens/admin_wallet_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/security_screen.dart';
import 'screens/help_screen.dart';
import 'screens/about_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/financial_report_detail_screen.dart';
import 'screens/order_tracking_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// FIX: navigatorKey global — dipakai supaya kalau token expired/invalid
// (401) di manapun dalam aplikasi, kita bisa langsung arahkan user ke
// halaman Login tanpa perlu BuildContext dari layar yang sedang aktif.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class BumdesApp extends StatelessWidget {
  const BumdesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: begitu server balas 401 (token expired/invalid) dari request
    // manapun, otomatis logout + balik ke Login — user tidak nyangkut
    // lihat pesan error teknis di tengah pemakaian.
    ApiService.onUnauthorized = () {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        Provider.of<AuthProvider>(ctx, listen: false).logout();
      }
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(LoginScreen.routeName, (r) => false);
    };

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'BUMDes Jabar',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          scaffoldBackgroundColor: Colors.grey[50],
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        initialRoute: SplashScreen.routeName,
        navigatorObservers: [routeObserver],
        routes: {
          SplashScreen.routeName: (_) => const SplashScreen(),
          LoginScreen.routeName: (_) => const LoginScreen(),
          RegisterScreen.routeName: (_) => const RegisterScreen(),
          HomeScreen.routeName: (_) => const HomeScreen(),
          CartScreen.routeName: (_) => const CartScreen(),
          OrderHistoryScreen.routeName: (_) => const OrderHistoryScreen(),
          ProfileScreen.routeName: (_) => const ProfileScreen(),
          StoreDashboardScreen.routeName: (_) => const StoreDashboardScreen(),
          EditProfileScreen.routeName: (_) => const EditProfileScreen(),
          SettingsScreen.routeName: (_) => const SettingsScreen(),
          SecurityScreen.routeName: (_) => const SecurityScreen(),
          HelpScreen.routeName: (_) => const HelpScreen(),
          AboutScreen.routeName: (_) => const AboutScreen(),
          AdminDashboardScreen.routeName: (_) => const AdminDashboardScreen(),
          ProductFormScreen.routeName: (_) => const ProductFormScreen(),
          StoreFormScreen.routeName: (_) => const StoreFormScreen(),
          SellerOrdersScreen.routeName: (_) => const SellerOrdersScreen(),
          SellerWalletScreen.routeName: (_) => const SellerWalletScreen(),
          AdminWalletScreen.routeName: (_) => const AdminWalletScreen(),
          FinancialReportDetailScreen.routeName: (_) =>
              const FinancialReportDetailScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == ProductDetailScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: args?['product']),
            );
          }
          if (settings.name == OrderTrackingScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>?;
            final order = args?['order'] as OrderModel?;
            if (order != null) {
              return MaterialPageRoute(
                builder: (_) => OrderTrackingScreen(order: order),
              );
            }
          }

          if (settings.name != null) {
            final uri = Uri.parse(settings.name!);
            final rawFragment = uri.fragment;
            final routeUri = rawFragment.isNotEmpty
                ? Uri.parse(rawFragment)
                : uri;

            // Support deep link to order detail using either:
            // - full path `/order-detail?orderId=...`
            // - hash route `/#/order-detail?orderId=...`
            // - short redirect `/?orderId=...`
            if (routeUri.path == OrderDetailScreen.routeName ||
                (routeUri.path == '/' &&
                    (routeUri.queryParameters['orderId'] != null ||
                        uri.queryParameters['orderId'] != null))) {
              final args = settings.arguments as Map<String, dynamic>?;
              final order = args?['order'] as OrderModel?;
              final orderId = int.tryParse(
                routeUri.queryParameters['orderId'] ??
                    uri.queryParameters['orderId'] ??
                    '',
              );
              return MaterialPageRoute(
                builder: (_) =>
                    OrderDetailScreen(order: order, orderId: orderId),
              );
            }
          }
          return null;
        },
      ),
    );
  }
}