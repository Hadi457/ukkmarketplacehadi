// lib/pages/my_store_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplacedesign/api_service.dart';

class MyStorePage extends StatefulWidget {
  const MyStorePage({super.key});

  @override
  State<MyStorePage> createState() => _MyStorePageState();
}

class _MyStorePageState extends State<MyStorePage> {
  final ApiService _api = ApiService();

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _loading = true; // load existing store
  bool _saving = false;
  File? _logoFile;
  String? _logoPreviewUrl;
  int? _storeId; // jika edit, id toko akan diset

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _waCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getStores();
      if (res == null) {
        _clearForm();
      } else if (res is Map && res.containsKey('data')) {
        final data = res['data'];
        if (data is List && data.isNotEmpty) {
          _applyStoreData(data.first);
        } else if (data is Map) {
          _applyStoreData(data);
        } else {
          _clearForm();
        }
      } else if (res is List && res.isNotEmpty) {
        _applyStoreData(res.first);
      } else if (res is Map && res.containsKey('store')) {
        _applyStoreData(res['store']);
      } else {
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat toko: $e')));
      }
      _clearForm();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyStoreData(dynamic s) {
    if (s is Map) {
      final idVal = (s['id'] ?? s['id_toko'] ?? s['id_store']);
      _storeId = (idVal is int) ? idVal : (int.tryParse(idVal?.toString() ?? '') ?? null);
      _nameCtrl.text = (s['nama_toko'] ?? s['name'] ?? s['nama'])?.toString() ?? '';
      _descCtrl.text = (s['deskripsi'] ?? s['description'])?.toString() ?? '';
      _waCtrl.text = (s['kontak_toko'] ?? s['kontak'] ?? s['contact'])?.toString() ?? '';
      _addressCtrl.text = (s['alamat'] ?? s['address'])?.toString() ?? '';
      final logoUrl = (s['logo'] ?? s['gambar'] ?? s['image'])?.toString();
      setState(() {
        _logoPreviewUrl = (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null;
        _logoFile = null; // prefer network preview unless user picks new file
      });
    }
  }

  void _clearForm() {
    setState(() {
      _storeId = null;
      _nameCtrl.text = '';
      _descCtrl.text = '';
      _waCtrl.text = '';
      _addressCtrl.text = '';
      _logoFile = null;
      _logoPreviewUrl = null;
    });
  }

  Future<void> _pickLogo(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
      if (xfile != null) {
        setState(() {
          _logoFile = File(xfile.path);
          _logoPreviewUrl = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih logo: $e')));
    }
  }

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final fields = <String, String>{
      'nama_toko': _nameCtrl.text.trim(),
      'deskripsi': _descCtrl.text.trim(),
      'kontak_toko': _waCtrl.text.trim(),
      'alamat': _addressCtrl.text.trim(),
    };
    if (_storeId != null) fields['id'] = _storeId.toString();

    try {
      await _api.saveStore(fields: fields, imageFile: _logoFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toko berhasil disimpan')));
        await _loadStore();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan toko: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada toko untuk dihapus')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Toko'),
        content: const Text('Apakah kamu yakin ingin menghapus toko ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await _deleteStore();
  }

  Future<void> _deleteStore() async {
    if (_storeId == null) return;
    setState(() => _saving = true);
    try {
      await _api.deleteStore(_storeId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toko dihapus')));
        _clearForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus toko: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildLogoPreview() {
    final double size = 110;
    if (_logoFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(_logoFile!, width: size, height: size, fit: BoxFit.cover),
      );
    } else if (_logoPreviewUrl != null && _logoPreviewUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _logoPreviewUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.white10,
            child: const Icon(Icons.store, size: 48, color: Colors.white24),
          ),
        ),
      );
    } else {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.store, size: 48, color: Colors.white24),
      );
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint, String? errorText, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
      filled: true,
      fillColor: Colors.white10,
      errorText: errorText,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('My Store', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStore,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildLogoPreview(),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _nameCtrl,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: _inputDecoration('Nama Toko', icon: Icons.store),
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan nama toko' : null,
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () async {
                                          final chosen = await showModalBottomSheet<ImageSource>(
                                            context: context,
                                            backgroundColor: Colors.black,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                            ),
                                            builder: (ctx) => SafeArea(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ListTile(
                                                    leading: const Icon(Icons.photo_library, color: Colors.white),
                                                    title: const Text('Pilih dari Galeri', style: TextStyle(color: Colors.white)),
                                                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(Icons.camera_alt, color: Colors.white),
                                                    title: const Text('Ambil foto', style: TextStyle(color: Colors.white)),
                                                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            ),
                                          );
                                          if (chosen != null) await _pickLogo(chosen);
                                        },
                                        icon: const Icon(Icons.photo_camera, color: Colors.white),
                                        label: const Text('Pilih / Ubah Logo', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Deskripsi', icon: Icons.description),
                              minLines: 2,
                              maxLines: 5,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan deskripsi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _waCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Nomor WhatsApp (contoh: 628123456789)', icon: Icons.phone),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Alamat', icon: Icons.location_on),
                              minLines: 1,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _saveStore,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                          )
                                        : const Icon(Icons.save, color: Colors.black),
                                    label: Text(
                                      _storeId == null ? 'Buat Toko' : 'Simpan Perubahan',
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                if (_storeId != null)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _saving ? null : _confirmDelete,
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      label: const Text('Hapus Toko', style: TextStyle(color: Colors.redAccent)),
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
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Tips', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(height: 8),
                            Text('- Isi nomor WhatsApp dalam format internasional (contoh: 628123456789).', style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 6),
                            Text('- Logo disarankan berukuran persegi agar tampil rapi.', style: TextStyle(color: Colors.white70)),
                          ],
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
