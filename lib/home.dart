import 'package:flutter/material.dart';
import 'package:marketplacedesign/api_service.dart';
import 'package:marketplacedesign/detail-product.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService(); // instance ApiService
  bool _loading = true; // status loading
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  String _query = '';
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndProducts(); // muat kategori + produk saat mulai
  }

  // Ambil kategori lalu produk
  Future<void> _loadCategoriesAndProducts() async {
    setState(() => _loading = true);
    try {
      final catRes = await _api.getCategories();
      if (catRes is List) {
        _categories = List.from(catRes);
      } else if (catRes is Map && catRes.containsKey('data')) {
        _categories = List.from(catRes['data']);
      } else {
        _categories = [];
      }

      await _loadProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load error: $e')));
        _categories = [];
        _products = [];
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Ambil produk dari API, mendukung filter kategori & keyword
  Future<void> _loadProducts({int? categoryId, String? keyword}) async {
    setState(() => _loading = true);
    try {
      final res = await _api.getProducts(
        page: 1,
        keyword: keyword ?? (_query.isEmpty ? null : _query),
        categoryId: categoryId,
        auth: false,
      );
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

  // Saat memilih kategori
  Future<void> _onSelectCategory(int? id) async {
    setState(() {
      _selectedCategoryId = id;
    });
    await _loadProducts(categoryId: id);
  }

  // Filter produk berdasarkan kategori dan pencarian lokal (fallback)
  List<dynamic> _filteredProductsByCategoryAndSearch() {
    List<dynamic> list = List.from(_products);

    if (_selectedCategoryId != null) {
      list = list.where((p) {
        final catId = p['id_kategori'] ?? p['category_id'] ?? p['id_category'] ?? p['kategori_id'] ?? p['idCategory'];
        if (catId == null) return false;
        return catId.toString() == _selectedCategoryId.toString();
      }).toList();
    }

    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((p) {
        final title = (p['nama_produk'] ?? p['title'] ?? '').toString().toLowerCase();
        final desc = (p['deskripsi'] ?? p['description'] ?? '').toString().toLowerCase();
        return title.contains(q) || desc.contains(q);
      }).toList();
    }

    return list;
  }

  // Format harga sederhana ke Rupiah
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

  @override
  Widget build(BuildContext context) {
    final items = _filteredProductsByCategoryAndSearch();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Marketplace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
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
                          onChanged: (v) {
                            setState(() => _query = v);
                            _loadProducts(categoryId: _selectedCategoryId); // langsung load ulang ke server
                          },
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            setState(() => _query = '');
                            _loadProducts(categoryId: _selectedCategoryId);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: _categories.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Text('Memuat kategori...', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            const SizedBox(width: 4),
                            _buildCategoryChip(null, 'Semua'),
                            const SizedBox(width: 8),
                            for (var c in _categories) ...[
                              _buildCategoryChip(
                                c['id'] ?? c['id_kategori'] ?? c['id_category'],
                                (c['nama'] ?? c['nama_kategori'] ?? c['name'] ?? 'Kategori').toString(),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadProducts(categoryId: _selectedCategoryId),
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
                          ? (stockValue.isEmpty ? '-' : stockValue)
                          : (stockInt <= 0 ? 'Habis' : stockInt.toString());

                      return Material(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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

  // Widget chip kategori sederhana
  Widget _buildCategoryChip(dynamic idVal, String label) {
    final int? id = idVal == null ? null : (int.tryParse(idVal.toString()) ?? null);
    final selected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () => _onSelectCategory(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.w500)),
            if (selected && id != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  _onSelectCategory(null);
                },
                child: const Icon(Icons.close, size: 16, color: Colors.white70),
              )
            ]
          ],
        ),
      ),
    );
  }
}
