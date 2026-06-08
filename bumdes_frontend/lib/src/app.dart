import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
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
import 'screens/edit_profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/security_screen.dart';
import 'screens/help_screen.dart';
import 'screens/about_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/financial_report_detail_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class BumdesApp extends StatelessWidget {
  const BumdesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
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
          FinancialReportDetailScreen.routeName: (_) => const FinancialReportDetailScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == ProductDetailScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: args?['product']),
            );
          }
          if (settings.name != null) {
            final uri = Uri.parse(settings.name!);

            // Support deep link to order detail using full path `/order-detail?orderId=...`
            // or short redirect from payment gateway like `/?orderId=...`.
            if (uri.path == OrderDetailScreen.routeName ||
                (uri.path == '/' && uri.queryParameters['orderId'] != null)) {
              final args = settings.arguments as Map<String, dynamic>?;
              final order = args?['order'] as OrderModel?;
              final orderId = int.tryParse(uri.queryParameters['orderId'] ?? '');
              return MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: order, orderId: orderId),
              );
            }
          }
          return null;
        },
      ),
    );
  }
}
