import 'package:flutter/material.dart';
import 'package:marketplacedesign/api_service.dart';
import 'package:marketplacedesign/register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtr = TextEditingController();
  final _passwordCtr = TextEditingController();
  bool _loading = false;
  final ApiService _api = ApiService();

  @override
  void dispose() {
    _usernameCtr.dispose();
    _passwordCtr.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final res = await _api.login(
        username: _usernameCtr.text.trim(),
        password: _passwordCtr.text,
      );

      debugPrint('LOGIN response: $res');

      String? token;
      try {
        if (res is Map) {
          if (res.containsKey('token') && res['token'] is String) {
            token = res['token'] as String;
          } else if (res.containsKey('access_token') && res['access_token'] is String) {
            token = res['access_token'] as String;
          } else if (res.containsKey('data') && res['data'] is Map) {
            final d = Map<String, dynamic>.from(res['data'] as Map);
            if (d.containsKey('token') && d['token'] is String) token = d['token'] as String;
            else if (d.containsKey('access_token') && d['access_token'] is String) token = d['access_token'] as String;
            else if (d.containsKey('data') && d['data'] is Map) {
              final dd = Map<String, dynamic>.from(d['data'] as Map);
              if (dd.containsKey('token') && dd['token'] is String) token = dd['token'] as String;
            }
          }
        }
      } catch (e) {
        debugPrint('Token extract error: $e');
      }

      if (token != null && token.isNotEmpty) {
        await _api.saveToken(token);
        debugPrint('Token disimpan dari login(): $token');
      } else {
        final saved = await _api.getToken();
        debugPrint('Token setelah login (shared prefs): $saved');
        if (saved == null || saved.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login gagal: token tidak ditemukan. Cek kredensial atau response server.')));
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login berhasil')));
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white10,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white70, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text('Login', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.storefront_rounded, size: 44, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Marketplace',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameCtr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Username', Icons.person),
                            validator: (v) => v == null || v.isEmpty ? 'Masukkan username' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtr,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Password', Icons.lock),
                            validator: (v) => v == null || v.isEmpty ? 'Masukkan password' : null,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              child: _loading
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Belum punya akun?", style: TextStyle(color: Colors.white70)),
                              TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                child: const Text('Daftar', style: TextStyle(decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text('Masuk untuk mengelola toko dan produk Anda', style: TextStyle(color: Colors.white54)),
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
