import 'package:flutter/material.dart';
import 'package:marketplacedesign/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _usernameCtr = TextEditingController();
  final _passwordCtr = TextEditingController();
  final _contactCtr = TextEditingController();
  bool _loading = false;
  final ApiService _api = ApiService();

  // map untuk menyimpan pesan error per field (key sesuai nama field server)
  Map<String, String?> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    // clear field-specific error saat user mengetik
    _nameCtr.addListener(() {
      if (_fieldErrors.containsKey('nama')) setState(() => _fieldErrors.remove('nama'));
    });
    _usernameCtr.addListener(() {
      if (_fieldErrors.containsKey('username')) setState(() => _fieldErrors.remove('username'));
    });
    _passwordCtr.addListener(() {
      if (_fieldErrors.containsKey('password')) setState(() => _fieldErrors.remove('password'));
    });
    _contactCtr.addListener(() {
      if (_fieldErrors.containsKey('kontak') || _fieldErrors.containsKey('contact')) setState(() {
        _fieldErrors.remove('kontak');
        _fieldErrors.remove('contact');
      });
    });
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _usernameCtr.dispose();
    _passwordCtr.dispose();
    _contactCtr.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white10,
      errorText: errorText,
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

  Future<void> _register() async {
    // reset previous field errors
    setState(() => _fieldErrors.clear());

    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await _api.register(
        name: _nameCtr.text.trim(),
        username: _usernameCtr.text.trim(),
        password: _passwordCtr.text,
        contact: _contactCtr.text.trim().isEmpty ? null : _contactCtr.text.trim(),
      );

      // sukses
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registrasi berhasil. Silakan login.')));
        Navigator.pop(context);
      }
    } catch (e) {
      String message = 'Register error: $e';

      // Gunakan tipe ApiException yang didefinisikan di ApiService (jika ada)
      if (e is ApiException) {
        // pakai message dari ApiException jika tersedia
        if (e.message != null && e.message.isNotEmpty) {
          message = e.message;
        }

        // mapping field-specific errors (jika server mengembalikan errors)
        if (e.errors != null) {
          final Map<String, String?> mapped = {};
          try {
            // e.errors diasumsikan Map<String, dynamic> atau Map
            final errorsMap = Map<String, dynamic>.from(e.errors as Map);
            errorsMap.forEach((key, value) {
              // value bisa List atau String atau lainnya
              if (value is List) {
                mapped[key.toString()] = value.join(' ');
              } else {
                mapped[key.toString()] = value?.toString();
              }
            });
          } catch (_) {
            // fallback: coba konversi sederhana
            try {
              mapped.addAll({'error': e.errors.toString()});
            } catch (_) {}
          }
          setState(() => _fieldErrors = mapped);
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Register gagal'),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Register', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // header/brand
                  Container(
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.storefront_rounded, size: 40, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Marketplace', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

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
                            controller: _nameCtr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Nama', Icons.person, errorText: _fieldErrors['nama']),
                            validator: (v) => v == null || v.isEmpty ? 'Masukkan nama' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _usernameCtr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Username', Icons.account_circle, errorText: _fieldErrors['username']),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Masukkan username';
                              if (v.trim().length < 6) return 'Username minimal 6 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Password', Icons.lock, errorText: _fieldErrors['password']),
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Masukkan password';
                              if (v.length < 6) return 'Password minimal 6 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _contactCtr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Kontak (opsional)', Icons.phone, errorText: _fieldErrors['kontak'] ?? _fieldErrors['contact']),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white, // putih
                                foregroundColor: Colors.black, // teks gelap
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              child: _loading
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : const Text('Daftar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Center(child: Text('Isi data untuk membuat akun', style: TextStyle(color: Colors.white54))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
