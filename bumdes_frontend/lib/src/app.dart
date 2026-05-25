import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/store_dashboard_screen.dart';
import 'screens/splash_screen.dart';

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
        routes: {
          SplashScreen.routeName: (_) => const SplashScreen(),
          LoginScreen.routeName: (_) => const LoginScreen(),
          RegisterScreen.routeName: (_) => const RegisterScreen(),
          HomeScreen.routeName: (_) => const HomeScreen(),
          CartScreen.routeName: (_) => const CartScreen(),
          OrderHistoryScreen.routeName: (_) => const OrderHistoryScreen(),
          ProfileScreen.routeName: (_) => const ProfileScreen(),
          StoreDashboardScreen.routeName: (_) => const StoreDashboardScreen(),
          ProductFormScreen.routeName: (_) => const ProductFormScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == ProductDetailScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: args?['product']),
            );
          }
          if (settings.name == OrderDetailScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: args?['order']),
            );
          }
          if (settings.name == PaymentScreen.routeName) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => PaymentScreen(order: args?['order']),
            );
          }
          return null;
        },
      ),
    );
  }
}
