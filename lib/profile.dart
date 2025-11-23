import 'package:flutter/material.dart';
import 'package:marketplacedesign/api_service.dart';
import 'package:marketplacedesign/login.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _api = ApiService();

  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _usernameCtr = TextEditingController();
  final _contactCtr = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  Map<String, String?> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();

    _nameCtr.addListener(() {
      if (_fieldErrors.containsKey('nama')) setState(() => _fieldErrors.remove('nama'));
    });
    _usernameCtr.addListener(() {
      if (_fieldErrors.containsKey('username')) setState(() => _fieldErrors.remove('username'));
    });
    _contactCtr.addListener(() {
      if (_fieldErrors.containsKey('kontak') || _fieldErrors.containsKey('contact')) {
        setState(() {
          _fieldErrors.remove('kontak');
          _fieldErrors.remove('contact');
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _usernameCtr.dispose();
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

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _fieldErrors.clear();
    });

    try {
      final res = await _api.getProfile();
      if (res is Map && res.containsKey('data')) {
        final data = res['data'];
        if (data is Map) _applyProfileData(Map<String, dynamic>.from(data));
      } else if (res is Map && res.containsKey('user')) {
        final data = res['user'];
        if (data is Map) _applyProfileData(Map<String, dynamic>.from(data));
      } else if (res is Map) {
        _applyProfileData(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat profil: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfileData(Map<String, dynamic> data) {
    _nameCtr.text = (data['name'] ?? data['nama'] ?? data['nama_lengkap'] ?? '').toString();
    _usernameCtr.text = (data['username'] ?? data['user_name'] ?? '').toString();
    _contactCtr.text = (data['contact'] ?? data['no_hp'] ?? data['kontak'] ?? data['telepon'] ?? '').toString();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final token = await _api.getToken();
    debugPrint('DEBUG: token before updateProfile -> $token');

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token tidak ditemukan. Silakan login ulang.')),
        );
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
      }
      setState(() => _saving = false);
      return;
    }

    final body = <String, dynamic>{
      'nama': _nameCtr.text.trim(),
      'username': _usernameCtr.text.trim(),
      'kontak': _contactCtr.text.trim(),
    };

    try {
      await _api.updateProfile(body);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui')));
        await _loadProfile();
      }
    } catch (e) {
      String message = 'Gagal memperbarui profil: $e';
      try {
        if (e is ApiException) {
          if (e.message != null && e.message.isNotEmpty) message = e.message;
          if (e.errors != null) {
            final Map<String, String?> mapped = {};
            try {
              final errorsMap = Map<String, dynamic>.from(e.errors as Map);
              errorsMap.forEach((key, value) {
                if (value is List) {
                  mapped[key.toString()] = value.join(' ');
                } else {
                  mapped[key.toString()] = value?.toString();
                }
              });
            } catch (_) {
              mapped['error'] = e.errors.toString();
            }
            setState(() => _fieldErrors = mapped);
          }
        }
      } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      try {
        await _api.logout();
      } catch (_) {
        await _api.removeToken();
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildAvatar() {
    final name = _nameCtr.text.trim();
    final initials =
        name.isNotEmpty ? name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase() : 'U';
    return CircleAvatar(
      radius: 44,
      backgroundColor: Colors.white12,
      child: Text(initials, style: const TextStyle(fontSize: 28, color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Profil', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildAvatar(),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtr,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Nama lengkap', Icons.person, errorText: _fieldErrors['nama']),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan nama' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _usernameCtr,
                              style: const TextStyle(color: Colors.white),
                              decoration:
                                  _inputDecoration('Username', Icons.account_circle, errorText: _fieldErrors['username']),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan username' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _contactCtr,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                  'Kontak / WhatsApp', Icons.phone, errorText: _fieldErrors['kontak'] ?? _fieldErrors['contact']),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _saveProfile,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                          )
                                        : const Icon(Icons.save, color: Colors.black),
                                    label: const Text('Simpan Perubahan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _logout,
                                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                                    label: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.redAccent),
                                      backgroundColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Perbarui informasi profil Anda.', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
