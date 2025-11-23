import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:marketplacedesign/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

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

  String? _categoryName;
  Map<String, dynamic>? _storeInfo;

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

      _categoryName = _extractCategoryName(_product);
      if (_categoryName == null) {
        final catId = _extractCategoryId(_product);
        if (catId != null) {
          try {
            final cats = await _api.getCategories();
            if (cats is Map && cats.containsKey('data')) {
              final list = cats['data'] as List;
              final match = list.cast<Map>().firstWhere(
                (e) {
                  final idVal = e['id'] ?? e['id_kategori'] ?? e['id_kat'];
                  return idVal != null && idVal.toString() == catId.toString();
                },
                orElse: () => {},
              );
              if (match.isNotEmpty) {
                _categoryName = (match['nama_kategori'] ?? match['name'] ?? match['kategori'])?.toString();
              }
            } else if (cats is List) {
              final match = cats.cast<Map>().firstWhere(
                (e) {
                  final idVal = e['id'] ?? e['id_kategori'];
                  return idVal != null && idVal.toString() == catId.toString();
                },
                orElse: () => {},
              );
              if (match.isNotEmpty) {
                _categoryName = (match['nama_kategori'] ?? match['name'])?.toString();
              }
            }
          } catch (_) {}
        }
      }

      _storeInfo = _extractStoreObject(_product);
      if (_storeInfo == null) {
        final storeId = _extractStoreId(_product);
        if (storeId != null) {
          try {
            final storesRes = await _api.getStores();
            if (storesRes is Map && storesRes.containsKey('data')) {
              final list = storesRes['data'] as List;
              final match = list.cast<Map>().firstWhere(
                (e) {
                  final idVal = e['id'] ?? e['id_toko'] ?? e['id_store'];
                  return idVal != null && idVal.toString() == storeId.toString();
                },
                orElse: () => {},
              );
              if (match.isNotEmpty) _storeInfo = Map<String, dynamic>.from(match);
            } else if (storesRes is List) {
              final match = storesRes.cast<Map>().firstWhere(
                (e) {
                  final idVal = e['id'] ?? e['id_toko'];
                  return idVal != null && idVal.toString() == storeId.toString();
                },
                orElse: () => {},
              );
              if (match.isNotEmpty) _storeInfo = Map<String, dynamic>.from(match);
            }
          } catch (_) {}
        }
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

  String? _extractCategoryName(Map<String, dynamic>? p) {
    if (p == null) return null;
    final candidates = ['kategori', 'category', 'nama_kategori', 'category_name', 'kategori_nama'];
    for (final k in candidates) {
      final v = p[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    final nested = p['kategori'] ?? p['category'];
    if (nested is Map && (nested['nama'] != null || nested['name'] != null)) {
      return (nested['nama'] ?? nested['name']).toString();
    }
    return null;
  }

  dynamic _extractCategoryId(Map<String, dynamic>? p) {
    if (p == null) return null;
    final candidates = ['id_kategori', 'category_id', 'idCategory', 'id_kat', 'id_tipe'];
    for (final k in candidates) {
      final v = p[k];
      if (v != null && v.toString().trim().isNotEmpty) return v;
    }
    final nested = p['kategori'] ?? p['category'];
    if (nested is Map && (nested['id'] != null)) return nested['id'];
    return null;
  }

  Map<String, dynamic>? _extractStoreObject(Map<String, dynamic>? p) {
    if (p == null) return null;
    final candidates = ['toko', 'store', 'seller', 'owner'];
    for (final k in candidates) {
      final v = p[k];
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return null;
  }

  dynamic _extractStoreId(Map<String, dynamic>? p) {
    if (p == null) return null;
    final candidates = ['id_toko', 'store_id', 'id_store', 'toko_id', 'owner_id'];
    for (final k in candidates) {
      final v = p[k];
      if (v != null && v.toString().trim().isNotEmpty) return v;
    }
    final nested = p['toko'] ?? p['store'];
    if (nested is Map && nested['id'] != null) return nested['id'];
    return null;
  }

  String? _getStoreContact() {
    if (_storeInfo != null) {
      final candidates = ['kontak_toko', 'kontak', 'contact', 'phone', 'telepon', 'no_hp', 'no_telp', 'hp'];
      for (final k in candidates) {
        final v = _storeInfo![k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
    }
    final candidatesProduct = ['kontak_toko', 'kontak', 'contact', 'phone', 'telepon', 'no_hp', 'no_telp', 'hp', 'contact_toko', 'contact_store'];
    for (final k in candidatesProduct) {
      final v = _product?[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  String _cleanPhoneForWhatsapp(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) digits = digits.substring(1);
    digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.replaceFirst(RegExp(r'^0+'), '62');
    if (digits.length <= 9) digits = '62$digits';
    return digits;
  }

  Future<void> _openWhatsApp(String rawPhone, {String? text}) async {
    final cleaned = _cleanPhoneForWhatsapp(rawPhone);
    if (cleaned.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor WhatsApp tidak valid')));
      return;
    }

    final encodedText = text == null ? null : Uri.encodeComponent(text);

    final waWeb = 'https://wa.me/$cleaned${encodedText != null ? '?text=$encodedText' : ''}';
    final whatsappAppUri = Uri.parse('whatsapp://send?phone=$cleaned${encodedText != null ? '&text=$encodedText' : ''}');

    if (kIsWeb) {
      try {
        final ok = await launchUrlString(waWeb, webOnlyWindowName: '_blank');
        if (!ok) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka WhatsApp Web')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuka WhatsApp Web: $e')));
      }
      return;
    }

    try {
      if (await canLaunchUrl(whatsappAppUri)) {
        await launchUrl(whatsappAppUri, mode: LaunchMode.externalApplication);
        return;
      }

      final ok = await launchUrlString(waWeb, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka WhatsApp')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal membuka WhatsApp: $e\nLink: $waWeb'),
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _product == null ? null : (_product!['gambar'] ?? _product!['image'] ?? _product!['url_image'])?.toString();
    final title = _product == null ? '' : (_product!['nama_produk'] ?? _product!['name'] ?? '');
    final harga = _product == null ? '' : (_product!['harga'] ?? _product!['price'] ?? '');

    final storeContact = _getStoreContact();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Detail Produk', style: TextStyle(color: Colors.white)),
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
                  if (_product != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.layers, color: Colors.white38, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                'Stok: ${_product!['stok'] ?? _product!['stock'] ?? '-'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.category, color: Colors.white38, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Kategori: ${_categoryName ?? (_product!['kategori'] ?? _product!['category'] ?? '-')}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.store, color: Colors.white38, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStoreWidget(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (storeContact != null && storeContact.trim().isNotEmpty)
                                      ? () async {
                                          final pesan = 'Halo, saya mau membeli produk: $title';
                                          await _openWhatsApp(storeContact, text: pesan);
                                        }
                                      : null,
                                  icon: const Icon(Icons.phone, color: Colors.white),
                                  label: Text(
                                    storeContact != null && storeContact.trim().isNotEmpty
                                        ? 'Beli via WhatsApp'
                                        : 'Kontak toko tidak tersedia',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: storeContact != null && storeContact.trim().isNotEmpty
                                        ? Colors.green
                                        : Colors.white12,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (storeContact != null && storeContact.trim().isNotEmpty)
                            Text(
                              'Nomor toko: $storeContact',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
  Widget _buildStoreWidget() {
    if (_storeInfo != null && _storeInfo!.isNotEmpty) {
      final name = _storeInfo!['nama_toko'] ?? _storeInfo!['nama'] ?? _storeInfo!['name'] ?? '-';
      final contact = _storeInfo!['kontak_toko'] ?? _storeInfo!['kontak'] ?? _storeInfo!['contact'] ?? '';
      final alamat = _storeInfo!['alamat'] ?? _storeInfo!['address'] ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Toko: $name', style: const TextStyle(color: Colors.white70)),
          if (contact.toString().trim().isNotEmpty) Text('Kontak: $contact', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (alamat.toString().trim().isNotEmpty) Text('Alamat: $alamat', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );
    }

    final storeNameFromProduct = _product?['toko'] is String ? _product!['toko'] : (_product?['store'] is String ? _product!['store'] : null);
    final storeNameViaField = _product?['nama_toko'] ?? _product?['store_name'];

    final storeId = _extractStoreId(_product);
    if (storeNameFromProduct != null) {
      return Text('Toko: ${storeNameFromProduct}', style: const TextStyle(color: Colors.white70));
    } else if (storeNameViaField != null) {
      return Text('Toko: ${storeNameViaField}', style: const TextStyle(color: Colors.white70));
    } else if (storeId != null) {
      return Text('Toko ID: $storeId', style: const TextStyle(color: Colors.white70));
    } else {
      return Text('-', style: const TextStyle(color: Colors.white70));
    }
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