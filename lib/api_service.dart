// lib/api_service.dart
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? errors; // per-field errors
  ApiException(this.message, [this.statusCode, this.errors]);

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      final combined = errors!.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n');
      return 'ApiException: $message (code: $statusCode)\n$combined';
    }
    return 'ApiException: $message (code: $statusCode)';
  }
}

class ApiService {
  static const String baseUrl = 'http://learncode.biz.id/api';
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // -------------------------
  // Token storage (shared_preferences)
  // -------------------------
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_token');
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
  }

  Map<String, String> _defaultHeaders({String? token, bool jsonType = true}) {
    final map = <String, String>{
      'Accept': 'application/json',
    };
    // Set Content-Type only when sending JSON (POST/PUT)
    if (jsonType) {
      map['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  dynamic _handleResponse(http.Response res) {
    final status = res.statusCode;
    if (res.body.isEmpty) {
      if (status >= 200 && status < 300) return null;
      throw ApiException('Empty response body', status);
    }

    dynamic data;
    try {
      data = json.decode(res.body);
    } catch (_) {
      // If body is not JSON, return raw body on success, otherwise throw.
      if (status >= 200 && status < 300) return res.body;
      throw ApiException('Invalid JSON response: ${res.body}', status);
    }

    if (status >= 200 && status < 300) {
      return data;
    } else {
      // try to extract message
      String message = 'Request failed with status $status';
      if (data is Map && data.containsKey('message')) {
        message = data['message'].toString();
      } else if (data is Map && data.containsKey('error')) {
        message = data['error'].toString();
      } else if (data is String) {
        message = data;
      }

      // Extract validation errors if available (422)
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
          parsedErrors = null;
        }
      }

      throw ApiException(message, status, parsedErrors);
    }
  }

  // -------------------------
  // AUTH
  // -------------------------
  /// Register — kirim sebagai form-data sesuai Postman (field: nama, username, password, kontak)
  Future<dynamic> register({
    required String name,
    required String username,
    required String password,
    String? contact,
  }) async {
    final uri = Uri.parse('$baseUrl/register');
    var request = http.MultipartRequest('POST', uri);
    request.fields['nama'] = name;
    request.fields['username'] = username;
    request.fields['password'] = password;
    if (contact != null && contact.isNotEmpty) request.fields['kontak'] = contact;
    request.headers['Accept'] = 'application/json';

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint('REGISTER -> status: ${response.statusCode}');
    debugPrint('REGISTER -> body: ${response.body}');

    // If 422, parse "errors" into structured map and throw ApiException with errors
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
        // fallback: return generic message if parsing failed
        throw ApiException('Validasi gagal (422) — tidak dapat parse detail.', 422, null);
      }
    }

    return _handleResponse(response);
  }

  /// Login -> biasanya mengembalikan token
  Future<dynamic> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/login');

    // Gunakan MultipartRequest seperti sebelumnya (sesuaikan bila server
    // mengharapkan JSON instead)
    var request = http.MultipartRequest('POST', uri);
    request.fields['username'] = username;
    request.fields['password'] = password;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    // Debug: print status & body supaya mudah lihat struktur response saat dev
    debugPrint('LOGIN -> status: ${response.statusCode}');
    debugPrint('LOGIN -> body: ${response.body}');

    // Jika server mengembalikan error HTML, _handleResponse akan melempar.
    final data = _handleResponse(response);

    // Coba ekstrak token dari berbagai kemungkinan lokasi dan simpan.
    try {
      String? token;

      if (data is Map) {
        // common variants
        if (data.containsKey('token') && data['token'] is String) token = data['token'] as String;
        else if (data.containsKey('access_token') && data['access_token'] is String) token = data['access_token'] as String;
        // sometimes token is inside data.data or data.user etc.
        else if (data.containsKey('data')) {
          final d = data['data'];
          if (d is Map) {
            if (d.containsKey('token') && d['token'] is String) token = d['token'] as String;
            else if (d.containsKey('access_token') && d['access_token'] is String) token = d['access_token'] as String;
            // nested further
            else if (d.containsKey('user') && d['user'] is Map) {
              final u = d['user'] as Map;
              if (u.containsKey('token') && u['token'] is String) token = u['token'] as String;
              else if (u.containsKey('access_token') && u['access_token'] is String) token = u['access_token'] as String;
            }
          }
        }
      }

      if (token != null && token.isNotEmpty) {
        await saveToken(token);
        debugPrint('ApiService login -> saved token: $token');
      } else {
        // jika tidak menemukan token, coba lihat apakah server sendiri menyimpan cookie/session
        debugPrint('ApiService login -> token not found in response. Response data: $data');
      }
    } catch (e) {
      debugPrint('ApiService.login -> error while saving token: $e');
    }

    return data;
  }

  /// Logout (calls API then clears local token).
  Future<dynamic> logout() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/logout');

    try {
      final res = await _client.post(uri, headers: _defaultHeaders(token: token));
      // debug
      debugPrint('LOGOUT -> status: ${res.statusCode}');
      debugPrint('LOGOUT -> body: ${res.body}');
      // call handle (akan menghapus token lokal setelah sukses)
      final data = _handleResponse(res);
      await removeToken();
      return data;
    } catch (e) {
      // Jika ada error network atau server mengembalikan non-JSON, tetap hapus token lokal
      debugPrint('LOGOUT -> error calling endpoint: $e. Removing local token anyway.');
      await removeToken();
      rethrow;
    }
  }

  /// Get profile (requires token)
  Future<dynamic> getProfile() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/profile');
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  /// Update profile (fields flexible)
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

  // -------------------------
  // CATEGORIES
  // -------------------------
  Future<dynamic> getCategories() async {
    final uri = Uri.parse('$baseUrl/categories');
    final res = await _client.get(uri, headers: _defaultHeaders(jsonType: false));
    return _handleResponse(res);
  }

  // -------------------------
  // PRODUCTS
  // -------------------------
  /// Get products (with optional page, keyword, categoryId)
  /// - `auth`: set true if endpoint requires Authorization header
  Future<dynamic> getProducts({int page = 1, String? keyword, int? categoryId, bool auth = false}) async {
    final params = <String, String>{'page': page.toString()};
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

    if (categoryId != null) {
      // primary param used by your previous code
      params['id_kategori'] = categoryId.toString();
      // include common variants for wider compatibility
      params['category_id'] = categoryId.toString();
      params['id_category'] = categoryId.toString();
    }

    final token = auth ? await getToken() : null;
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);

    debugPrint('getProducts -> GET $uri (auth: $auth, token present: ${token != null})');

    // For GET requests, avoid Content-Type header
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  /// Get product detail
  Future<dynamic> getProductDetail(int id) async {
    final uri = Uri.parse('$baseUrl/products/$id/show');
    final res = await _client.get(uri, headers: _defaultHeaders(jsonType: false));
    return _handleResponse(res);
  }

  /// Search products (alternative endpoint)
  Future<dynamic> searchProducts(String keyword, {int page = 1}) async {
    final uri = Uri.parse('$baseUrl/products/search').replace(queryParameters: {'keyword': keyword, 'page': page.toString()});
    final res = await _client.get(uri, headers: _defaultHeaders(jsonType: false));
    return _handleResponse(res);
  }

  /// Save product - JSON variant (if API accepts JSON)
  Future<dynamic> saveProductJson(Map<String, dynamic> body) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/products/save');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token), body: json.encode(body));
    return _handleResponse(res);
  }

  /// Save product - Multipart variant (if API expects upload fields + image)
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

  /// Delete product
  Future<dynamic> deleteProduct(int id) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/products/$id/delete');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token));
    return _handleResponse(res);
  }

  // -------------------------
  // PRODUCT IMAGES
  // -------------------------
  /// List images for product (GET)
  Future<dynamic> getProductImages(int idProduk) async {
    final uri = Uri.parse('$baseUrl/products/$idProduk/images');
    final res = await _client.get(uri, headers: _defaultHeaders(jsonType: false));
    return _handleResponse(res);
  }

  /// Upload product image (multipart)
  Future<dynamic> uploadProductImage({
    required int idProduk,
    required File file,
    String fieldName = 'gambar', // field expected by API
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

  /// Delete an image (if endpoint uses POST /products/images/{image_id})
  Future<dynamic> deleteProductImage(int imageId) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/products/images/$imageId');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token));
    return _handleResponse(res);
  }

  // -------------------------
  // STORES / TOKO
  // -------------------------
  /// Get store(s) for the logged-in user
  Future<dynamic> getStores() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/stores');
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  /// Save store (multipart if ada gambar)
  Future<dynamic> saveStore({required Map<String, String> fields, File? imageFile}) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/stores/save');

    var request = http.MultipartRequest('POST', uri);

    // jangan set Content-Type (MultipartRequest akan set boundary otomatis)
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

    // DEBUG: log status dan awal body (batas 1200 char supaya tidak banjir)
    final bodyPreview = response.body.length > 1200 ? response.body.substring(0, 1200) + '... (truncated)' : response.body;
    print('saveStore -> status: ${response.statusCode}');
    print('saveStore -> bodyPreview: $bodyPreview');

    // Cek content-type header; jika bukan json, berikan error informatif
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) {
      // Kemungkinan HTML/redirect/error view
      throw ApiException('Server returned non-JSON response (status ${response.statusCode}). Response preview: $bodyPreview', response.statusCode);
    }

    // Jika JSON, decode seperti biasa
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
      // jika decode gagal
      throw ApiException('Invalid JSON from server: ${e.toString()}. Body preview: $bodyPreview', response.statusCode);
    }
  }

  /// Delete store
  Future<dynamic> deleteStore(int id) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/stores/$id/delete');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token));
    return _handleResponse(res);
  }

  /// Get products of the logged-in user's store
  Future<dynamic> getStoreProducts() async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/stores/products');
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  // -------------------------
  // OTHER / UTILITIES
  // -------------------------
  /// Generic GET helper (optionally with query params)
  Future<dynamic> get(String path, {Map<String, String>? params, bool auth = false}) async {
    final token = auth ? await getToken() : null;
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final res = await _client.get(uri, headers: _defaultHeaders(token: token, jsonType: false));
    return _handleResponse(res);
  }

  /// Generic POST helper (JSON body)
  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final token = auth ? await getToken() : null;
    final uri = Uri.parse('$baseUrl$path');
    final res = await _client.post(uri, headers: _defaultHeaders(token: token), body: json.encode(body));
    return _handleResponse(res);
  }

  /// Close HTTP client (call on dispose if needed)
  void dispose() {
    _client.close();
  }

  // -------------------------
  // Compatibility static helpers (so UI can call ApiService.getProdukToko(token) etc.)
  // -------------------------

  /// Static wrapper agar kode lama yang memanggil ApiService.getProdukToko(token)
  /// tetap bekerja. Memanggil endpoint yang sama dengan getStoreProducts()
  static Future<dynamic> getProdukToko(String token) async {
    final api = ApiService();
    // Sesuaikan path jika backend-mu menggunakan path lain (mis. '/produk-toko' atau '/toko/produk')
    final uri = Uri.parse('$baseUrl/stores/products');
    final res = await api._client.get(uri, headers: api._defaultHeaders(token: token, jsonType: false));
    return api._handleResponse(res);
  }

  /// Static wrapper agar UI lama bisa memanggil ApiService.hapusProduk(token, id)
  /// Memanggil endpoint delete/post sesuai implementasi yang ada.
  static Future<dynamic> hapusProduk(String token, int idProduk) async {
    final api = ApiService();
    // Jika backend-mu memakai DELETE, ubah ke api._client.delete(...)
    final uri = Uri.parse('$baseUrl/products/$idProduk/delete');
    final res = await api._client.post(uri, headers: api._defaultHeaders(token: token));
    return api._handleResponse(res);
  }
}
