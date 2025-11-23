import 'dart:io';
import 'package:flutter/material.dart';
import 'package:marketplacedesign/api_service.dart';
import 'package:image_picker/image_picker.dart';

class ProductDetailPage extends StatefulWidget {
  final int productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final ApiService _api = ApiService();

  bool _loading = true;
  Map<String, dynamic>? _product;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getProductDetail(widget.productId);
      if (res == null) {
        _product = null;
      } else if (res is Map && res.containsKey('data')) {
        _product = Map<String, dynamic>.from(res['data']);
      } else if (res is Map) {
        _product = Map<String, dynamic>.from(res);
      } else {
        _product = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat detail produk: $e')));
      }
      _product = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white10,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white70, width: 1.5)),
    );
  }

  Future<void> _showEditSheet() async {
    if (_product == null) return;

    final _formKey = GlobalKey<FormState>();
    final nameCtr = TextEditingController(text: _product!['nama_produk'] ?? _product!['name'] ?? '');
    final priceCtr = TextEditingController(text: (_product!['harga'] ?? _product!['price'] ?? '').toString());
    final stokCtr = TextEditingController(text: (_product!['stok'] ?? _product!['stock'] ?? '').toString());
    final descCtr = TextEditingController(text: _product!['deskripsi'] ?? _product!['description'] ?? '');
    final katCtr = TextEditingController(text: (_product!['id_kategori'] ?? _product!['category_id'] ?? '').toString());

    File? _imageFile;
    String? _imagePreview = (_product!['gambar'] ?? _product!['image'] ?? _product!['url_image'])?.toString();

    Future<void> _pickImage(ImageSource src) async {
      try {
        final picker = ImagePicker();
        final x = await picker.pickImage(source: src, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
        if (x != null) {
          _imageFile = File(x.path);
          // update preview inside sheet via stateful builder
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        bool _savingLocal = false;
        return StatefulBuilder(builder: (ctx2, setStateSB) {
          Future<void> _save() async {
            if (!_formKey.currentState!.validate()) return;
            setStateSB(() => _savingLocal = true);
            final fields = <String, String>{
              'nama_produk': nameCtr.text.trim(),
              'harga': priceCtr.text.trim(),
              'stok': stokCtr.text.trim(),
              'deskripsi': descCtr.text.trim(),
              'id_kategori': katCtr.text.trim(),
              'id': widget.productId.toString(),
            };
            try {
              if (_imageFile != null) {
                await _api.saveProductMultipart(fields, imageFile: _imageFile);
              } else {
                await _api.saveProductJson(fields);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk diperbarui')));
                Navigator.pop(ctx);
                await _loadDetail();
              }
            } catch (e) {
              String msg = e.toString();
              if (e is ApiException) msg = e.message;
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $msg')));
            } finally {
              setStateSB(() => _savingLocal = false);
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
                        Expanded(child: Text('Edit Produk', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
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
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                child: _imageFile != null
                                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imageFile!, fit: BoxFit.cover))
                                    : (_imagePreview != null && _imagePreview.isNotEmpty
                                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_imagePreview!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image, color: Colors.white24)))
                                        : const Icon(Icons.image, size: 48, color: Colors.white24)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(controller: nameCtr, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Nama Produk'), validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan nama' : null),
                                    const SizedBox(height: 8),
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
                          TextFormField(controller: priceCtr, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Harga'), keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          TextFormField(controller: stokCtr, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Stok'), keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          TextFormField(controller: katCtr, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('ID Kategori'), keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          TextFormField(controller: descCtr, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Deskripsi'), minLines: 2, maxLines: 5),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _savingLocal ? null : _save,
                                  icon: _savingLocal ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.save, color: Colors.black),
                                  label: const Text('Simpan', style: TextStyle(color: Colors.black)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () async {
                                  // delete product
                                  final confirm = await showDialog<bool>(
                                    context: ctx2,
                                    builder: (dialogCtx) => AlertDialog(
                                      backgroundColor: Colors.black,
                                      title: const Text('Hapus Produk', style: TextStyle(color: Colors.white)),
                                      content: const Text('Yakin ingin menghapus produk ini?', style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Batal')),
                                        TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Hapus', style: TextStyle(color: Colors.redAccent))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      await _api.deleteProduct(widget.productId);
                                      if (mounted) {
                                        Navigator.pop(ctx); // close sheet
                                        Navigator.pop(context); // close detail page
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dihapus')));
                                      }
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.delete),
                                label: const Text('Hapus'),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _confirmDeleteFromPage() async {
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
    if (ok == true) {
      try {
        await _api.deleteProduct(widget.productId);
        if (mounted) {
          Navigator.pop(context); // close detail page
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dihapus')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _product == null ? null : (_product!['gambar'] ?? _product!['image'] ?? _product!['url_image'])?.toString();
    final title = _product == null ? '' : (_product!['nama_produk'] ?? _product!['name'] ?? '');
    final harga = _product == null ? '' : (_product!['harga'] ?? _product!['price'] ?? '');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Detail Produk', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _product == null ? null : _showEditSheet,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _product == null ? null : _confirmDeleteFromPage,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(imageUrl, height: 260, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 260, color: Colors.white10, child: const Icon(Icons.broken_image, size: 64, color: Colors.white24))),
                    )
                  else
                    Container(height: 260, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.image, size: 72, color: Colors.white24)),
                  const SizedBox(height: 12),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Harga: ${_formatPrice(harga)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Deskripsi Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        SelectableText(
                          _product?['deskripsi']?.toString().trim().isNotEmpty == true
                              ? _product!['deskripsi'].toString()
                              : (_product?['description']?.toString() ?? 'Tidak ada deskripsi.'),
                          style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // meta info
                  if (_product != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Informasi', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.layers, color: Colors.white38, size: 18),
                            const SizedBox(width: 8),
                            Text('Stok: ${_product!['stok'] ?? _product!['stock'] ?? '-'}', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.category, color: Colors.white38, size: 18),
                            const SizedBox(width: 8),
                            Text('Kategori: ${_product!['kategori'] ?? _product!['category'] ?? '-'}', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  String _formatPrice(dynamic price) {
    try {
      if (price == null) return '';
      final str = price.toString();
      final value = double.tryParse(str.replaceAll(',', '').replaceAll(' ', ''));
      if (value != null) {
        final parts = value.toInt().toString();
        final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
        return 'Rp ' + parts.replaceAllMapped(reg, (m) => '.');
      }
      return str;
    } catch (_) {
      return price.toString();
    }
  }
}
