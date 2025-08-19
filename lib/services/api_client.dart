import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaltes_car_app/app_constants.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  String? _token;
  String? get token => _token;
  void setToken(String? t) => _token = t;

  String get _base => AppConstants.BASE_URL;

  // header
  Map<String, String> _headers({bool json = true}) => {
    if (json) 'Content-Type': 'application/json',
    'accept': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  // giriş işlemleri
  Future<void> login(String email, String password) async {
    final r = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode == 200) {
      _token = (jsonDecode(r.body) as Map)['access_token'] as String?;
      return;
    }
    if (r.statusCode == 422) {
      debugPrint('VALIDATION ERROR: ${r.body}');
      throw Exception('Validation failed: ${r.body}');
    }
    debugPrint('LOGIN ERROR BODY: ${r.body}');
    throw Exception('Login failed with status ${r.statusCode}: ${r.body}');
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final r = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
      }),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 422) throw Exception('Validation failed: ${r.body}');
    if (r.statusCode == 400) throw Exception(jsonDecode(r.body).toString());
    throw Exception('Register failed with status ${r.statusCode}: ${r.body}');
  }

  Future<void> adminLogin(String email, String password) async {
    final r = await http.post(
      Uri.parse('$_base/admin/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode == 200) {
      _token =
          (jsonDecode(r.body) as Map<String, dynamic>)['access_token']
              as String?;
      return;
    }
    if (r.statusCode == 422) {
      debugPrint('ADMIN VALIDATION ERROR: ${r.body}');
      throw Exception('Validation failed: ${r.body}');
    }
    debugPrint('ADMIN LOGIN ERROR BODY: ${r.body}');
    throw Exception(
      'Admin login failed with status ${r.statusCode}: ${r.body}',
    );
  }

  Future<Map<String, dynamic>> me() async {
    final r = await http.get(
      Uri.parse('$_base/me'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200) throw Exception('Me failed: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // token muhabbeti
  static const _kTokenKey = 'jwt';

  Future<void> saveToken() async {
    final sp = await SharedPreferences.getInstance();
    if (_token != null && _token!.isNotEmpty) {
      await sp.setString(_kTokenKey, _token!);
    }
  }

  Future<bool> loadToken() async {
    final sp = await SharedPreferences.getInstance();
    final t = sp.getString(_kTokenKey);
    if (t != null && t.isNotEmpty) {
      _token = t;
      return true;
    }
    return false;
  }

  Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kTokenKey);
    _token = null;
  }

  Future<void> logout() => clearToken();

  //araç işleöleri
  Future<List<dynamic>> listVehicles() async {
    final r = await http.get(
      Uri.parse('$_base/vehicles'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200) throw Exception('Vehicles error: ${r.body}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getVehicle(String id) async {
    final r = await http.get(
      Uri.parse('$_base/vehicles/$id'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200) throw Exception('Get vehicle error: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createVehicle(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$_base/vehicles'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception('Create vehicle error: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateVehicle(
    String id,
    Map<String, dynamic> body,
  ) async {
    final r = await http.put(
      Uri.parse('$_base/vehicles/$id'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception('Update vehicle error: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> deleteVehicle(String id) async {
    final r = await http.delete(
      Uri.parse('$_base/vehicles/$id'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200) throw Exception('Delete vehicle error: ${r.body}');
  }

  // randevus
  Future<List<dynamic>> listBookings() async {
    final r = await http.get(
      Uri.parse('$_base/bookings'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200) throw Exception('Bookings error: ${r.body}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> approveBooking(String id) async {
    final r = await http.post(
      Uri.parse('$_base/bookings/$id/approve'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200)
      throw Exception('Approve booking error: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelBooking(String id) async {
    final r = await http.post(
      Uri.parse('$_base/bookings/$id/cancel'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200) throw Exception('Cancel booking error: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeBooking(String id) async {
    final r = await http.post(
      Uri.parse('$_base/bookings/$id/complete'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200)
      throw Exception('Complete booking error: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  //müsaitlik
  Future<List<dynamic>> availability(DateTime from, DateTime to) async {
    final frm = Uri.encodeQueryComponent(from.toUtc().toIso8601String());
    final end = Uri.encodeQueryComponent(to.toUtc().toIso8601String());
    final r = await http.get(
      Uri.parse('$_base/availability?frm=$frm&to=$end'),
      headers: _headers(json: false),
    );
    if (r.statusCode != 200) throw Exception('Availability error: ${r.body}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  // araç görsli yükleme
  Future<String> uploadImage(File file) async {
    final uri = Uri.parse('${AppConstants.BASE_URL}/upload');

    final req = http.MultipartRequest('POST', uri);

    if (token != null && token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.headers['Accept'] = 'application/json';

    final ext = p.extension(file.path).toLowerCase();
    final mediaType = (ext == '.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');

    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: p.basename(file.path),
        contentType: mediaType,
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    debugPrint(
      'UPLOAD RESP ${res.statusCode} ${res.headers['content-type']} ${res.body}',
    );

    if (res.statusCode != 200) {
      throw Exception('Upload error: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['url'] as String;
  }
}
