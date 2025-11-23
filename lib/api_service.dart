import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';

// Exception khusus untuk menangani error dari API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? errors;
  ApiException(this.message, [this.statusCode, this.errors]);

  @override
  String toString() {
    // Kalau ada errors per-field, gabungkan agar mudah dibaca
    if (errors != null && errors!.isNotEmpty) {
      final combined = errors!.entries.map((e) => '${e.key}: ${e.value.join(", ") }').join('\n');
      return 'ApiException: $message (code: $statusCode)\n$combined';
    }
    return 'ApiException: $message (code: $statusCode)';
  }
}

class ApiService {
  // URL dasar API — ganti kalau endpoint berubah
  static const String baseUrl = 'http://learncode.biz.id/api';
  final http.Client _client;

  // Bisa inject http.Client untuk testing/mocking
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Simpan token ke SharedPreferences
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', token);
  }

  // Ambil token dari local storage
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_token');
  }

  // Hapus token (mis. saat logout)
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
  }

  // Header default untuk request
  Map<String, String> _defaultHeaders({String? token, bool jsonType = true}) {
    final map = <String, String>{
      'Accept': 'application/json', // server mengembalikan JSON diharapkan
    };
    if (jsonType) {
      map['Content-Type'] = 'application/json'; // body dikirim JSON
    }
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token'; // auth header jika ada token
    }
    return map;
  }

  // Fungsi umum untuk menangani response HTTP
  dynamic _handleResponse(http.Response res) {
    final status = res.statusCode;

    // Jika body kosong dan status OK, kembalikan null
    if (res.body.isEmpty) {
      if (status >= 200 && status < 300) return null;
      throw ApiException('Empty response body', status);
    }

    dynamic data;
    try {
      data = json.decode(res.body); // coba parse JSON
    } catch (_) {
      // Kalau bukan JSON tapi status OK, kembalikan raw body
      if (status >= 200 && status < 300) return res.body;
      throw ApiException('Invalid JSON response: ${res.body}', status);
    }

    // Status sukses -> return data
    if (status >= 200 && status < 300) {
      return data;
    } else {
      // Status error -> buat pesan yang informatif
      String message = 'Request failed with status $status';
      if (data is Map && data.containsKey('message')) {
        message = data['message'].toString();
      } else if (data is Map && data.containsKey('error')) {
        message = data['error'].toString();
      } else if (data is String) {
        message = data;
      }

      // Jika validation error 422, parsing error-field supaya bisa ditampilkan
      Map<String, List<String>>? parsedErrors;
      if (status == 422 && data is Map && data.containsKey('errors')) {
        try {
          parsedErrors = {};
          (data['errors'] as Map).forEach((k, v) {
            if (v is List) {
              parsedErrors![k.toString()] = v.map((e) => e.toString()).toList();
            } else {
              parsedErrors![k.toString()] = [v.toString()];
            }
          });
        } catch (_) {
          parsedErrors = null; // kalau parsing gagal, biarkan null
        }
      }

      throw ApiException(message, status, parsedErrors);
    }
  }

  // Register user (multipart request karena server mungkin menerima file juga)
  Future<dynamic> register({
    required String name,
    required String username,
    required String password,
    String? contact,
  }) async {
    final uri = Uri.parse('$baseUrl/register');
    var request = http.MultipartRequest('POST', uri);

    // Field sesuai nama yang diharapkan server
    request.fields['nama'] = name;
    request.fields['username'] = username;
    request.fields['password'] = password;
    if (contact != null && contact.isNotEmpty) request.fields['kontak'] = contact;
    request.headers['Accept'] = 'application/json';

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint('REGISTER -> status: ${response.statusCode}');
    debugPrint('REGISTER -> body: ${response.body}');

    // Tangani 422 manual supaya bisa kembalikan detail validasi
    if (response.statusCode == 422) {
      try {
        final map = json.decode(response.body);
        final String combined = map['message']?.toString() ?? 'Validasi gagal.';
        Map<String, List<String>> parsed = {};
        if (map.containsKey('errors') && map['errors'] is Map) {
          (map['errors'] as Map).forEach((k, v) {
            if (v is List) {
              parsed[k.toString()] = v.map((e) => e.toString()).toList();
            } else {
              parsed[k.toString()] = [v.toString()];
            }
          });
        }
        throw ApiException(combined, 422, parsed);
      } catch (e) {
        throw ApiException('Validasi gagal (422) — tidak dapat parse detail.', 422, null);
      }
    }

    return _handleResponse(response);
  }

  // Login user
  Future<dynamic> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/login');

    var request = http.MultipartRequest('POST', uri);
    request.fields['username'] = username;
    request.fields['password'] = password;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint('LOGIN -> status: ${response.statusCode}');
    debugPrint('LOGIN -> body: ${response.body}');

    final data = _handleResponse(response);

    // Mencari token di response dalam beberapa bentuk yang mungkin
    try {
      String? token;

      if (data is Map) {
        if (data.containsKey('token') && data['token'] is String) token = data['token'] as String;
        else if (data.containsKey('access_token') && data['access_token'] is String) token = data['access_token'] as String;
        else if (data.containsKey('data')) {
          final d = data['data'];
          if (d is Map) {
            if (d.containsKey('token') && d['token'] is String) token = d['token'] as String;
            else if (d.containsKey('access_token') && d['access_token'] is String) token = d['access_token'] as String;
            else if (d.containsKey('user') && d['user'] is Map) {
              final u = d['user'] as Map;
              if (u.containsKey('token') && u['token'] is String) token = u['token'] as String;
              else if (u.containsKey('access_token') && u['access_token'] is String) token = u['access_token'] as String;
            }
          }
        }
      }

      // Kalau dapat token, simpan ke storage lokal
      if (token != null && token.isNotEmpty) {
        await saveToken(token);
        debugPrint('ApiService login -> saved token: $token');
      } else {
        debugPrint('ApiService login -> token not found in response. Response data: $data');
      }
    } catch (e) {
      debugPrint('ApiService.login -> error while saving token: $e');
    }

    return data;
  }

  // Logout: panggil endpoint lalu hapus token lokal
  Future<dynamic> logout() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/logout');

    try {
      final res = await _client.post(uri, headers: _defaultHeaders(token: token));
      debugPrint('LOGOUT -> status: ${res.statusCode}');
      debugPrint('LOGOUT -> body: ${res.body}');
      final data = _handleResponse(res);
      await removeToken();
      return data;
    } catch (e) {
      // Jika error panggil endpoint, tetap hapus token lokal supaya state konsisten
      debugPrint('LOGOUT -> error calling endpoint: $e. Removing local token anyway.');
      await removeToken();
      rethrow;
    }
  }

  // Dapatkan profil user (butuh token)
  Future<dynamic> getProfile() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/profile');
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  // Update profil (kirim JSON)
  Future<dynamic> updateProfile(Map<String, dynamic> fields) async {
    final token = await getToken();
    debugPrint('updateProfile -> token: $token');
    final uri = Uri.parse('$baseUrl/profile/update');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    final res = await _client.post(uri, headers: headers, body: json.encode(fields));

    debugPrint('updateProfile -> status: ${res.statusCode}');
    debugPrint('updateProfile -> body: ${res.body}');
    return _handleResponse(res);
  }

  // Ambil daftar kategori
  Future<dynamic> getCategories() async {
    final uri = Uri.parse('$baseUrl/categories');
    final res = await _client.get(uri, headers: _defaultHeaders(jsonType: false));
    return _handleResponse(res);
  }

  // Ambil daftar produk dengan beberapa parameter opsional
  Future<dynamic> getProducts({int page = 1, String? keyword, int? categoryId, bool auth = false}) async {
    final params = <String, String>{'page': page.toString()};
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

    if (categoryId != null) {
      // Menambahkan beberapa key karena backend kadang memakai nama berbeda
      params['id_kategori'] = categoryId.toString();
      params['category_id'] = categoryId.toString();
      params['id_category'] = categoryId.toString();
    }

    final token = auth ? await getToken() : null;
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);

    debugPrint('getProducts -> GET $uri (auth: $auth, token present: ${token != null})');

    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  // Ambil detail produk berdasarkan id
  Future<dynamic> getProductDetail(int id) async {
    final uri = Uri.parse('$baseUrl/products/$id/show');
    final res = await _client.get(uri, headers: _defaultHeaders(jsonType: false));
    return _handleResponse(res);
  }

  // Cari produk
  Future<dynamic> searchProducts(String keyword, {int page = 1}) async {
    final uri = Uri.parse('$baseUrl/products/search').replace(queryParameters: {'keyword': keyword, 'page': page.toString()});
    final res = await _client.get(uri, headers: _defaultHeaders(jsonType: false));
    return _handleResponse(res);
  }

  // Simpan produk lewat JSON
  Future<dynamic> saveProductJson(Map<String, dynamic> body) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/products/save');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token), body: json.encode(body));
    return _handleResponse(res);
  }

  // Simpan produk dengan multipart (untuk upload gambar)
  Future<dynamic> saveProductMultipart(Map<String, String> fields, {File? imageFile}) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/products/save');
    var request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (imageFile != null) {
      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      final multipartFile = http.MultipartFile('gambar', stream, length, filename: basename(imageFile.path));
      request.files.add(multipartFile);
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  // Hapus produk
  Future<dynamic> deleteProduct(int id) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/products/$id/delete');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token));
    return _handleResponse(res);
  }

  // Ambil gambar-gambar produk
  Future<dynamic> getProductImages(int idProduk) async {
    final uri = Uri.parse('$baseUrl/products/$idProduk/images');
    final res = await _client.get(uri, headers: _defaultHeaders(jsonType: false));
    return _handleResponse(res);
  }

  // Upload satu gambar untuk produk
  Future<dynamic> uploadProductImage({
    required int idProduk,
    required File file,
    String fieldName = 'gambar',
  }) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/products/images/upload');
    var request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
    request.fields['id_produk'] = idProduk.toString();
    final stream = http.ByteStream(file.openRead());
    final length = await file.length();
    final multipartFile = http.MultipartFile(fieldName, stream, length, filename: basename(file.path));
    request.files.add(multipartFile);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  // Hapus gambar produk
  Future<dynamic> deleteProductImage(int imageId) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/products/images/$imageId');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token));
    return _handleResponse(res);
  }

  // Ambil semua toko
  Future<dynamic> getStores() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/stores');
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  // Simpan toko (multipart, bisa upload gambar)
  Future<dynamic> saveStore({required Map<String, String> fields, File? imageFile}) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/stores/save');

    var request = http.MultipartRequest('POST', uri);

    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll(fields);

    if (imageFile != null) {
      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      final multipartFile = http.MultipartFile('gambar', stream, length, filename: basename(imageFile.path));
      request.files.add(multipartFile);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    // Preview body agar mudah debugging ketika terjadi masalah
    final bodyPreview = response.body.length > 1200 ? response.body.substring(0, 1200) + '... (truncated)' : response.body;
    print('saveStore -> status: ${response.statusCode}');
    print('saveStore -> bodyPreview: $bodyPreview');

    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) {
      throw ApiException('Server returned non-JSON response (status ${response.statusCode}). Response preview: $bodyPreview', response.statusCode);
    }

    try {
      final data = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        String message = 'Request failed with status ${response.statusCode}';
        if (data is Map && data.containsKey('message')) message = data['message'].toString();
        throw ApiException(message, response.statusCode);
      }
    } catch (e) {
      throw ApiException('Invalid JSON from server: ${e.toString()}. Body preview: $bodyPreview', response.statusCode);
    }
  }

  // Hapus toko
  Future<dynamic> deleteStore(int id) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/stores/$id/delete');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token));
    return _handleResponse(res);
  }

  // Ambil produk yang terkait dengan toko
  Future<dynamic> getStoreProducts() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/stores/products');
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  // Generic GET helper
  Future<dynamic> get(String path, {Map<String, String>? params, bool auth = false}) async {
    final token = auth ? await getToken() : null;
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  // Generic POST helper
  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final token = auth ? await getToken() : null;
    final uri = Uri.parse('$baseUrl$path');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token), body: json.encode(body));
    return _handleResponse(res);
  }

  // Tutup client HTTP saat tidak dipakai
  void dispose() {
    _client.close();
  }

  // Helper statis: ambil produk toko dengan token yang diberikan
  static Future<dynamic> getProdukToko(String token) async {
    final api = ApiService();
    final uri = Uri.parse('$baseUrl/stores/products');
    final res = await api._client.get(uri, headers: api._defaultHeaders(token: token, jsonType: false));
    return api._handleResponse(res);
  }

  // Helper statis: hapus produk dengan token yang diberikan
  static Future<dynamic> hapusProduk(String token, int idProduk) async {
    final api = ApiService();
    final uri = Uri.parse('$baseUrl/products/$idProduk/delete');
    final res = await api._client.post(uri, headers: api._defaultHeaders(token: token));
    return api._handleResponse(res);
  }
}
