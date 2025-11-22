import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplacedesign/api_service.dart';

// Converted TokoProdukPage: make the "tampilan-baru" behave/look like the
// "tampilan-lama". This file keeps the token parameter (for authenticated
// APIs) and reuses patterns from the older UI: refresh, pagination, categories,
// product form (add/edit), image picker, delete confirmation.

class TokoProdukPage extends StatefulWidget {
  final String token;

  const TokoProdukPage({super.key, required this.token});

  @override
  State<TokoProdukPage> createState() => _TokoProdukPageState();
}

class _TokoProdukPageState extends State<TokoProdukPage> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _refreshing = false;
  List<dynamic> _products = [];
  int _page = 1;
  int _lastPage = 1;

  // categories for dropdown
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      await _loadCategories();
      await _loadProducts(page: 1);
    } catch (e) {
      // if categories fail, still try products
      await _loadProducts(page: 1);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _api.getCategories();
      List<Map<String, dynamic>> cats = [];
      if (res == null) {
        cats = [];
      } else if (res is Map && res.containsKey('data')) {
        final data = res['data'];
        if (data is List) cats = data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (res is List) {
        cats = res.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (res is Map) {
        cats = [Map<String, dynamic>.from(res)];
      }
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      // ignore errors for categories for now
    }
  }

  Future<void> _loadProducts({int page = 1}) async {
    setState(() {
      if (page == 1) _loading = true;
      _refreshing = true;
    });
    try {
      // Use the store-specific API which expects token
      final res = await ApiService.getProdukToko(widget.token);

      // Adapt to multiple shapes: the old API returned { success:true, data: { produk: [...] } }
      List<dynamic> items = [];
      int currentPage = page;
      int lastPage = 1;

      if (res == null) {
        items = [];
      } else if (res is Map && res.containsKey('data')) {
        final data = res['data'];
        if (data is Map && data.containsKey('produk')) {
          items = (data['produk'] is List) ? List.from(data['produk']) : [];
        } else if (data is List) {
          items = List.from(data);
        }

        // try to read pagination if present
        final pagination = res['pagination'] ?? res['meta'] ?? data['pagination'] ?? data['meta'];
        if (pagination is Map) {
          currentPage = (pagination['current_page'] is int) ? pagination['current_page'] : currentPage;
          lastPage = (pagination['last_page'] is int) ? pagination['last_page'] : lastPage;
        }
      } else if (res is List) {
        items = List.from(res);
        currentPage = page;
        lastPage = 1;
      } else {
        items = [];
      }

      if (mounted) {
        setState(() {
          _products = items;
          _page = currentPage;
          _lastPage = lastPage;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat produk: $e')));
      }
    } finally {
      if (mounted) setState(() => {_loading = false, _refreshing = false});
    }
  }

  Future<void> _deleteProduct(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Hapus Produk', style: TextStyle(color: Colors.white)),
        content: const Text('Yakin ingin menghapus produk ini?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // use token-aware delete if available
      final res = await ApiService.hapusProduk(widget.token, id);
      String msg = 'Produk dihapus';
      if (res is Map && res.containsKey('message')) msg = res['message'].toString();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        await _loadProducts(page: 1);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus produk: $e')));
    }
  }

  Future<void> _showProductForm({Map<String, dynamic>? product}) async {
    final isEdit = product != null;
    final _formKey = GlobalKey<FormState>();
    final nameCtr = TextEditingController(text: isEdit ? (product!['nama_produk'] ?? product['name'] ?? '') : '');
    final priceCtr = TextEditingController(text: isEdit ? (product!['harga']?.toString() ?? product['price']?.toString() ?? '') : '');
    final stokCtr = TextEditingController(text: isEdit ? (product!['stok']?.toString() ?? product['stock']?.toString() ?? '') : '');
    final descCtr = TextEditingController(text: isEdit ? (product!['deskripsi'] ?? product['description'] ?? '') : '');

    int? formSelectedCategoryId = isEdit
        ? (product!['id_kategori'] ?? product['category_id'] ?? product['idKategori'] ?? product['kategori_id'])
            ?.toString()
            .isNotEmpty == true
            ? int.tryParse((product['id_kategori'] ?? product['category_id'] ?? product['idKategori'] ?? product['kategori_id']).toString())
            : null
        : null;

    File? _imageFile;
    String? _imagePreviewUrl = isEdit ? (product!['gambar'] ?? product['image'] ?? product['url_image'])?.toString() : null;

    Future<void> _pickImage(ImageSource source) async {
      try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
        if (xfile != null) {
          _imageFile = File(xfile.path);
          _imagePreviewUrl = null;
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }

    bool _saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateSB) {
          Future<void> _save() async {
            if (!_formKey.currentState!.validate()) return;
            setStateSB(() => _saving = true);

            final fields = <String, String>{
              'nama_produk': nameCtr.text.trim(),
              'harga': priceCtr.text.trim(),
              'stok': stokCtr.text.trim(),
              'deskripsi': descCtr.text.trim(),
            };

            if (formSelectedCategoryId != null) fields['id_kategori'] = formSelectedCategoryId.toString();

            if (isEdit) {
              final idVal = product!['id'] ?? product['id_produk'] ?? product['id_product'];
              if (idVal != null) fields['id'] = idVal.toString();
            }

            try {
              // NOTE: adapt these calls to your ApiService signatures. If your
              // ApiService requires token for save, update the methods accordingly.
              if (_imageFile != null) {
                await _api.saveProductMultipart(fields, imageFile: _imageFile);
              } else {
                await _api.saveProductJson(fields);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Produk diperbarui' : 'Produk ditambahkan')));
                Navigator.pop(ctx); // close sheet
                await _loadProducts(page: 1);
              }
            } catch (e) {
              String msg = 'Gagal menyimpan produk: $e';
              if (e is ApiException) msg = e.message;
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            } finally {
              if (mounted) setStateSB(() => _saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(isEdit ? 'Edit Produk' : 'Tambah Produk', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // preview
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                child: _imageFile != null
                                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imageFile!, width: 110, height: 110, fit: BoxFit.cover))
                                    : (_imagePreviewUrl != null && _imagePreviewUrl!.isNotEmpty
                                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_imagePreviewUrl!, width: 110, height: 110, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white24)))
                                        : const Icon(Icons.image, size: 48, color: Colors.white24)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: nameCtr,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: _inputDecoration('Nama Produk'),
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan nama produk' : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await _pickImage(ImageSource.gallery);
                                            setStateSB(() {});
                                          },
                                          icon: const Icon(Icons.photo, color: Colors.black),
                                          label: const Text('Pilih Gambar', style: TextStyle(color: Colors.black)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await _pickImage(ImageSource.camera);
                                            setStateSB(() {});
                                          },
                                          icon: const Icon(Icons.camera_alt, color: Colors.black),
                                          label: const Text('Ambil', style: TextStyle(color: Colors.black)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: priceCtr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Harga'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan harga' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: stokCtr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Stok'),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<int>(
                            value: formSelectedCategoryId,
                            items: _categories.map((c) {
                              final id = (c['id'] ?? c['id_kategori'] ?? c['idKategori'] ?? c['value'])?.toString();
                              final name = (c['nama_kategori'] ?? c['name'] ?? c['title'] ?? c['label'] ?? '').toString();
                              if (id == null) return null;
                              return DropdownMenuItem<int>(
                                value: int.tryParse(id),
                                child: Text(name),
                              );
                            }).whereType<DropdownMenuItem<int>>().toList(),
                            onChanged: (v) => setStateSB(() => formSelectedCategoryId = v),
                            decoration: _inputDecoration('Kategori'),
                            dropdownColor: Colors.white,
                            validator: (v) {
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),
                          TextFormField(
                            controller: descCtr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Deskripsi'),
                            minLines: 2,
                            maxLines: 5,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.save, color: Colors.black),
                                  label: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Produk', style: const TextStyle(color: Colors.black)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildProductItem(dynamic p) {
    final id = p['id'] ?? p['id_produk'] ?? p['id_product'];
    final name = p['nama_produk'] ?? p['name'] ?? '';
    final harga = p['harga'] ?? p['price'] ?? '';
    final gambar = p['gambar'] ?? p['image'] ?? p['url_image'] ?? '';

    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: (gambar != null && gambar.toString().isNotEmpty)
              ? Image.network(gambar.toString(), width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white24))
              : Container(width: 56, height: 56, color: Colors.white12, child: const Icon(Icons.image, color: Colors.white24)),
        ),
        title: Text(name.toString(), style: const TextStyle(color: Colors.white)),
        subtitle: Text('Harga: ${harga.toString()}', style: const TextStyle(color: Colors.white70)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async {
                try {
                  final detail = await _api.getProductDetail(int.parse(id.toString()));
                  Map<String, dynamic>? data;
                  if (detail is Map && detail.containsKey('data')) data = (detail['data'] as Map).cast<String, dynamic>();
                  else if (detail is Map) data = (detail as Map).cast<String, dynamic>();
                  else data = null;
                  await _showProductForm(product: data ?? (p as Map<String, dynamic>));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat detail produk: $e')));
                }
              },
              icon: const Icon(Icons.edit, color: Colors.white),
            ),
            IconButton(
              onPressed: () async {
                final idVal = id;
                if (idVal != null) await _deleteProduct(int.parse(idVal.toString()));
              },
              icon: const Icon(Icons.delete, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white10,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Kelola Produk', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: () => _loadProducts(page: 1), icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: () => _loadProducts(page: 1),
              color: Colors.white,
              backgroundColor: Colors.black,
              child: _products.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Icon(Icons.inbox, size: 64, color: Colors.white24)),
                        SizedBox(height: 12),
                        Center(child: Text('Tidak ada produk', style: TextStyle(color: Colors.white54))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _products.length,
                      itemBuilder: (_, i) {
                        final p = _products[i];
                        return _buildProductItem(p);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        onPressed: () => _showProductForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// NOTE: This file assumes your ApiService provides the following methods (used above):
// - getProdukToko(token)
// - hapusProduk(token, id)
// - getCategories()
// - getProductDetail(id)
// - saveProductMultipart(fields, imageFile: File)
// - saveProductJson(fields)
// - Possibly ApiException class for nicer errors.
// If your ApiService uses different method names or signatures, adapt the calls
// accordingly.
