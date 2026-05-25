import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (success) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk ke BUMDes Jabar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Selamat datang!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Masuk menggunakan email dan password Anda.'),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Email wajib diisi';
                      if (!value.contains('@')) return 'Masukkan email valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Password wajib diisi';
                      if (value.length < 8)
                        return 'Password minimal 8 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      child: auth.isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Masuk'),
                    ),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (auth.infoMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      auth.infoMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                  if (auth.errorMessage != null &&
                      auth.errorMessage!.toLowerCase().contains(
                        'belum dikonfirmasi',
                      )) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                final success = await auth.resendVerification(
                                  _emailController.text.trim(),
                                );
                                if (success && mounted) {
                                  setState(() {});
                                }
                              },
                        child: const Text('Kirim ulang email verifikasi'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Belum punya akun?'),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, RegisterScreen.routeName);
                  },
                  child: const Text('Daftar sekarang'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
