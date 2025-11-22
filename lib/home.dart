import 'package:flutter/material.dart';
import 'package:marketplacedesign/api_service.dart';
import 'package:marketplacedesign/detail-product.dart';
import 'package:marketplacedesign/login.dart';
import 'package:marketplacedesign/my_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _products = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getProducts(page: 1);
      if (res is Map && res.containsKey('data')) {
        _products = List.from(res['data']);
      } else if (res is List) {
        _products = res;
      } else if (res is Map && res.containsKey('products')) {
        _products = List.from(res['products']);
      } else {
        _products = [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load products error: $e')));
        _products = [];
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _api.removeToken();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  List<dynamic> _filteredProducts() {
    if (_query.trim().isEmpty) return _products;
    final q = _query.toLowerCase();
    return _products.where((p) {
      final title = (p['nama_produk'] ?? p['title'] ?? '').toString().toLowerCase();
      final desc = (p['deskripsi'] ?? p['description'] ?? '').toString().toLowerCase();
      return title.contains(q) || desc.contains(q);
    }).toList();
  }

  String _formatPrice(dynamic price) {
    try {
      if (price == null) return '';
      final str = price.toString();
      // jika numeric, format sederhana dengan pemisah ribuan
      final value = double.tryParse(str.replaceAll(',', '').replaceAll(' ', ''));
      if (value != null) {
        final parts = value.toInt().toString();
        // simple thousands separator
        final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
        return 'Rp ' + parts.replaceAllMapped(reg, (m) => '.');
      }
      return str;
    } catch (_) {
      return price.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredProducts();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Marketplace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.search, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Cari produk...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () => setState(() => _query = ''),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _loadProducts,
        edgeOffset: 16,
        color: Colors.white,
        backgroundColor: Colors.black,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                      const Center(child: Icon(Icons.inbox, size: 64, color: Colors.white24)),
                      const SizedBox(height: 12),
                      const Center(child: Text('Tidak ada produk', style: TextStyle(color: Colors.white54, fontSize: 16))),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final p = items[index];
                      final title = (p['nama_produk'] ?? p['title'] ?? 'Produk').toString();
                      final price = _formatPrice(p['harga'] ?? p['price'] ?? '');
                      final image = (p['gambar'] is String)
                          ? p['gambar']
                          : (p['image'] is String ? p['image'] : null);
                      final stockValue = (p['stok'] ?? p['stock'] ?? p['qty'] ?? p['jumlah'] ?? p['stok_produk'] ?? '').toString();
                      final stockInt = int.tryParse(stockValue.replaceAll(RegExp(r'[^0-9\-]'), ''));
                      final stockLabel = stockInt == null
                          ? (stockValue.isEmpty ? '-' : stockValue) // jika bukan angka, tampilkan apa adanya
                          : (stockInt <= 0 ? 'Habis' : stockInt.toString());

                      return Material(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            // TODO: buka detail produk
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // gambar
                              ClipRRect(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                child: AspectRatio(
                                  aspectRatio: 1.1,
                                  child: image != null
                                      ? Image.network(
                                          image,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.white12,
                                            child: const Icon(Icons.broken_image, color: Colors.white24, size: 36),
                                          ),
                                        )
                                      : Container(
                                          color: Colors.white12,
                                          child: const Icon(Icons.shopping_bag, color: Colors.white24, size: 36),
                                        ),
                                ),
                              ),

                              // isi kartu
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              price,
                                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 6),
                                            // tampilkan stok
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white12,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Stok: $stockLabel',
                                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // tombol buka detail produk kecil (tetap sama)
                                        Container(
                                          height: 34,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white12,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                                            onPressed: () {
                                              final idVal = (p['id'] ?? p['id_produk'] ?? p['id_product']);
                                              if (idVal == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID produk tidak tersedia')));
                                                return;
                                              }
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => ProductDetailPage(productId: int.parse(idVal.toString()))),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
